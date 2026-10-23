import SpriteKit
import UIKit

/// Frostbite Approach battleground (Level 21+) — a whole frozen theater:
/// polar sky with aurora ribbons, a three-range glacier panorama with
/// snow-capped peaks, ice spires and a frozen bay, snow-covered open
/// pastures in the mid ground (rolling fields, furrow lines, spruce groves,
/// a barn, a cottage and a windmill), a white snow lane over deep blue ice,
/// and a drift-formed foreground. SnowFX runs the actual falling snow.
///
/// Performance notes (mirrors TwilightRuinsBG rules):
/// - Every big surface is ONE low-res CoreGraphics texture baked once,
///   cached in a static, stretched with .nearest (chunky pixels, tiny VRAM).
/// - One wide panorama per layer — nothing tiles, nothing repeats.
/// - Static dressing is rasterized per 1024pt chunk via SceneryBake
///   (one sprite per chunk instead of dozens of live nodes).
/// - Dynamics are only looping SKActions on few nodes — no per-frame
///   Swift code anywhere in this file.
enum FrostbiteBG {

    // MARK: - Palette (polar, bright white field over cold blue)

    private static let skyTop = UIColor(red: 0.02, green: 0.035, blue: 0.10, alpha: 1)
    private static let skyMid = UIColor(red: 0.08, green: 0.13, blue: 0.28, alpha: 1)
    private static let skyLow = UIColor(red: 0.34, green: 0.44, blue: 0.58, alpha: 1)
    private static let horizonIce = UIColor(red: 0.74, green: 0.84, blue: 0.92, alpha: 1)
    private static let mistCold = UIColor(red: 0.56, green: 0.66, blue: 0.75, alpha: 1)

    private static let glacierHi = UIColor(red: 0.58, green: 0.66, blue: 0.78, alpha: 1)
    private static let glacierBody = UIColor(red: 0.42, green: 0.50, blue: 0.64, alpha: 1)
    private static let glacierDk = UIColor(red: 0.30, green: 0.37, blue: 0.51, alpha: 1)
    private static let massif = UIColor(red: 0.19, green: 0.24, blue: 0.36, alpha: 1)
    private static let capWhite = UIColor(red: 0.93, green: 0.97, blue: 1.0, alpha: 1)
    private static let rimCold = UIColor(red: 0.80, green: 0.92, blue: 1.0, alpha: 1)
    private static let spireIce = UIColor(red: 0.66, green: 0.86, blue: 0.97, alpha: 1)
    private static let spireBody = UIColor(red: 0.34, green: 0.46, blue: 0.62, alpha: 1)
    private static let spireGlow = UIColor(red: 0.45, green: 0.88, blue: 1.0, alpha: 1)

    // Snow lane.
    private static let snowHi = UIColor(red: 0.86, green: 0.92, blue: 0.97, alpha: 1)
    private static let snow = UIColor(red: 0.74, green: 0.81, blue: 0.89, alpha: 1)
    private static let snowDk = UIColor(red: 0.60, green: 0.69, blue: 0.80, alpha: 1)
    private static let frostCliff = UIColor(red: 0.15, green: 0.19, blue: 0.29, alpha: 1)
    private static let frostCliffDk = UIColor(red: 0.10, green: 0.13, blue: 0.21, alpha: 1)
    private static let frostDeep = UIColor(red: 0.055, green: 0.075, blue: 0.14, alpha: 1)

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

    // MARK: - Sky (screen-locked)

