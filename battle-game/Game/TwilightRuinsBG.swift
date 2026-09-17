import SpriteKit
import UIKit

/// Twilight Ruins battleground — pixel-art backdrop matching the Sniper
/// sheet's "IN GAME EXAMPLE": dusk indigo sky, layered purple mountains,
/// a broken temple ruin on the far right, dark treeline mid, and a
/// mossy grass lane over a brick cliff face.
///
/// Darker + dimmed vs the reference so units and pink tracers pop.
/// Non-repeating: far/mid are ONE wide panorama each (no tiling); the
/// ground uses 4 variants (= 8 unique faces with mirroring) plus uniquely
/// placed vines, stones and glows. Dynamic: twinkling stars, drifting
/// clouds + mist, floating fireflies/pollen, pulsing ruin windows and
/// breathing mushroom glows — all via looping SKActions (no per-frame code).
enum TwilightRuinsBG {

    // MARK: - Palette (dimmed dusk)

    private static let skyTop = UIColor(red: 0.035, green: 0.045, blue: 0.13, alpha: 1)
    private static let skyMid = UIColor(red: 0.11, green: 0.10, blue: 0.27, alpha: 1)
    private static let skyLow = UIColor(red: 0.26, green: 0.20, blue: 0.42, alpha: 1)
    private static let horizonPink = UIColor(red: 0.52, green: 0.30, blue: 0.52, alpha: 1)
    private static let mistBlue = UIColor(red: 0.22, green: 0.28, blue: 0.44, alpha: 1)

    private static let mtnFar = UIColor(red: 0.26, green: 0.27, blue: 0.50, alpha: 1)
    private static let mtnFarRim = UIColor(red: 0.55, green: 0.42, blue: 0.65, alpha: 1)
    private static let mtnNear = UIColor(red: 0.14, green: 0.14, blue: 0.30, alpha: 1)
    private static let ruinBody = UIColor(red: 0.12, green: 0.13, blue: 0.26, alpha: 1)
    private static let ruinRim = UIColor(red: 0.60, green: 0.54, blue: 0.82, alpha: 1)
    private static let ruinGlow = UIColor(red: 0.42, green: 0.88, blue: 1.0, alpha: 1)

    private static let treeDark = UIColor(red: 0.06, green: 0.11, blue: 0.14, alpha: 1)
    private static let treeRim = UIColor(red: 0.16, green: 0.29, blue: 0.28, alpha: 1)

