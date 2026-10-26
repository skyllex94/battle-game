import SpriteKit
import UIKit

/// Umbral Outskirts battleground (Level 28+) — the dark core wastes, a
/// Mordor-inspired blood-red theater: a burning maroon sky under a huge
/// bloated ember moon, a black jagged peak-wall with a smoking volcano at
/// its heart, rolling ash wastes in the mid ground, and a cracked basalt
/// lane veined with living ember over deep dark rock.
///
/// Performance notes (mirrors TwilightRuinsBG / FrostbiteBG rules):
/// - Every big surface is ONE low-res CoreGraphics texture baked once,
///   cached in a static, stretched with .nearest (chunky pixels, tiny VRAM).
/// - One wide panorama per layer — nothing tiles, nothing repeats.
/// - Static dressing is rasterized per 1024pt chunk via SceneryBake
///   (one sprite per chunk instead of dozens of live nodes).
/// - Dynamics are only looping SKActions on few nodes — no per-frame
///   Swift code anywhere in this file.
enum MordorBG {

    // MARK: - Palette (blood-red wastes over black rock)

    private static let skyTop = UIColor(red: 0.05, green: 0.01, blue: 0.015, alpha: 1)
    private static let skyMid = UIColor(red: 0.23, green: 0.05, blue: 0.06, alpha: 1)
    private static let skyLow = UIColor(red: 0.52, green: 0.14, blue: 0.08, alpha: 1)
    private static let horizonFire = UIColor(red: 1.0, green: 0.38, blue: 0.10, alpha: 1)
    private static let mistAsh = UIColor(red: 0.38, green: 0.16, blue: 0.12, alpha: 1)

