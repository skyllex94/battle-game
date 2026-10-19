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
    /// The overgrown theme (Level 2) regrades the same dusk concept toward
    /// alien jungle teal-green: same moon/stars/vignette, greener air.
    /// The bastion theme (Level 3) burns it toward timber-ember amber:
    /// same shapes, furnace horizon, russet air.
    /// The dawn theme (Level 4) breaks early morning over the dunes: a
    /// touch brighter overall, pale-gold horizon, warm haze.
    /// The sunscorch theme (Level 5) is high noon: brightest so far,
    /// bleached blue sky, harsh sun, pale horizon, thin haze.
    /// The sandhold theme (Level 6) is desert-keep dusk: burnt-orange
    /// ember grade, fortress silhouette, shadow flyers circling far.
    static func buildSky(in layer: SKNode, sceneSize: CGSize) {
        let theme = Balance.active.theme
        let overgrown = theme == .overgrown
        let bastion = theme == .bastion
        let dawn = theme == .dawn
        let sunscorch = theme == .sunscorch
        let sandhold = theme == .sandhold
        let dunesea = theme == .dunesea
        let oasis = theme == .oasis
        // Golden desert day: bright sky, harsh sun, washed-out stars.
        let brightDay = sunscorch || dunesea || oasis
        let gTop = oasis ? UIColor(red: 0.26, green: 0.50, blue: 0.74, alpha: 1)
            : dunesea ? UIColor(red: 0.30, green: 0.52, blue: 0.75, alpha: 1)
            : sandhold ? UIColor(red: 0.10, green: 0.06, blue: 0.13, alpha: 1)
            : sunscorch ? UIColor(red: 0.32, green: 0.52, blue: 0.78, alpha: 1)
            : overgrown ? UIColor(red: 0.02, green: 0.09, blue: 0.12, alpha: 1)
            : bastion ? UIColor(red: 0.07, green: 0.04, blue: 0.10, alpha: 1)
            : dawn ? UIColor(red: 0.08, green: 0.08, blue: 0.20, alpha: 1) : skyTop
        let gMid = oasis ? UIColor(red: 0.58, green: 0.68, blue: 0.62, alpha: 1)
            : dunesea ? UIColor(red: 0.62, green: 0.66, blue: 0.62, alpha: 1)
            : sandhold ? UIColor(red: 0.28, green: 0.12, blue: 0.11, alpha: 1)
            : sunscorch ? UIColor(red: 0.52, green: 0.66, blue: 0.84, alpha: 1)
            : overgrown ? UIColor(red: 0.05, green: 0.20, blue: 0.21, alpha: 1)
            : bastion ? UIColor(red: 0.20, green: 0.09, blue: 0.12, alpha: 1)
            : dawn ? UIColor(red: 0.22, green: 0.16, blue: 0.30, alpha: 1) : skyMid
        let gLow = oasis ? UIColor(red: 0.94, green: 0.80, blue: 0.52, alpha: 1)
            : dunesea ? UIColor(red: 0.95, green: 0.76, blue: 0.48, alpha: 1)
            : sandhold ? UIColor(red: 0.55, green: 0.25, blue: 0.12, alpha: 1)
            : sunscorch ? UIColor(red: 0.82, green: 0.76, blue: 0.64, alpha: 1)
            : overgrown ? UIColor(red: 0.13, green: 0.30, blue: 0.22, alpha: 1)
            : bastion ? UIColor(red: 0.36, green: 0.17, blue: 0.10, alpha: 1)
            : dawn ? UIColor(red: 0.42, green: 0.28, blue: 0.30, alpha: 1) : skyLow
        let gHorizon = oasis ? UIColor(red: 0.90, green: 0.94, blue: 0.72, alpha: 1)
            : dunesea ? UIColor(red: 1.0, green: 0.86, blue: 0.58, alpha: 1)
            : sandhold ? UIColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
            : sunscorch ? UIColor(red: 1.0, green: 0.92, blue: 0.72, alpha: 1)
            : overgrown ? UIColor(red: 0.38, green: 0.50, blue: 0.28, alpha: 1)
            : bastion ? UIColor(red: 0.80, green: 0.50, blue: 0.22, alpha: 1)
            : dawn ? UIColor(red: 0.95, green: 0.70, blue: 0.45, alpha: 1) : horizonPink
        let gMist = oasis ? UIColor(red: 0.86, green: 0.82, blue: 0.62, alpha: 1)
            : dunesea ? UIColor(red: 0.90, green: 0.74, blue: 0.52, alpha: 1)
            : sandhold ? UIColor(red: 0.40, green: 0.25, blue: 0.18, alpha: 1)
            : sunscorch ? UIColor(red: 0.88, green: 0.80, blue: 0.68, alpha: 1)
            : overgrown ? UIColor(red: 0.15, green: 0.32, blue: 0.28, alpha: 1)
            : bastion ? UIColor(red: 0.30, green: 0.20, blue: 0.15, alpha: 1)
            : dawn ? UIColor(red: 0.35, green: 0.30, blue: 0.32, alpha: 1) : mistBlue
        // Dithered vertical gradient: deep indigo -> purple -> dim pink band -> mist.
        let grad = render(w: 2, h: 256) { cg in
            for y in 0..<256 {
                let t = CGFloat(y) / 255 // 0 top -> 1 bottom (row 0 = top)
                let c: UIColor
                switch t {
                case 0..<0.45:
                    let k = t / 0.45
                    c = blend(gTop, gMid, k)
                case 0.45..<0.72:
                    let k = (t - 0.45) / 0.27
                    c = blend(gMid, gLow, k)
                case 0.72..<0.86:
                    let k = (t - 0.72) / 0.14
                    c = blend(gLow, gHorizon, k * 0.55)
                default:
                    let k = (t - 0.86) / 0.14
                    c = blend(gHorizon, gMist, 0.55 + k * 0.45)
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
        // Sunscorch: harsh high-noon sun instead — bigger, warm white.
        // Dunesea: big low golden sun hanging over the dune sea.
        let sunY: CGFloat = brightDay ? 0.22 : 0.30
        let moon = SKShapeNode(circleOfRadius: brightDay ? 34 : 26)
        moon.fillColor = brightDay
            ? SKColor(red: 1.0, green: 0.95, blue: 0.82, alpha: 1.0)
            : SKColor(red: 0.82, green: 0.80, blue: 0.94, alpha: 0.95)
        moon.strokeColor = .clear
        moon.position = CGPoint(x: W * 0.30, y: H * sunY)
        moon.zPosition = 1
        layer.addChild(moon)
        let halo = SKShapeNode(circleOfRadius: brightDay ? 70 : 52)
        halo.fillColor = brightDay
            ? SKColor(red: 1.0, green: 0.90, blue: 0.65, alpha: 0.30)
            : SKColor(red: 0.55, green: 0.52, blue: 0.85, alpha: 0.14)
        halo.strokeColor = .clear
        halo.position = moon.position
        halo.zPosition = 1
        layer.addChild(halo)
        halo.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 3.2), .fadeAlpha(to: 1.0, duration: 3.2),
        ])))
        // Moon craters (pixel blocks). Skipped under bright day.
        if !brightDay {
            for (dx, dy, r) in [(-8, 5, 5), (6, -4, 4), (2, 9, 3)] as [(CGFloat, CGFloat, CGFloat)] {
                let c = SKShapeNode(circleOfRadius: r)
                c.fillColor = SKColor(red: 0.68, green: 0.66, blue: 0.82, alpha: 0.8)
                c.strokeColor = .clear
                c.position = CGPoint(x: moon.position.x + dx, y: moon.position.y + dy)
                c.zPosition = 2
                layer.addChild(c)
            }
        }

        // Stars: ~90 pixel dots, upper 2/3, gentle twinkle. Pink/white mix.
        // Bright day washes them out — a few faint ones only.
        var rng = SeededRNG(seed: 20260917)
        let starCount = brightDay ? 18 : 90
        for i in 0..<starCount {
            let sx = rng.cgFloat(in: -W * 0.6...W * 0.6)
            let sy = rng.cgFloat(in: -H * 0.05...H * 0.68)
            let s: CGFloat = rng.cgFloat(in: 1.5...3.2)
            let pink = rng.int(in: 0...3) == 0
            let star = SKSpriteNode(color: pink
                ? SKColor(red: 1, green: 0.55, blue: 0.8, alpha: brightDay ? 0.25 : 0.9)
                : SKColor(white: 0.92, alpha: brightDay ? 0.25 : 0.9),
                size: CGSize(width: s, height: s))
            star.position = CGPoint(x: sx, y: sy)
            star.zPosition = 1
            layer.addChild(star)
            let wait = SKAction.wait(forDuration: rng.double(in: 0...2.5))
            let dim = SKAction.fadeAlpha(to: 0.15, duration: rng.double(in: 0.7...1.8))
            let bright = SKAction.fadeAlpha(to: brightDay ? 0.3 : 0.95, duration: rng.double(in: 0.7...1.8))
            star.run(.repeatForever(.sequence([wait, dim, bright])))
            _ = i
        }

        // Horizon glow band: faint pink light sitting over the mountains
        // (lime-gold breath over the jungle for the overgrown theme,
        // furnace amber for the bastion theme, pale gold for dawn,
        // bleached noon glare for sunscorch, ember blaze for sandhold).
        let glowTex = render(w: 64, h: 8) { cg in
            for x in 0..<64 {
                let edge = abs(CGFloat(x) - 32) / 32 // 0 center -> 1 edge
                if oasis {
                    cg.setFillColor(UIColor(red: 0.92, green: 0.95, blue: 0.70, alpha: 0.30 * (1 - edge)).cgColor)
                } else if dunesea {
                    cg.setFillColor(UIColor(red: 1, green: 0.85, blue: 0.55, alpha: 0.32 * (1 - edge)).cgColor)
                } else if sandhold {
                    cg.setFillColor(UIColor(red: 1, green: 0.50, blue: 0.20, alpha: 0.30 * (1 - edge)).cgColor)
                } else if sunscorch {
                    cg.setFillColor(UIColor(red: 1, green: 0.92, blue: 0.70, alpha: 0.30 * (1 - edge)).cgColor)
                } else if overgrown {
                    cg.setFillColor(UIColor(red: 0.55, green: 0.9, blue: 0.45, alpha: 0.16 * (1 - edge)).cgColor)
                } else if bastion {
                    cg.setFillColor(UIColor(red: 1, green: 0.55, blue: 0.25, alpha: 0.20 * (1 - edge)).cgColor)
                } else if dawn {
                    cg.setFillColor(UIColor(red: 1, green: 0.75, blue: 0.45, alpha: 0.22 * (1 - edge)).cgColor)
                } else {
                    cg.setFillColor(UIColor(red: 1, green: 0.42, blue: 0.66, alpha: 0.20 * (1 - edge)).cgColor)
                }
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

        // Drifting clouds: 5 long wispy streaks, pink-purple, very dim
        // (teal-green for the overgrown theme, ember for the bastion theme,
        // warm pale for dawn, bright white-gold for sunscorch, burnt
        // ember for sandhold).
        for i in 0..<5 {
            let cw = W * rng.cgFloat(in: 0.35...0.6)
            let cloud = SKSpriteNode(color: oasis
                ? SKColor(red: 0.98, green: 0.96, blue: 0.84, alpha: 0.26)
                : dunesea
                ? SKColor(red: 1.0, green: 0.92, blue: 0.78, alpha: 0.30)
                : sandhold
                ? SKColor(red: 0.65, green: 0.30, blue: 0.18, alpha: 0.20)
                : sunscorch
                ? SKColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 0.35)
                : overgrown
                ? SKColor(red: 0.30, green: 0.48, blue: 0.38, alpha: 0.16)
                : bastion
                ? SKColor(red: 0.55, green: 0.35, blue: 0.25, alpha: 0.16)
                : dawn
                ? SKColor(red: 0.60, green: 0.50, blue: 0.45, alpha: 0.16)
                : SKColor(red: 0.45, green: 0.32, blue: 0.55, alpha: 0.16),
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
        // Sunscorch skips most of it — high noon stays bright and open.
        let vig = render(w: 128, h: 128) { cg in
            for px in 0..<128 {
                for py in 0..<128 {
                    let dx = (CGFloat(px) - 64) / 64, dy = (CGFloat(py) - 64) / 64
                    let d = min(1, sqrt(dx * dx + dy * dy))
                    let a: CGFloat = max(0, d - 0.55) * (brightDay ? 0.25 : 0.75)
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
            // Oasis theme: bright warm range + green oases, ruin arches
            // and a bone field instead of the dark mountain/forest sheet.
            if Balance.active.theme == .oasis {
                drawOasisRange(cg, PW: PW, PH: PH)
            } else {
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
            // Overgrown/bastion signature: a colossal world-tree rising behind
            // the range, canopy glowing faintly with spores (Level 2 identity,
            // timber great-tree for Level 3's Thornwood). Dawn stays open.
            if Balance.active.theme == .overgrown || Balance.active.theme == .bastion {
                let tx = 400
                fill(cg, tx - 6, 30, 12, 92, mtnNear) // trunk
                fill(cg, tx - 6, 30, 3, 92, treeRim.withAlpha(0.5)) // moonlit edge
                for r in 0..<5 { // tiered canopy shelves
                    let cy = 18 + r * 8
                    let half = 64 - r * 9
                    fill(cg, tx - half, cy, half * 2, 7, treeDark)
                    fill(cg, tx - half, cy, half * 2, 2, treeRim.withAlpha(0.7))
                }
                for s in 0..<14 { // spore lights in the branches
                    let sx = tx - 56 + hash(s, 3, 31) * 112 / 100
                    let sy = 16 + hash(s, 7, 32) * 40 / 100
                    fill(cg, sx, sy, 2, 2, heartY.withAlpha(0.8))
                }
                // Hanging moss strands off the lowest shelf.
                for mx in stride(from: tx - 48, to: tx + 48, by: 8) {
                    let len = 6 + hash(mx, 1, 33) % 10
                    fill(cg, mx, 46, 2, len, treeDark)
                }
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
            // Sandhold signature: desert-keep citadel on the far LEFT —
            // blocky sandstone hold with twin watchtowers, battlements,
            // arched gate, ember windows, war banners on the ramparts.
            if Balance.active.theme == .sandhold {
                let stone = UIColor(red: 0.22, green: 0.14, blue: 0.12, alpha: 1)
                let stoneRim = UIColor(red: 0.95, green: 0.55, blue: 0.28, alpha: 1)
                let ember = UIColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 1)
                // Twin watchtowers.
                fill(cg, 48, 28, 26, 96, stone)
                fill(cg, 122, 28, 26, 96, stone)
                for tx in [48, 122] {
                    // Battlement merlons.
                    for m in stride(from: tx, to: tx + 26, by: 8) {
                        fill(cg, m, 22, 5, 7, stone)
                    }
                    fill(cg, tx + 24, 28, 2, 96, stoneRim.withAlpha(0.7))
                    // Arrow slits.
                    for sy in stride(from: 44, to: 100, by: 14) {
                        fill(cg, tx + 11, sy, 3, 7, UIColor(red: 0.05, green: 0.04, blue: 0.06, alpha: 1))
                    }
                }
                // Main keep block between the towers.
                fill(cg, 70, 44, 56, 80, stone)
                for m in stride(from: 70, to: 126, by: 10) {
                    fill(cg, m, 38, 6, 7, stone)
                }
                fill(cg, 124, 44, 2, 80, stoneRim.withAlpha(0.6))
                fill(cg, 70, 44, 56, 2, stoneRim.withAlpha(0.5))
                // Arched gate.
                fill(cg, 90, 92, 16, 32, UIColor(red: 0.05, green: 0.04, blue: 0.06, alpha: 1))
                fill(cg, 90, 92, 16, 3, stoneRim.withAlpha(0.6))
                // Ember windows (pulsed at runtime via the ruin overlays).
                fill(cg, 80, 58, 6, 9, ember)
                fill(cg, 110, 58, 6, 9, ember)
                fill(cg, 97, 70, 8, 8, ember.withAlpha(0.8))
                // War banners on the ramparts.
                for bx in [56, 134] {
                    fill(cg, bx, 8, 2, 16, stone)
                    fill(cg, bx + 2, 8, 10, 6, UIColor(red: 0.75, green: 0.15, blue: 0.10, alpha: 1))
                }
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
        // Sunscorch stays bright: thin warm haze instead of dusk dim.
        // Sandhold keeps a dark warm dusk over the keep.
        // Dunesea keeps it bright: thin golden haze over the mesas.
        let theme0 = Balance.active.theme
        let veil = SKSpriteNode(color: theme0 == .sunscorch
            ? SKColor(red: 0.90, green: 0.82, blue: 0.66, alpha: 0.18)
            : theme0 == .dunesea
            ? SKColor(red: 0.95, green: 0.80, blue: 0.55, alpha: 0.20)
            : theme0 == .oasis
            ? SKColor(red: 0.86, green: 0.92, blue: 0.68, alpha: 0.20)
            : theme0 == .sandhold
            ? SKColor(red: 0.10, green: 0.06, blue: 0.08, alpha: 0.30)
            : SKColor(red: 0.05, green: 0.06, blue: 0.16, alpha: 0.38),
                                size: CGSize(width: panoW, height: sceneSize.height * 0.62))
        veil.anchorPoint = CGPoint(x: 0, y: 0.5)
        veil.position = pano.position
        veil.zPosition = 2
        layer.addChild(veil)

        // Sandhold shadow flyers: dark glider silhouettes circling the far
        // range — slow wing beats, glide + bob loops, looping forever.
        if theme0 == .sandhold {
            var frng = SeededRNG(seed: 60606)
            for i in 0..<5 {
                let s = frng.cgFloat(in: 0.6...1.3)
                let flyer = SKNode()
                flyer.setScale(s)
                flyer.alpha = 0.55
                let wingPath = CGMutablePath()
                wingPath.move(to: CGPoint(x: -26, y: 0))
                wingPath.addLine(to: CGPoint(x: -6, y: 7))
                wingPath.addLine(to: CGPoint(x: 0, y: 0))
                wingPath.addLine(to: CGPoint(x: 6, y: 7))
                wingPath.addLine(to: CGPoint(x: 26, y: 0))
                wingPath.addLine(to: CGPoint(x: 6, y: -3))
                wingPath.addLine(to: CGPoint(x: -6, y: -3))
                wingPath.closeSubpath()
                let wings = SKShapeNode(path: wingPath)
                wings.fillColor = SKColor(white: 0.05, alpha: 1)
                wings.strokeColor = SKColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 0.35)
                wings.lineWidth = 1
                flyer.addChild(wings)
                flyer.position = CGPoint(x: frng.cgFloat(in: -sceneSize.width * 0.5...sceneSize.width * 0.5),
                                         y: frng.cgFloat(in: -20...90))
                flyer.zPosition = 1
                layer.addChild(flyer)
                flyer.run(.repeatForever(.sequence([
                    .scaleY(to: 0.6, duration: 0.9), .scaleY(to: 1.0, duration: 0.9),
                ])))
                let span = sceneSize.width * frng.cgFloat(in: 0.4...0.7)
                let glide = SKAction.moveBy(x: frng.cgFloat(in: -1...1) > 0 ? span : -span,
                                            y: frng.cgFloat(in: -14...14),
                                            duration: frng.double(in: 13...20))
                let bob = SKAction.repeatForever(.sequence([
                    .moveBy(x: 0, y: 12, duration: 2.4),
                    .moveBy(x: 0, y: -12, duration: 2.4),
                ]))
                flyer.run(bob)
                flyer.run(.repeatForever(.sequence([glide, glide.reversed()])))
                _ = i
            }
        }
    }

    // MARK: - Mid treeline (ONE strip, never tiled)

    /// Dark forest + fallen pillars + drifting mist bands + fireflies.
    /// Overgrown theme: lusher double canopy, hanging vines, heavier glow.
    /// Bastion theme: same dense timberline in russet-amber (thornwood
    /// autumn), amber fireflies instead of green.
    /// Dawn theme: open dry treeline (single pass, olive-gold) — the
    /// atoll feels airy after three night woods.
    /// Sunscorch theme: high-noon expanse — lowest, sparsest dry scrub,
    /// bleached rims, heat-dust instead of fireflies.
    /// Sandhold theme: desert-keep dusk — broken sandstone wall chunks in
    /// the scrub line, dead brush, rising ember sparks.
    static func buildMid(in layer: SKNode, sceneSize: CGSize) {
        // Oasis theme: palm-fringed sand ridges with crawling creatures
        // stalking the crest (instead of the bare dune ridges).
        if Balance.active.theme == .oasis {
            buildOasisRidges(in: layer, sceneSize: sceneSize)
            return
        }
        // Dunesea theme skips the treeline: hazy dune-ridge panorama.
        if Balance.active.theme == .dunesea {
            buildDuneRidges(in: layer, sceneSize: sceneSize)
            return
        }
        let travel = Balance.levelWidth * Balance.parallaxMid
        let panoW: CGFloat = sceneSize.width + travel + 500
        let theme = Balance.active.theme
        let overgrown = theme == .overgrown
        let bastion = theme == .bastion
        let dawn = theme == .dawn
        let sunscorch = theme == .sunscorch
        let sandhold = theme == .sandhold
        let wooded = overgrown || bastion
        let canopy = sandhold ? UIColor(red: 0.25, green: 0.15, blue: 0.10, alpha: 1)
            : sunscorch ? UIColor(red: 0.30, green: 0.28, blue: 0.16, alpha: 1)
            : overgrown ? UIColor(red: 0.05, green: 0.22, blue: 0.14, alpha: 1)
            : bastion ? UIColor(red: 0.22, green: 0.11, blue: 0.07, alpha: 1)
            : dawn ? UIColor(red: 0.16, green: 0.18, blue: 0.10, alpha: 1) : treeDark
        let rim = sandhold ? UIColor(red: 1.0, green: 0.60, blue: 0.30, alpha: 1)
            : sunscorch ? UIColor(red: 1.0, green: 0.90, blue: 0.60, alpha: 1)
            : overgrown ? UIColor(red: 0.30, green: 0.62, blue: 0.32, alpha: 1)
            : bastion ? UIColor(red: 0.80, green: 0.48, blue: 0.20, alpha: 1)
            : dawn ? UIColor(red: 0.85, green: 0.70, blue: 0.45, alpha: 1) : treeRim
        let PW = 800, PH = 90
        let tex = render(w: PW, h: PH) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: PW, height: PH))
            // Canopy: overlapping dark blobs with teal moonlit tops.
            // Wooded themes run a second offset pass for jungle density.
            for pass in 0..<(wooded ? 2 : 1) {
                var rng = SeededRNG(seed: 555 + UInt64(pass * 1000))
                var x = -10 + pass * 23
                while x < PW + 10 {
                    let w = rng.int(in: 46...90)
                    // Sunscorch: low sparse scrub, not tall forest.
                    var h = rng.int(in: 30...58) + (pass == 1 ? 10 : 0)
                    if sunscorch { h = rng.int(in: 14...26) }
                    let top = PH - h - rng.int(in: 0...10) - (pass == 1 ? 6 : 0)
                    for px in x..<(x + w) {
                        guard px >= 0 && px < PW else { continue }
                        let edge = abs(CGFloat(px - (x + w / 2))) / CGFloat(w / 2)
                        let colH = Int(CGFloat(h) * (1 - edge * edge * 0.55))
                        fill(cg, px, top + (h - colH), 1, colH, canopy)
                    }
                    // Moonlit crown.
                    for px in x..<(x + w) where hash(px, top, 6) < 40 {
                        fill(cg, px, top, 1, 2, rim.withAlpha(0.8))
                    }
                    // Trunk slivers.
                    if rng.int(in: 0...2) == 0 {
                        fill(cg, x + w / 2, 0, 3, PH - h + 12, canopy)
                    }
                    x += w * 3 / 4
                }
            }
            // Hanging vines off the wooded canopy (overgrown + bastion).
            if wooded {
                for vx in stride(from: 8, to: PW - 8, by: 14) {
                    if hash(vx, 5, 41) < 55 {
                        let len = 10 + hash(vx, 9, 42) % 22
                        let vtop = PH - 52 + hash(vx, 3, 43) % 14
                        fill(cg, vx, vtop - len, 2, len, canopy)
                        for k in stride(from: 0, to: len, by: 6) {
                            fill(cg, vx - 2, vtop - k, 5, 2, rim.withAlpha(0.6))
                        }
                    }
                }
            }
            // Fallen ruin pillars breaking the treeline (unique spots).
            for px in [250, 528, 690] {
                let h = 34 + hash(px, 1, 9) * 18 / 100
                fill(cg, px, PH - h - 18, 10, h, ruinBody)
                fill(cg, px + 8, PH - h - 18, 2, h, ruinRim.withAlpha(0.5))
                fill(cg, px - 6, PH - 22, 22, 6, ruinBody) // toppled chunk
            }
            // Sandhold: broken sandstone wall chunks with crenellations
            // holding the scrub line like a ruined curtain wall.
            if sandhold {
                let wall = UIColor(red: 0.30, green: 0.19, blue: 0.13, alpha: 1)
                for wx in [120, 360, 620] {
                    let wh = 26 + hash(wx, 2, 61) * 14 / 100
                    fill(cg, wx, PH - wh - 14, 64, wh, wall)
                    for m in stride(from: wx, to: wx + 64, by: 12) {
                        fill(cg, m, PH - wh - 20, 7, 7, wall)
                    }
                    fill(cg, wx, PH - wh - 14, 64, 2, rim.withAlpha(0.6))
                    // Breach hole.
                    fill(cg, wx + 24, PH - 30, 12, 16, UIColor(red: 0.08, green: 0.05, blue: 0.05, alpha: 1))
                }
            }
            // Firefly dots baked faintly into the canopy (denser wooded).
            // Sunscorch: almost none — bleached scrub, not glowing woods.
            // Sandhold: ember sparks in the dusk.
            var frng = SeededRNG(seed: 777)
            for _ in 0..<(sandhold ? 34 : sunscorch ? 8 : wooded ? 44 : 26) {
                let fx = frng.int(in: 0...(PW - 1))
                let fy = frng.int(in: 8...(PH - 8))
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

        // Live fireflies: warm dots floating above the treeline
        // (more + greener for the overgrown jungle; amber for the bastion).
        // Sunscorch: thin heat-dust, few and pale.
        // Sandhold: ember sparks rising off the scrub line.
        let liveCount = sandhold ? 18 : sunscorch ? 6 : (wooded ? 22 : 14)
        for i in 0..<liveCount {
            let green = overgrown && i % 3 == 0
            let f = SKSpriteNode(color: sandhold
                ? SKColor(red: 1, green: 0.45, blue: 0.15, alpha: 0.9)
                : sunscorch
                ? SKColor(red: 1, green: 0.95, blue: 0.80, alpha: 0.6)
                : green
                ? SKColor(red: 0.55, green: 1, blue: 0.6, alpha: 0.95)
                : SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.95),
                                 size: CGSize(width: 3, height: 3))
            f.position = CGPoint(x: CGFloat(i) * (panoW / CGFloat(liveCount)) + rng.cgFloat(in: -20...20),
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

    // MARK: - Dunesea: dune-ridge panorama + rolling dune field

    private static var ridgeCache: [SKTexture] = []

    static func duneRidgeTexture(variant: Int) -> SKTexture {
        let v = ((variant % 3) + 3) % 3
        while ridgeCache.count <= v { ridgeCache.append(renderRidge(variant: ridgeCache.count)) }
        return ridgeCache[v]
    }

    /// Pixel dune-ridge silhouette (200x64, upscaled with .nearest so the
    /// crest steps stay chunky): sand body below a smooth sine crest, lit
    /// crest pixels, stepped shade bands + dither with depth. Row 0 = top.
    private static func renderRidge(variant: Int) -> SKTexture {
        let tex = render(w: 200, h: 64) { cg in
            drawRidge(cg, variant: variant)
        }
        tex.filteringMode = .nearest
        return tex
    }

    private static func drawRidge(_ cg: CGContext, variant: Int) {
        cg.clear(CGRect(x: 0, y: 0, width: 200, height: 64))
        let cols: [UIColor] = [UIColor(red: 0.85, green: 0.68, blue: 0.47, alpha: 1),
                               UIColor(red: 0.78, green: 0.58, blue: 0.36, alpha: 1),
                               UIColor(red: 0.64, green: 0.44, blue: 0.25, alpha: 1)]
        let shade = UIColor(red: 0.45, green: 0.30, blue: 0.17, alpha: 1)
        let hi = UIColor(red: 1.0, green: 0.90, blue: 0.66, alpha: 1)
        let bases: [Int] = [18, 28, 38]
        let amps: [Int] = [9, 13, 17]
        let phases: [Double] = [0.0, 1.7, 3.4]
        let base: Int = bases[variant]
        let amp: Int = amps[variant]
        let ph: Double = phases[variant]
        for x in 0..<200 {
            drawRidgeColumn(cg, x: x, base: base, amp: amp, ph: ph,
                            body: cols[variant], shade: shade, hi: hi, variant: variant)
        }
    }

    private static func drawRidgeColumn(_ cg: CGContext, x: Int, base: Int, amp: Int,
                                       ph: Double, body: UIColor, shade: UIColor,
                                       hi: UIColor, variant: Int) {
        let crest: Int = base + Int(Double(amp) * sin(Double(x) * 0.06 + ph)
            + Double(amp) * 0.35 * sin(Double(x) * 0.17 + ph * 1.8))
        // Sand body below the crest, darkening in stepped bands.
        for yy in crest..<64 {
            let depth: Int = (yy - crest) / 8
            var c: UIColor = body
            if depth >= 2 || hash(x, yy, variant) < depth * 18 { c = shade }
            fill(cg, x, yy, 1, 1, c)
        }
        // Lit crest pixel + a bright pixel kissing the slip face.
        fill(cg, x, crest, 1, 1, hi)
        if crest + 1 < 64, hash(x, 7, variant) < 45 {
            fill(cg, x, crest + 1, 1, 1, hi.withAlpha(0.5))
        }
    }

    /// Oasis far sheet: hazy warm range, a broken desert ruin arch and a
    /// bone field. All pixel rows, chunky when scaled.
    private static func drawOasisRange(_ cg: CGContext, PW: Int, PH: Int) {
        let rock = UIColor(red: 0.62, green: 0.45, blue: 0.28, alpha: 1)
        let rim = UIColor(red: 1.0, green: 0.88, blue: 0.62, alpha: 1)
        let stone = UIColor(red: 0.55, green: 0.40, blue: 0.25, alpha: 1)
        let bone = UIColor(red: 0.93, green: 0.88, blue: 0.72, alpha: 1)
        // Hazy back range.
        let back: [(x: Int, peak: Int, half: Int)] = [
            (70, 126, 96), (230, 146, 118), (400, 122, 88),
            (560, 148, 124), (720, 134, 100),
        ]
        for b in back {
            for px in (b.x - b.half)..<(b.x + b.half) {
                guard px >= 0 && px < PW else { continue }
                let k = 1 - abs(CGFloat(px - b.x)) / CGFloat(b.half)
                let top = b.peak - Int(k * 50)
                fill(cg, px, top, 1, PH - top, rock)
                if hash(px, 1, 5) < 28 { fill(cg, px, top, 1, 2, rim) }
            }
        }
        // Broken desert ruin arch (center-right).
        let rx = 330, ry = 104
        fill(cg, rx, ry, 14, 60, stone)
        fill(cg, rx + 74, ry, 14, 44, stone)
        fill(cg, rx, ry, 88, 8, stone)
        fill(cg, rx, ry, 88, 2, rim.withAlpha(0.7))
        fill(cg, rx + 10, ry + 4, 62, 8, UIColor(red: 0.86, green: 0.78, blue: 0.60, alpha: 1))
        // Chipped top edge.
        for k in stride(from: 0, to: 88, by: 10) {
            if hash(k, 1, 33) < 40 { fill(cg, rx + k, ry + 8, 6, 4, stone) }
        }
        // Bone field along the sand line.
        for bx in stride(from: 20, to: PW - 20, by: 46) {
            let by = 150 + hash(bx, 2, 41) % 10
            fill(cg, bx, by, 9, 2, bone)
            fill(cg, bx + 1, by - 3, 2, 3, bone)
            fill(cg, bx + 5, by - 3, 2, 3, bone)
            if hash(bx, 3, 42) < 40 { fill(cg, bx + 11, by + 2, 6, 2, bone) }
        }
    }

    /// Mid-layer for the oasis: pixel sand ridges fringed with palms,
    /// bone spires and scrub. Replaces the bare dune ridges on Level 8.
    static func buildOasisRidges(in layer: SKNode, sceneSize: CGSize) {
        let travel = Balance.levelWidth * Balance.parallaxMid
        let panoW: CGFloat = sceneSize.width + travel + 500
        let panoH = sceneSize.height * 0.30
        let baseY = -sceneSize.height * 0.22
        let frond = UIColor(red: 0.22, green: 0.46, blue: 0.22, alpha: 1)
        let frondHi = UIColor(red: 0.34, green: 0.62, blue: 0.28, alpha: 1)
        let trunk = UIColor(red: 0.42, green: 0.30, blue: 0.18, alpha: 1)
        let bone = UIColor(red: 0.92, green: 0.87, blue: 0.70, alpha: 1)

        // Pixel ridge silhouettes (same chunky tiles as the dune sea, with
        // a greener wash on the nearest one).
        for (ri, lift) in [30, 10, -10].enumerated() {
            let ridge = SKSpriteNode(texture: duneRidgeTexture(variant: ri))
            ridge.anchorPoint = CGPoint(x: 0, y: 0.5)
            ridge.size = CGSize(width: panoW, height: panoH)
            ridge.position = CGPoint(x: -sceneSize.width * 0.6, y: baseY + CGFloat(lift))
            ridge.zPosition = CGFloat(ri)
            if ri == 2 {
                // Slight green tint over the near ridge: sand near water.
                ridge.colorBlendFactor = 0.18
                ridge.color = UIColor(red: 0.55, green: 0.70, blue: 0.45, alpha: 1)
            }
            layer.addChild(ridge)
        }

        // Palms + bone spires studded along the ridge line.
        var rng = SeededRNG(seed: 51515)
        let ornamentCount = 26
        for i in 0..<ornamentCount {
            let ox = rng.cgFloat(in: 0...panoW)
            let oy = baseY + rng.cgFloat(in: -6...40)
            let node = SKNode()
            node.position = CGPoint(x: ox, y: oy)
            node.zPosition = 2
            node.setScale(rng.cgFloat(in: 0.7...1.2))
            layer.addChild(node)
            if i % 3 == 0 {
                drawPalmNode(node, frond: frond, frondHi: frondHi, trunk: trunk,
                             sway: Double(i % 5) - 2)
            } else if i % 3 == 1 {
                // Bone spire: ribbed skull tower.
                let h: CGFloat = rng.cgFloat(in: 16...30)
                let spire = SKSpriteNode(color: bone, size: CGSize(width: 5, height: h))
                spire.position = CGPoint(x: 0, y: h / 2)
                node.addChild(spire)
                let cap = SKSpriteNode(color: bone.withAlphaComponent(0.8),
                                       size: CGSize(width: 9, height: 5))
                cap.position = CGPoint(x: 0, y: h)
                node.addChild(cap)
                for r in 1..<3 {
                    let rib = SKSpriteNode(color: bone.withAlphaComponent(0.7),
                                           size: CGSize(width: 3, height: 4))
                    rib.position = CGPoint(x: 6, y: h * CGFloat(r) / 3)
                    node.addChild(rib)
                }
            } else {
                // Scrub tuft.
                for b in 0..<3 {
                    let blade = SKSpriteNode(color: frond.withAlphaComponent(0.8),
                                             size: CGSize(width: 2, height: 9))
                    blade.position = CGPoint(x: CGFloat(b) * 3 - 3, y: 4)
                    blade.zRotation = 0.3 * CGFloat(b) - 0.3
                    node.addChild(blade)
                }
            }
            _ = frondHi
        }
    }

    /// One pixel palm as a live node (fronds as small sprites).
    private static func drawPalmNode(_ node: SKNode, frond: UIColor, frondHi: UIColor,
                                     trunk: UIColor, sway: Double) {
        let th: CGFloat = 26
        let pole = SKSpriteNode(color: trunk, size: CGSize(width: 3, height: th))
        pole.position = CGPoint(x: 0, y: th / 2)
        node.addChild(pole)
        let top = CGPoint(x: 0, y: th)
        let angles: [Double] = [-1.0, -0.5, 0.0, 0.5, 1.0]
        for i in 0..<angles.count {
            let a = angles[i]
            let len = abs(a) * 16 + 8
            let fr = SKSpriteNode(color: i == 2 ? frondHi : frond,
                                  size: CGSize(width: len, height: 2))
            fr.anchorPoint = CGPoint(x: a < 0 ? 1 : 0, y: 0.5)
            fr.position = top
            fr.zRotation = CGFloat(a) * 0.7
            node.addChild(fr)
        }
        let crown = SKSpriteNode(color: frondHi, size: CGSize(width: 5, height: 4))
        crown.position = top
        node.addChild(crown)
        if sway != 0 {
            node.run(.repeatForever(.sequence([
                .rotate(toAngle: CGFloat(sway) * 0.04, duration: 2.4),
                .rotate(toAngle: -CGFloat(sway) * 0.04, duration: 2.4),
            ])))
        }
    }


    /// Mid-layer for the dune sea: three pixel-art ridge silhouettes
    /// stacked far -> near (hazier + paler behind, darker + taller ahead),
    /// plus drifting pixel-sand clusters. Replaces the treeline on dune
    /// levels.
    static func buildDuneRidges(in layer: SKNode, sceneSize: CGSize) {
        let travel = Balance.levelWidth * Balance.parallaxMid
        let panoW: CGFloat = sceneSize.width + travel + 500
        let panoH = sceneSize.height * 0.30
        let baseY = -sceneSize.height * 0.22
        for (ri, lift) in [30, 10, -10].enumerated() {
            let ridge = SKSpriteNode(texture: duneRidgeTexture(variant: ri))
            ridge.anchorPoint = CGPoint(x: 0, y: 0.5)
            ridge.size = CGSize(width: panoW, height: panoH)
            ridge.position = CGPoint(x: -sceneSize.width * 0.6, y: baseY + CGFloat(lift))
            ridge.zPosition = CGFloat(ri)
            layer.addChild(ridge)
        }
        // Drifting pixel-sand clusters (dynamic, translucent grains).
        var rng = SeededRNG(seed: 4141)
        for i in 0..<4 {
            let cluster = SKNode()
            cluster.position = CGPoint(x: rng.cgFloat(in: 0...panoW * 0.6),
                                       y: baseY + rng.cgFloat(in: -10...60))
            cluster.zPosition = 3
            layer.addChild(cluster)
            for k in 0..<6 {
                let grain = SKSpriteNode(
                    color: SKColor(red: 1.0, green: 0.88, blue: 0.62, alpha: 0.5),
                    size: CGSize(width: 3, height: 3))
                grain.position = CGPoint(x: rng.cgFloat(in: 0...120),
                                         y: rng.cgFloat(in: -8...8))
                cluster.addChild(grain)
                _ = k
            }
            let drift = SKAction.moveBy(x: rng.cgFloat(in: 80...160), y: 0,
                                        duration: rng.double(in: 6...10))
            cluster.run(.repeatForever(.sequence([drift, drift.reversed()])))
            _ = i
        }
    }

    private static var sandTile: SKTexture?

    /// Pixel sand tile (110x26 @4x = 440x104): pale crest, wind-ripple
    /// scallops, shaded foot, grain speckles. Row 0 = top.
    static func sandTileTexture() -> SKTexture {
        if let sandTile { return sandTile }
        let tex = render(w: 110, h: 26) { cg in
            let crest = UIColor(red: 0.98, green: 0.88, blue: 0.62, alpha: 1)
            let mid = UIColor(red: 0.82, green: 0.64, blue: 0.38, alpha: 1)
            let dark = UIColor(red: 0.58, green: 0.42, blue: 0.23, alpha: 1)
            let foot = UIColor(red: 0.66, green: 0.48, blue: 0.28, alpha: 1)
            fill(cg, 0, 0, 110, 26, mid)
            // Pale crest rows.
            fill(cg, 0, 0, 110, 2, crest)
            // Wind-ripple scallops: dark double-row arcs marching right.
            for x in 0..<110 {
                let arc = Int(2.0 * sin(Double(x) * 0.30) + 2.0) // 0...4
                fill(cg, x, 5 + arc, 1, 2, dark)
            }
            // Shaded foot.
            fill(cg, 0, 14, 110, 12, foot)
            fill(cg, 0, 14, 110, 1, dark.withAlpha(0.6))
            // Grain speckles, light + dark.
            for g in 0..<90 {
                let gx = hash(g, 1, 7) * 110 / 100
                let gy = 2 + hash(g, 3, 8) * 22 / 100
                fill(cg, gx, gy, 1, 1,
                     hash(g, 5, 9) < 50 ? crest.withAlpha(0.8) : dark.withAlpha(0.8))
            }
        }
        tex.filteringMode = .nearest
        sandTile = tex
        return tex
    }

    /// Flat dune-sea field for the desert level: pixel sand tiles with a
    /// pale crest lip, sandstone strata below, team washes, ripple ticks
    /// + pebbles on the deck. Straight like the other lanes.
    static func buildDuneGround(in world: SKNode) {
        let width = Balance.levelWidth
        let gy = Balance.groundTopY
        let tile = sandTileTexture()
        let tileW: CGFloat = 440, tileH: CGFloat = 104 // 110x26 @4x
        var x: CGFloat = 0
        var i = 0
        while x < width {
            let t = SKSpriteNode(texture: tile)
            t.anchorPoint = CGPoint(x: 0, y: 1)
            t.size = CGSize(width: tileW, height: tileH)
            if i % 2 == 1 {
                t.xScale = -1
                t.position = CGPoint(x: x + tileW, y: gy)
            } else {
                t.position = CGPoint(x: x, y: gy)
            }
            t.zPosition = 1
            world.addChild(t)
            x += tileW
            i += 1
        }
        // Pale crest lip on the walkable edge.
        let lip = SKSpriteNode(color: SKColor(red: 1.0, green: 0.93, blue: 0.70, alpha: 0.8),
                               size: CGSize(width: width, height: 3))
        lip.anchorPoint = CGPoint(x: 0, y: 1)
        lip.position = CGPoint(x: 0, y: gy + 1)
        lip.zPosition = 2
        world.addChild(lip)
        // Sandstone strata under the sand, then dark depth.
        var y = gy - tileH
        for (depth, color) in [(60, SKColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1)),
                              (120, SKColor(red: 0.40, green: 0.27, blue: 0.15, alpha: 1))] as [(CGFloat, SKColor)] {
            let d = min(depth, y)
            guard d > 0 else { break }
            let band = SKSpriteNode(color: color, size: CGSize(width: width, height: d))
            band.anchorPoint = CGPoint(x: 0, y: 1)
            band.position = CGPoint(x: 0, y: y)
            band.zPosition = 0
            world.addChild(band)
            y -= d
        }
        if y > 0 {
            let deep = SKSpriteNode(color: SKColor(red: 0.20, green: 0.13, blue: 0.08, alpha: 1),
                                    size: CGSize(width: width, height: y))
            deep.anchorPoint = CGPoint(x: 0, y: 1)
            deep.position = CGPoint(x: 0, y: y)
            deep.zPosition = 0
            world.addChild(deep)
        }
        // Team washes: faint so the desert grade survives.
        let half = width / 2
        let washL = SKSpriteNode(color: SKColor(red: 0.3, green: 0.5, blue: 1, alpha: 0.07),
                                 size: CGSize(width: half, height: tileH))
        washL.anchorPoint = CGPoint(x: 0, y: 1)
        washL.position = CGPoint(x: 0, y: gy)
        washL.zPosition = 2
        world.addChild(washL)
        let washR = SKSpriteNode(color: SKColor(red: 1, green: 0.3, blue: 0.25, alpha: 0.07),
                                 size: CGSize(width: half, height: tileH))
        washR.anchorPoint = CGPoint(x: 0, y: 1)
        washR.position = CGPoint(x: half, y: gy)
        washR.zPosition = 2
        world.addChild(washR)
        // Ripple ticks + pebbles + pale speckles (pixel squares on the deck).
        var rng = SeededRNG(seed: 70707)
        var px: CGFloat = 20
        while px < width - 20 {
            px += rng.cgFloat(in: 90...200)
            let tick = SKSpriteNode(color: SKColor(red: 0.58, green: 0.42, blue: 0.23, alpha: 0.7),
                                    size: CGSize(width: rng.cgFloat(in: 10...20), height: 2))
            tick.position = CGPoint(x: px, y: gy + 3)
            tick.zPosition = 2
            world.addChild(tick)
            let peb = SKSpriteNode(color: SKColor(red: 0.42, green: 0.30, blue: 0.18, alpha: 1),
                                   size: CGSize(width: 3, height: 3))
            peb.position = CGPoint(x: px + rng.cgFloat(in: -30...30), y: gy + 2)
            peb.zPosition = 2
            world.addChild(peb)
            let sp = SKSpriteNode(color: SKColor(red: 1.0, green: 0.93, blue: 0.70, alpha: 0.85),
                                  size: CGSize(width: 2, height: 2))
            sp.position = CGPoint(x: px + rng.cgFloat(in: -30...30), y: gy + 2)
            sp.zPosition = 2
            world.addChild(sp)
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
    /// Dune levels branch to the rolling dune-sea renderer instead.
    static func buildGround(in world: SKNode) {
        if Balance.dunes {
            buildDuneGround(in: world)
            return
        }
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
