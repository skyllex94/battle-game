import SpriteKit

/// Cheap looping snowfall for snowy battlefields (`Balance.snowfall`,
/// Level 20+) — built to cost almost nothing:
/// - ONE small seamless flake texture is baked once (CoreGraphics, flakes
///   wrap-drawn across the edges so the sheet tiles invisibly).
/// - Each sheet is just TWO sprites stacked, scrolling one tile down on a
///   repeatForever action with an instant teleport back — zero per-frame
///   Swift code, no SKShapeNodes, no emitters. All sprites share one
///   texture, so the two sheets batch into a couple of draw runs.
/// - A slow ping-pong `moveBy` provides wind sway without any per-frame
///   logic (each sheet is its own node, so their sways run independently).
/// - The node is screen-locked: the scene merely re-pins its position to
///   the camera once per frame inside updateParallax — exactly like the
///   sky layer.
/// Settings doors: hidden entirely when particles are off or weather FX is
/// off; the LOW quality tier drops the far sheet and thins the flakes.
enum SnowFX {

    /// Screen-locked snow overlay sized for the visible camera rect.
    /// Returns nil when the level has no snowfall, particles are off, or
    /// weather FX is off — the scene adds it only if this returns a node.
    static func buildSnow(sceneSize: CGSize, cameraZoom: CGFloat) -> SKNode? {
        guard Balance.snowfall, GameSettings.particlesEnabled,
              GameSettings.weatherEnabled else { return nil }

        let root = SKNode()
        root.name = "snow"

        // Visible span at the camera's zoom, padded so fall + sway never
        // expose an edge.
        let visW = sceneSize.width / cameraZoom
        let visH = sceneSize.height / cameraZoom
        let tileH = visH + 80

        let quality = GameSettings.effectsQuality
        let texture = flakeTexture(width: visW, height: tileH,
                                   flakeCount: quality.particleScale)

        // Two sheets: far (dim, slow, smaller drift, slightly smaller
        // flakes) + near (bright, fast, bigger). LOW keeps only the near.
        let sheets: [(alpha: CGFloat, speed: CGFloat, drift: CGFloat, zoom: CGFloat, on: Bool)] = [
            (alpha: 0.5, speed: 90, drift: 26, zoom: 0.9, on: quality != .low),
            (alpha: 0.85, speed: 165, drift: 42, zoom: 1.15, on: true),
        ]

        for (i, s) in sheets.enumerated() where s.on {
            let tileW = visW + s.drift * 2 + 40
            let w = tileW * s.zoom
            let h = tileH * s.zoom
            let stackHome = CGPoint(x: -w / 2, y: -h / 2)

            // One node per sheet so each gets its own independent sway.
            let sheet = SKNode()
            sheet.zPosition = i == 0 ? 11 : 18
            sheet.alpha = s.alpha
            let stack = SKNode()
            // Two stacked copies of the seamless texture cover one full
            // loop, so falling exactly one tile resets invisibly.
            for row in 0..<2 {
                let sprite = SKSpriteNode(texture: texture, size: CGSize(width: w, height: h))
                sprite.anchorPoint = CGPoint(x: 0, y: 0)
                sprite.position = CGPoint(x: 0, y: CGFloat(row) * h)
                stack.addChild(sprite)
            }
            stack.position = stackHome
            sheet.addChild(stack)

            // Continuous fall: one tile down + instant seamless reset.
            let fallDuration = Double(h / (s.speed * s.zoom))
            let fallDown = SKAction.moveBy(x: 0, y: -h, duration: fallDuration)
            let fallReset = SKAction.move(to: stackHome, duration: 0)
            let fallLoop = SKAction.repeatForever(.sequence([fallDown, fallReset]))
            stack.run(fallLoop)

            // Wind sway: slow ping-pong on the whole sheet (no reset pop).
            func sway(x: CGFloat) -> SKAction {
                let a = SKAction.moveBy(x: x, y: 0,
                                        duration: 3.4 + Double(i) * 1.1)
                a.timingMode = .easeInEaseOut
                return a
            }
            let swayLoop = SKAction.repeatForever(.sequence([sway(x: s.drift),
                                                             sway(x: -s.drift)]))
            sheet.run(swayLoop)
            root.addChild(sheet)
        }
        return root
    }

    // MARK: - Flake texture (baked once, cached)

    private static var cachedTexture: SKTexture?
    private static var cachedKey = ""

    /// Small seamless sheet of white flakes, wrap-drawn so it tiles on
    /// every edge. Baked at half resolution and stretched back up by the
    /// sprites (linear filtering softens the dots) — a one-time CPU cost
    /// of a few milliseconds per level entry.
    private static func flakeTexture(width: CGFloat, height: CGFloat, flakeCount: Double) -> SKTexture {
        let tw = max(64, Int(width / 2))
        let th = max(64, Int(height / 2))
        let flakeSpan = Double(tw * th) / 4600
        let n = max(16, Int(flakeSpan * max(0.4, flakeCount)))
        let key = "\(tw)x\(th)x\(n)"
        if let cached = cachedTexture, cachedKey == key { return cached }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: tw, height: th), format: format)
            .image { ctx in bakeFlakes(ctx.cgContext, width: tw, height: th, count: n) }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear // soft flakes; stay away from .nearest
        cachedTexture = tex
        cachedKey = key
        return tex
    }

    /// Scatter deterministic white flakes, each 9x wrap-drawn so the
    /// pattern is seamless on all four edges.
    private static func bakeFlakes(_ cg: CGContext, width tw: Int, height th: Int, count n: Int) {
        var state: UInt64 = 0xC0FFEE_0000_2020
        func rng() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) % 10_000) / 10_000
        }
        let w = CGFloat(tw), h = CGFloat(th)
        for _ in 0..<n {
            let x = rng() * w
            let y = rng() * h
            let r = 1.0 + rng() * 1.3 // 2-4.4 pt on screen after the 2x bake
            let a = 0.45 + rng() * 0.5
            cg.setFillColor(UIColor(white: 1, alpha: a).cgColor)
            for dx in [-w, 0, w] {
                for dy in [-h, 0, h] {
                    cg.fillEllipse(in: CGRect(x: x + dx - r, y: y + dy - r,
                                              width: r * 2, height: r * 2))
                }
            }
        }
    }
}