    private static let peakDk = UIColor(red: 0.07, green: 0.045, blue: 0.05, alpha: 1)
    private static let peakBody = UIColor(red: 0.13, green: 0.08, blue: 0.08, alpha: 1)
    private static let peakHi = UIColor(red: 0.24, green: 0.12, blue: 0.10, alpha: 1)
    private static let emberRim = UIColor(red: 1.0, green: 0.42, blue: 0.12, alpha: 1)
    private static let lavaHot = UIColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 1)
    private static let lavaCore = UIColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 1)

    // Ash lane.
    private static let ashHi = UIColor(red: 0.38, green: 0.22, blue: 0.18, alpha: 1)
    private static let ash = UIColor(red: 0.28, green: 0.15, blue: 0.13, alpha: 1)
    private static let ashDk = UIColor(red: 0.17, green: 0.09, blue: 0.09, alpha: 1)
    private static let basalt = UIColor(red: 0.10, green: 0.06, blue: 0.065, alpha: 1)
    private static let basaltDk = UIColor(red: 0.06, green: 0.035, blue: 0.04, alpha: 1)
    private static let abyssDeep = UIColor(red: 0.025, green: 0.012, blue: 0.015, alpha: 1)

    // MARK: - Canvas helpers

    private static func fill(_ cg: CGContext, _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: UIColor) {
        cg.setFillColor(c.cgColor)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    private static func blend(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t,
                       blue: ab + (bb - ab) * t, alpha: aa + (ba - aa) * t)
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

    private struct SeededRNG {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
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

    // MARK: - Sky (screen-locked)

    /// Burning Mordor sky: near-black maroon zenith melting into blood red
    /// and a blazing ember horizon. A huge bloated ember moon hangs low
    /// with a breathing halo and dark surface scars; sparse blood-red
    /// stars twinkle above; dark ash clouds drift; embers rise everywhere;
    /// a hot glow band breathes over the peaks. All bakes + looping actions.
    static func buildSky(in layer: SKNode, sceneSize: CGSize) {
        // Dithered vertical gradient: black-maroon -> blood -> ember fire.
        let grad = render(w: 2, h: 256) { cg in
            for y in 0..<256 {
                let t = CGFloat(y) / 255 // 0 top -> 1 bottom
                let c: UIColor
                switch t {
                case 0..<0.42:
                    c = blend(skyTop, skyMid, t / 0.42)
                case 0.42..<0.68:
                    c = blend(skyMid, skyLow, (t - 0.42) / 0.26)
                case 0.68..<0.85:
                    c = blend(skyLow, horizonFire, (t - 0.68) / 0.17 * 0.7)
                default:
                    c = blend(horizonFire, mistAsh, 0.35 + (t - 0.85) / 0.15 * 0.65)
                }
                fill(cg, 0, y, 2, 1, c)
            }
        }
        grad.filteringMode = .linear
        let sky = SKSpriteNode(texture: grad)
        sky.size = CGSize(width: sceneSize.width * 1.25, height: sceneSize.height * 1.5)
        sky.zPosition = 0
        layer.addChild(sky)

        let W = sceneSize.width, H = sceneSize.height
        var rng = SeededRNG(seed: 280128)

        // The ember moon: a huge bloated blood-red disc low over the wastes,
        // baked tiny and stretched with .nearest so every pixel reads chunky.
        let moon = SKSpriteNode(texture: emberMoonTexture())
        moon.size = CGSize(width: 112, height: 112)
        moon.position = CGPoint(x: W * 0.30, y: H * 0.16)
        moon.zPosition = 1
        layer.addChild(moon)
        // Breathing heat halo: blocky baked glow, never a vector circle.
        let halo = SKSpriteNode(texture: emberGlowTexture())
        halo.size = CGSize(width: 300, height: 300)
        halo.position = moon.position
        halo.zPosition = 1
        layer.addChild(halo)
        halo.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 4.4), .fadeAlpha(to: 1.0, duration: 4.4),
        ])))

        // Blood stars: sparse ember dots in the upper dark, gentle pulse.
        for _ in 0..<64 {
            let sx = rng.cgFloat(in: -W * 0.6...W * 0.6)
            let sy = rng.cgFloat(in: H * 0.08...H * 0.68)
            let s = rng.cgFloat(in: 1.4...3.2)
            let ember = rng.int(in: 0...2) == 0
            let star = SKSpriteNode(color: ember
                ? SKColor(red: 1.0, green: 0.45, blue: 0.20, alpha: 0.9)
                : SKColor(red: 0.95, green: 0.75, blue: 0.62, alpha: 0.85),
                size: CGSize(width: s, height: s))
            star.position = CGPoint(x: sx, y: sy)
            star.zPosition = 1
            layer.addChild(star)
            star.run(.repeatForever(.sequence([
                .wait(forDuration: rng.double(in: 0...2.6)),
                .fadeAlpha(to: 0.15, duration: rng.double(in: 0.8...1.9)),
                .fadeAlpha(to: 0.95, duration: rng.double(in: 0.8...1.9)),
            ])))
        }

        // Horizon fire band: hot light sitting over the peak-wall.
        let glowTex = render(w: 64, h: 8) { cg in
            for x in 0..<64 {
                let edge = abs(CGFloat(x) - 32) / 32 // 0 center -> 1 edge
                cg.setFillColor(UIColor(red: 1, green: 0.42, blue: 0.12,
                                        alpha: 0.38 * (1 - edge)).cgColor)
                cg.fill(CGRect(x: x, y: 0, width: 1, height: 8))
            }
        }
        glowTex.filteringMode = .linear
        let glow = SKSpriteNode(texture: glowTex)
        glow.size = CGSize(width: W * 0.9, height: 52)
        glow.position = CGPoint(x: 0, y: -H * 0.10)
        glow.zPosition = 2
        layer.addChild(glow)
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.6, duration: 3.6), .fadeAlpha(to: 1.0, duration: 3.6),
        ])))

        // Ash clouds: 6 long dark streaks drifting slowly, ember-lit below.
        for _ in 0..<6 {
            let cw = W * rng.cgFloat(in: 0.35...0.6)
            let cloud = SKSpriteNode(color: SKColor(red: 0.16, green: 0.06, blue: 0.06, alpha: 0.42),
                                     size: CGSize(width: cw, height: rng.cgFloat(in: 12...24)))
            cloud.position = CGPoint(x: rng.cgFloat(in: -W * 0.6...W * 0.6),
                                     y: H * rng.cgFloat(in: 0.08...0.48))
            cloud.zPosition = 2
            layer.addChild(cloud)
            // Ember underlight: thin hot strip glued to the cloud's belly.
            let under = SKSpriteNode(color: SKColor(red: 1.0, green: 0.40, blue: 0.12, alpha: 0.25),
                                     size: CGSize(width: cw * 0.9, height: 3))
            under.position = CGPoint(x: 0, y: -cloud.size.height / 2)
            cloud.addChild(under)
            let drift = SKAction.moveBy(x: rng.cgFloat(in: -90...90), y: 0,
                                        duration: rng.double(in: 10...17))
            cloud.run(.repeatForever(.sequence([drift, drift.reversed()])))
        }

        // Rising embers across the whole sky: the air itself burns.
        for i in 0..<22 {
            let s: CGFloat = rng.cgFloat(in: 2...4)
            let ember = SKSpriteNode(color: SKColor(red: 1.0, green: 0.52, blue: 0.16, alpha: 0.9),
                                     size: CGSize(width: s, height: s))
            let homeX = rng.cgFloat(in: -W * 0.6...W * 0.6)
            ember.position = CGPoint(x: homeX, y: rng.cgFloat(in: -H * 0.2...H * 0.3))
            ember.zPosition = 3
            layer.addChild(ember)
            let fly = SKAction.moveBy(x: rng.cgFloat(in: -30...30),
                                      y: rng.cgFloat(in: 90...220),
                                      duration: rng.double(in: 3.0...6.0))
            let vanish = SKAction.sequence([
                SKAction.wait(forDuration: 2.0),
                SKAction.fadeOut(withDuration: 2.0),
            ])
            ember.run(.repeatForever(.sequence([
                SKAction.wait(forDuration: Double(i) * 0.28),
                SKAction.group([fly, vanish]),
                SKAction.run { ember.position = CGPoint(x: homeX, y: -H * 0.2) },
                SKAction.fadeIn(withDuration: 0.5),
            ])))
        }

        // Ashen March grade (Level 29+): the storm thickens — dark ash
        // streaks tear sideways across the embers and a second hot band
        // breathes low over the peaks. The Vale keeps the March's storm.
        if Balance.ashenMarch || Balance.blackrootVale || Balance.cinderGate || Balance.shadowRift || Balance.dreadHollow || Balance.obsidianGate || Balance.embralCore {
            for i in 0..<7 {
                let streak = SKSpriteNode(
                    color: SKColor(red: 0.10, green: 0.04, blue: 0.04, alpha: 0.5),
                    size: CGSize(width: W * rng.cgFloat(in: 0.2...0.35), height: 5))
                streak.position = CGPoint(x: rng.cgFloat(in: -W * 0.6...W * 0.6),
                                          y: H * rng.cgFloat(in: -0.05...0.35))
                streak.zPosition = 2
                layer.addChild(streak)
                let tear = SKAction.moveBy(x: rng.cgFloat(in: 140...260),
                                           y: rng.cgFloat(in: -12...6),
                                           duration: rng.double(in: 3.0...5.0))
                streak.run(.repeatForever(.sequence([
                    SKAction.wait(forDuration: Double(i) * 0.3),
                    tear, tear.reversed(),
                ])))
            }
            let ashBand = SKSpriteNode(
                color: SKColor(red: 0.42, green: 0.12, blue: 0.07, alpha: 0.20),
                size: CGSize(width: W * 0.9, height: 26))
            ashBand.position = CGPoint(x: 0, y: -H * 0.16)
            ashBand.zPosition = 2
            layer.addChild(ashBand)
            ashBand.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.5, duration: 3.0), .fadeAlpha(to: 1.0, duration: 3.0),
            ])))
        }

        // Cinematic vignette (hot grade): darker edges, burning center.
        let vig = render(w: 128, h: 128) { cg in
            for px in 0..<128 {
                for py in 0..<128 {
                    let dx = (CGFloat(px) - 64) / 64, dy = (CGFloat(py) - 64) / 64
                    let d = min(1, sqrt(dx * dx + dy * dy))
                    let a = max(0, d - 0.55) * 0.78
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

    /// Per-column ridge for one mountain range: every peak contributes a
    /// straight flank rising to its summit, overlapped peaks carve the
    /// valleys, hash grain roughens the line. Row 0 = top.
    private static func skyline(_ peaks: [(x: Int, top: Int, slope: Double)],
                                base: Int, jitter: Int, seed: Int, w: Int) -> [Int] {
        var ridge = [Int](repeating: base, count: w)
        for x in 0..<w {
            var best = base
            for p in peaks {
                let d = abs(x - p.x)
                let h = p.top + Int(Double(d) * p.slope)
                if h < best { best = h }
            }
            let grain = hash(x, 7, seed) % (jitter + 1)
            ridge[x] = Swift.max(4, Swift.min(base, best + grain))
        }
        return ridge
    }

    /// Paint one black range: basalt body, ember-lit crest, shadowed right
    /// flanks, faint ash strata and glowing crack seams on tall faces.
    private static func paintRange(_ cg: CGContext, ridge: [Int], depth: Int,
                                   base: Int, rock: UIColor, rockDk: UIColor,
                                   ember: Bool, seed: Int) {
        let W = ridge.count
        for x in 0..<W {
            let top = ridge[x]
            guard top < depth - 2 else { continue }
            fill(cg, x, top, 1, depth - top, rock)

            // Right-facing flanks fall away from the firelight.
            if x > 2, x + 2 < W {
                let slope = ridge[x + 2] - ridge[x - 2]
                if slope > 2 {
                    let band = Swift.min(depth - top, 8 + slope * 3)
                    fill(cg, x, top, 1, band, rockDk.withAlphaComponent(0.45))
                }
            }

            // Ember crest along the silhouette — the peaks catch the fire.
            if top < base - 1 {
                fill(cg, x, top, 1, 1, emberRim.withAlphaComponent(0.85))
                if hash(x, 19, seed) < 22 {
                    fill(cg, x, top + 1, 1, 1, emberRim.withAlphaComponent(0.4))
                }
            }

            // Glowing crack seams bleeding down the taller faces.
            if ember, hash(x, 31, seed) < 8 {
                let len = 6 + hash(x, 32, seed) % 18
                let ry = top + 8 + hash(x, 33, seed) % 20
                if ry + len < depth {
                    fill(cg, x, ry, 1, len, lavaHot.withAlphaComponent(0.55))
                    fill(cg, x, ry, 1, 2, lavaCore.withAlphaComponent(0.8))
                }
            }
        }
    }

    private static var farTexCache: SKTexture?
    /// Black peak-wall panorama (fixed 1100x280 canvas): a hazy far wall, a
    /// nearer jagged range, and at center the volcano — a broad smoking cone
    /// with a blazing crater, lava rivers running down its flanks, and a
    /// glowing lava lake pooling at its foot.
    private static func farTexture() -> SKTexture {
        if let farTexCache { return farTexCache }
        let PW = 1100, PH = 280
        let tex = render(w: PW, h: PH) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: PW, height: PH))

            // 1) Far wall: tall, hazy, half-lost in ash smoke.
            let farPeaks: [(x: Int, top: Int, slope: Double)] = [
                (30, 70, 0.52), (105, 38, 0.44), (180, 56, 0.50),
                (252, 22, 0.38), (330, 64, 0.54), (405, 110, 0.46),
                (480, 96, 0.40), (562, 78, 0.58), (640, 60, 0.42),
                (716, 20, 0.36), (796, 62, 0.52), (875, 40, 0.44),
                (952, 26, 0.40), (1032, 68, 0.54), (1092, 46, 0.48),
            ]
            let farRidge = skyline(farPeaks, base: 152, jitter: 3, seed: 281, w: PW)
            paintRange(cg, ridge: farRidge, depth: PH, base: 152,
                       rock: blend(peakBody, peakHi, 0.4), rockDk: peakDk,
                       ember: false, seed: 283)
            // Ash smoke pooling at the wall's feet.
            for x in 0..<PW {
                let wob = hash(x, 61, 3) * 10 / 100
                fill(cg, x, 140 + wob, 1, PH - 140 - wob, mistAsh.withAlphaComponent(0.30))
            }

            // 2) Near range: darker, jagged, ember-crested.
            let midPeaks: [(x: Int, top: Int, slope: Double)] = [
                (0, 100, 0.55), (75, 82, 0.48), (152, 108, 0.58),
                (232, 122, 0.44), (316, 92, 0.50), (402, 150, 0.60),
                (486, 128, 0.46), (566, 100, 0.52), (652, 120, 0.44),
                (736, 150, 0.56), (820, 80, 0.48), (902, 112, 0.58),
                (986, 70, 0.46), (1072, 96, 0.52),
            ]
            let midRidge = skyline(midPeaks, base: 170, jitter: 3, seed: 293, w: PW)
            paintRange(cg, ridge: midRidge, depth: PH, base: 170,
                       rock: peakBody, rockDk: peakDk,
                       ember: true, seed: 297)
            for x in 0..<PW {
                let wob = hash(x, 67, 4) * 8 / 100
                fill(cg, x, 160 + wob, 1, PH - 160 - wob, mistAsh.withAlphaComponent(0.32))
            }

            // 3) The volcano: a broad cone rising out of the near range at
            // center-right, crater blazing, lava rivers down both flanks,
            // smoke column leaning downwind.
            let vx = 640
            let craterY = 96
            let coneHalf = 150
            for px in (vx - coneHalf)..<(vx + coneHalf) {
                guard px >= 0, px < PW else { continue }
                let k = 1 - abs(CGFloat(px - vx)) / CGFloat(coneHalf)
                let flank = Int(k * k * 70)
                let top = craterY + 74 - flank + (hash(px, 71, 5) < 25 ? 2 : 0)
                let base = 190
                guard top < base else { continue }
                fill(cg, px, top, 1, base - top, peakBody)
                // Left flank catches the fire; right falls to shadow.
                if px < vx { fill(cg, px, top, 1, base - top, peakHi.withAlphaComponent(0.35)) }
                // Ember crest on the cone silhouette.
                fill(cg, px, top, 1, 1, emberRim.withAlphaComponent(0.9))
            }
            // Crater mouth: dark pit ringed with white-hot fire.
            fill(cg, vx - 26, craterY + 66, 52, 10, abyssDeep)
            fill(cg, vx - 26, craterY + 66, 52, 3, lavaCore)
            fill(cg, vx - 20, craterY + 69, 40, 2, lavaHot)
            // Lava rivers: bright threads running down the cone.
            for river in [-64, -30, 18, 52, 88] {
                var rx = vx + river
                var ry = craterY + 74
                while ry < 188 {
                    fill(cg, rx, ry, 2, 3, lavaHot.withAlphaComponent(0.9))
                    if hash(rx, ry, 91) < 40 { fill(cg, rx, ry, 1, 1, lavaCore) }
                    rx += (hash(rx, ry, 92) < 50 ? -1 : 1)
                    ry += 3
                }
            }
            // Lava lake pooling at the cone's foot.
            fill(cg, vx - 120, 190, 240, 8, abyssDeep)
            fill(cg, vx - 120, 190, 240, 3, lavaHot)
            for x in (vx - 120)..<(vx + 120) where hash(x, 3, 93) < 45 {
                fill(cg, x, 190, 2, 2, lavaCore)
            }
            // Smoke column leaning downwind off the crater.
            for r in 0..<46 {
                let w = 14 + r / 2
                let sx = vx + r * 3
                let sy = craterY + 66 - r * 2
                guard sy >= 0 else { break }
                for px in (sx - w / 2)..<(sx + w / 2) {
                    guard px >= 0, px < PW else { continue }
                    if hash(px, sy, 94) < 30 {
                        fill(cg, px, sy, 1, 3, UIColor(red: 0.12, green: 0.05, blue: 0.05, alpha: 0.8))
                    }
                }
                // Glowing cinders inside the fresh smoke near the crater.
                if r < 14 {
                    for px in (sx - 4)...(sx + 4) where hash(px, sy, 95) < 30 {
                        fill(cg, px, sy + 1, 1, 1, lavaHot.withAlphaComponent(0.8))
                    }
                }
            }

            // 4) Landmark fangs: two lone obsidian spires at the right
            // shoulder, ember veins crawling up their faces.
            for (sx, w, top) in [(918, 14, 148), (947, 18, 128), (972, 11, 156)] as [(Int, Int, Int)] {
                for px in sx..<(sx + w) {
                    guard px >= 0, px < PW else { continue }
                    let k = 1 - abs(CGFloat(px - sx - w / 2)) / CGFloat(w / 2)
                    let jag = hash(px, 4, 43) < 25 ? 2 : 0
                    let t = top + Int(k * 6) + jag
                    fill(cg, px, t, 1, 196 - t, peakBody)
                    fill(cg, px, t, 1, 2, peakHi)
                    if hash(px, 5, 47) < 30 {
                        fill(cg, px, t + 6, 1, 4, lavaHot.withAlphaComponent(0.6))
                    }
                }
            }

            // Ash bed along the base + frozen heat shimmer over the lake.
            for x in 0..<PW {
                let wobble = hash(x, 7, 2) * 8 / 100
                fill(cg, x, 188 + wobble, 1, 12 - wobble / 2, mistAsh.withAlphaComponent(0.5))
            }
            fill(cg, 0, 204, PW, PH - 204, abyssDeep)
        }
        farTexCache = tex
        return tex
    }

    /// Black peak-wall under a burning sky: hazy far wall lost in ash,
    /// jagged ember-crested near range, the smoking volcano with blazing
    /// crater + lava rivers + lava lake, lone obsidian fangs. Heat shimmer
    /// pools along the base.
    static func buildFar(in layer: SKNode, sceneSize: CGSize) {
        let travel = Balance.levelWidth * Balance.parallaxFar
        let panoW: CGFloat = sceneSize.width + travel + 500
        let tex = farTexture()
        let pano = SKSpriteNode(texture: tex)
        pano.anchorPoint = CGPoint(x: 0, y: 0.5)
        let panoH = sceneSize.height * 0.78
        pano.size = CGSize(width: panoW, height: panoH)
        pano.position = CGPoint(x: -sceneSize.width * 0.6, y: -sceneSize.height * 0.07)
        pano.alpha = 0.95
        layer.addChild(pano)

        // Volcano glow: one hot blocky bloom pulsing over the crater (texture
        // rows ~66-80 of 280, so it rides the crater mouth).
        let glowX = -sceneSize.width * 0.6 + panoW * (640.0 / 1100.0)
        let glowRow: CGFloat = 72
        let farH: CGFloat = 280
        let glowY = -sceneSize.height * 0.07
            + (farH / 2 - glowRow) / farH * panoH
        let glow = SKSpriteNode(texture: emberGlowTexture())
        glow.size = CGSize(width: 190, height: 90)
        glow.position = CGPoint(x: glowX, y: glowY)
        glow.zPosition = 1
        layer.addChild(glow)
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.5, duration: 2.6), .fadeAlpha(to: 1.0, duration: 2.6),
        ])))

        // Ashen March grade (Level 29+): the volcano burns a second mouth —
        // a smaller bloom pulsing left of the crater, slightly out of phase.
        // The Vale keeps the March's twin fire.
        if Balance.ashenMarch || Balance.blackrootVale || Balance.cinderGate || Balance.shadowRift || Balance.dreadHollow || Balance.obsidianGate || Balance.embralCore {
            let second = SKSpriteNode(texture: emberGlowTexture())
            second.size = CGSize(width: 110, height: 56)
            second.position = CGPoint(x: glowX - panoW * 0.09, y: glowY - 8)
            second.zPosition = 1
            layer.addChild(second)
            second.run(.repeatForever(.sequence([
                .wait(forDuration: 1.3),
                .fadeAlpha(to: 0.45, duration: 2.6), .fadeAlpha(to: 1.0, duration: 2.6),
            ])))
        }

        // Blackroot Vale grade (Level 30): gnarled root-spires rise off the
        // far range's left shoulder — the vale's rot climbing toward the
        // peaks. Chunky stacked segments (never smooth vectors), ember-lit
        // windward rims, sap drops glowing in the splits.
        if Balance.blackrootVale {
            let rootDk = SKColor(red: 0.05, green: 0.03, blue: 0.035, alpha: 1)
            let rootHi = SKColor(red: 0.22, green: 0.11, blue: 0.09, alpha: 1)
            let sap = SKColor(red: 1.0, green: 0.45, blue: 0.10, alpha: 0.9)
            for (fi, fh, lean) in [(0.10, 0.30, 1.0),
                                   (0.16, 0.22, -1.0),
                                   (0.045, 0.17, 0.6)] as [(CGFloat, CGFloat, CGFloat)] {
                let spire = SKNode()
                spire.position = CGPoint(x: -sceneSize.width * 0.6 + panoW * fi,
                                         y: -sceneSize.height * 0.07 - panoH * 0.12)
                spire.zPosition = 1
                layer.addChild(spire)
                let h = panoH * fh
                var px: CGFloat = 0
                var py: CGFloat = 0
                while py < h {
                    let w: CGFloat = max(3, 10 - py / h * 7)
                    let seg = SKSpriteNode(color: rootDk, size: CGSize(width: w, height: 9))
                    px += lean * 2.5
                    py += 8
                    seg.position = CGPoint(x: px, y: py)
                    seg.zRotation = lean * 0.12
                    spire.addChild(seg)
                    // Ember-lit windward rim + a sap drop every third segment.
                    if Int(py) % 24 < 9 {
                        let rim = SKSpriteNode(color: rootHi, size: CGSize(width: 2, height: 8))
                        rim.position = CGPoint(x: -w / 2, y: 0)
                        seg.addChild(rim)
                        let drop = SKSpriteNode(color: sap, size: CGSize(width: 2, height: 2))
                        drop.position = CGPoint(x: 1, y: 2)
                        seg.addChild(drop)
                    }
                }
            }
        }

        // Cinder Gate grade (Level 31): the fallen gate's far silhouette —
        // two broken iron gate-towers straddling the volcano's shoulder,
        // ember-lit rims facing the lane, one leaning where it was torn.
        if Balance.cinderGate {
            let ironDk = SKColor(red: 0.08, green: 0.05, blue: 0.05, alpha: 1)
            let ironRim = SKColor(red: 0.55, green: 0.22, blue: 0.10, alpha: 1)
            for (fi, fh, lean) in [(0.30, 0.34, 0.10),
                                   (0.52, 0.28, -0.22)] as [(CGFloat, CGFloat, CGFloat)] {
                let ruin = SKNode()
                ruin.position = CGPoint(x: -sceneSize.width * 0.6 + panoW * fi,
                                        y: -sceneSize.height * 0.07 - panoH * 0.12)
                ruin.zPosition = 1
                layer.addChild(ruin)
                let h = panoH * fh
                var py: CGFloat = 0
                while py < h {
                    let w: CGFloat = max(4, 14 - py / h * 6)
                    let seg = SKSpriteNode(color: ironDk, size: CGSize(width: w, height: 10))
                    py += 9
                    seg.position = CGPoint(x: lean * py * 0.12, y: py)
                    seg.zRotation = lean * 0.10
                    ruin.addChild(seg)
                    if Int(py) % 27 < 10 {
                        let rim = SKSpriteNode(color: ironRim, size: CGSize(width: 2, height: 9))
                        rim.position = CGPoint(x: -w / 2, y: 0)
                        seg.addChild(rim)
                    }
                }
                // Snapped lintel stub jutting toward its twin.
                let stub = SKSpriteNode(color: ironDk, size: CGSize(width: 26, height: 7))
                stub.position = CGPoint(x: fi < 0.4 ? 16 : -16, y: h * 0.92)
                stub.zRotation = fi < 0.4 ? 0.12 : -0.14
                ruin.addChild(stub)
            }
        }

        // Shadowrift grade (Level 32): the rift's far silhouette — a dark
        // cleft splitting the far range with a broken black bridge span
        // still hanging across it, ember light bleeding up from below.
        if Balance.shadowRift {
            let riftX = -sceneSize.width * 0.6 + panoW * 0.41
            let riftY = -sceneSize.height * 0.07 - panoH * 0.12
            let ironDk = SKColor(red: 0.07, green: 0.045, blue: 0.05, alpha: 1)
            let ironRim = SKColor(red: 1.0, green: 0.42, blue: 0.12, alpha: 0.8)
            // Dark cleft wedge in the range line.
            let cleft = SKSpriteNode(color: SKColor(red: 0.02, green: 0.01, blue: 0.015, alpha: 1),
                                     size: CGSize(width: 70, height: panoH * 0.22))
            cleft.position = CGPoint(x: riftX, y: riftY + panoH * 0.10)
            cleft.zPosition = 1
            layer.addChild(cleft)
            let glow = SKSpriteNode(color: SKColor(red: 1.0, green: 0.40, blue: 0.10, alpha: 0.5),
                                    size: CGSize(width: 46, height: 6))
            glow.position = CGPoint(x: riftX, y: riftY + 4)
            glow.zPosition = 1
            layer.addChild(glow)
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 2.2), .fadeAlpha(to: 1.0, duration: 2.2),
            ])))
            // Broken span: two deck stubs reaching toward each other.
            for (dx, len) in [(-24 as CGFloat, 30 as CGFloat), (22, 26)] {
                let span = SKSpriteNode(color: ironDk, size: CGSize(width: len, height: 7))
                span.position = CGPoint(x: riftX + dx, y: riftY + panoH * 0.19)
                span.zRotation = dx < 0 ? 0.06 : -0.09
                span.zPosition = 1
                layer.addChild(span)
                let rim = SKSpriteNode(color: ironRim, size: CGSize(width: len, height: 1))
                rim.position = CGPoint(x: 0, y: 3)
                span.addChild(rim)
            }
        }

        // Dread Hollow grade (Level 33): the hollow's far silhouette — a
        // ring of jagged black spires rising off the far range, war banners
        // hung between them, ember light breathing up from the bowl below.
        if Balance.dreadHollow {
            let hollowX = -sceneSize.width * 0.6 + panoW * 0.41
            let hollowY = -sceneSize.height * 0.07 - panoH * 0.12
            let rockDk = SKColor(red: 0.07, green: 0.045, blue: 0.05, alpha: 1)
            let cloth = SKColor(red: 0.55, green: 0.08, blue: 0.07, alpha: 1)
            // Jagged spire teeth along the range line.
            for (dx, hgt) in [(-52 as CGFloat, 0.20), (-26, 0.26), (0, 0.17), (28, 0.24), (54, 0.18)] as [(CGFloat, CGFloat)] {
                let h = panoH * hgt
                var py: CGFloat = 0
                var w: CGFloat = 12
                while py < h {
                    let seg = SKSpriteNode(color: rockDk, size: CGSize(width: w, height: 9))
                    seg.position = CGPoint(x: hollowX + dx + (py / max(h, 1)) * 6, y: hollowY + py)
                    seg.zPosition = 1
                    layer.addChild(seg)
                    py += 9
                    w = max(3, w - 1.6)
                }
            }
            // War banners strung between the spires.
            for dx in [-39, -13, 14, 41] as [CGFloat] {
                let banner = SKSpriteNode(color: cloth, size: CGSize(width: 16, height: 24))
                banner.position = CGPoint(x: hollowX + dx, y: hollowY + panoH * 0.17)
                banner.zPosition = 1
                layer.addChild(banner)
                let sigil = SKSpriteNode(color: SKColor(red: 1.0, green: 0.45, blue: 0.10, alpha: 0.8),
                                         size: CGSize(width: 4, height: 4))
                sigil.position = CGPoint(x: 0, y: -2)
                banner.addChild(sigil)
                sigil.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.3, duration: 1.4), .fadeAlpha(to: 0.9, duration: 1.4),
                ])))
            }
            // Ember breath rising out of the hollow bowl.
            let bowlGlow = SKSpriteNode(color: SKColor(red: 1.0, green: 0.40, blue: 0.10, alpha: 0.45),
                                        size: CGSize(width: 120, height: 6))
            bowlGlow.position = CGPoint(x: hollowX, y: hollowY + 4)
            bowlGlow.zPosition = 1
            layer.addChild(bowlGlow)
            bowlGlow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 2.2), .fadeAlpha(to: 1.0, duration: 2.2),
            ])))
        }

        // Obsidian Gate grade (Level 34): the gate's far silhouette — a
        // row of black-glass monolith blades rising off the far range,
        // violet void-light breathing up between them from the gate below.
        // The Embral Core (Level 35 finale) keeps the same blades on its
        // horizon, crowned by the Core's own ember glow (added below).
        if Balance.obsidianGate || Balance.embralCore {
            let gateX = -sceneSize.width * 0.6 + panoW * 0.41
            let gateY = -sceneSize.height * 0.07 - panoH * 0.12
            let glassDk = SKColor(red: 0.05, green: 0.02, blue: 0.10, alpha: 1)
            let voidLt = SKColor(red: 0.62, green: 0.30, blue: 1.0, alpha: 1)
            // Monolith blades along the range line.
            for (dx, hgt) in [(-56 as CGFloat, 0.24), (-28, 0.31), (0, 0.21), (28, 0.28), (56, 0.22)] as [(CGFloat, CGFloat)] {
                let h = panoH * hgt
                var py: CGFloat = 0
                var w: CGFloat = 14
                while py < h {
                    let seg = SKSpriteNode(color: glassDk, size: CGSize(width: w, height: 9))
                    seg.position = CGPoint(x: gateX + dx + (py / max(h, 1)) * -5, y: gateY + py)
                    seg.zPosition = 1
                    layer.addChild(seg)
                    py += 9
                    w = max(3, w - 1.6)
                }
            }
            // Violet breath rising between the blades.
            let voidGlow = SKSpriteNode(color: SKColor(red: 0.62, green: 0.30, blue: 1.0, alpha: 0.45),
                                        size: CGSize(width: 150, height: 6))
            voidGlow.position = CGPoint(x: gateX, y: gateY + 4)
            voidGlow.zPosition = 1
            layer.addChild(voidGlow)
            voidGlow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 2.0), .fadeAlpha(to: 1.0, duration: 2.0),
            ])))
            // Cold rim ticks on the two tallest blades.
            for dx in [-28, 28] as [CGFloat] {
                let tick = SKSpriteNode(color: voidLt, size: CGSize(width: 3, height: 5))
                tick.position = CGPoint(x: gateX + dx - 5, y: gateY + panoH * 0.27)
                tick.zPosition = 1
                layer.addChild(tick)
                tick.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.3, duration: 1.5), .fadeAlpha(to: 0.95, duration: 1.5),
                ])))
            }
        }

        // Embral Core grade (Level 35 finale): the Core's ember crown
        // burning behind the monolith blades — a hot ember band breathing
        // over the far range, marking the last fortress on Emra.
        if Balance.embralCore {
            let coreX = -sceneSize.width * 0.6 + panoW * 0.41
            let coreY = -sceneSize.height * 0.07 - panoH * 0.12
            let crown = SKSpriteNode(color: SKColor(red: 1.0, green: 0.38, blue: 0.08, alpha: 0.5),
                                     size: CGSize(width: 210, height: 8))
            crown.position = CGPoint(x: coreX, y: coreY + panoH * 0.30)
            crown.zPosition = 1
            layer.addChild(crown)
            crown.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.4, duration: 1.8), .fadeAlpha(to: 1.0, duration: 1.8),
            ])))
            let heart = SKSpriteNode(color: SKColor(red: 1.0, green: 0.62, blue: 0.15, alpha: 0.85),
                                     size: CGSize(width: 26, height: 10))
            heart.position = crown.position
            heart.zPosition = 1
            layer.addChild(heart)
            heart.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.5, duration: 1.1), .fadeAlpha(to: 1.0, duration: 1.1),
            ])))
        }

        // Thin hot veil so the panorama reads as distant burning air.
        let veil = SKSpriteNode(color: SKColor(red: 0.55, green: 0.16, blue: 0.08, alpha: 0.14),
                                size: CGSize(width: panoW, height: panoH))
        veil.anchorPoint = CGPoint(x: 0, y: 0.5)
        veil.position = pano.position
        veil.zPosition = 2
        layer.addChild(veil)
    }

    // MARK: - Mid ground (ONE strip set, never tiled)

    private static var ashTexCache: [SKTexture] = []
    private static let fieldW = 800
    private static let fieldH = 110

    /// Rolling skyline contour per ash sheet (far / mid / near).
    private static let ashContours: [
        (base: Int, amp1: Int, f1: Double, amp2: Int, f2: Double, phase: Double)
    ] = [
        (42, 12, 1.35, 6, 2.75, 0.35),
        (54, 17, 1.05, 9, 2.45, 1.15),
        (64, 21, 0.80, 11, 2.15, 2.05),
    ]

    /// Low ash dunes per sheet.
    private static let ashDunes: [[(x: Int, w: Int, h: Int)]] = [
        [(150, 120, 9), (470, 140, 7), (720, 110, 8)],
        [(80, 100, 12), (330, 130, 10), (610, 120, 13), (760, 90, 8)],
        [(140, 130, 14), (430, 110, 11), (680, 140, 13)],
    ]

    private static func ashRow(_ px: Int, variant: Int) -> Int {
        let c = ashContours[variant]
        let t = Double(px) / Double(fieldW)
        let w1 = Double(sin(t * .pi * 2.0 * c.f1 + c.phase)) * Double(c.amp1)
        let w2 = Double(sin(t * .pi * 2.0 * c.f2 + c.phase * 2.3)) * Double(c.amp2)
        var rise = 0.0
        for dune in ashDunes[variant] {
            let dx = (Double(px) - Double(dune.x)) / Double(dune.w)
            rise += Double(dune.h) * exp(-dx * dx * 2.4)
        }
        let grain = Double(hash(px, 11, 700 + variant) - 50) / 100 * 1.5
        return Int((Double(c.base) - rise + w1 + w2 + grain).rounded())
    }

    private static func ashTexture(variant: Int) -> SKTexture {
        let W = fieldW, H = fieldH
        while ashTexCache.count <= variant {
            let v = ashTexCache.count
            ashTexCache.append(render(w: W, h: H) { cg in
                cg.setShouldAntialias(false)
                cg.clear(CGRect(x: 0, y: 0, width: W, height: H))

                var sky = [Int](repeating: H / 2, count: W)
                for px in 0..<W {
                    sky[px] = max(6, min(H - 8, ashRow(px, variant: v)))
                }

                // Ash face: dark wastes rolling into ember-lit shadow, lit
                // from the burning horizon. Slope shading rounds the dunes.
                let bandRows = 8
                for px in 0..<W {
                    let top = sky[px]
                    let depth = H - top
                    let l = sky[max(0, px - 2)]
                    let r = sky[min(W - 1, px + 2)]
                    let slope = CGFloat(r - l) / 4
                    let shade = min(1, max(0, slope * 0.14))
                    let lit = min(1, max(0, -slope * 0.14))
                    for r0 in stride(from: top, to: H, by: bandRows) {
                        let rows = min(bandRows, H - r0)
                        let mid = CGFloat(r0 - top) + CGFloat(rows) / 2
                        let t = mid / CGFloat(max(1, depth))
                        var c: UIColor
                        if v == 0 {
                            c = blend(ashDk, ash, 0.35 + t * 0.4)
                        } else if v == 1 {
                            c = blend(ash, ashDk, t * 0.6)
                        } else {
                            c = blend(ash, basalt, t * 0.55)
                        }
                        let edge = 1 - t * 0.7
                        if shade > 0.01 { c = blend(c, peakDk, shade * 0.4 * edge) }
                        if lit > 0.01 { c = blend(c, emberRim, lit * 0.35 * edge) }
                        fill(cg, px, r0, 1, rows, c)
                    }
                    // Ember-lit crest of the rolling ridge.
                    fill(cg, px, top, 1, 2, emberRim.withAlphaComponent(0.5))
                    if hash(px, 23, 90 + v) < 12 {
                        fill(cg, px, top + 2, 1, 2, lavaHot.withAlphaComponent(0.3))
                    }
                }

                // Glowing lava cracks bleeding across the waste.
                for k in 0..<3 {
                    let row = H / 3 + k * 22 + hash(k, 5, 301 + v) % 8
                    guard row < H - 4 else { continue }
                    var rx = hash(k, 7, 302 + v) % (W / 2)
                    while rx < W - 10 {
                        let seg = 8 + hash(rx, row, 303 + v) % 22
                        for px in rx..<(rx + seg) {
                            guard px < W else { break }
                            fill(cg, px, row, 1, 1, lavaHot.withAlphaComponent(0.7))
                            if hash(px, row, 304 + v) < 35 {
                                fill(cg, px, row, 1, 1, lavaCore)
                            }
                        }
                        rx += seg + 10 + hash(rx, row, 305 + v) % 30
                    }
                }

                // Depth seating shadow along the base.
                for px in 0..<W {
                    let wobble = hash(px, 7, 2) * 5 / 100
                    let row = H - 9 + wobble
                    guard row < H else { continue }
                    fill(cg, px, row, 1, H - row, peakDk.withAlphaComponent(0.5))
                }

                switch v {
                case 0: drawFarWaste(cg, sky: sky, W: W, H: H)
                case 1: drawMidWaste(cg, sky: sky, W: W, H: H)
                default: drawNearWaste(cg, sky: sky, W: W, H: H)
                }
            })
            ashTexCache[v].filteringMode = .nearest
        }
        return ashTexCache[variant]
    }

    /// Far sheet: a ruined black gatehouse on the skyline + dead trees.
    private static func drawFarWaste(_ cg: CGContext, sky: [Int], W: Int, H: Int) {
        let stone = UIColor(red: 0.09, green: 0.06, blue: 0.06, alpha: 1)
        let rim = UIColor(red: 1.0, green: 0.42, blue: 0.12, alpha: 1)
        // Broken gatehouse straddling the ridge (x 560-620).
        let bx = 566
        let brow = sky[bx]
        fill(cg, bx, brow, 10, 18, stone)
        fill(cg, bx + 44, brow, 10, 18, stone)
        fill(cg, bx, brow, 54, 5, stone)
        fill(cg, bx, brow, 54, 1, rim.withAlphaComponent(0.7))
        fill(cg, bx + 22, brow + 5, 10, 13, abyssDeep)
        fill(cg, bx + 22, brow + 14, 10, 1, lavaHot.withAlphaComponent(0.8))
        // Dead trees: bare forked black snags along the ridge.
        for tx in [120, 240, 380, 700, 760] {
            let base = sky[tx] + 2
            let h = 14 + hash(tx, 3, 311) % 12
            fill(cg, tx, base - h, 2, h, stone)
            fill(cg, tx - 5, base - h + 4, 5, 2, stone)
            fill(cg, tx + 2, base - h + 8, 5, 2, stone)
        }
        _ = H
    }

    /// Mid sheet: obsidian shard clusters jutting out of the ash.
    private static func drawMidWaste(_ cg: CGContext, sky: [Int], W: Int, H: Int) {
        for cx in [90, 300, 520, 700] {
            let base = sky[cx] + 2
            let shards = 3 + hash(cx, 3, 321) % 3
            for s in 0..<shards {
                let h = 10 + hash(cx, s, 322) % 18
                let w = 3 + hash(cx, s, 323) % 3
                let x = cx + (s - shards / 2) * 7
                for i in 0..<h {
                    let ww = max(1, w - i * w / max(1, h))
                    fill(cg, x - ww / 2, base - i, ww, 1,
                         i < 2 ? emberRim.withAlphaComponent(0.7) : basalt)
                }
            }
        }
        _ = W; _ = H
    }

    /// Near sheet: a fallen scorched banner-pole + rubble.
    private static func drawNearWaste(_ cg: CGContext, sky: [Int], W: Int, H: Int) {
        let bx = 420
        let base = sky[bx] + 2
        // Toppled pole lying along the ridge.
        for px in bx..<(bx + 60) {
            fill(cg, px, base + (px - bx) / 12, 2, 2,
                 UIColor(red: 0.10, green: 0.07, blue: 0.07, alpha: 1))
        }
        // Torn war cloth still clinging to it, ember-edged.
        fill(cg, bx + 12, base - 2, 16, 8, UIColor(red: 0.45, green: 0.08, blue: 0.06, alpha: 1))
        fill(cg, bx + 12, base + 5, 16, 1, emberRim.withAlphaComponent(0.6))
        // Rubble chunks.
        for r in 0..<6 {
            let rx = bx - 30 + hash(r, 3, 331) % 130
            let ry = base + hash(r, 5, 332) % 4
            fill(cg, rx, ry, 3 + hash(r, 7, 333) % 4, 2, basaltDk)
            fill(cg, rx, ry + 2, 3, 1, ashHi.withAlphaComponent(0.6))
        }
        _ = W; _ = H
    }

    /// Rolling ash wastes: three stacked sheets of ember-veined dunes with
    /// a ruined gatehouse, dead trees, obsidian fangs and fallen banners —
    /// plus drifting ash mist. Only the mist + lava shimmer loop.
    static func buildMid(in layer: SKNode, sceneSize: CGSize) {
        let travel = Balance.levelWidth * Balance.parallaxMid
        let panoW: CGFloat = sceneSize.width + travel + 1200
        let panoH = sceneSize.height * 0.34
        let baseY = -sceneSize.height * 0.20
        let baseX = -sceneSize.width * 0.6

        let grades: [(lift: CGFloat, hue: (UIColor, CGFloat), factor: CGFloat)] = [
            (44, (mistAsh, 0.45), Balance.parallaxMid - 0.055),
            (16, (ash, 0.30), Balance.parallaxMid),
            (-10, (basalt, 0.22), Balance.parallaxMid + 0.055),
        ]
        for (ri, g) in grades.enumerated() {
            let root = MidParallaxNode()
            root.baseX = baseX
            root.cameraFactor = g.factor
            root.position = CGPoint(x: baseX, y: baseY + g.lift)
            root.zPosition = CGFloat(ri)
            let strip = SKSpriteNode(texture: ashTexture(variant: ri))
            strip.anchorPoint = CGPoint(x: 0, y: 0.5)
            strip.size = CGSize(width: panoW, height: panoH)
            strip.color = g.hue.0
            strip.colorBlendFactor = g.hue.1
            root.addChild(strip)
            layer.addChild(root)
        }

        // Drifting ash mist: dark red-grey bands along the waste line.
        let mistRoot = MidParallaxNode()
        mistRoot.baseX = 0
        mistRoot.cameraFactor = Balance.parallaxMid + 0.075
        mistRoot.zPosition = 3
        layer.addChild(mistRoot)
        var rng = SeededRNG(seed: 281128)
        let mistTex = ashMistTexture()
        for _ in 0..<8 {
            let band = SKSpriteNode(texture: mistTex)
            band.size = CGSize(width: panoW * rng.cgFloat(in: 0.14...0.24),
                               height: rng.cgFloat(in: 18...30))
            band.position = CGPoint(x: rng.cgFloat(in: 0...panoW * 0.7),
                                    y: baseY + rng.cgFloat(in: 10...64))
            band.zPosition = 0
            band.alpha = rng.cgFloat(in: 0.14...0.22)
            mistRoot.addChild(band)
            let drift = SKAction.moveBy(x: rng.cgFloat(in: 70...150), y: 0,
                                        duration: rng.double(in: 9...15))
            band.run(.repeatForever(.sequence([drift, drift.reversed()])))
        }

        // Ashen March grade (Level 29+): the march kicks up the waste — an
        // extra low sheet of fast ash drifts scouring the dune feet.
        // The Vale keeps the March's churned air.
        if Balance.ashenMarch || Balance.blackrootVale || Balance.cinderGate || Balance.shadowRift || Balance.dreadHollow || Balance.obsidianGate || Balance.embralCore {
            for i in 0..<5 {
                let band = SKSpriteNode(texture: mistTex)
                band.size = CGSize(width: panoW * rng.cgFloat(in: 0.10...0.18),
                                   height: rng.cgFloat(in: 10...16))
                band.position = CGPoint(x: rng.cgFloat(in: 0...panoW * 0.7),
                                        y: baseY + rng.cgFloat(in: 2...18))
                band.zPosition = 4
                band.alpha = rng.cgFloat(in: 0.20...0.30)
                mistRoot.addChild(band)
                let scour = SKAction.moveBy(x: rng.cgFloat(in: 180...300), y: 0,
                                            duration: rng.double(in: 5...8))
                band.run(.repeatForever(.sequence([
                    SKAction.wait(forDuration: Double(i) * 0.4),
                    scour,
                    SKAction.run { [weak band] in
                        band?.position.x -= 260
                    },
                ])))
            }
        }
    }

    private static var ashMistTexCache: SKTexture?
    private static func ashMistTexture() -> SKTexture {
        if let ashMistTexCache { return ashMistTexCache }
        let tex = render(w: 120, h: 12) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: 120, height: 12))
            for x in 0..<120 {
                let env = sin(CGFloat(x) / 120 * .pi)
                for y in 0..<12 {
                    let v = sin(CGFloat(y) / 12 * .pi)
                    let a = env * v * 0.5
                    guard a > 0.03 else { continue }
                    fill(cg, x, y, 1, 1, UIColor(red: 0.45, green: 0.18, blue: 0.12, alpha: a))
                }
            }
        }
        tex.filteringMode = .linear
        ashMistTexCache = tex
        return tex
    }

    // MARK: - Shared pixel-art decals (also used by LevelDressing)

    private static var moonTexCache: SKTexture?
    /// Chunky pixel-art ember moon: stepped disc with a dithered edge,
    /// blocky maria scars and a molten lower rim. Baked 44px, stretched
    /// with .nearest — never a smooth vector disc.
    private static func emberMoonTexture() -> SKTexture {
        if let moonTexCache { return moonTexCache }
        let S = 44
        let tex = render(w: S, h: S) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: S, height: S))
            let blood = UIColor(red: 0.72, green: 0.16, blue: 0.07, alpha: 1)
            let bloodDk = UIColor(red: 0.42, green: 0.08, blue: 0.05, alpha: 1)
            let scar = UIColor(red: 0.34, green: 0.07, blue: 0.045, alpha: 1)
            for py in 0..<S {
                for px in 0..<S {
                    let dx = CGFloat(px) - 21.5, dy = CGFloat(py) - 21.5
                    let d = sqrt(dx * dx + dy * dy)
                    guard d <= 20 else { continue }
                    // Dithered stepped edge instead of an antialiased rim.
                    if d > 19, (px + py) % 2 == 0 { continue }
                    let t = CGFloat(py) / CGFloat(S - 1) // hotter low
                    fill(cg, px, py, 1, 1, blend(bloodDk, blood, t))
                }
            }
            // Blocky maria scars so it reads as a scorched moon, not a sun.
            for (rx, ry, rw, rh) in [(12, 10, 7, 5), (25, 18, 8, 6), (16, 27, 6, 5)] as [(Int, Int, Int, Int)] {
                fill(cg, rx, ry, rw, rh, scar)
                fill(cg, rx, ry, rw, 1, bloodDk)
            }
            // Molten lower rim: a bright stepped crescent along the bottom.
            for px in 0..<S {
                let dx = CGFloat(px) - 21.5
                let edge = 20 * 20 - dx * dx
                guard edge > 0 else { continue }
                let iy = Int(21.5 + sqrt(edge)) - 1
                guard iy >= 0, iy + 1 < S else { continue }
                fill(cg, px, iy, 1, 2, lavaHot)
                if px % 3 == 0 { fill(cg, px, iy, 1, 1, lavaCore) }
            }
        }
        tex.filteringMode = .nearest
        moonTexCache = tex
        return tex
    }

    private static var glowTexCache: SKTexture?
    /// Blocky baked glow: quantized alpha steps so every halo and bloom
    /// reads as chunky pixels, never a smooth vector gradient.
    static func emberGlowTexture() -> SKTexture {
        if let glowTexCache { return glowTexCache }
        let S = 32
        let tex = render(w: S, h: S) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: S, height: S))
            for py in 0..<S {
                for px in 0..<S {
                    let dx = (CGFloat(px) - 15.5) / 16, dy = (CGFloat(py) - 15.5) / 16
                    let d = min(1, sqrt(dx * dx + dy * dy))
                    guard d < 1 else { continue }
                    let step = max(0, min(3, Int((1 - d) * 4)))
                    let a: CGFloat = [0.05, 0.10, 0.16, 0.24][step]
                    fill(cg, px, py, 1, 1, UIColor(red: 1.0, green: 0.42, blue: 0.10, alpha: a))
                }
            }
        }
        tex.filteringMode = .nearest
        glowTexCache = tex
        return tex
    }

    private static var crackTexCache: [SKTexture] = []
    /// Jagged lava-crack decals: a wandering dark split with ember pixels
    /// and a hot core — split rock, never filled dark blobs. 3 baked
    /// variants, 64x12px, stretched 2x.
    static func crackTexture(variant: Int) -> SKTexture {
        let v = ((variant % 3) + 3) % 3
        while crackTexCache.count <= v {
            let idx = crackTexCache.count
            crackTexCache.append(render(w: 64, h: 12) { cg in
                cg.clear(CGRect(x: 0, y: 0, width: 64, height: 12))
                var seed = UInt64(idx * 131 + 7)
                var y = 6
                var x = 0
                while x < 64 {
                    seed = seed &* 1103515245 &+ 12345
                    let seg = 3 + Int(seed % 5)
                    for px in x..<(min(64, x + seg)) {
                        fill(cg, px, y, 1, 2, abyssDeep)
                        fill(cg, px, y, 1, 1, lavaHot)
                        seed = seed &* 1103515245 &+ 12345
                        if seed % 100 < 30 { fill(cg, px, y, 1, 1, lavaCore) }
                        seed = seed &* 1103515245 &+ 12345
                        if seed % 100 < 28 {
                            fill(cg, px, max(0, y - 2), 1, 1,
                                 lavaHot.withAlphaComponent(0.35))
                        }
                        if seed % 100 < 24 {
                            fill(cg, px, min(10, y + 2), 1, 1,
                                 lavaHot.withAlphaComponent(0.3))
                        }
                    }
                    seed = seed &* 1103515245 &+ 12345
                    y = max(2, min(9, y + Int(seed % 5) - 2))
                    x += seg
                }
            })
            crackTexCache[idx].filteringMode = .nearest
        }
        return crackTexCache[v]
    }

    private static var shardTexCache: [SKTexture] = []
    /// Obsidian shard clusters: stepped black-glass blades with ember-lit
    /// windward edges and a hot tip pixel. 3 baked variants, 28x18px.
    static func obsidianShardTexture(variant: Int) -> SKTexture {
        let v = ((variant % 3) + 3) % 3
        while shardTexCache.count <= v {
            let idx = shardTexCache.count
            let layouts = [
                [(5, 12, 5), (12, 16, 5), (19, 9, 4)],
                [(4, 9, 4), (10, 14, 5), (17, 16, 5), (23, 8, 4)],
                [(6, 15, 5), (13, 10, 4), (20, 13, 5)],
            ]
            shardTexCache.append(render(w: 28, h: 18) { cg in
                cg.clear(CGRect(x: 0, y: 0, width: 28, height: 18))
                let glass = UIColor(red: 0.05, green: 0.035, blue: 0.045, alpha: 1)
                for (bx, h, bw) in layouts[idx] {
                    for i in 0..<h {
                        let ww = max(1, bw - i * bw / max(1, h))
                        let row = 17 - i
                        fill(cg, bx - ww / 2, row, ww, 1, glass)
                        fill(cg, bx - ww / 2, row, 1, 1, emberRim)
                    }
                    fill(cg, bx, 17 - h, 1, 1, lavaHot)
                }
            })
            shardTexCache[idx].filteringMode = .nearest
        }
        return shardTexCache[v]
    }

    private static var scorchTexCache: SKTexture?
    /// Scorched-earth patch: dithered dark pixels fading at the rim —
    /// grounds braziers and rocks with no smooth ellipse anywhere.
    static func scorchTexture() -> SKTexture {
        if let scorchTexCache { return scorchTexCache }
        let tex = render(w: 24, h: 6) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: 24, height: 6))
            for py in 0..<6 {
                for px in 0..<24 {
                    let ex = abs(CGFloat(px) - 11.5) / 12
                    let ey = abs(CGFloat(py) - 2.5) / 3
                    let d = max(ex, ey)
                    // Dithered rim: pixels drop out toward the edge.
                    if d > 0.55, (px * 7 + py * 13) % 10 < Int(d * 10) { continue }
                    fill(cg, px, py, 1, 1, UIColor(white: 0, alpha: 0.5))
                }
            }
        }
        tex.filteringMode = .nearest
        scorchTexCache = tex
        return tex
    }

    private static var rockTexCache: [SKTexture] = []
    /// Near-camera basalt chunks: stepped pixel rocks with ember top rims
    /// and ash speckle. 3 baked variants, 24x14px.
    private static func foregroundRockTexture(variant: Int) -> SKTexture {
        let v = ((variant % 3) + 3) % 3
        while rockTexCache.count <= v {
            let idx = rockTexCache.count
            let apex = [9, 13, 7][idx]
            rockTexCache.append(render(w: 24, h: 14) { cg in
                cg.clear(CGRect(x: 0, y: 0, width: 24, height: 14))
                for r in 0..<12 {
                    let w = max(2, 22 - r * 2 + (r == 4 ? 2 : 0))
                    let cx = apex + (r < 6 ? (r - 3) / 2 : (9 - r) / 2)
                    let row = 13 - r
                    fill(cg, cx - w / 2, row, w, 1, basalt)
                    if r == 11 || r == 10 {
                        fill(cg, cx - w / 2, row, w, 1, emberRim.withAlphaComponent(0.6))
                    }
                    if hash(cx, row, 881 + idx) < 22 {
                        fill(cg, cx - w / 2 + hash(row, 3, 882) % max(1, w), row, 1, 1,
                             ashHi.withAlphaComponent(0.6))
                    }
                }
            })
            rockTexCache[idx].filteringMode = .nearest
        }
        return rockTexCache[v]
    }

    // MARK: - Ground (cracked basalt lane)

    /// Basalt surface: near-black ash rock, hairline cracks, ember veins
    /// bleeding through, ash mottling and hot sparkle pixels. Row 0 = top.
    private static var tileCache: SKTexture?
    static func mordorLaneTileTexture() -> SKTexture {
        if let tileCache { return tileCache }
        let W = 115, H = 26
        let tex = render(w: W, h: H) { cg in
            cg.setShouldAntialias(false)
            // Walkable face: dark ash rock, faintly warm so units pop.
            for py in 0..<H {
                let t = CGFloat(py) / CGFloat(H - 1)
                fill(cg, 0, py, W, 1, blend(ashHi, ash, 0.2 + t * 0.8))
            }
            // Mottled ash + scorched patches.
            for i in 0..<70 {
                let x = hash(i, 4, 551) % W
                let y = 2 + hash(i, 5, 552) % (H - 2)
                let c = hash(i, 6, 553) < 45 ? ashDk : basalt
                fill(cg, x, y, 1 + hash(i, 7, 554) % 3, 1, c.withAlphaComponent(0.6))
            }
            // Hairline cracks with ember hearts.
            for c in 0..<5 {
                var cx = hash(c, 3, 555) % W
                let cy = 4 + hash(c, 5, 556) % (H - 8)
                while cx < W - 2 {
                    fill(cg, cx, cy, 2, 1, abyssDeep)
                    if hash(cx, cy, 557) < 40 {
                        fill(cg, cx, cy, 1, 1, lavaHot)
                        if hash(cx, cy, 558) < 20 {
                            fill(cg, cx, cy, 1, 1, lavaCore)
                        }
                    }
                    cx += 2 + hash(cx, cy, 559) % 4
                }
            }
            // Hot sparkles.
            for s in 0..<22 {
                let sx = hash(s, 3, 560) % W
                let sy = hash(s, 4, 561) % (H - 4) + 2
                fill(cg, sx, sy, 1, 1,
                     hash(s, 5, 562) < 50 ? lavaHot.withAlphaComponent(0.85) : lavaCore.withAlphaComponent(0.8))
            }
            // Ember-lit lip clumps on the top edge.
            for px in 0..<W {
                if hash(px, 1, 563) < 16 {
                    fill(cg, px, H - 2, 2, 2, emberRim.withAlphaComponent(0.5))
                }
            }
        }
        tex.filteringMode = .nearest
        tileCache = tex
        return tex
    }

    /// Cracked basalt lane over deep dark strata, ember-lit lip, faint team
    /// washes, baked ash details + looping ember updrafts.
    static func buildGround(in world: SKNode) {
        let width = Balance.levelWidth
        let gy = Balance.groundTopY

        let tile = mordorLaneTileTexture()
        let tileW: CGFloat = 460, tileH: CGFloat = 104
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

        // Ember-lit walkable lip + heat shimmer beneath it.
        let lip = SKSpriteNode(color: SKColor(red: 1.0, green: 0.45, blue: 0.14, alpha: 0.75),
                               size: CGSize(width: width, height: 3))
        lip.anchorPoint = CGPoint(x: 0, y: 1)
        lip.position = CGPoint(x: 0, y: gy + 1)
        lip.zPosition = 2
        world.addChild(lip)
        let shimmer = SKSpriteNode(color: SKColor(red: 1.0, green: 0.35, blue: 0.08, alpha: 0.10),
                                   size: CGSize(width: width, height: 12))
        shimmer.anchorPoint = CGPoint(x: 0, y: 1)
        shimmer.position = CGPoint(x: 0, y: gy - 2)
        shimmer.zPosition = 2
        world.addChild(shimmer)

        // Dark basalt strata below the lane, then the deep.
        var y = gy - tileH
        let strata: [(CGFloat, SKColor)] = [
            (64, SKColor(red: 0.10, green: 0.06, blue: 0.065, alpha: 1)),
            (120, SKColor(red: 0.06, green: 0.035, blue: 0.04, alpha: 1)),
            (180, SKColor(red: 0.025, green: 0.012, blue: 0.015, alpha: 1)),
        ]
        for (depth, color) in strata {
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
            let deep = SKSpriteNode(color: SKColor(red: 0.025, green: 0.012, blue: 0.015, alpha: 1),
                                    size: CGSize(width: width, height: y))
            deep.anchorPoint = CGPoint(x: 0, y: 1)
            deep.position = CGPoint(x: 0, y: y)
            deep.zPosition = 0
            world.addChild(deep)
        }
        // Embedded embers glowing inside the rock.
        var rng = SeededRNG(seed: 285281)
        for _ in 0..<18 {
            let s: CGFloat = rng.cgFloat(in: 2...5)
            let ember = SKSpriteNode(color: SKColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 0.8),
                                     size: CGSize(width: s, height: s))
            ember.position = CGPoint(x: rng.cgFloat(in: 0...width),
                                     y: rng.cgFloat(in: 8...(gy - tileH - 6)))
            ember.zPosition = 1
            world.addChild(ember)
            ember.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.25, duration: rng.double(in: 0.6...1.4)),
                .fadeAlpha(to: 0.9, duration: rng.double(in: 0.6...1.4)),
            ])))
        }

        // Faint team washes (blue left / red right).
        let half = width / 2
        let washL = SKSpriteNode(color: SKColor(red: 0.3, green: 0.5, blue: 1, alpha: 0.06),
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

        // Ashen March grade (Level 29+): the lane runs hotter — extra ember
        // veins breathing under the lip and a deeper red wash mid-field.
        // The Vale keeps the March's hot lane under its roots.
        if Balance.ashenMarch || Balance.blackrootVale || Balance.cinderGate || Balance.shadowRift || Balance.dreadHollow || Balance.obsidianGate || Balance.embralCore {
            let marchWash = SKSpriteNode(
                color: SKColor(red: 0.85, green: 0.18, blue: 0.06, alpha: 0.08),
                size: CGSize(width: width, height: tileH))
            marchWash.anchorPoint = CGPoint(x: 0, y: 1)
            marchWash.position = CGPoint(x: 0, y: gy - 6)
            marchWash.zPosition = 2
            world.addChild(marchWash)
            marchWash.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 2.8), .fadeAlpha(to: 1.0, duration: 2.8),
            ])))
            for i in 0..<6 {
                let vein = SKSpriteNode(texture: crackTexture(variant: i % 3))
                vein.size = CGSize(width: 150, height: 20)
                let vx = (width / 6) * (CGFloat(i) + 0.5)
                vein.position = CGPoint(x: vx, y: gy - tileH * 0.25)
                vein.zPosition = 2
                vein.alpha = 0.8
                world.addChild(vein)
                vein.run(.repeatForever(.sequence([
                    .wait(forDuration: Double(i) * 0.4),
                    .fadeAlpha(to: 0.5, duration: 1.8),
                    .fadeAlpha(to: 0.85, duration: 1.8),
                ])))
            }
        }

        bakeGroundDetails(in: world, width: width, gy: gy)
        startEmberUpdraft(in: world, width: width, gy: gy)
    }

    /// Static chunk dressing: scorched slabs + ash chips, one baked sprite
    /// per 1024pt.
    private static func bakeGroundDetails(in world: SKNode, width: CGFloat, gy: CGFloat) {
        let chunkW: CGFloat = 1024
        var x0: CGFloat = 0
        var chunk = 0
        while x0 < width {
            let span = min(chunkW, width - x0)
            var rng = SeededRNG(seed: UInt64(282810 + chunk * 613))
            let root = SKNode()

            let slabCount = max(0, Int((22 * span / width).rounded()))
            for _ in 0..<slabCount {
                let sx = rng.cgFloat(in: 24...(span - 24))
                let w = rng.cgFloat(in: 12...36)
                let h = rng.cgFloat(in: 3...6)
                let slab = SKSpriteNode(color: SKColor(red: 0.14, green: 0.08, blue: 0.08, alpha: 0.95),
                                        size: CGSize(width: w, height: h))
                slab.position = CGPoint(x: sx, y: gy + rng.cgFloat(in: 2...5))
                slab.zPosition = 2
                root.addChild(slab)
                // Hot seam pixel row riding the slab's top edge.
                let seam = SKSpriteNode(color: SKColor(red: 1.0, green: 0.42, blue: 0.12, alpha: 0.4),
                                        size: CGSize(width: w, height: 1))
                seam.position = CGPoint(x: 0, y: h / 2)
                slab.addChild(seam)
            }

            // Baked lava-crack decals splitting the ash between the slabs.
            let crackCount = max(1, Int((3 * span / width).rounded()))
            for c in 0..<crackCount {
                let decal = SKSpriteNode(texture: crackTexture(variant: (chunk + c) % 3))
                decal.size = CGSize(width: 128, height: 24)
                decal.position = CGPoint(x: rng.cgFloat(in: 64...(span - 64)), y: gy + 3)
                decal.zPosition = 2
                root.addChild(decal)
            }

            let chipCount = max(0, Int((30 * span / width).rounded()))
            for _ in 0..<chipCount {
                let sx = rng.cgFloat(in: 20...(span - 20))
                let s = rng.cgFloat(in: 2...5)
                let chip = SKSpriteNode(color: rng.int(in: 0...1) == 0
                    ? SKColor(red: 0.30, green: 0.17, blue: 0.14, alpha: 0.9)
                    : SKColor(red: 0.10, green: 0.06, blue: 0.06, alpha: 0.9),
                    size: CGSize(width: s, height: s * 0.7))
                chip.position = CGPoint(x: sx, y: gy + 2)
                chip.zPosition = 2
                root.addChild(chip)
            }

            if let baked = SceneryBake.baked(key: "mordor.ground.detail.\(Int(width)).\(chunk)",
                                             build: { root }) {
                SceneryBake.add(baked, to: world,
                                origin: CGPoint(x: x0, y: 0), zPosition: 2)
            }
            x0 += span
            chunk += 1
        }
    }

    /// Looping ember updrafts + drifting ash grains over the lane.
    private static func startEmberUpdraft(in world: SKNode, width: CGFloat, gy: CGFloat) {
        var rng = SeededRNG(seed: 282828)
        for i in 0..<20 {
            let emberHot = rng.int(in: 0...2) != 0
            let s: CGFloat = rng.cgFloat(in: 2...4)
            let mote = SKSpriteNode(color: emberHot
                ? SKColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 0.9)
                : SKColor(red: 0.45, green: 0.25, blue: 0.20, alpha: 0.7),
                size: CGSize(width: s, height: s))
            let homeX = rng.cgFloat(in: 0...width)
            mote.position = CGPoint(x: homeX, y: gy + rng.cgFloat(in: 4...50))
            mote.zPosition = 3
            world.addChild(mote)
            let fly = SKAction.moveBy(x: rng.cgFloat(in: -26...26),
                                      y: rng.cgFloat(in: 60...150),
                                      duration: rng.double(in: 2.2...4.4))
            let vanish = SKAction.sequence([
                SKAction.wait(forDuration: 1.4),
                SKAction.fadeOut(withDuration: 1.4),
            ])
            mote.run(.repeatForever(.sequence([
                SKAction.wait(forDuration: Double(i) * 0.18),
                SKAction.group([fly, vanish]),
                SKAction.run { mote.position = CGPoint(x: homeX, y: gy + 4) },
                SKAction.fadeIn(withDuration: 0.4),
            ])))
        }
    }

    // MARK: - Foreground (factor 1.28, subtle)

    /// Near-camera wastes: ash scrub with ember tips and sway, angular
    /// basalt chunks with hot rims, drifting ash bokeh + rising sparks —
    /// sparse so the fight stays readable.
    static func buildForeground(in layer: SKNode) {
        var rng = SeededRNG(seed: 288046)
        let span = Balance.levelWidth * Balance.parallaxForeground

        // Ash scrub: sparse dark blade fans with ember tips.
        for _ in 0..<30 {
            let x = rng.cgFloat(in: 0...span)
            let tuft = SKNode()
            tuft.position = CGPoint(x: x, y: 0)
            let blades = rng.int(in: 3...5)
            for b in 0..<blades {
                let h = rng.cgFloat(in: 20...42)
                let bx = CGFloat(b - blades / 2) * 6 + rng.cgFloat(in: -3...3)
                let blade = SKSpriteNode(color: SKColor(red: 0.12, green: 0.07, blue: 0.07, alpha: 0.75),
                                         size: CGSize(width: 5, height: h))
                blade.anchorPoint = CGPoint(x: 0.5, y: 0)
                blade.position = CGPoint(x: bx, y: 0)
                blade.zRotation = rng.cgFloat(in: -0.14...0.14)
                tuft.addChild(blade)
                let tip = SKSpriteNode(color: SKColor(red: 1.0, green: 0.45, blue: 0.14, alpha: 0.6),
                                       size: CGSize(width: 2, height: 3))
                tip.position = CGPoint(x: bx, y: h - 2)
                tip.zRotation = blade.zRotation
                tuft.addChild(tip)
            }
            layer.addChild(tuft)
            tuft.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.022, duration: rng.double(in: 2.2...3.6)),
                .rotate(toAngle: -0.022, duration: rng.double(in: 2.2...3.6)),
            ])))
        }

        // Angular basalt chunks with ember rims over dithered contact
        // shadows — baked pixels, no vector shapes.
        for i in 0..<6 {
            let x = CGFloat(i) * (span / 6) + rng.cgFloat(in: -70...70)
            let w = rng.cgFloat(in: 44...72)
            let shadow = SKSpriteNode(texture: scorchTexture())
            shadow.size = CGSize(width: w + 12, height: 14)
            shadow.position = CGPoint(x: x, y: 1)
            layer.addChild(shadow)
            let rock = SKSpriteNode(texture: foregroundRockTexture(variant: i % 3))
            rock.size = CGSize(width: w, height: w * 14 / 24)
            rock.position = CGPoint(x: x, y: 4)
            layer.addChild(rock)
        }

        // Hot bokeh: chunky low-alpha ember squares drifting near-camera.
        for _ in 0..<8 {
            let s = rng.cgFloat(in: 6...12)
            let mote = SKSpriteNode(color: SKColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 0.10),
                                    size: CGSize(width: s, height: s))
            mote.position = CGPoint(x: rng.cgFloat(in: 0...span), y: rng.cgFloat(in: 24...180))
            layer.addChild(mote)
            let drift = SKAction.moveBy(x: rng.cgFloat(in: -110...110),
                                        y: rng.cgFloat(in: -18...22),
                                        duration: rng.double(in: 6...11))
            mote.run(.repeatForever(.sequence([drift, drift.reversed()])))
        }
        for i in 0..<10 {
            let f = SKSpriteNode(color: SKColor(red: 1, green: 0.5, blue: 0.15, alpha: 0.9),
                                 size: CGSize(width: 4, height: 4))
            f.position = CGPoint(x: CGFloat(i) * (span / 10), y: rng.cgFloat(in: 30...150))
            layer.addChild(f)
            let roam = SKAction.moveBy(x: rng.cgFloat(in: -40...40),
                                       y: rng.cgFloat(in: 30...80),
                                       duration: rng.double(in: 2.5...5.0))
            let vanish = SKAction.sequence([
                SKAction.wait(forDuration: 1.6),
                SKAction.fadeOut(withDuration: 1.2),
            ])
            let home = f.position
            f.run(.repeatForever(.sequence([
                SKAction.group([roam, vanish]),
                SKAction.run { f.position = home },
                SKAction.fadeIn(withDuration: 0.4),
            ])))
        }
    }
}