    /// Polar sky: deep arctic gradient, low pale winter sun iced into the
    /// horizon, two slow-breathing aurora ribbons, cold star twinkle and
    /// thin ice-haze streaks. All bakes + looping actions.
    static func buildSky(in layer: SKNode, sceneSize: CGSize) {
        // Rimevault evening (Level 26): the same frozen theater under a
        // low amber sun — deep indigo zenith melting to ember-gold at the
        // horizon instead of the pale polar noon.
        let evening = Balance.frostEvening
        let eTop = UIColor(red: 0.05, green: 0.06, blue: 0.18, alpha: 1)
        let eMid = UIColor(red: 0.20, green: 0.14, blue: 0.36, alpha: 1)
        let eLow = UIColor(red: 0.62, green: 0.30, blue: 0.28, alpha: 1)
        let eHorizon = UIColor(red: 1.0, green: 0.62, blue: 0.30, alpha: 1)
        let eMist = UIColor(red: 0.52, green: 0.34, blue: 0.32, alpha: 1)
        // Dithered vertical gradient: navy -> steel -> pale ice -> mist.
        let grad = render(w: 2, h: 256) { cg in
            for y in 0..<256 {
                let t = CGFloat(y) / 255 // 0 top -> 1 bottom
                let c: UIColor
                switch t {
                case 0..<0.40:
                    c = blend(evening ? eTop : skyTop, evening ? eMid : skyMid, t / 0.40)
                case 0.40..<0.68:
                    c = blend(evening ? eMid : skyMid, evening ? eLow : skyLow, (t - 0.40) / 0.28)
                case 0.68..<0.85:
                    c = blend(evening ? eLow : skyLow, evening ? eHorizon : horizonIce, (t - 0.68) / 0.17 * 0.7)
                default:
                    c = blend(evening ? eHorizon : horizonIce, evening ? eMist : mistCold, 0.4 + (t - 0.85) / 0.15 * 0.6)
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

        // Winter sun: a small pale disc low over the glacier, warm white
        // to keep the lane readable but cold overall. Evening: a low
        // amber disc sinking into the glacier, with a wider warm halo.
        let sun = SKShapeNode(circleOfRadius: evening ? 42 : 34)
        sun.fillColor = evening
            ? SKColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
            : SKColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
        sun.strokeColor = .clear
        sun.position = CGPoint(x: W * (evening ? 0.60 : 0.70), y: H * (evening ? 0.10 : 0.15))
        sun.zPosition = 1
        layer.addChild(sun)
        let halo = SKShapeNode(circleOfRadius: evening ? 150 : 120)
        halo.fillColor = evening
            ? SKColor(red: 1.0, green: 0.60, blue: 0.30, alpha: 0.35)
            : SKColor(red: 0.80, green: 0.90, blue: 1.0, alpha: 0.26)
        halo.strokeColor = .clear
        halo.position = sun.position
        halo.zPosition = 1
        layer.addChild(halo)
        halo.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 4.2), .fadeAlpha(to: 1.0, duration: 4.2),
        ])))

        // Cold starfield: sparse white dots in the upper half, gentle pulse.
        var rng = SeededRNG(seed: 71021017)
        for _ in 0..<56 {
            let sx = rng.cgFloat(in: -W * 0.6...W * 0.6)
            let sy = rng.cgFloat(in: -H * 0.02...H * 0.62)
            let s = rng.cgFloat(in: 1.4...3.0)
            let star = SKSpriteNode(color: SKColor(white: 0.94, alpha: 0.92),
                                    size: CGSize(width: s, height: s))
            star.position = CGPoint(x: sx, y: sy)
            star.zPosition = 1
            layer.addChild(star)
            star.run(.repeatForever(.sequence([
                .wait(forDuration: rng.double(in: 0...2.6)),
                .fadeAlpha(to: 0.18, duration: rng.double(in: 0.8...1.9)),
                .fadeAlpha(to: 0.95, duration: rng.double(in: 0.8...1.9)),
            ])))
        }

        // Aurora ribbons: two baked gradient sheets with wavy column fades,
        // pulsing alpha + slow drift — the cheapest "living" polar sky.
        // Evening washes them out, so they burn dimmer under the amber sun.
        let auroraTex = auroraTexture()
        for i in 0..<2 {
            let ribbon = SKSpriteNode(texture: auroraTex)
            ribbon.size = CGSize(width: W * 1.1, height: H * (i == 0 ? 0.30 : 0.22))
            ribbon.anchorPoint = CGPoint(x: 0.5, y: 1)
            ribbon.position = CGPoint(x: W * 0.32 + CGFloat(i) * W * 0.34,
                                      y: H * (i == 0 ? 0.86 : 0.66))
            ribbon.zPosition = 1
            ribbon.alpha = evening ? (i == 0 ? 0.22 : 0.16) : (i == 0 ? 0.42 : 0.30)
            layer.addChild(ribbon)
            let pulse = SKAction.sequence([
                .fadeAlpha(to: evening ? (i == 0 ? 0.34 : 0.24) : (i == 0 ? 0.62 : 0.44), duration: 5.6 + Double(i) * 1.7),
                .fadeAlpha(to: evening ? (i == 0 ? 0.16 : 0.12) : (i == 0 ? 0.30 : 0.22), duration: 5.6 + Double(i) * 1.7),
            ])
            ribbon.run(.repeatForever(pulse))
            let sway = SKAction.moveBy(x: W * 0.04, y: 0, duration: 11.0 + Double(i) * 4.0)
            sway.timingMode = .easeInEaseOut
            ribbon.run(.repeatForever(.sequence([sway, sway.reversed()])))
        }

        // Ice-haze streaks: thin cold cloud sheets drifting slowly.
        // Evening tints them warm ember-rose under the low sun.
        for _ in 0..<6 {
            let cw = W * rng.cgFloat(in: 0.32...0.55)
            let cloud = SKSpriteNode(color: evening
                ? SKColor(red: 0.96, green: 0.62, blue: 0.44, alpha: 0.22)
                : SKColor(red: 0.82, green: 0.88, blue: 0.96, alpha: 0.20),
                                     size: CGSize(width: cw, height: rng.cgFloat(in: 8...16)))
            cloud.position = CGPoint(x: rng.cgFloat(in: -W * 0.6...W * 0.6),
                                     y: H * rng.cgFloat(in: 0.04...0.46))
            cloud.zPosition = 2
            layer.addChild(cloud)
            let drift = SKAction.moveBy(x: rng.cgFloat(in: -80...80), y: 0,
                                        duration: rng.double(in: 10...17))
            cloud.run(.repeatForever(.sequence([drift, drift.reversed()])))
        }

        // Cinematic vignette (cold grade): darker edges, brighter center so
        // the white field stays luminous. Fixed 128x128 canvas: baked once,
        // shared by every frost scene.
        let vigNode = SKSpriteNode(texture: vignetteTexture())
        vigNode.size = CGSize(width: W * 1.25, height: H * 1.5)
        vigNode.zPosition = 50
        layer.addChild(vigNode)
    }

    private static var vignetteTexCache: SKTexture?
    private static func vignetteTexture() -> SKTexture {
        if let vignetteTexCache { return vignetteTexCache }
        let vig = render(w: 128, h: 128) { cg in
            for px in 0..<128 {
                for py in 0..<128 {
                    let dx = (CGFloat(px) - 64) / 64, dy = (CGFloat(py) - 64) / 64
                    let d = min(1, sqrt(dx * dx + dy * dy))
                    let a = max(0, d - 0.58) * 0.62
                    cg.setFillColor(UIColor(white: 0, alpha: a).cgColor)
                    cg.fill(CGRect(x: px, y: 127 - py, width: 1, height: 1))
                }
            }
        }
        vig.filteringMode = .linear
        vignetteTexCache = vig
        return vig
    }

    private static var auroraTexCache: SKTexture?
    /// One seamless-ish aurora gradient sheet: vertical fade teal -> violet
    /// with sine-modulated column alpha so the ribbon looks torn by wind.
    private static func auroraTexture() -> SKTexture {
        if let auroraTexCache { return auroraTexCache }
        let W = 320, H = 120
        let tex = render(w: W, h: H) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: W, height: H))
            let teal = UIColor(red: 0.35, green: 1.0, blue: 0.72, alpha: 1)
            let ice = UIColor(red: 0.45, green: 0.86, blue: 1.0, alpha: 1)
            let violet = UIColor(red: 0.72, green: 0.55, blue: 1.0, alpha: 1)
            // Precompute the vertical profile once: color + envelope per row.
            var rowColors: [UIColor] = []
            var rowEnv: [CGFloat] = []
            for y in 0..<H {
                let fy = CGFloat(y) / CGFloat(H - 1) // 0 bottom -> 1 top
                let sine = CGFloat(sinf(Float(fy) * Float.pi))
                let env = Swift.max(0, sine - 0.12) / 0.88
                rowEnv.append(env)
                let c: UIColor = fy < 0.55
                    ? blend(teal, ice, fy / 0.55)
                    : blend(ice, violet, (fy - 0.55) / 0.45)
                rowColors.append(c)
            }
            for x in 0..<W {
                let jitter = CGFloat(hash(x, 3, 610) - 50) / 100
                let phase = CGFloat(x) / CGFloat(W) * .pi * 2.0
                let wave = jitter + sin(phase) * 0.5
                let clampIn = Swift.min(1, Swift.max(0, CGFloat(x) / CGFloat(W) * 0.35 + wave * 0.4))
                let fade = 1.0 - clampIn
                if fade <= 0 { continue }
                let windFade = 1.0 - Swift.min(1, Swift.max(0, abs(wave) * 0.6))
                for y in 0..<H {
                    let a = (rowEnv[y] * windFade).clamped01() * fade * 0.55
                    guard a > 0.01 else { continue }
                    cg.setFillColor(rowColors[y].withAlphaComponent(a).cgColor)
                    cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        auroraTexCache = tex
        return tex
    }

    // MARK: - Far panorama (ONE strip, never tiled)

    /// Per-column ridge for one mountain range: every peak contributes a
    /// straight flank rising to its summit, overlapped peaks carve the
    /// valleys between them, and hash grain roughens the line. Row 0 = top.
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

    /// Paint one range: rock body, left-lit ridge line, shadowed right
    /// flanks, snow fields hanging from the summits down to the snowline,
    /// faint strata and thin snow gullies. All fills are per-column bands.
    private static func paintRange(_ cg: CGContext, ridge: [Int], depth: Int,
                                   base: Int,
                                   rock: UIColor, rockDk: UIColor,
                                   snowline: Int, snowScale: Double,
                                   gullyChance: Int, seed: Int) {
        let snowLo = blend(capWhite, rock, 0.38)
        let snowMid = blend(capWhite, rock, 0.14)
        let W = ridge.count
        for x in 0..<W {
            let top = ridge[x]
            guard top < depth - 2 else { continue }
            fill(cg, x, top, 1, depth - top, rock)

            // Right-facing flanks fall away from the light.
            if x > 2, x + 2 < W {
                let slope = ridge[x + 2] - ridge[x - 2]
                if slope > 2 {
                    let band = Swift.min(depth - top, 8 + slope * 3)
                    fill(cg, x, top, 1, band, rockDk.withAlpha(0.4))
                }
            }

            // Snow field off the summit with a ragged lower edge.
            if top < snowline {
                let raw = Double(snowline - top) * snowScale + 5.0
                let wobble = Double(hash(x, 21, seed) % 7) - 3.0
                let cap = Int((raw + wobble).rounded())
                let d = Swift.max(3, Swift.min(depth - top, cap))
                fill(cg, x, top, 1, d, snowLo)
                fill(cg, x, top, 1, Swift.max(1, d / 2), snowMid)
                if d > 4 { fill(cg, x, top + d - 1, 1, 1, snowLo.withAlpha(0.45)) }
            }

            // Lit crest along the actual silhouette only.
            if top < base - 1 { fill(cg, x, top, 1, 1, capWhite) }

            // Strata flecks and snow gullies on the taller faces.
            if hash(x, 31, seed) < 9 {
                let ry = top + 14 + hash(x, 32, seed) % 24
                if ry + 2 < depth {
                    fill(cg, x, ry, 1, 1, rockDk.withAlpha(0.5))
                }
            }
            if top < snowline, hash(x, 41, seed) < gullyChance {
                let len = 7 + hash(x, 42, seed) % 16
                fill(cg, x, top + 2, 1, len,
                     blend(capWhite, rock, 0.10).withAlpha(0.8))
            }
        }
    }

    private static var farTexCache: SKTexture?
    /// Glacier panorama sheet (fixed 1100x280 canvas — lane width only
    /// sizes the sprite, never the bake). Baked once and shared by every
    /// frost briefing + battle: three painted ranges make this the heaviest
    /// frost bake, and rebuilding it on the main thread is what stalls the
    /// map → Level 21+ push.
    private static func farTexture() -> SKTexture {
        if let farTexCache { return farTexCache }
        let PW = 1100, PH = 280
        let tex = render(w: PW, h: PH) { cg in
            cg.clear(CGRect(x: 0, y: 0, width: PW, height: PH))

            // 1) Back wall: tall, pale, almost entirely under snow.
            let farPeaks: [(x: Int, top: Int, slope: Double)] = [
                (30, 66, 0.52), (105, 34, 0.44), (180, 52, 0.50),
                (252, 18, 0.38), (330, 60, 0.54), (405, 40, 0.46),
                (480, 26, 0.40), (562, 74, 0.58), (640, 30, 0.42),
                (716, 16, 0.36), (796, 58, 0.52), (875, 36, 0.44),
                (952, 22, 0.40), (1032, 64, 0.54), (1092, 42, 0.48),
            ]
            let farRidge = skyline(farPeaks, base: 150, jitter: 3, seed: 11, w: PW)
            paintRange(cg, ridge: farRidge, depth: PH, base: 150,
                       rock: blend(glacierHi, glacierBody, 0.35),
                       rockDk: glacierDk,
                       snowline: 138, snowScale: 1.0, gullyChance: 26, seed: 13)

            // Cold air pooling at the wall's feet.
            for x in 0..<PW {
                let wob = hash(x, 61, 3) * 10 / 100
                fill(cg, x, 138 + wob, 1, PH - 138 - wob,
                     mistCold.withAlpha(0.16))
            }

            // 2) Mid range: colder rock, caps only on the taller summits.
            let midPeaks: [(x: Int, top: Int, slope: Double)] = [
                (0, 96, 0.55), (75, 78, 0.48), (152, 104, 0.58),
                (232, 62, 0.44), (316, 88, 0.50), (402, 112, 0.60),
                (486, 70, 0.46), (566, 96, 0.52), (652, 58, 0.44),
                (736, 102, 0.56), (820, 76, 0.48), (902, 108, 0.58),
                (986, 66, 0.46), (1072, 92, 0.52),
            ]
            let midRidge = skyline(midPeaks, base: 168, jitter: 3, seed: 23, w: PW)
            paintRange(cg, ridge: midRidge, depth: PH, base: 168,
                       rock: blend(glacierBody, massif, 0.40),
                       rockDk: blend(massif, skyTop, 0.25),
                       snowline: 92, snowScale: 0.85, gullyChance: 16, seed: 29)

            for x in 0..<PW {
                let wob = hash(x, 67, 4) * 8 / 100
                fill(cg, x, 158 + wob, 1, PH - 158 - wob,
                     mistCold.withAlpha(0.18))
            }

            // 3) Near massif: dark, mostly bare rock with snow ledges.
            let nearPeaks: [(x: Int, top: Int, slope: Double)] = [
                (24, 150, 0.62), (112, 132, 0.55), (202, 158, 0.66),
                (288, 138, 0.58), (382, 152, 0.62), (472, 128, 0.54),
                (562, 148, 0.60), (652, 160, 0.68), (742, 134, 0.56),
                (832, 154, 0.62), (922, 140, 0.58), (1012, 156, 0.64),
                (1092, 136, 0.56),
            ]
            let nearRidge = skyline(nearPeaks, base: 182, jitter: 2, seed: 37, w: PW)
            paintRange(cg, ridge: nearRidge, depth: PH, base: 182,
                       rock: massif,
                       rockDk: blend(massif, skyTop, 0.35),
                       snowline: 144, snowScale: 0.75, gullyChance: 10, seed: 41)

            // Frozen bay at the massif's feet: pale glare sheet + bergs.
            fill(cg, 0, 184, PW, 18,
                 blend(horizonIce, mistCold, 0.30).withAlpha(0.55))
            for x in 0..<PW {
                let wob = hash(x, 71, 5) * 6 / 100
                fill(cg, x, 185 + wob, 1, 1, capWhite.withAlpha(0.35))
            }
            let bergs: [(x: Double, w: Double, h: Double)] = [
                (110, 30, 15), (300, 22, 11), (500, 34, 18),
                (690, 20, 10), (840, 26, 14),
            ]
            for b in bergs {
                let x0 = Int(b.x)
                let w = Int(b.w)
                for px in x0..<(x0 + w) {
                    guard px >= 0, px < PW else { continue }
                    let k = 1 - abs(CGFloat(px - x0 - w / 2)) / CGFloat(w / 2)
                    let top = 190 - Int(k * b.h)
                    fill(cg, px, top, 1, 196 - top,
                         blend(spireBody, spireIce, 0.5))
                    fill(cg, px, top, 1, 1, capWhite.withAlpha(0.85))
                }
            }

            // Landmark: glowing ice spires at the bay's right shoulder.
            let spires: [(x: Double, w: Double, top: Int)] = [
                (918, 14, 144), (934, 10, 118), (947, 16, 156),
                (966, 9, 100), (980, 12, 132),
            ]
            for s in spires {
                let x0 = Int(s.x)
                let w = Int(s.w)
                for px in x0..<(x0 + w) {
                    guard px >= 0, px < PW else { continue }
                    let k = 1 - abs(CGFloat(px - x0 - w / 2)) / CGFloat(w / 2)
                    let jag = hash(px, 4, 43) < 25 ? 2 : 0
                    let top = s.top + Int((k * 6).rounded()) + jag
                    fill(cg, px, top, 1, 194 - top,
                         blend(spireBody, spireIce, k * 0.8))
                    fill(cg, px, top, 1, 2, spireIce)
                    if hash(px, 5, 47) < 35 {
                        fill(cg, px, top + 4, 1, 2, spireGlow.withAlpha(0.55))
                    }
                }
            }

            // Mist bed along the bay + deep frozen base.
            for x in 0..<PW {
                let wobble = hash(x, 7, 2) * 8 / 100
                fill(cg, x, 186 + wobble, 1, 14 - wobble / 2,
                     mistCold.withAlpha(0.45))
            }
            for x in 0..<PW where hash(x, 118, 4) < 22 {
                fill(cg, x, 194, 1, 1, mistCold.withAlpha(0.8))
            }
            fill(cg, 0, 202, PW, PH - 202,
                 blend(glacierDk, frostDeep, 0.55))
        }
        farTexCache = tex
        return tex
    }

    /// Three glacier ranges stacked back to front: a high pale wall under
    /// deep snow (most summits capped white), a colder mid range whose
    /// taller peaks carry snow caps, and a dark near massif with only snow
    /// ledges — over a frozen bay with drifted bergs and the region's
    /// glowing ice-spire landmark. Cold haze pools between every range.
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

        // Ice spire glow: one soft cyan bloom pulsing at the landmark
        // (rows ~100-194 of the texture, so it rides the spire mid-height).
        let glowX = -sceneSize.width * 0.6 + panoW * (950.0 / 1100.0)
        let glowRow: CGFloat = 150
        let farH: CGFloat = 280 // farTexture() canvas height
        let glowY = -sceneSize.height * 0.07
            + (farH / 2 - glowRow) / farH * panoH
        let glow = SKShapeNode(ellipseOf: CGSize(width: 120, height: 60))
        glow.fillColor = SKColor(red: 0.45, green: 0.88, blue: 1.0, alpha: 0.10)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: glowX, y: glowY)
        glow.zPosition = 1
        layer.addChild(glow)
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.45, duration: 3.4), .fadeAlpha(to: 1.0, duration: 3.4),
        ])))

        // Thin cold veil so the panorama reads as distant air.
        // Evening: a warm amber wash over the cold veil so the glacier
        // ridge catches the sinking sun.
        let veil = SKSpriteNode(color: SKColor(red: 0.62, green: 0.74, blue: 0.86, alpha: 0.10),
                                size: CGSize(width: panoW, height: panoH))
        veil.anchorPoint = CGPoint(x: 0, y: 0.5)
        veil.position = pano.position
        veil.zPosition = 2
        layer.addChild(veil)
        if Balance.frostEvening {
            let ember = SKSpriteNode(color: SKColor(red: 1.0, green: 0.48, blue: 0.22, alpha: 0.14),
                                     size: CGSize(width: panoW, height: panoH * 0.45))
            ember.anchorPoint = CGPoint(x: 0, y: 0.5)
            ember.position = CGPoint(x: pano.position.x, y: pano.position.y - panoH * 0.16)
            ember.zPosition = 3
            layer.addChild(ember)
        }
    }

    // MARK: - Mid ground (ONE strip set, never tiled)

    /// Snow-covered pastures: three stacked sheets of rolling farm fields
    /// with big oval hills and hollows, furrow rows under thin snow, spruce
    /// clumps, a barn + crofter cottage + windmill on the far skyline and a
    /// spruce grove on the near sheet — plus drifting cold mist bands.
    /// Every sheet is its own parallax node, so the pastures slide against
    /// each other as the camera pans. All baked; only the mist loops and
    /// window pulse move.
    static func buildMid(in layer: SKNode, sceneSize: CGSize) {
        let travel = Balance.levelWidth * Balance.parallaxMid
        // Extra width absorbs the small per-sheet parallax offsets.
        let panoW: CGFloat = sceneSize.width + travel + 1200
        let panoH = sceneSize.height * 0.34
        let baseY = -sceneSize.height * 0.20
        let baseX = -sceneSize.width * 0.6

        // Far field drifts slowest, near field fastest — depth inside the
        // mid band itself.
        let grades: [(lift: CGFloat, hue: (UIColor, CGFloat), factor: CGFloat)] = [
            (44, (capWhite, 0.55), Balance.parallaxMid - 0.055),
            (16, (snowHi, 0.42), Balance.parallaxMid),
            (-10, (snowDk, 0.30), Balance.parallaxMid + 0.055),
        ]
        var farRoot: MidParallaxNode?
        for (ri, g) in grades.enumerated() {
            let root = MidParallaxNode()
            root.baseX = baseX
            root.cameraFactor = g.factor
            root.position = CGPoint(x: baseX, y: baseY + g.lift)
            root.zPosition = CGFloat(ri)
            let strip = SKSpriteNode(texture: pastureTexture(variant: ri))
            strip.anchorPoint = CGPoint(x: 0, y: 0.5)
            strip.size = CGSize(width: panoW, height: panoH)
            strip.color = g.hue.0
            strip.colorBlendFactor = g.hue.1
            root.addChild(strip)
            layer.addChild(root)
            if ri == 0 { farRoot = root }
        }

        // Barn window glow: one soft warm bloom riding the far sheet's
        // doorlight — the only living light out in the white.
        let barnX = 601
        let barnRow = pastureRow(barnX, variant: 0)
        let vScale = panoH / CGFloat(fieldH)
        let glow = SKShapeNode(ellipseOf: CGSize(width: 18, height: 10))
        glow.fillColor = SKColor(red: 1.0, green: 0.76, blue: 0.40, alpha: 0.30)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: panoW * (CGFloat(barnX) / CGFloat(fieldW)),
                                y: (CGFloat(barnRow + 3) - CGFloat(fieldH) / 2) * vScale)
        glow.zPosition = 1
        farRoot?.addChild(glow)
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.5, duration: 2.8), .fadeAlpha(to: 1.0, duration: 2.8),
        ])))

        // Drifting mist: pale white-blue bands along the field line. Its
        // own node drift (fastest in the band) keeps it sliding over the
        // sheets as the camera moves.
        let mistRoot = MidParallaxNode()
        mistRoot.baseX = 0
        mistRoot.cameraFactor = Balance.parallaxMid + 0.075
        mistRoot.zPosition = 3
        layer.addChild(mistRoot)
        var rng = SeededRNG(seed: 120321)
        let mistTex = mistTexture()
        for _ in 0..<8 {
            let band = SKSpriteNode(texture: mistTex)
            band.size = CGSize(width: panoW * rng.cgFloat(in: 0.14...0.24),
                               height: rng.cgFloat(in: 18...30))
            band.position = CGPoint(x: rng.cgFloat(in: 0...panoW * 0.7),
                                    y: baseY + rng.cgFloat(in: 10...64))
            band.zPosition = 0
            band.color = SKColor(red: 0.88, green: 0.94, blue: 1.0, alpha: 1)
            band.colorBlendFactor = 1
            band.alpha = rng.cgFloat(in: 0.12...0.20)
            mistRoot.addChild(band)
            let drift = SKAction.moveBy(x: rng.cgFloat(in: 70...150), y: 0,
                                        duration: rng.double(in: 9...15))
            band.run(.repeatForever(.sequence([drift, drift.reversed()])))
        }

        // Frozen Narrows small alteration (Level 25): the glacier pinches
        // into a channel — pale ice floes ride the near sheet's speed so
        // the mid ground reads as the same pastures split by ice.
        // Overlay only (baked sheets untouched), a handful of nodes,
        // no per-frame code.
        if Balance.frozenNarrows {
            let leadRoot = MidParallaxNode()
            leadRoot.baseX = 0
            leadRoot.cameraFactor = Balance.parallaxMid + 0.055
            leadRoot.zPosition = 2
            layer.addChild(leadRoot)
            var leadRNG = SeededRNG(seed: 225_025)
            // Ice floes: small pale slabs scattered along the field line.
            for _ in 0..<6 {
                let s = leadRNG.cgFloat(in: 10...22)
                let floe = SKSpriteNode(
                    color: SKColor(red: 0.88, green: 0.94, blue: 0.99, alpha: 0.95),
                    size: CGSize(width: s, height: s * 0.45))
                floe.position = CGPoint(x: leadRNG.cgFloat(in: 0...panoW * 0.8),
                                        y: baseY + leadRNG.cgFloat(in: 14...58))
                floe.zRotation = leadRNG.cgFloat(in: -0.12...0.12)
                leadRoot.addChild(floe)
            }
        }
    }

    private static var pastureTexCache: [SKTexture] = []
    private static let fieldW = 800
    private static let fieldH = 110

    /// Rolling skyline contour per pasture sheet (far / mid / near): two
    /// rounded sines plus pixel grain, so the fields roll instead of
    /// sitting flat.
    private static let pastureContours: [
        (base: Int, amp1: Int, f1: Double, amp2: Int, f2: Double, phase: Double)
    ] = [
        (42, 12, 1.35, 6, 2.75, 0.35),   // far: broad open swells
        (54, 17, 1.05, 9, 2.45, 1.15),   // mid: bigger rounded humps
        (64, 21, 0.80, 11, 2.15, 2.05),  // near: closest big slopes
    ]

    /// Oval grassy hills per sheet: gaussian rises that add real uphills
    /// and downhills between the sine swells (never pointy).
    private static let pastureHills: [[(x: Int, w: Int, h: Int)]] = [
        [(150, 120, 11), (470, 140, 9), (720, 110, 10)],
        [(80, 100, 15), (330, 130, 13), (610, 120, 16), (760, 90, 10)],
        [(140, 130, 17), (430, 110, 13), (680, 140, 16)],
    ]

    private static func pastureRow(_ px: Int, variant: Int) -> Int {
        let c = pastureContours[variant]
        let t = Double(px) / Double(fieldW)
        let w1 = Double(sin(t * .pi * 2.0 * c.f1 + c.phase)) * Double(c.amp1)
        let w2 = Double(sin(t * .pi * 2.0 * c.f2 + c.phase * 2.3)) * Double(c.amp2)
        var rise = 0.0
        for hill in pastureHills[variant] {
            let dx = (Double(px) - Double(hill.x)) / Double(hill.w)
            rise += Double(hill.h) * exp(-dx * dx * 2.4)
        }
        let grain = Double(hash(px, 11, 700 + variant) - 50) / 100 * 1.5
        return Int((Double(c.base) - rise + w1 + w2 + grain).rounded())
    }

    /// One pasture sheet per variant. All sheets share the same rolling
    /// language: contour skyline, terrace bands, furrow hatching, boundary
    /// lines. Variant 0 adds the distant barn + windmill on the skyline;
    /// variant 1 adds spruce clumps; variant 2 adds a sparse spruce grove.
    private static func pastureTexture(variant: Int) -> SKTexture {
        let W = fieldW, H = fieldH
        while pastureTexCache.count <= variant {
            let v = pastureTexCache.count
            pastureTexCache.append(renderPastureTexture(variant: v, W: W, H: H))
        }
        return pastureTexCache[variant]
    }

    private static func renderPastureTexture(variant: Int, W: Int, H: Int) -> SKTexture {
        let tex = render(w: W, h: H) { cg in
            cg.setShouldAntialias(false)
            cg.clear(CGRect(x: 0, y: 0, width: W, height: H))

            // Skyline contour per column (precomputed — the face gradient
            // and every follower below share it).
            var sky = [Int](repeating: H / 2, count: W)
            for px in 0..<W {
                sky[px] = max(6, min(H - 8, pastureRow(px, variant: variant)))
            }

            // Field face: pale snow rolling into cold shade, lit from the
            // upper left. Slope-derived shading turns each swell into a
            // rounded oval hill instead of a flat cut-out. Drawn in 8-row
            // bands (one fill per band) so the whole sheet bakes fast.
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
                    if variant == 0 {
                        c = blend(snowHi, snow, t * 0.55)
                    } else if variant == 1 {
                        c = blend(snow, snowDk, t * 0.60)
                    } else {
                        c = blend(snow, snowDk, t * 0.80)
                    }
                    let edge = 1 - t * 0.7
                    if shade > 0.01 { c = blend(c, skyMid, shade * 0.32 * edge) }
                    if lit > 0.01 { c = blend(c, capWhite, lit * 0.26 * edge) }
                    fill(cg, px, r0, 1, rows, c)
                }
                // Lit crest of the rolling ridge.
                fill(cg, px, top, 1, 2, snowHi.withAlpha(0.9))
                // Occasional wind-packed drifts along the crest.
                if hash(px, 23, 90 + variant) < 14 {
                    fill(cg, px, top + 2, 1, 2, capWhite.withAlpha(0.35))
                }
            }

            // Terrace bands: contour-following boundaries with furrow
            // hatching inside. Band count + spacing tighten per depth.
            let bandCount = variant == 0 ? 3 : (variant == 1 ? 3 : 2)
            let bandGap = variant == 0 ? 12 : (variant == 1 ? 18 : 24)
            let hatchPhase = variant * 4
            for px in 0..<W {
                let top = sky[px]
                for k in 0..<bandCount {
                    var row = top + 5 + k * bandGap
                    guard row < H - 6 else { break }
                    // Boundary line: dark furrow cut + light lip above.
                    fill(cg, px, row - 1, 1, 1, capWhite.withAlpha(0.5))
                    fill(cg, px, row, 1, 1, snowDk.withAlpha(0.85))
                    // Furrow hatch inside the band: slanted thin rows.
                    row += 2
                    while row < top + 5 + (k + 1) * bandGap - 2 {
                        guard row < H - 6 else { break }
                        if (row + px / 5 + hatchPhase) % 9 < 1 {
                            fill(cg, px, row, 1, 1, snowDk.withAlpha(0.30))
                        }
                        row += 1
                    }
                }
            }

            // Depth seating shadow along the very base of the strip.
            for px in 0..<W {
                let wobble = hash(px, 7, 2) * 5 / 100
                let row = H - 9 + wobble
                guard row < H else { continue }
                fill(cg, px, row, 1, H - row, skyMid.withAlpha(0.38))
            }

            switch variant {
            case 0:
                drawFarFarms(cg, sky: sky, W: W, H: H)
            case 1:
                drawMidFarm(cg, sky: sky, W: W, H: H)
            default:
                drawNearGrove(cg, sky: sky, W: W, H: H)
            }
        }
        tex.filteringMode = .nearest
        return tex
    }

    // MARK: Pasture props (baked per sheet)

    /// Small snow-laden spruces dotted along a ridge: dark tapered trees
    /// with white snow ledges, giving the rolling fields scale. Baked.
    private static func drawSpruces(_ cg: CGContext, sky: [Int], W: Int,
                                    H: Int, spots: [Int], seed: Int, maxH: Int) {
        let spruce = UIColor(red: 0.10, green: 0.18, blue: 0.20, alpha: 1)
        let spruceLit = UIColor(red: 0.20, green: 0.30, blue: 0.33, alpha: 1)
        for s in spots {
            guard s > 6, s < W - 8 else { continue }
            let n = 2 + hash(s, 3, seed) % 3
            for t in 0..<n {
                let x = s + (t - n / 2) * 8 + hash(s, t + 5, seed) % 5 - 2
                guard x > 5, x < W - 5 else { continue }
                let h = 6 + hash(x, 7, seed) % maxH
                let base = sky[x] + 3 + hash(x, 9, seed) % 3
                guard base - h > 2, base < H else { continue }
                for i in 0..<h {
                    let w = 1 + (h - i) * 5 / h
                    fill(cg, x - w / 2, base - 1 - i, w, 1,
                         (i % 3 == 0) ? spruceLit : spruce)
                }
                // Snow ledges catching the light on the left flank.
                for i in stride(from: 1, to: h, by: 3) {
                    let w = 1 + (h - i) * 5 / h
                    fill(cg, x - w / 2, base - 1 - i, w, 1,
                         capWhite.withAlpha(0.55))
                    fill(cg, x - w / 2, base - 1 - i, 1, 1,
                         capWhite.withAlpha(0.85))
                }
            }
        }
    }

    /// Far sheet: barn with a snow roof + warm window, a crofter cottage
    /// with a smoking chimney, a slim windmill, and spruce clumps.
    private static func drawFarFarms(_ cg: CGContext, sky: [Int], W: Int, H: Int) {
        let bodyRust = UIColor(red: 0.30, green: 0.155, blue: 0.13, alpha: 1)
        let bodyDk = UIColor(red: 0.20, green: 0.10, blue: 0.09, alpha: 1)
        let slateDk = UIColor(red: 0.20, green: 0.24, blue: 0.30, alpha: 1)
        let warm = UIColor(red: 1.0, green: 0.72, blue: 0.38, alpha: 1)

        drawSpruces(cg, sky: sky, W: W, H: H,
                    spots: [70, 262, 372, 462, 545, 700, 790], seed: 71, maxH: 10)

        // Barn on the skyline (x 596-628): body, snow roof, lit window.
        let bx = 596
        let brow = sky[bx]
        for px in bx..<(bx + 26) {
            guard px >= 0, px < W else { continue }
            fill(cg, px, brow, 1, 12, bodyRust)
            fill(cg, px, brow + 11, 1, 1, bodyDk)
        }
        // Roof wedge with snow load.
        for i in 0..<7 {
            let w = 26 - i * 3
            let roofY = brow - 1 - i
            if w > 0, roofY >= 0 {
                fill(cg, bx + i * 3 / 2, roofY, w, 1, capWhite)
                if i < 3 { fill(cg, bx + i * 3 / 2, roofY, w, 1, slateDk) }
            }
        }
        // Door + window.
        fill(cg, bx + 11, brow + 4, 5, 8, bodyDk)
        fill(cg, bx + 3, brow + 3, 4, 3, warm)

        // Crofter cottage further along the skyline (x ~318).
        let cx = 318
        let crow = sky[cx]
        for px in cx..<(cx + 16) {
            guard px >= 0, px < W else { continue }
            fill(cg, px, crow, 1, 9, bodyDk)
        }
        for i in 0..<4 {
            let w = 16 - i * 3
            let roofY = crow - 1 - i
            if w > 0, roofY >= 0 {
                fill(cg, cx + i * 3 / 2, roofY, w, 1, capWhite)
            }
        }
        fill(cg, cx + 3, crow + 3, 3, 3, warm)   // lit window
        fill(cg, cx + 10, crow + 3, 3, 3, bodyDk) // shuttered window
        for r in 0..<5 {
            fill(cg, cx + 12, crow - 5 - r, 2, 1, slateDk)
        }
        for r in 0..<4 where hash(cx, 40 + r, 77) < 70 {
            fill(cg, cx + 13, crow - 10 - r, 1, 1, capWhite.withAlpha(0.22))
        }

        // Windmill on the skyline (x ~175): slim tower, four blades.
        let wx = 174
        let wrow = sky[wx]
        if wrow - 26 >= 0 {
            for r in 0..<22 {
                let width = r < 4 ? 4 : 3
                fill(cg, wx, wrow - 1 - r, width, 1, slateDk)
            }
            fill(cg, wx, wrow - 23, 1, 3, slateDk)
            // Blades: two crossing diagonals, snow-tipped hub.
            for k in -5...5 {
                if k == 0 { continue }
                fill(cg, wx + 1 + k, wrow - 24 + abs(k) / 2, 1, 1, slateDk)
                fill(cg, wx + 1 + k, wrow - 24 - abs(k) / 2, 1, 1, slateDk)
            }
            fill(cg, wx + 1, wrow - 25, 1, 2, capWhite)
        }
    }

    /// Mid sheet: spruce clumps across the rolling snowfields.
    private static func drawMidFarm(_ cg: CGContext, sky: [Int], W: Int, H: Int) {
        drawSpruces(cg, sky: sky, W: W, H: H,
                    spots: [40, 120, 172, 288, 392, 480, 600, 690, 756], seed: 83, maxH: 13)
    }

    /// Near sheet: a sparse spruce grove across the close snowfields.
    private static func drawNearGrove(_ cg: CGContext, sky: [Int], W: Int, H: Int) {
        drawSpruces(cg, sky: sky, W: W, H: H,
                    spots: [40, 150, 280, 430, 590, 730], seed: 97, maxH: 18)
    }

    private static var mistTexCache: SKTexture?
    private static func mistTexture() -> SKTexture {
        if let mistTexCache { return mistTexCache }
        let W = 128, H = 24
        let tex = render(w: W, h: H) { cg in
            for x in 0..<W {
                for y in 0..<H {
                    let ddx = abs(CGFloat(x) - 64) / 64
                    let ddy = abs(CGFloat(y) - 12) / 12
                    let a = max(0, 1 - (ddx * ddx + ddy * ddy)) * 0.9
                    if a <= 0.02 { continue }
                    cg.setFillColor(UIColor(white: 1, alpha: a).cgColor)
                    cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        tex.filteringMode = .linear
        mistTexCache = tex
        return tex
    }

    // MARK: - Ground (factor 1.0)

    /// White snow lane over deep blue ice: one baked surface tile, cyan
    /// catch-light lip, cold strata below, team washes and chunk-baked
    /// frost glitter. No embers, no lava — cold field.
    static func buildGround(in world: SKNode) {
        let width = Balance.levelWidth
        let gy = Balance.groundTopY

        // Surface tiles: one texture, mirrored every other tile so the
        // seam repeats invisibly.
        let tile = snowTileTexture()
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

        // Icy catch-light lip + soft AO beneath the walkable edge.
        let lip = SKSpriteNode(color: SKColor(red: 0.84, green: 0.95, blue: 1.0, alpha: 0.9),
                               size: CGSize(width: width, height: 3))
        lip.anchorPoint = CGPoint(x: 0, y: 1)
        lip.position = CGPoint(x: 0, y: gy + 1)
        lip.zPosition = 2
        world.addChild(lip)
        let ao = SKSpriteNode(color: SKColor(white: 0.05, alpha: 0.35),
                              size: CGSize(width: width, height: 10))
        ao.anchorPoint = CGPoint(x: 0, y: 1)
        ao.position = CGPoint(x: 0, y: gy - 10)
        ao.zPosition = 2
        world.addChild(ao)

        // Sheer frozen strata below the snow shelf.
        var y = gy - tileH
        let strata: [(CGFloat, SKColor)] = [
            (64, frostCliff),
            (120, frostCliffDk),
            (180, frostDeep),
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
            let deep = SKSpriteNode(color: frostDeep, size: CGSize(width: width, height: y))
            deep.anchorPoint = CGPoint(x: 0, y: 1)
            deep.position = CGPoint(x: 0, y: y)
            deep.zPosition = 0
            world.addChild(deep)
        }
        // A few embedded ice glints in the cliff (static, baked twice over).
        var rng = SeededRNG(seed: 521901)
        for _ in 0..<12 {
            let s = rng.cgFloat(in: 3...6)
            let glint = SKSpriteNode(color: SKColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 0.5),
                                     size: CGSize(width: 1.5, height: s))
            glint.position = CGPoint(x: rng.cgFloat(in: 0...width),
                                     y: rng.cgFloat(in: 8...(gy - tileH - 6)))
            glint.zPosition = 1
            world.addChild(glint)
        }

        // Faint team washes (blue left / red right).
        let half = width / 2
        let washL = SKSpriteNode(color: SKColor(red: 0.3, green: 0.5, blue: 1, alpha: 0.06),
                                 size: CGSize(width: half, height: tileH))
        washL.anchorPoint = CGPoint(x: 0, y: 1)
        washL.position = CGPoint(x: 0, y: gy)
        washL.zPosition = 2
        world.addChild(washL)
        let washR = SKSpriteNode(color: SKColor(red: 1, green: 0.3, blue: 0.25, alpha: 0.06),
                                 size: CGSize(width: half, height: tileH))
        washR.anchorPoint = CGPoint(x: 0, y: 1)
        washR.position = CGPoint(x: half, y: gy)
        washR.zPosition = 2
        world.addChild(washR)

        bakeGroundDetails(in: world, width: width, gy: gy)
    }

    /// Snow surface: flat pale walkable strip, wind ripple diagonals, a few
    /// buried drift shadows, sparkle pixels and drifted clumps at the lip.
    private static var tileCache: SKTexture?
    static func snowLaneTileTexture() -> SKTexture {
        snowTileTexture()
    }
    private static func snowTileTexture() -> SKTexture {
        if let tileCache { return tileCache }
        let W = 115, H = 26
        let tex = render(w: W, h: H) { cg in
            cg.setShouldAntialias(false)
            // Walkable face: pale, even, slightly warm-white so units pop.
            for py in 0..<H {
                let t = CGFloat(py) / CGFloat(H - 1)
                fill(cg, 0, py, W, 1, blend(snowHi, snow, 0.25 + t * 0.75))
            }
            // Wind ripple diagonals.
            for px in 0..<W {
                let wave = Int(Float(px) * 0.22 + Float(hash(px, 2, 33) % 5)) % 18
                if wave < 2 {
                    for py in 6..<H {
                        let yy = py + (px / 3) % 5
                        if yy < H {
                            fill(cg, px, yy, 1, 1,
                                 snowDk.withAlpha(hash(px, py, 34) < 40 ? 0.5 : 0.25))
                        }
                    }
                }
            }
            // Buried shadow hints.
            for b in [(12, 14), (34, 20), (71, 16), (92, 18)] {
                let (bx, by) = b
                for dx in -7...7 {
                    let depth = 7 - abs(dx) / 2
                    let px = bx + dx
                    if depth > 0, px >= 0, px < W {
                        fill(cg, px, by, 1, depth, snowDk.withAlpha(0.35))
                    }
                }
            }
            // Sparkles.
            for s in 0..<26 {
                let sx = hash(s, 3, 55) % W
                let sy = hash(s, 4, 56) % (H - 4) + 2
                fill(cg, sx, sy, 1, 1, capWhite.withAlpha(0.8))
            }
            // Lip clumps: soft drift bumps on the top edge.
            for px in 0..<W {
                if hash(px, 1, 57) < 18 {
                    fill(cg, px, H - 2, 2, 2, capWhite.withAlpha(0.55))
                }
                if hash(px, 8, 58) < 10 {
                    fill(cg, px, H - 5, 1, 3, capWhite.withAlpha(0.4))
                }
            }
        }
        tex.filteringMode = .nearest
        tileCache = tex
        return tex
    }

    /// Static chunk dressing: frost glitter only — one baked sprite per
    /// 1024pt.
    private static func bakeGroundDetails(in world: SKNode,
                                          width: CGFloat, gy: CGFloat) {
        let chunkW: CGFloat = 1024
        var x0: CGFloat = 0
        var chunk = 0
        while x0 < width {
            let span = min(chunkW, width - x0)
            var rng = SeededRNG(seed: UInt64(92410 + chunk * 613))
            let root = SKNode()

            // Frost glitter: tiny white/cyan pixels scattered on the face.
            let sparkCount = max(0, Int((30 * span / width).rounded()))
            for _ in 0..<sparkCount {
                let sx = rng.cgFloat(in: 12...(span - 12))
                let sparkle = SKSpriteNode(color: rng.int(in: 0...1) == 0
                    ? capWhite.withAlpha(0.75) : spireIce.withAlpha(0.6),
                    size: CGSize(width: 2, height: 2))
                sparkle.position = CGPoint(x: sx, y: gy + rng.cgFloat(in: 1...6))
                sparkle.zPosition = 2
                root.addChild(sparkle)
            }

            if let baked = SceneryBake.baked(key: "frost.ground.detail.\(Int(width)).\(chunk)",
                                             build: { root }) {
                SceneryBake.add(baked, to: world,
                                origin: CGPoint(x: x0, y: 0), zPosition: 2)
            }
            x0 += span
            chunk += 1
        }
    }

    // MARK: - Foreground (factor 1.28, subtle)

    /// Near-camera frozen dressing: frost scrub with gentle sway, angular
    /// ice chunks and drifting snow motes — sparse so the fight stays
    /// readable.
    static func buildForeground(in layer: SKNode) {
        var rng = SeededRNG(seed: 88046)
        let span = Balance.levelWidth * Balance.parallaxForeground

        // Frost scrub: sparse gray-blue blade fans with sway.
        for i in 0..<34 {
            let x = rng.cgFloat(in: 0...span)
            let tuft = SKNode()
            tuft.position = CGPoint(x: x, y: 0)
            let blades = rng.int(in: 3...5)
            for b in 0..<blades {
                let h = rng.cgFloat(in: 22...44)
                let bx = CGFloat(b - blades / 2) * 6 + rng.cgFloat(in: -3...3)
                let blade = SKSpriteNode(color: SKColor(red: 0.24, green: 0.32, blue: 0.40, alpha: 0.7),
                                         size: CGSize(width: 5, height: h))
                blade.anchorPoint = CGPoint(x: 0.5, y: 0)
                blade.position = CGPoint(x: bx, y: 0)
                blade.zRotation = rng.cgFloat(in: -0.14...0.14)
                tuft.addChild(blade)
                let rim = SKSpriteNode(color: SKColor(red: 0.80, green: 0.90, blue: 0.97, alpha: 0.55),
                                       size: CGSize(width: 2, height: h * 0.7))
                rim.anchorPoint = CGPoint(x: 0.5, y: 0)
                rim.position = CGPoint(x: bx + 1, y: 0)
                rim.zRotation = blade.zRotation
                tuft.addChild(rim)
            }
            layer.addChild(tuft)
            let sway = SKAction.sequence([
                .rotate(toAngle: 0.022, duration: rng.double(in: 2.2...3.6)),
                .rotate(toAngle: -0.022, duration: rng.double(in: 2.2...3.6)),
            ])
            tuft.run(.repeatForever(sway))
        }

        // Depth C — angular ice chunks with cold rims + contact shadows.
        for i in 0..<6 {
            let x = CGFloat(i) * (span / 6) + rng.cgFloat(in: -70...70)
            let w = rng.cgFloat(in: 30...50)
            let h = rng.cgFloat(in: 18...30)
            let shadow = SKShapeNode(ellipseOf: CGSize(width: w + 10, height: 7))
            shadow.fillColor = SKColor(white: 0, alpha: 0.35)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: x, y: 3)
            layer.addChild(shadow)
            let chunk = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -w / 2, y: 0))
            path.addLine(to: CGPoint(x: -w / 3, y: h * 0.8))
            path.addLine(to: CGPoint(x: w / 7, y: h))
            path.addLine(to: CGPoint(x: w / 2, y: h * 0.45))
            path.addLine(to: CGPoint(x: w / 2.4, y: 0))
            path.closeSubpath()
            chunk.path = path
            chunk.fillColor = SKColor(red: 0.46, green: 0.58, blue: 0.72, alpha: 1)
            chunk.strokeColor = rimCold.withAlpha(0.7)
            chunk.lineWidth = 1
            chunk.position = CGPoint(x: x, y: 4)
            layer.addChild(chunk)
        }

        // Cold bokeh + near-camera snow motes drifting against the camera.
        for _ in 0..<8 {
            let r = rng.cgFloat(in: 4...9)
            let mote = SKShapeNode(circleOfRadius: r)
            mote.fillColor = SKColor(white: 0.9, alpha: 0.07)
            mote.strokeColor = .clear
            mote.position = CGPoint(x: rng.cgFloat(in: 0...span),
                                    y: rng.cgFloat(in: 30...210))
            layer.addChild(mote)
            let drift = SKAction.moveBy(x: rng.cgFloat(in: -110...110),
                                        y: rng.cgFloat(in: -24...24),
                                        duration: rng.double(in: 6...11))
            mote.run(.repeatForever(.sequence([drift, drift.reversed()])))
        }
    }
}

private extension CGFloat {
    func clamped01() -> CGFloat { Swift.min(1, Swift.max(0, self)) }
}

private extension UIColor {
    func withAlpha(_ a: CGFloat) -> UIColor {
        withAlphaComponent(a)
    }
}