    // Twilight grass (moonlit, dimmed — not sunlit pasture).
    private static let grassHi = UIColor(red: 0.36, green: 0.56, blue: 0.28, alpha: 1)
    private static let grass = UIColor(red: 0.22, green: 0.38, blue: 0.20, alpha: 1)
    private static let grassDk = UIColor(red: 0.12, green: 0.24, blue: 0.14, alpha: 1)
    private static let dirt = UIColor(red: 0.20, green: 0.15, blue: 0.11, alpha: 1)
    private static let dirtDk = UIColor(red: 0.12, green: 0.09, blue: 0.07, alpha: 1)
    private static let dirtLt = UIColor(red: 0.30, green: 0.23, blue: 0.16, alpha: 1)
    private static let stone = UIColor(red: 0.24, green: 0.24, blue: 0.30, alpha: 1)
    private static let lipLight = UIColor(red: 0.75, green: 0.72, blue: 0.90, alpha: 1)
    private static let petalP = UIColor(red: 1.0, green: 0.42, blue: 0.65, alpha: 1)
    private static let petalW = UIColor(red: 0.85, green: 0.85, blue: 0.90, alpha: 1)
    private static let heartY = UIColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 1)
    private static let shroom = UIColor(red: 0.42, green: 0.88, blue: 1.0, alpha: 1)
    private static let outline = UIColor(red: 0.05, green: 0.04, blue: 0.05, alpha: 1)

    // MARK: - Canvas helpers

    private static func fill(_ cg: CGContext, _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: UIColor) {
        cg.setFillColor(c.cgColor)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    private static func render(w: Int, h: Int, draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format)
            .image { ctx in draw(ctx.cgContext) }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
    }

    private static func hash(_ x: Int, _ y: Int, _ s: Int) -> Int {
        abs((x &* 73856093) ^ (y &* 19349663) ^ (s &* 83492791)) % 100
    }

    // MARK: - Sky (screen-locked)

    /// Gradient + moon + stars + drifting clouds + horizon glow + vignette.
    static func buildSky(in layer: SKNode, sceneSize: CGSize) {
        // Dithered vertical gradient: deep indigo -> purple -> dim pink band -> mist.
        let grad = render(w: 2, h: 256) { cg in
            for y in 0..<256 {
                let t = CGFloat(y) / 255 // 0 top -> 1 bottom (row 0 = top)
                let c: UIColor
                switch t {
                case 0..<0.45:
                    let k = t / 0.45
                    c = blend(skyTop, skyMid, k)
                case 0.45..<0.72:
                    let k = (t - 0.45) / 0.27
                    c = blend(skyMid, skyLow, k)
                case 0.72..<0.86:
                    let k = (t - 0.72) / 0.14
                    c = blend(skyLow, horizonPink, k * 0.55)
                default:
                    let k = (t - 0.86) / 0.14
                    c = blend(horizonPink, mistBlue, 0.55 + k * 0.45)
                }
                // Slight dither so bands don't show on device.
                let dither: CGFloat = (y % 2 == 0) ? 0.004 : -0.004
                fill(cg, 0, y, 2, 1, c.adjusted(by: dither))
            }
        }
        grad.filteringMode = .linear
        let sky = SKSpriteNode(texture: grad)
        sky.size = CGSize(width: sceneSize.width * 1.25, height: sceneSize.height * 1.5)
        sky.zPosition = 0
        layer.addChild(sky)

        let W = sceneSize.width, H = sceneSize.height

        // Moon: pale lavender disc + halo, upper right. Dimmed for mood.
        let moon = SKShapeNode(circleOfRadius: 26)
        moon.fillColor = SKColor(red: 0.82, green: 0.80, blue: 0.94, alpha: 0.95)
        moon.strokeColor = .clear
        moon.position = CGPoint(x: W * 0.30, y: H * 0.30)
        moon.zPosition = 1
        layer.addChild(moon)
        let halo = SKShapeNode(circleOfRadius: 52)
        halo.fillColor = SKColor(red: 0.55, green: 0.52, blue: 0.85, alpha: 0.14)
        halo.strokeColor = .clear
        halo.position = moon.position
        halo.zPosition = 1
        layer.addChild(halo)
        halo.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 3.2), .fadeAlpha(to: 1.0, duration: 3.2),
        ])))
        // Moon craters (pixel blocks).
        for (dx, dy, r) in [(-8, 5, 5), (6, -4, 4), (2, 9, 3)] as [(CGFloat, CGFloat, CGFloat)] {
            let c = SKShapeNode(circleOfRadius: r)
            c.fillColor = SKColor(red: 0.68, green: 0.66, blue: 0.82, alpha: 0.8)
            c.strokeColor = .clear
            c.position = CGPoint(x: moon.position.x + dx, y: moon.position.y + dy)
            c.zPosition = 2
            layer.addChild(c)
        }

        // Stars: ~90 pixel dots, upper 2/3, gentle twinkle. Pink/white mix.
        var rng = SeededRNG(seed: 20260917)
        for i in 0..<90 {
            let sx = rng.cgFloat(in: -W * 0.6...W * 0.6)
            let sy = rng.cgFloat(in: -H * 0.05...H * 0.68)
            let s: CGFloat = rng.cgFloat(in: 1.5...3.2)
            let pink = rng.int(in: 0...3) == 0
            let star = SKSpriteNode(color: pink
                ? SKColor(red: 1, green: 0.55, blue: 0.8, alpha: 0.9)
                : SKColor(white: 0.92, alpha: 0.9),
                size: CGSize(width: s, height: s))
            star.position = CGPoint(x: sx, y: sy)
            star.zPosition = 1
            layer.addChild(star)
            let wait = SKAction.wait(forDuration: rng.double(in: 0...2.5))
            let dim = SKAction.fadeAlpha(to: 0.15, duration: rng.double(in: 0.7...1.8))
            let bright = SKAction.fadeAlpha(to: 0.95, duration: rng.double(in: 0.7...1.8))
            star.run(.repeatForever(.sequence([wait, dim, bright])))
            _ = i
        }

        // Horizon glow band: faint pink light sitting over the mountains.
        let glowTex = render(w: 64, h: 8) { cg in
            for x in 0..<64 {
                let edge = abs(CGFloat(x) - 32) / 32 // 0 center -> 1 edge
                cg.setFillColor(UIColor(red: 1, green: 0.42, blue: 0.66, alpha: 0.20 * (1 - edge)).cgColor)
                cg.fill(CGRect(x: x, y: 0, width: 1, height: 8))
            }
        }
        glowTex.filteringMode = .linear
        let glow = SKSpriteNode(texture: glowTex)
        glow.size = CGSize(width: W * 0.9, height: 44)
        glow.position = CGPoint(x: 0, y: -H * 0.10)
        glow.zPosition = 2
        layer.addChild(glow)
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.6, duration: 4.0), .fadeAlpha(to: 1.0, duration: 4.0),
        ])))

        // Drifting clouds: 5 long wispy streaks, pink-purple, very dim.
        for i in 0..<5 {
            let cw = W * rng.cgFloat(in: 0.35...0.6)
            let cloud = SKSpriteNode(color: SKColor(red: 0.45, green: 0.32, blue: 0.55,
                                                   alpha: 0.16),
                                     size: CGSize(width: cw, height: rng.cgFloat(in: 10...22)))
            cloud.position = CGPoint(x: rng.cgFloat(in: -W * 0.6...W * 0.6),
                                     y: H * rng.cgFloat(in: 0.05...0.42))
            cloud.zPosition = 2
            layer.addChild(cloud)
            // Soft ends via scale pulse + slow drift loop.
            let drift = SKAction.moveBy(x: rng.cgFloat(in: -90...90), y: 0,
                                        duration: rng.double(in: 9...16))
            cloud.run(.repeatForever(.sequence([drift, drift.reversed()])))
        }

        // Distant birds: tiny dark chevrons gliding across, very slow.
        for i in 0..<3 {
            let bird = SKLabelNode(fontNamed: "Helvetica-Bold")
            bird.text = "﹏"
            bird.fontSize = 10
            bird.fontColor = SKColor(white: 0.1, alpha: 0.7)
            bird.position = CGPoint(x: -W * 0.5 + CGFloat(i) * W * 0.3, y: H * (0.22 + Double(i) * 0.05))
            bird.zPosition = 2
            layer.addChild(bird)
            let fly = SKAction.moveBy(x: W * 0.25, y: -8, duration: 14 + Double(i) * 4)
            let back = SKAction.moveBy(x: -W * 0.25, y: 8, duration: 0.01)
            bird.run(.repeatForever(.sequence([fly, back])))
        }

        // Cinematic vignette: darkens edges so the lane feels dim + focused.
        let vig = render(w: 128, h: 128) { cg in
            for px in 0..<128 {
                for py in 0..<128 {
                    let dx = (CGFloat(px) - 64) / 64, dy = (CGFloat(py) - 64) / 64
                    let d = min(1, sqrt(dx * dx + dy * dy))
                    let a: CGFloat = max(0, d - 0.55) * 0.75
                    cg.setFillColor(UIColor(white: 0, alpha: a).cgColor)
                    cg.fill(CGRect(x: px, y: 127 - py, width: 1, height: 1))
                }
            }
        }
        vig.filteringMode = .linear
        let vigNode = SKSpriteNode(texture: vig)
        vigNode.size = CGSize(width: W * 1.25, height: H * 1.5)
        vigNode.zPosition = 50
        layer.addChild(vigNode)
    }

    // MARK: - Far panorama (ONE strip, never tiled)

    /// Single wide pixel panorama: hazy peaks behind, dark jagged range in
    /// front, broken temple ruin parked on the far right (like the sheet),
    /// pine spires far left. Rendered once at low res for chunky pixels.
    static func buildFar(in layer: SKNode, sceneSize: CGSize) {
        let travel = Balance.levelWidth * Balance.parallaxFar
        let panoW: CGFloat = sceneSize.width + travel + 500
        // Low-res canvas -> chunky pixels when stretched with .nearest.
        let PW = 800, PH = 190
        let tex = render(w: PW, h: PH) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: PW, height: PH))
            // Back range: soft wide peaks.
            let back: [(x: Int, peak: Int, half: Int)] = [
                (60, 128, 90), (190, 148, 110), (330, 120, 80),
                (470, 152, 120), (610, 138, 95), (730, 150, 90),
            ]
            for b in back {
                for px in (b.x - b.half)..<(b.x + b.half) {
                    guard px >= 0 && px < PW else { continue }
                    let k = 1 - abs(CGFloat(px - b.x)) / CGFloat(b.half)
                    let top = b.peak - Int(k * 52)
                    fill(cg, px, top, 1, PH - top, mtnFar)
                    if hash(px, 1, 5) < 30 { fill(cg, px, top, 1, 2, mtnFarRim) }
                }
            }
            // Snow/pink caps on the tallest.
            for b in back where b.peak > 140 {
                for px in (b.x - 14)..<(b.x + 14) {
                    guard px >= 0 && px < PW else { continue }
                    fill(cg, px, b.peak - 52, 1, 3, UIColor(red: 0.72, green: 0.58, blue: 0.78, alpha: 1))
                }
            }
            // Front range: darker, jagged.
            let front: [(x: Int, peak: Int, half: Int)] = [
                (30, 96, 60), (120, 112, 70), (230, 92, 55),
                (340, 110, 75), (450, 96, 60), (560, 108, 70), (700, 100, 80), (780, 112, 50),
            ]
            for f in front {
                for px in (f.x - f.half)..<(f.x + f.half) {
                    guard px >= 0 && px < PW else { continue }
                    let jag = hash(px, 9, 3) < 20 ? 6 : 0
                    let k = 1 - abs(CGFloat(px - f.x)) / CGFloat(f.half)
                    let top = f.peak - Int(k * 44) + jag
                    fill(cg, px, top, 1, PH - top, mtnNear)
                    if hash(px, 2, 8) < 18 { fill(cg, px, top, 1, 1, ruinRim.withAlpha(0.5)) }
                }
            }
            // Far-left pine spires.
            for px in stride(from: 18, to: 150, by: 9) {
                let h = 26 + hash(px, 4, 11) * 22 / 100
                fill(cg, px, 78 - h, 5, h, mtnNear)
                fill(cg, px + 1, 78 - h, 1, 4, treeRim.withAlpha(0.6))
            }
            // The ruin: broken temple tower + arch, far right (~x 640-730).
            // Main shaft.
            fill(cg, 648, 40, 52, 78, ruinBody)
            // Battlements (broken: missing middle merlon).
            fill(cg, 648, 34, 12, 8, ruinBody)
            fill(cg, 676, 32, 12, 10, ruinBody)
            // Side wing + collapsed arch.
            fill(cg, 700, 62, 34, 56, ruinBody)
            fill(cg, 706, 96, 22, 22, UIColor(red: 0.05, green: 0.06, blue: 0.14, alpha: 1)) // arch hole
            fill(cg, 640, 78, 8, 40, ruinBody) // fallen pillar
            // Moonlit right edges.
            fill(cg, 698, 40, 2, 78, ruinRim.withAlpha(0.85))
            fill(cg, 732, 62, 2, 56, ruinRim.withAlpha(0.7))
            fill(cg, 648, 40, 52, 2, ruinRim.withAlpha(0.6))
            // Glowing windows (pulsed at runtime via overlay nodes).
            fill(cg, 664, 58, 8, 12, ruinGlow)
            fill(cg, 664, 84, 8, 8, ruinGlow.withAlpha(0.7))
            fill(cg, 712, 74, 6, 10, ruinGlow.withAlpha(0.8))
            // Cracks.
            for py in stride(from: 46, to: 110, by: 7) {
                fill(cg, 656 + hash(py, 1, 21) * 30 / 100, py, 4, 1, dirtDk.withAlpha(0.8))
            }
            // Mist bed along the base.
            for px in 0..<PW {
                let wobble = hash(px, 7, 2) * 8 / 100
                fill(cg, px, 110 + wobble, 1, 10 - wobble / 2, mistBlue.withAlpha(0.55))
            }
            // Pixel dither where ranges meet the mist.
            for px in 0..<PW where hash(px, 118, 4) < 22 {
                fill(cg, px, 118, 1, 1, mistBlue.withAlpha(0.8))
            }
        }
        let pano = SKSpriteNode(texture: tex)
        pano.anchorPoint = CGPoint(x: 0, y: 0.5)
        pano.size = CGSize(width: panoW, height: sceneSize.height * 0.62)
        pano.position = CGPoint(x: -sceneSize.width * 0.6, y: 0)
        pano.alpha = 0.92 // dimmed into the dusk
        layer.addChild(pano)

        // Ruin window glow overlays: soft pulse (dynamic).
        let winX = -sceneSize.width * 0.6 + panoW * (668.0 / 800.0)
        for (dy, s) in [(-8, 14), (-34, 10)] as [(CGFloat, CGFloat)] {
            let g = SKSpriteNode(color: SKColor(red: 0.42, green: 0.88, blue: 1, alpha: 0.35),
                                 size: CGSize(width: s, height: s * 1.4))
            g.position = CGPoint(x: winX, y: dy)
            g.zPosition = 1
            layer.addChild(g)
            g.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.25, duration: 2.2), .fadeAlpha(to: 0.8, duration: 2.2),
            ])))
        }

        // Dim veil so the panorama sits behind gameplay.
        let veil = SKSpriteNode(color: SKColor(red: 0.05, green: 0.06, blue: 0.16, alpha: 0.38),
                                size: CGSize(width: panoW, height: sceneSize.height * 0.62))
        veil.anchorPoint = CGPoint(x: 0, y: 0.5)
        veil.position = pano.position
        veil.zPosition = 2
        layer.addChild(veil)
    }

    // MARK: - Mid treeline (ONE strip, never tiled)

    /// Dark forest + fallen pillars + drifting mist bands + fireflies.
    static func buildMid(in layer: SKNode, sceneSize: CGSize) {
        let travel = Balance.levelWidth * Balance.parallaxMid
        let panoW: CGFloat = sceneSize.width + travel + 500
        let PW = 800, PH = 90
        let tex = render(w: PW, h: PH) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: PW, height: PH))
            // Canopy: overlapping dark blobs with teal moonlit tops.
            var rng = SeededRNG(seed: 555)
            var x = -10
            while x < PW + 10 {
                let w = rng.int(in: 46...90)
                let h = rng.int(in: 30...58)
                let top = PH - h - rng.int(in: 0...10)
                for px in x..<(x + w) {
                    guard px >= 0 && px < PW else { continue }
                    let edge = abs(CGFloat(px - (x + w / 2))) / CGFloat(w / 2)
                    let colH = Int(CGFloat(h) * (1 - edge * edge * 0.55))
                    fill(cg, px, top + (h - colH), 1, colH, treeDark)
                }
                // Moonlit crown.
                for px in x..<(x + w) where hash(px, top, 6) < 40 {
                    fill(cg, px, top, 1, 2, treeRim.withAlpha(0.8))
                }
                // Trunk slivers.
                if rng.int(in: 0...2) == 0 {
                    fill(cg, x + w / 2, 0, 3, PH - h + 12, treeDark)
                }
                x += w * 3 / 4
            }
            // Fallen ruin pillars breaking the treeline (unique spots).
            for px in [250, 528, 690] {
                let h = 34 + hash(px, 1, 9) * 18 / 100
                fill(cg, px, PH - h - 18, 10, h, ruinBody)
                fill(cg, px + 8, PH - h - 18, 2, h, ruinRim.withAlpha(0.5))
                fill(cg, px - 6, PH - 22, 22, 6, ruinBody) // toppled chunk
            }
            // Firefly dots baked faintly into the canopy.
            for _ in 0..<26 {
                let fx = rng.int(in: 0...(PW - 1))
                let fy = rng.int(in: 8...(PH - 8))
                fill(cg, fx, fy, 1, 1, heartY.withAlpha(0.85))
            }
        }
        let pano = SKSpriteNode(texture: tex)
        pano.anchorPoint = CGPoint(x: 0, y: 0.5)
        pano.size = CGSize(width: panoW, height: sceneSize.height * 0.30)
        pano.position = CGPoint(x: -sceneSize.width * 0.6, y: -sceneSize.height * 0.22)
        pano.alpha = 0.96
        layer.addChild(pano)

        // Drifting mist bands (dynamic, translucent).
        var rng = SeededRNG(seed: 909)
        for i in 0..<4 {
            let band = SKSpriteNode(color: SKColor(red: 0.55, green: 0.62, blue: 0.85,
                                                  alpha: 0.10),
                                    size: CGSize(width: panoW * rng.cgFloat(in: 0.25...0.4),
                                                 height: rng.cgFloat(in: 14...26)))
            band.position = CGPoint(x: rng.cgFloat(in: 0...panoW * 0.6),
                                    y: -sceneSize.height * 0.22 + rng.cgFloat(in: -30...30))
            band.zPosition = 1
            layer.addChild(band)
            let drift = SKAction.moveBy(x: rng.cgFloat(in: 60...140), y: 0,
                                        duration: rng.double(in: 7...12))
            band.run(.repeatForever(.sequence([drift, drift.reversed()])))
            _ = i
        }

        // Live fireflies: warm dots floating above the treeline.
        for i in 0..<14 {
            let f = SKSpriteNode(color: SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.95),
                                 size: CGSize(width: 3, height: 3))
            f.position = CGPoint(x: CGFloat(i) * (panoW / 14) + rng.cgFloat(in: -20...20),
                                 y: -sceneSize.height * 0.22 + rng.cgFloat(in: -10...70))
            f.zPosition = 2
            layer.addChild(f)
            let float_ = SKAction.moveBy(x: rng.cgFloat(in: -24...24),
                                         y: rng.cgFloat(in: 10...34),
                                         duration: rng.double(in: 2.2...4.2))
            f.run(.repeatForever(.sequence([
                .group([float_, .sequence([.fadeAlpha(to: 0.2, duration: 1.6),
                                           .fadeAlpha(to: 1.0, duration: 1.6)])]),
                float_.reversed(),
            ])))
        }
    }

    // MARK: - Ground (twilight lane, 6 variants = no visible repeat)

    static let tileW = 125
    static let tileH = 26
    private static var tileCache: [SKTexture] = []
    private static var cliffCache: [SKTexture] = []

    static func tileTexture(variant: Int) -> SKTexture {
        let v = ((variant % 6) + 6) % 6
        while tileCache.count <= v { tileCache.append(renderTile(variant: tileCache.count)) }
        return tileCache[v]
    }

    /// Realistic mossy turf: irregular moonlit lip, 3-blade tuft clusters
    /// with shadow, vertical grass gradient, dark topsoil seam with hanging
    /// roots, 3-tone beveled dirt clods, 3-tone pebbles, moss patches,
    /// dew sparkles + fine grain. Row 0 = top.
    private static func renderTile(variant: Int) -> SKTexture {
        render(w: tileW, h: tileH) { cg in
            let W = tileW, H = tileH
            // Grass body with vertical gradient (light crown -> dark root zone).
            for py in 0..<9 {
                let k = CGFloat(py) / 8
                fill(cg, 0, py, W, 1, blend(grassHi, grassDk, k * 0.85))
            }
            // Irregular top edge: 1px bumps so the silhouette isn't a ruler line.
            for px in 0..<W {
                let bump = hash(px, 3, variant) % 2
                if bump == 0 {
                    fill(cg, px, 0, 1, 1, blend(grassHi, lipLight, 0.25))
                } else {
                    fill(cg, px, 0, 1, 1, grassDk)
                    fill(cg, px, 1, 1, 1, blend(grassHi, grass, 0.4))
                }
                if hash(px, 0, variant) < 22 {
                    fill(cg, px, 0, 1, 1, lipLight.withAlpha(0.75)) // moon catch
                }
            }
            // Tuft clusters: 3 blades + 1px shadow at the base (depth cue).
            var tx = 5 + variant * 7
            while tx < W - 6 {
                let th = 2 + hash(tx, 1, variant) % 2 // 2-3px tall
                let lean = hash(tx, 2, variant) % 3 - 1 // -1...1
                for b in -1...1 {
                    let bx = tx + b
                    guard bx >= 0 && bx < W else { continue }
                    fill(cg, bx, 0, 1, th, grassHi)
                    fill(cg, bx, th - 1, 1, 1, grass) // shaded tip base
                    if lean != 0 && th > 2 { fill(cg, bx + lean, 0, 1, 1, grassHi) }
                }
                fill(cg, tx - 1, th, 3, 1, grassDk.withAlpha(0.9)) // contact shadow
                tx += 9 + hash(tx, 0, variant) % 5
            }
            // Speckle + moss patches in the turf.
            for px in 3..<(W - 3) {
                for py in 2..<9 {
                    let r = hash(px, py, variant)
                    if r < 10 { fill(cg, px, py, 1, 1, grassDk) }
                    else if r >= 30 && r < 34 { fill(cg, px, py, 2, 1, blend(grass, heartY, 0.18)) } // dry moss
                    else if r > 96 && py > 5 {
                        // 3-tone pebble: highlight / body / shadow.
                        fill(cg, px, py, 2, 1, stone)
                        fill(cg, px, py - 1, 2, 1, lipLight.withAlpha(0.55))
                        fill(cg, px, py + 1, 2, 1, outline.withAlpha(0.6))
                    }
                }
            }
            // Variant dressing — each face gets its own story:
            switch variant {
            case 0: // pink sniper flowers, shaded stems
                for fx in [20, 66, 104] {
                    fill(cg, fx, 5, 1, 3, grassDk)
                    fill(cg, fx + 1, 6, 1, 2, grass)
                    fill(cg, fx - 1, 3, 3, 2, petalP)
                    fill(cg, fx - 1, 3, 3, 1, petalP.withAlpha(0.7)) // lit petal edge
                    fill(cg, fx, 3, 1, 1, heartY)
                    fill(cg, fx - 1, 5, 3, 1, outline.withAlpha(0.5)) // ground shadow
                }
            case 1: // glowing cyan mushrooms with gills + halo baked in
                for fx in [34, 92] {
                    fill(cg, fx, 5, 1, 3, petalW)
                    fill(cg, fx - 2, 3, 5, 2, shroom)
                    fill(cg, fx - 2, 3, 5, 1, UIColor(white: 1, alpha: 0.75))
                    fill(cg, fx - 1, 5, 3, 1, dirtDk.withAlpha(0.7)) // gill shade
                    fill(cg, fx, 2, 1, 1, UIColor(white: 1, alpha: 0.95))
                    fill(cg, fx - 3, 4, 7, 1, shroom.withAlpha(0.25)) // spill glow
                }
                fill(cg, 62, 5, 1, 3, grassDk)
                fill(cg, 61, 3, 3, 2, petalW)
                fill(cg, 62, 3, 1, 1, heartY)
            case 2: // embedded beveled stones + roots
                for px in stride(from: 12, to: W - 12, by: 24) {
                    fill(cg, px, 6, 5, 2, stone)
                    fill(cg, px, 5, 5, 1, lipLight.withAlpha(0.6))
                    fill(cg, px, 8, 5, 1, outline.withAlpha(0.65))
                    fill(cg, px - 1, 6, 1, 3, grassDk) // soil lip around stone
                    fill(cg, px + 5, 6, 1, 3, grassDk)
                }
                fill(cg, 74, 5, 1, 3, grassDk)
                fill(cg, 73, 3, 3, 2, petalP)
                fill(cg, 74, 3, 1, 1, heartY)
            case 3: // clover runs + dew
                for fx in stride(from: 10, to: W - 10, by: 18) {
                    fill(cg, fx, 5, 2, 1, grassHi)
                    fill(cg, fx, 6, 1, 1, grassDk)
                    fill(cg, fx + 2, 4, 1, 1, lipLight.withAlpha(0.8)) // dew
                }
                for px in stride(from: 8, to: W - 8, by: 15) {
                    if hash(px, 5, 9) < 45 {
                        fill(cg, px, 6, 2, 1, stone)
                        fill(cg, px, 5, 2, 1, lipLight.withAlpha(0.5))
                    }
                }
            case 4: // cracked earth patch: dark fissures in the turf
                for px in stride(from: 16, to: W - 10, by: 26) {
                    fill(cg, px, 4, 6, 1, dirtDk)
                    fill(cg, px + 2, 5, 2, 2, dirtDk.withAlpha(0.9))
                    fill(cg, px, 3, 6, 1, grass) // raised lip beside crack
                }
                fill(cg, 88, 5, 1, 3, grassDk)
                fill(cg, 87, 3, 3, 2, petalW)
                fill(cg, 88, 3, 1, 1, heartY)
            default: // fallen petals + dense grain
                for fx in [26, 70, 108] {
                    fill(cg, fx, 6, 2, 1, petalP.withAlpha(0.85))
                    fill(cg, fx + 1, 5, 1, 1, petalP.withAlpha(0.5))
                }
                for px in 3..<(W - 3) where hash(px, 7, variant) < 12 {
                    fill(cg, px, 7, 1, 1, grassHi.withAlpha(0.7))
                }
            }
            // Topsoil seam: near-black humus line with dangling roots.
            fill(cg, 0, 9, W, 2, UIColor(red: 0.09, green: 0.07, blue: 0.05, alpha: 1))
            for px in stride(from: 4, to: W - 4, by: 7) {
                if hash(px, 9, variant) < 45 {
                    let rl = 1 + hash(px, 10, variant) % 3
                    fill(cg, px, 11, 1, rl, dirtDk)
                }
            }
            // Dirt body: warm base + large soft blotches for realism.
            fill(cg, 0, 11, W, H - 11, dirt)
            for bx in stride(from: 0, to: W, by: 18) {
                if hash(bx, 12, variant) < 50 {
                    fill(cg, bx, 13, 12, 5, dirtLt.withAlpha(0.35)) // lit patch
                } else {
                    fill(cg, bx, 16, 12, 5, dirtDk.withAlpha(0.4)) // sunk patch
                }
            }
            // Beveled clods: highlight top, body, shadow bottom.
            for px in 3..<(W - 3) {
                for py in 12..<(H - 1) {
                    let r = hash(px, py, variant + 7)
                    if r < 8 {
                        fill(cg, px, py, 3, 2, dirtLt)
                        fill(cg, px, py, 3, 1, lipLight.withAlpha(0.25))
                        fill(cg, px, py + 2, 3, 1, dirtDk)
                    } else if r > 94 {
                        fill(cg, px, py, 2, 1, dirtLt.withAlpha(0.8))
                    } else if r >= 40 && r < 43 {
                        fill(cg, px, py, 1, 3, dirtDk) // root
                    }
                }
            }
            // Staggered brick coursing in the lower dirt (retaining-wall feel).
            let courseY = H - 8
            for px in 0..<W {
                let offset = ((courseY % 2 == 0) ? 0 : 8)
                if (px + offset) % 16 == 0 { fill(cg, px, courseY, 1, 6, dirtDk.withAlpha(0.85)) }
            }
            fill(cg, 0, courseY, W, 1, dirtDk.withAlpha(0.7))
            // Fine grain over everything + AO at the very bottom.
            for px in stride(from: 0, to: W, by: 3) {
                for py in stride(from: 11, to: H - 1, by: 3) {
                    if hash(px, py, variant + 31) < 14 {
                        fill(cg, px, py, 1, 1, UIColor(white: 1, alpha: 0.05))
                    }
                }
            }
            fill(cg, 0, H - 2, W, 1, outline.withAlpha(0.55))
            fill(cg, 0, H - 1, W, 1, outline)
        }
    }

    /// Textured cliff band: beveled bricks + moss streaks + cracks + AO.
    /// Tiled horizontally beneath the turf tiles for a real cut-bank read.
    private static func cliffTexture(variant: Int) -> SKTexture {
        let v = ((variant % 3) + 3) % 3
        while cliffCache.count <= v {
            let idx = cliffCache.count
            cliffCache.append(render(w: 120, h: 40) { cg in
                // Base gradient: lit top -> deep shadow.
                for py in 0..<40 {
                    let k = CGFloat(py) / 39
                    fill(cg, 0, py, 120, 1, blend(
                        UIColor(red: 0.16, green: 0.12, blue: 0.10, alpha: 1),
                        UIColor(red: 0.05, green: 0.04, blue: 0.05, alpha: 1), k))
                }
                // Brick courses with bevel: light top edge, dark bottom + mortar.
                for row in 0..<4 {
                    let by = 4 + row * 9
                    fill(cg, 0, by, 120, 1, lipLight.withAlpha(0.14))
                    fill(cg, 0, by + 7, 120, 1, outline.withAlpha(0.55))
                    let stagger = (row % 2 == 0) ? 0 : 15
                    var vx = stagger
                    while vx < 120 {
                        fill(cg, vx, by, 1, 7, dirtDk.withAlpha(0.9))
                        // Brick face shading: left light, right shade.
                        fill(cg, vx + 1, by + 1, 1, 5, dirtLt.withAlpha(0.30))
                        vx += 30
                    }
                }
                // Moss streaks bleeding down from the top.
                for px in stride(from: 2, to: 118, by: 9) {
                    if hash(px, 1, idx) < 38 {
                        let len = 4 + hash(px, 2, idx) % 12
                        for k in 0..<len {
                            fill(cg, px, 1 + k, 2, 1,
                                 blend(grassDk, grass, CGFloat(k) / CGFloat(max(1, len))).withAlpha(0.75))
                        }
                    }
                }
                // Cracks + embedded stones with highlight/shadow.
                for _ in 0..<4 {
                    let cx = hash(cliffCache.count * 7 + 1, 2, idx + 3) % 110 + 4
                    let cy = 8 + hash(cx, 5, idx) % 24
                    fill(cg, cx, cy, 1, 5, outline.withAlpha(0.7))
                    if hash(cx, cy, idx) < 40 { fill(cg, cx + 1, cy + 2, 1, 1, dirtLt.withAlpha(0.6)) }
                }
                for _ in 0..<5 {
                    let sx = hash(3, 7, idx + cliffCache.count) % 112 + 4
                    let sy = 10 + hash(sx, 11, idx) % 24
                    fill(cg, sx, sy, 4, 3, stone)
                    fill(cg, sx, sy - 1, 4, 1, lipLight.withAlpha(0.5))
                    fill(cg, sx, sy + 3, 4, 1, outline.withAlpha(0.6))
                    _ = sy
                }
                // Grain.
                for px in stride(from: 0, to: 120, by: 4) {
                    for py in stride(from: 0, to: 40, by: 4) {
                        if hash(px, py, idx + 51) < 12 {
                            fill(cg, px, py, 1, 1, UIColor(white: 1, alpha: 0.05))
                        }
                    }
                }
            })
        }
        return cliffCache[v]
    }

    /// Full ground build: 6-variant turf tiles + textured brick cliff +
    /// contact AO + washes + unique scatter (stones, vines, shroom glows, pollen).
    static func buildGround(in world: SKNode) {
        let tileW: CGFloat = 500
        let tileH: CGFloat = 104 // 125x26 @4x
        var x: CGFloat = 0
        var i = 0
        while x < Balance.levelWidth {
            let tile = SKSpriteNode(texture: tileTexture(variant: i))
            tile.anchorPoint = CGPoint(x: 0, y: 1)
            tile.size = CGSize(width: tileW, height: tileH)
            if i % 6 == 5 {
                tile.xScale = -1
                tile.position = CGPoint(x: x + tileW, y: Balance.groundTopY)
            } else {
                tile.position = CGPoint(x: x, y: Balance.groundTopY)
            }
            tile.zPosition = 1
            world.addChild(tile)
            x += tileW
            i += 1
        }

        // Moonlit walkable lip (1px catch-light) + soft AO just beneath it.
        let lip = SKSpriteNode(color: SKColor(red: 0.80, green: 0.78, blue: 0.94, alpha: 0.55),
                               size: CGSize(width: Balance.levelWidth, height: 3))
        lip.anchorPoint = CGPoint(x: 0, y: 1)
        lip.position = CGPoint(x: 0, y: Balance.groundTopY + 1)
        lip.zPosition = 2
        world.addChild(lip)
        let ao = SKSpriteNode(color: SKColor(white: 0, alpha: 0.35),
                              size: CGSize(width: Balance.levelWidth, height: 10))
        ao.anchorPoint = CGPoint(x: 0, y: 1)
        ao.position = CGPoint(x: 0, y: Balance.groundTopY - 10)
        ao.zPosition = 2
        world.addChild(ao)
        // Faint pink bounce under the lip (sniper-tracer mood).
        let bounce = SKSpriteNode(color: SKColor(red: 1, green: 0.35, blue: 0.6, alpha: 0.07),
                                  size: CGSize(width: Balance.levelWidth, height: 12))
        bounce.anchorPoint = CGPoint(x: 0, y: 1)
        bounce.position = CGPoint(x: 0, y: Balance.groundTopY - 3)
        bounce.zPosition = 2
        world.addChild(bounce)

        // Textured cliff face: 3 beveled-brick variants tiled under the turf,
        // then a depth gradient so it falls off into darkness.
        let cliffTop = Balance.groundTopY - tileH
        let bandH: CGFloat = 160 // 120x40 @4x
        var cx: CGFloat = 0
        var ci = 0
        while cx < Balance.levelWidth {
            let band = SKSpriteNode(texture: cliffTexture(variant: ci))
            band.anchorPoint = CGPoint(x: 0, y: 1)
            band.size = CGSize(width: 480, height: bandH)
            band.position = CGPoint(x: cx, y: cliffTop)
            band.zPosition = 0
            world.addChild(band)
            cx += 480
            ci += 1
        }
        // Depth falloff over the cliff.
        if cliffTop > 0 {
            let shade = SKSpriteNode(color: SKColor(white: 0, alpha: 0.45),
                                     size: CGSize(width: Balance.levelWidth, height: cliffTop))
            shade.anchorPoint = CGPoint(x: 0, y: 0)
            shade.position = CGPoint(x: 0, y: 0)
            shade.zPosition = 1
            world.addChild(shade)
        }

        // Team washes: very faint so the dusk grade survives.
        let half = Balance.levelWidth / 2
        let washL = SKSpriteNode(color: SKColor(red: 0.3, green: 0.5, blue: 1, alpha: 0.07),
                                 size: CGSize(width: half, height: tileH))
        washL.anchorPoint = CGPoint(x: 0, y: 1)
        washL.position = CGPoint(x: 0, y: Balance.groundTopY)
        washL.zPosition = 2
        world.addChild(washL)
        let washR = SKSpriteNode(color: SKColor(red: 1, green: 0.3, blue: 0.25, alpha: 0.07),
                                 size: CGSize(width: half, height: tileH))
        washR.anchorPoint = CGPoint(x: 0, y: 1)
        washR.position = CGPoint(x: half, y: Balance.groundTopY)
        washR.zPosition = 2
        world.addChild(washR)

        scatterStones(in: world)
        hangVines(in: world)
        scatterGlowShrooms(in: world)
        floatPollen(in: world)
    }

    /// Twilight platform block: moss cap + brick dirt (matches the lane).
    /// Beveled top, moss fringe hanging over the edge, shaded brick body.
    private static var blockTex: SKTexture?
    static func platformTexture() -> SKTexture {
        if let blockTex { return blockTex }
        let tex = render(w: 80, h: 14) { cg in
            // Moss cap with gradient + irregular fringe.
            for py in 0..<5 {
                fill(cg, 0, py, 80, 1, blend(grassHi, grassDk, CGFloat(py) / 4 * 0.8))
            }
            for px in 0..<80 {
                if hash(px, 0, 1) < 30 {
                    fill(cg, px, 0, 1, 1, lipLight.withAlpha(0.7))
                }
                if hash(px, 1, 4) < 18 { fill(cg, px, 5, 1, 1 + hash(px, 2, 4) % 2, grassDk) } // fringe
            }
            var x = 3
            while x < 77 {
                fill(cg, x, 0, 1, 3, grassHi)
                fill(cg, x, 3, 1, 1, grassDk.withAlpha(0.8))
                x += 6
            }
            fill(cg, 20, 3, 3, 2, petalP)
            fill(cg, 21, 3, 1, 1, heartY)
            fill(cg, 19, 5, 5, 1, outline.withAlpha(0.4))
            // Topsoil seam + brick body with bevel.
            fill(cg, 0, 5, 80, 1, UIColor(red: 0.09, green: 0.07, blue: 0.05, alpha: 1))
            fill(cg, 0, 6, 80, 8, dirt)
            fill(cg, 0, 6, 80, 1, dirtLt.withAlpha(0.5)) // top bevel catch
            for px in stride(from: 0, to: 80, by: 16) { fill(cg, px, 6, 1, 7, dirtDk.withAlpha(0.9)) }
            fill(cg, 0, 9, 80, 1, dirtDk.withAlpha(0.7))
            for px in 2..<78 {
                for py in 6..<13 {
                    let r = hash(px, py, 3)
                    if r < 10 {
                        fill(cg, px, py, 3, 2, dirtLt)
                        fill(cg, px, py + 2, 3, 1, dirtDk)
                    } else if r > 92 { fill(cg, px, py, 2, 1, dirtLt.withAlpha(0.8)) }
                }
            }
            // Side + bottom AO: rounded dark rim so blocks float.
            fill(cg, 0, 6, 2, 8, dirtDk)
            fill(cg, 78, 6, 2, 8, dirtDk)
            fill(cg, 0, 6, 2, 1, dirtLt.withAlpha(0.4))
            fill(cg, 0, 13, 80, 1, outline)
            fill(cg, 0, 12, 80, 1, outline.withAlpha(0.5))
        }
        blockTex = tex
        return tex
    }

    // MARK: - Ground scatter (unique placements, clear of structures)

    private static var clearZones: [ClosedRange<CGFloat>] {
        (Balance.playerTowerXs + Balance.enemyTowerXs
         + [Balance.playerBaseX, Balance.heroSpawnX, Balance.enemyBaseX])
            .map { ($0 - 150)...($0 + 150) }
    }

    private static func isClear(_ x: CGFloat) -> Bool {
        !clearZones.contains(where: { $0.contains(x) })
    }

    private static func scatterStones(in world: SKNode) {
        // Realistic boulders: stacked beveled lumps with moonlit tops,
        // dark contact shadow, moss speckle. Kept ankle-high for readability.
        var rng = SeededRNG(seed: 4242)
        var placed = 0, guard_ = 0
        while placed < 26, guard_ < 240 {
            guard_ += 1
            let x = rng.cgFloat(in: 40...(Balance.levelWidth - 40))
            guard isClear(x) else { continue }
            let rock = SKNode()
            rock.position = CGPoint(x: x, y: Balance.groundTopY + 2)
            rock.zPosition = 2
            // Contact shadow grounds the rock.
            let shadow = SKSpriteNode(color: SKColor(white: 0, alpha: 0.4),
                                      size: CGSize(width: 30, height: 5))
            shadow.position = CGPoint(x: 0, y: 1)
            rock.addChild(shadow)
            let lumps = rng.int(in: 3...5)
            for _ in 0..<lumps {
                let s = rng.cgFloat(in: 6...14)
                let tone = rng.cgFloat(in: 0.14...0.30)
                let lump = SKSpriteNode(color: SKColor(white: tone, alpha: 1),
                                        size: CGSize(width: s, height: s * 0.75))
                lump.position = CGPoint(x: rng.cgFloat(in: -12...12), y: rng.cgFloat(in: 3...10))
                rock.addChild(lump)
                // Bevel: moonlit top edge + dark base.
                let hi = SKSpriteNode(color: SKColor(red: 0.80, green: 0.78, blue: 0.94, alpha: 0.5),
                                      size: CGSize(width: s * 0.9, height: 2))
                hi.position = CGPoint(x: lump.position.x, y: lump.position.y + s * 0.38)
                rock.addChild(hi)
                let lo = SKSpriteNode(color: SKColor(white: 0, alpha: 0.45),
                                      size: CGSize(width: s, height: 2))
                lo.position = CGPoint(x: lump.position.x, y: lump.position.y - s * 0.38)
                rock.addChild(lo)
                // Moss speckle on some faces.
                if rng.int(in: 0...2) == 0 {
                    let moss = SKSpriteNode(color: SKColor(red: 0.16, green: 0.32, blue: 0.16, alpha: 1),
                                            size: CGSize(width: s * 0.4, height: 3))
                    moss.position = CGPoint(x: lump.position.x - 1, y: lump.position.y + 1)
                    rock.addChild(moss)
                }
            }
            world.addChild(rock)
            placed += 1
        }
    }

    /// Mossy vines dangling off the cliff edge at unique spots.
    private static func hangVines(in world: SKNode) {
        var rng = SeededRNG(seed: 31337)
        var x: CGFloat = 300
        while x < Balance.levelWidth - 200 {
            x += rng.cgFloat(in: 260...460)
            guard isClear(x) else { continue }
            let len = rng.cgFloat(in: 22...52)
            let vine = SKSpriteNode(color: SKColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1),
                                    size: CGSize(width: 4, height: len))
            vine.anchorPoint = CGPoint(x: 0.5, y: 1)
            vine.position = CGPoint(x: x, y: Balance.groundTopY - 8)
            vine.zPosition = 2
            world.addChild(vine)
            for k in 0..<Int(len / 12) {
                let leaf = SKSpriteNode(color: SKColor(red: 0.20, green: 0.36, blue: 0.18, alpha: 1),
                                        size: CGSize(width: 7, height: 4))
                leaf.position = CGPoint(x: x + (k % 2 == 0 ? 4 : -4),
                                        y: Balance.groundTopY - 14 - CGFloat(k) * 12)
                leaf.zPosition = 2
                world.addChild(leaf)
            }
            // Gentle sway.
            vine.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.06, duration: 2.2), .rotate(toAngle: -0.06, duration: 2.2),
            ])))
        }
    }

    /// Breathing cyan shroom glows (echo the ruin windows).
    private static func scatterGlowShrooms(in world: SKNode) {
        var rng = SeededRNG(seed: 7777)
        var x: CGFloat = 620
        var k = 0
        while x < Balance.levelWidth - 300 {
            x += rng.cgFloat(in: 520...780)
            k += 1
            guard x < Balance.levelWidth - 200, isClear(x) else { continue }
            let stem = SKSpriteNode(color: SKColor(white: 0.85, alpha: 1),
                                    size: CGSize(width: 4, height: 10))
            stem.position = CGPoint(x: x, y: Balance.groundTopY + 7)
            stem.zPosition = 2
            world.addChild(stem)
            let cap = SKSpriteNode(color: SKColor(red: 0.42, green: 0.88, blue: 1, alpha: 1),
                                   size: CGSize(width: 14, height: 7))
            cap.position = CGPoint(x: x, y: Balance.groundTopY + 14)
            cap.zPosition = 2
            world.addChild(cap)
            let halo = SKShapeNode(ellipseOf: CGSize(width: 44, height: 22))
            halo.fillColor = SKColor(red: 0.42, green: 0.88, blue: 1, alpha: 0.12)
            halo.strokeColor = .clear
            halo.position = cap.position
            halo.zPosition = 2
            world.addChild(halo)
            halo.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.4, duration: 1.4 + Double(k % 3) * 0.3),
                .fadeAlpha(to: 1.0, duration: 1.4 + Double(k % 3) * 0.3),
            ])))
        }
    }

    /// Floating pollen/fireflies over the lane (dynamic).
    private static func floatPollen(in world: SKNode) {
        var rng = SeededRNG(seed: 1212)
        for i in 0..<22 {
            let pink = rng.int(in: 0...2) == 0
            let mote = SKSpriteNode(
                color: pink ? SKColor(red: 1, green: 0.55, blue: 0.75, alpha: 0.9)
                    : SKColor(red: 1, green: 0.88, blue: 0.5, alpha: 0.9),
                size: CGSize(width: 3, height: 3))
            let x = rng.cgFloat(in: 0...Balance.levelWidth)
            mote.position = CGPoint(x: x, y: Balance.groundTopY + rng.cgFloat(in: 6...90))
            mote.zPosition = 3
            world.addChild(mote)
            let rise = rng.cgFloat(in: 40...110)
            let drift = rng.cgFloat(in: -30...30)
            let duration = rng.double(in: 2.4...4.8)
            let fly = SKAction.moveBy(x: drift, y: rise, duration: duration)
            let vanish = SKAction.sequence([
                SKAction.wait(forDuration: duration * 0.55),
                SKAction.fadeOut(withDuration: duration * 0.45),
            ])
            let homeX = x
            let reset = SKAction.run {
                mote.position = CGPoint(x: homeX, y: Balance.groundTopY + 6)
            }
            mote.run(.repeatForever(.sequence([
                SKAction.wait(forDuration: Double(i) * 0.2),
                SKAction.group([fly, vanish]),
                reset,
                SKAction.fadeIn(withDuration: 0.4),
            ])))
        }
    }

    // MARK: - Foreground (two-depth front parallax, realistic + subtle)

    /// Factor ~1.28 layer (see Balance): drifts faster than the world so it
    /// reads as camera-near. Three depths inside for a real parallax feel:
    /// far wisps (small, dim) -> mid tufts (detailed clusters + pebbles,
    /// swaying) -> near silhouettes (large, dark, bottom-anchored rocks and
    /// out-of-focus bokeh spores drifting on their own).
    static func buildForeground(in layer: SKNode) {
        var rng = SeededRNG(seed: 6464)
        let span = Balance.levelWidth * Balance.parallaxForeground

        // Depth A — far wisps: tiny dim blades hugging the bottom.
        for i in 0..<70 {
            let x = CGFloat(i) * (span / 70) + rng.cgFloat(in: -10...10)
            let blade = SKSpriteNode(color: SKColor(red: 0.05, green: 0.10, blue: 0.08, alpha: 0.45),
                                     size: CGSize(width: 5, height: rng.cgFloat(in: 14...30)))
            blade.anchorPoint = CGPoint(x: 0.5, y: 0)
            blade.position = CGPoint(x: x, y: 0)
            blade.zRotation = rng.cgFloat(in: -0.10...0.10)
            layer.addChild(blade)
        }

        // Depth B — mid tufts: 3-blade clusters with highlight + shadow,
        // pebbles, tiny moonlit flowers. Gentle sway sells the wind.
        for i in 0..<70 {
            let x = rng.cgFloat(in: 0...span)
            let tuft = SKNode()
            tuft.position = CGPoint(x: x, y: 0)
            let blades = rng.int(in: 3...5)
            for b in 0..<blades {
                let h = rng.cgFloat(in: 30...64)
                let bx = CGFloat(b - blades / 2) * 7 + rng.cgFloat(in: -3...3)
                let blade = SKSpriteNode(color: SKColor(red: 0.05, green: 0.12, blue: 0.08, alpha: 0.75),
                                         size: CGSize(width: 7, height: h))
                blade.anchorPoint = CGPoint(x: 0.5, y: 0)
                blade.position = CGPoint(x: bx, y: 0)
                blade.zRotation = rng.cgFloat(in: -0.14...0.14)
                tuft.addChild(blade)
                // Moonlit edge on one side.
                let edge = SKSpriteNode(color: SKColor(red: 0.45, green: 0.62, blue: 0.42, alpha: 0.5),
                                        size: CGSize(width: 2, height: h * 0.8))
                edge.anchorPoint = CGPoint(x: 0.5, y: 0)
                edge.position = CGPoint(x: bx + 2, y: 0)
                edge.zRotation = blade.zRotation
                tuft.addChild(edge)
            }
            // Pebble + occasional flower at the tuft base.
            if rng.int(in: 0...2) == 0 {
                let peb = SKSpriteNode(color: SKColor(white: 0.16, alpha: 1),
                                       size: CGSize(width: rng.cgFloat(in: 8...16), height: 7))
                peb.position = CGPoint(x: rng.cgFloat(in: -10...10), y: 4)
                tuft.addChild(peb)
            }
            if rng.int(in: 0...4) == 0 {
                let fl = SKSpriteNode(color: SKColor(red: 1, green: 0.45, blue: 0.65, alpha: 0.85),
                                      size: CGSize(width: 6, height: 6))
                fl.position = CGPoint(x: rng.cgFloat(in: -12...12), y: rng.cgFloat(in: 26...48))
                tuft.addChild(fl)
            }
            layer.addChild(tuft)
            let sway = SKAction.sequence([
                .rotate(toAngle: 0.025, duration: rng.double(in: 1.8...3.0)),
                .rotate(toAngle: -0.025, duration: rng.double(in: 1.8...3.0)),
            ])
            tuft.run(.repeatForever(sway))
        }

        // Depth C — near field, kept small + subtle: low thin grass along
        // the bottom edge plus the odd small rounded rock (ellipse, never
        // a box). Sparse so it never hides the fight.
        for i in 0..<40 {
            let x = rng.cgFloat(in: 0...span)
            let blade = SKSpriteNode(color: SKColor(red: 0.04, green: 0.09, blue: 0.06, alpha: 0.5),
                                     size: CGSize(width: 4, height: rng.cgFloat(in: 10...24)))
            blade.anchorPoint = CGPoint(x: 0.5, y: 0)
            blade.position = CGPoint(x: x, y: 0)
            blade.zRotation = rng.cgFloat(in: -0.12...0.12)
            layer.addChild(blade)
        }
        // Occasional small foreground rock: rounded ellipse with a moonlit
        // top rim and soft contact shadow. ~7 across the whole lane.
        for i in 0..<7 {
            let x = CGFloat(i) * (span / 7) + rng.cgFloat(in: -80...80)
            let w = rng.cgFloat(in: 28...52)
            let h = rng.cgFloat(in: 14...22)
            let shadow = SKShapeNode(ellipseOf: CGSize(width: w + 8, height: 6))
            shadow.fillColor = SKColor(white: 0, alpha: 0.35)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: x, y: 3)
            layer.addChild(shadow)
            let rock = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
            rock.fillColor = SKColor(white: 0.09, alpha: 1)
            rock.strokeColor = .clear
            rock.position = CGPoint(x: x, y: h / 2)
            layer.addChild(rock)
            let rim = SKShapeNode(ellipseOf: CGSize(width: w * 0.8, height: 5))
            rim.fillColor = SKColor(red: 0.55, green: 0.55, blue: 0.70, alpha: 0.4)
            rim.strokeColor = .clear
            rim.position = CGPoint(x: x, y: h - 2)
            layer.addChild(rim)
            // A few grass blades sprouting beside the rock.
            for b in 0..<3 {
                let bh = rng.cgFloat(in: 12...22)
                let blade = SKSpriteNode(color: SKColor(red: 0.05, green: 0.11, blue: 0.07, alpha: 0.6),
                                         size: CGSize(width: 4, height: bh))
                blade.anchorPoint = CGPoint(x: 0.5, y: 0)
                blade.position = CGPoint(x: x + rng.cgFloat(in: -w / 2...w / 2), y: 2)
                blade.zRotation = rng.cgFloat(in: -0.15...0.15)
                layer.addChild(blade)
            }
        }

        // Bokeh spores: small soft out-of-focus dots drifting against the
        // parallax — a subtle near-camera depth cue.
        for i in 0..<10 {
            let r = rng.cgFloat(in: 5...11)
            let bokeh = SKShapeNode(circleOfRadius: r)
            bokeh.fillColor = SKColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 0.05)
            bokeh.strokeColor = .clear
            bokeh.position = CGPoint(x: rng.cgFloat(in: 0...span), y: rng.cgFloat(in: 30...220))
            layer.addChild(bokeh)
            let drift = SKAction.moveBy(x: rng.cgFloat(in: -120...120),
                                        y: rng.cgFloat(in: -24...24),
                                        duration: rng.double(in: 6...11))
            bokeh.run(.repeatForever(.sequence([drift, drift.reversed()])))
            _ = i
        }

        // Near-camera fireflies with halos.
        for i in 0..<8 {
            let f = SKSpriteNode(color: SKColor(red: 1, green: 0.85, blue: 0.45, alpha: 0.9),
                                 size: CGSize(width: 4, height: 4))
            f.position = CGPoint(x: CGFloat(i) * (span / 8), y: rng.cgFloat(in: 40...160))
            layer.addChild(f)
            let roam = SKAction.moveBy(x: rng.cgFloat(in: -60...60),
                                       y: rng.cgFloat(in: -20...30),
                                       duration: rng.double(in: 3...5.5))
            f.run(.repeatForever(.sequence([roam, roam.reversed()])))
        }
    }

    // MARK: - Small color helpers

    private static func blend(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t,
                       blue: ab + (bb - ab) * t, alpha: aa + (ba - aa) * t)
    }
}

private extension UIColor {
    func adjusted(by d: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(1, max(0, r + d)), green: min(1, max(0, g + d)),
                       blue: min(1, max(0, b + d)), alpha: a)
    }

    func withAlpha(_ a: CGFloat) -> UIColor {
        withAlphaComponent(a)
    }
}

private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    private mutating func step() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func cgFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let t = CGFloat(step() % 10000) / 10000
        return range.lowerBound + (range.upperBound - range.lowerBound) * t
    }
    mutating func double(in range: ClosedRange<Double>) -> Double {
        let t = Double(step() % 10000) / 10000
        return range.lowerBound + (range.upperBound - range.lowerBound) * t
    }
    mutating func int(in range: ClosedRange<Int>) -> Int {
        let lo = range.lowerBound, hi = range.upperBound
        guard hi > lo else { return lo }
        return lo + Int(step() % UInt64(hi - lo + 1))
    }
}
