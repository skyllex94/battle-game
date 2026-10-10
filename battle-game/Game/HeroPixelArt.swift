import SpriteKit
import UIKit

    /// Detailed pixel-art hero roster in the battle hero's astronaut language
    /// (rounded helmets, visors, backpacks, plated armor). Six fighters on a
    /// 30x40 canvas (facing +x): 4 walk frames for battle (contact → support
    /// → toe-off → swing, like the astronaut run cycle), 2 idle frames for
    /// showcases, plus a torso-up card portrait. `.nearest` filtering.
enum HeroPixelArt {

    enum Kind: CaseIterable {
        case vanguard, scout, bulwark, ranger, saboteur, warlord
        case titan, wraith, paladin, juggernaut, spectre, inferno
    }

    /// Hero id (roster / scene) → pixel kind.
    static func kind(for heroId: String) -> Kind {
        switch heroId {
        case "scout": return .scout
        case "bulwark": return .bulwark
        case "ranger": return .ranger
        case "saboteur": return .saboteur
        case "warlord": return .warlord
        case "titan": return .titan
        case "wraith": return .wraith
        case "paladin": return .paladin
        case "juggernaut": return .juggernaut
        case "spectre": return .spectre
        case "inferno": return .inferno
        default: return .vanguard
        }
    }

    /// Walk frames for battle: full 4-step stride. Shared per kind.
    static func frames(for kind: Kind) -> [SKTexture] {
        (0...3).map { body(kind, pose: $0, marching: true) }
    }

    /// Idle frames for showcases: [stand, breathe]. Shared per kind.
    static func idleFrames(for kind: Kind) -> [SKTexture] {
        [body(kind, pose: 0, marching: false), body(kind, pose: 1, marching: false)]
    }

    /// Full-body idle frame as a UIImage (for SwiftUI showcases).
    static func bodyImage(for kind: Kind, pose: Int) -> UIImage {
        _ = idleFrames(for: kind) // warm the cache
        return imageCache["hero-\(key(kind))-i\(pose)"] ?? UIImage()
    }

    // MARK: - Canvas

    private static let W = 30, H = 40

    /// Battle display size: 2pt per pixel — every fighter shares one
    /// frame so the roster reads as a unit (bulk comes from the art).
    static func displaySize(for kind: Kind) -> CGSize {
        CGSize(width: CGFloat(W) * 2, height: CGFloat(H) * 2)
    }

    private static func canvas(kind: Kind, key: String, draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: W, height: H),
                                          format: format).image { ctx in
            draw(ctx.cgContext) // UIKit coords: row 0 = top
        }
        imageCache[key] = img
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
    }

    private static var imageCache: [String: UIImage] = [:]
    private static var portraitCache: [Kind: UIImage] = [:]

    /// Card portrait: torso-up crop of the real sprite. 36x24 px — show
    /// with `.interpolation(.none)` so pixels stay crisp when upscaled.
    static func portraitImage(for kind: Kind) -> UIImage {
        if let cached = portraitCache[kind] { return cached }
        _ = idleFrames(for: kind) // warm the cache
        guard let body = imageCache["hero-\(key(kind))-i0"] else { return UIImage() }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let portrait = UIGraphicsImageRenderer(size: CGSize(width: 36, height: 24),
                                               format: format).image { _ in
            let crop = CGRect(x: 0, y: 2, width: 30, height: 20)
            if let bust = body.cgImage?.cropping(to: crop) {
                UIImage(cgImage: bust, scale: 1, orientation: .up)
                    .draw(in: CGRect(x: 3, y: 2, width: 30, height: 20))
            }
        }
        portraitCache[kind] = portrait
        return portrait
    }

    private static func key(_ kind: Kind) -> String {
        switch kind {
        case .vanguard: return "vanguard"
        case .scout: return "scout"
        case .bulwark: return "bulwark"
        case .ranger: return "ranger"
        case .saboteur: return "saboteur"
        case .warlord: return "warlord"
        case .titan: return "titan"
        case .wraith: return "wraith"
        case .paladin: return "paladin"
        case .juggernaut: return "juggernaut"
        case .spectre: return "spectre"
        case .inferno: return "inferno"
        }
    }

    private static func fill(_ cg: CGContext, x: Int, y: Int, w: Int, h: Int,
                             _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    // Shared inks.
    private static let outline = UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
    private static let dark = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)
    private static let white = UIColor(white: 1, alpha: 1)

    /// Astronaut walk legs: two striding legs under the hips with bent
    /// knees pushing forward — thigh + shin + knee pad + boot with sole.
    /// step is the walk frame (0-3); negative parks both legs neutral
    /// for idle showcases. Mirrors the astronaut run cycle.
    private static func stride(_ frame: Int, back: Bool) -> (dx: Int, lift: Int) {
        if frame < 0 { return (0, 0) }
        let table = [(4, 0), (0, 0), (-4, 1), (1, 3)]
        return table[(frame + (back ? 2 : 0)) % 4]
    }

    private static func segment(_ cg: CGContext, x0: Int, y0: Int,
                                x1: Int, y1: Int, w: Int, color: UIColor) {
        let steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = Int(round(CGFloat(x0) + CGFloat(x1 - x0) * t))
            let y = Int(round(CGFloat(y0) + CGFloat(y1 - y0) * t))
            fill(cg, x: x - w / 2, y: y, w: w, h: 1, color)
        }
    }

    private static func marchLegs(_ cg: CGContext, step: Int, cx: Int, top: Int, len: Int,
                                  main: UIColor, shade: UIColor, pad: UIColor,
                                  boot: UIColor, sole: UIColor, wide: Bool = false) {
        let w = wide ? 4 : 3
        let back = stride(step, back: true)
        let front = stride(step, back: false)
        marchLeg(cg, hipX: cx - 3, dx: back.dx, lift: back.lift,
                 top: top, len: len, w: w,
                 main: main, shade: shade, pad: pad, boot: boot, sole: sole)
        marchLeg(cg, hipX: cx + 2, dx: front.dx, lift: front.lift,
                 top: top, len: len, w: w,
                 main: main, shade: shade, pad: pad, boot: boot, sole: sole)
    }

    private static func marchLeg(_ cg: CGContext, hipX: Int, dx: Int, lift: Int,
                                 top: Int, len: Int, w: Int,
                                 main: UIColor, shade: UIColor, pad: UIColor,
                                 boot: UIColor, sole: UIColor) {
        let footX = hipX + dx
        let footY = top + len - lift
        let kneeX = (hipX + footX) / 2 + 1
        let kneeY = (top + footY) / 2
        segment(cg, x0: hipX, y0: top, x1: kneeX, y1: kneeY, w: w, color: main)
        segment(cg, x0: kneeX, y0: kneeY, x1: footX, y1: footY, w: w - 1, color: shade)
        fill(cg, x: kneeX - 2, y: kneeY - 1, w: 4, h: 3, pad)
        fill(cg, x: kneeX - 2, y: kneeY - 1, w: 4, h: 1, white.withAlphaComponent(0.3))
        fill(cg, x: footX - 2, y: footY, w: 5, h: 2, boot)
        fill(cg, x: footX - 2, y: footY + 2, w: 5, h: 1, sole)
        fill(cg, x: footX + 2, y: footY, w: 1, h: 2, sole)
    }

    /// Backpack unit with tank stripe + vents (shared astronaut gear).
    private static func pack(_ cg: CGContext, x: Int, top: Int, w: Int, h: Int,
                             shell: UIColor, stripe: UIColor) {
        fill(cg, x: x, y: top, w: w, h: h, outline)
        fill(cg, x: x + 1, y: top + 1, w: w - 2, h: h - 2, shell)
        fill(cg, x: x + 1, y: top + 1, w: 1, h: h - 2, stripe) // tank stripe
        fill(cg, x: x, y: top + h, w: w, h: 1, outline) // vent base
    }

    private static func body(_ kind: Kind, pose: Int, marching: Bool) -> SKTexture {
        canvas(kind: kind, key: "hero-\(key(kind))-\(marching ? "w" : "i")\(pose)") { cg in
            // Walk frames bob every other step; idle breathes on frame 1.
            // Visors blink mid-stride (walk frame 2) or on breathe (idle 1).
            let bob = marching ? (pose % 2 == 1 ? -1 : 0) : (pose == 1 ? -1 : 0)
            let blink = marching ? (pose == 2) : (pose == 1)
            let step = marching ? pose : -1 // -1 parks the legs neutral
            switch kind {
            case .vanguard: vanguard(cg, bob: bob, blink: blink, step: step)
            case .scout: scout(cg, bob: bob, blink: blink, step: step)
            case .bulwark: bulwark(cg, bob: bob, blink: blink, step: step)
            case .ranger: ranger(cg, bob: bob, blink: blink, step: step)
            case .saboteur: saboteur(cg, bob: bob, blink: blink, step: step)
            case .warlord: warlord(cg, bob: bob, blink: blink, step: step)
            case .titan: titan(cg, bob: bob, blink: blink, step: step)
            case .wraith: wraith(cg, bob: bob, blink: blink, step: step)
            case .paladin: paladin(cg, bob: bob, blink: blink, step: step)
            case .juggernaut: juggernaut(cg, bob: bob, blink: blink, step: step)
            case .spectre: spectre(cg, bob: bob, blink: blink, step: step)
            case .inferno: inferno(cg, bob: bob, blink: blink, step: step)
            }
        }
    }

    // MARK: - Vanguard (the battle hero: silver-white + gold V-visor)

    private static func vanguard(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let armor = UIColor(red: 0.85, green: 0.87, blue: 0.92, alpha: 1)
        let armorD = UIColor(red: 0.55, green: 0.57, blue: 0.65, alpha: 1)
        let suit = UIColor(red: 0.20, green: 0.22, blue: 0.32, alpha: 1)
        let suitD = UIColor(red: 0.11, green: 0.11, blue: 0.19, alpha: 1)
        let gold = UIColor(red: 1.0, green: 0.74, blue: 0.28, alpha: 1)
        let tank = UIColor(red: 0.32, green: 0.86, blue: 1.0, alpha: 1)
        let O = outline
        // Backpack with air tank.
        pack(cg, x: 7, top: 14 + bob, w: 4, h: 9, shell: suit, stripe: tank)
        // Big rounded helmet + center ridge + chin guard + side lamp.
        fill(cg, x: 10, y: 2 + bob, w: 13, h: 1, O)
        fill(cg, x: 9, y: 3 + bob, w: 15, h: 10, armor)
        fill(cg, x: 9, y: 3 + bob, w: 2, h: 10, armorD)
        fill(cg, x: 22, y: 3 + bob, w: 2, h: 10, armorD)
        fill(cg, x: 9, y: 12 + bob, w: 15, h: 1, armorD)
        fill(cg, x: 15, y: 2 + bob, w: 3, h: 5, armorD)
        fill(cg, x: 15, y: 2 + bob, w: 3, h: 1, white)
        fill(cg, x: 10, y: 5 + bob, w: 2, h: 4, gold)
        // Dark face opening + angular gold V-visor (signature).
        fill(cg, x: 15, y: 8 + bob, w: 8, h: blink ? 2 : 5, O)
        if !blink {
            fill(cg, x: 16, y: 9 + bob, w: 2, h: 3, gold)
            fill(cg, x: 18, y: 10 + bob, w: 2, h: 2, gold)
            fill(cg, x: 20, y: 9 + bob, w: 2, h: 3, gold)
            fill(cg, x: 18, y: 11 + bob, w: 2, h: 1, white)
        }
        fill(cg, x: 16, y: 7 + bob, w: 2, h: 1, gold) // brow light
        // Neck + bulky shoulder pads with studs.
        fill(cg, x: 14, y: 13 + bob, w: 5, h: 3, suit)
        fill(cg, x: 6, y: 15 + bob, w: 6, h: 6, armor)
        fill(cg, x: 6, y: 15 + bob, w: 6, h: 1, white)
        fill(cg, x: 7, y: 17 + bob, w: 1, h: 1, gold)
        fill(cg, x: 23, y: 15 + bob, w: 5, h: 5, armor)
        fill(cg, x: 23, y: 15 + bob, w: 5, h: 1, armorD)
        fill(cg, x: 25, y: 17 + bob, w: 1, h: 1, gold)
        // Torso: white chest + dark vest + gold core + hip lights.
        fill(cg, x: 11, y: 16 + bob, w: 12, h: 1, O)
        fill(cg, x: 11, y: 17 + bob, w: 12, h: 10, armor)
        fill(cg, x: 11, y: 17 + bob, w: 2, h: 10, armorD)
        fill(cg, x: 21, y: 17 + bob, w: 2, h: 10, armorD)
        fill(cg, x: 14, y: 19 + bob, w: 5, h: 7, suit)
        fill(cg, x: 14, y: 19 + bob, w: 5, h: 1, suitD)
        fill(cg, x: 16, y: 21 + bob, w: 2, h: 3, gold)
        fill(cg, x: 16, y: 21 + bob, w: 2, h: 1, white)
        // Belt + buckle + hip lights.
        fill(cg, x: 11, y: 27 + bob, w: 12, h: 2, suitD)
        fill(cg, x: 15, y: 27 + bob, w: 3, h: 2, gold)
        fill(cg, x: 11, y: 28 + bob, w: 2, h: 1, gold)
        fill(cg, x: 21, y: 28 + bob, w: 2, h: 1, gold)
        // Walking astronaut legs (rifle brings the hands).
        marchLegs(cg, step: step, cx: 15, top: 29 + bob, len: 6, main: suit,
                  shade: suitD, pad: armorD, boot: suitD, sole: gold)
    }

    // MARK: - Scout (light recon: slim teal shell + comms gear)

    private static func scout(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let shell = UIColor(red: 0.25, green: 0.62, blue: 0.62, alpha: 1)
        let shellD = UIColor(red: 0.12, green: 0.36, blue: 0.40, alpha: 1)
        let suit = UIColor(red: 0.16, green: 0.22, blue: 0.26, alpha: 1)
        let suitD = UIColor(red: 0.09, green: 0.12, blue: 0.16, alpha: 1)
        let lens = UIColor(red: 0.65, green: 1.0, blue: 1.0, alpha: 1)
        let O = outline
        // Slim backpack + stripe.
        pack(cg, x: 8, top: 15 + bob, w: 3, h: 8, shell: suit, stripe: lens)
        // Sleek helm + crest fin + big lens.
        fill(cg, x: 11, y: 3 + bob, w: 11, h: 8, O)
        fill(cg, x: 12, y: 4 + bob, w: 9, h: 6, shell)
        fill(cg, x: 14, y: 1 + bob, w: 4, h: 3, shellD)
        fill(cg, x: 14, y: 1 + bob, w: 4, h: 1, lens)
        fill(cg, x: 17, y: 5 + bob, w: 5, h: blink ? 1 : 3, O)
        if !blink { fill(cg, x: 18, y: 5 + bob, w: 3, h: 2, lens) }
        // Comms headset: band + earpiece + mic boom.
        fill(cg, x: 11, y: 4 + bob, w: 11, h: 1, suitD)
        fill(cg, x: 11, y: 5 + bob, w: 2, h: 3, suitD)
        fill(cg, x: 11, y: 6 + bob, w: 2, h: 1, lens)
        fill(cg, x: 11, y: 8 + bob, w: 4, h: 1, suitD)
        // Whip antenna with a live tip.
        fill(cg, x: 22, y: 0 + bob, w: 2, h: 4, suitD)
        fill(cg, x: 22, y: 0 + bob, w: 2, h: 1, lens)
        // Padded collar instead of a scarf.
        fill(cg, x: 12, y: 11 + bob, w: 9, h: 2, shellD)
        fill(cg, x: 12, y: 11 + bob, w: 9, h: 1, shell)
        // Light shoulder shells.
        fill(cg, x: 8, y: 14 + bob, w: 5, h: 4, shell)
        fill(cg, x: 8, y: 14 + bob, w: 5, h: 1, white.withAlphaComponent(0.4))
        fill(cg, x: 22, y: 14 + bob, w: 4, h: 4, shellD)
        // Light torso + strap + rangefinder + chest light.
        fill(cg, x: 12, y: 13 + bob, w: 9, h: 11, O)
        fill(cg, x: 13, y: 14 + bob, w: 7, h: 9, shell)
        fill(cg, x: 13, y: 16 + bob, w: 7, h: 1, shellD)
        fill(cg, x: 16, y: 14 + bob, w: 2, h: 3, O)
        fill(cg, x: 16, y: 14 + bob, w: 2, h: 2, lens)
        fill(cg, x: 16, y: 19 + bob, w: 2, h: 2, O)
        fill(cg, x: 16, y: 19 + bob, w: 2, h: 1, lens)
        // Belt with pouches + striding sprinter legs.
        fill(cg, x: 12, y: 24 + bob, w: 9, h: 2, suitD)
        fill(cg, x: 13, y: 24 + bob, w: 2, h: 2, shellD)
        fill(cg, x: 18, y: 24 + bob, w: 2, h: 2, shellD)
        marchLegs(cg, step: step, cx: 15, top: 26 + bob, len: 7, main: suit,
                  shade: suitD, pad: shellD, boot: suitD, sole: lens)
    }

    // MARK: - Bulwark (siege armor: navy slabs + hazard core)

    private static func bulwark(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let plate = UIColor(red: 0.24, green: 0.34, blue: 0.58, alpha: 1)
        let plateD = UIColor(red: 0.13, green: 0.18, blue: 0.35, alpha: 1)
        let suit = UIColor(red: 0.14, green: 0.15, blue: 0.22, alpha: 1)
        let suitD = UIColor(red: 0.08, green: 0.08, blue: 0.13, alpha: 1)
        let lamp = UIColor(red: 0.55, green: 0.9, blue: 1.0, alpha: 1)
        let hazard = UIColor(red: 0.95, green: 0.7, blue: 0.15, alpha: 1)
        let O = outline
        // Heavy backpack block + vents.
        pack(cg, x: 5, top: 13 + bob, w: 5, h: 10, shell: suit, stripe: lamp)
        fill(cg, x: 5, y: 18 + bob, w: 5, h: 1, hazard)
        // Slab helm + crest + slit lamp.
        fill(cg, x: 9, y: 2 + bob, w: 14, h: 8, O)
        fill(cg, x: 10, y: 3 + bob, w: 12, h: 6, plate)
        fill(cg, x: 10, y: 3 + bob, w: 12, h: 1, white.withAlphaComponent(0.35))
        fill(cg, x: 14, y: 1 + bob, w: 4, h: 2, plateD)
        fill(cg, x: 15, y: 6 + bob, w: 7, h: blink ? 1 : 3, O)
        if !blink { fill(cg, x: 16, y: 6 + bob, w: 5, h: 2, lamp) }
        // Fortress pauldrons with rivets.
        fill(cg, x: 3, y: 10 + bob, w: 8, h: 6, O)
        fill(cg, x: 4, y: 11 + bob, w: 6, h: 4, plate)
        fill(cg, x: 4, y: 11 + bob, w: 6, h: 1, white.withAlphaComponent(0.3))
        fill(cg, x: 5, y: 13 + bob, w: 1, h: 1, lamp)
        fill(cg, x: 20, y: 10 + bob, w: 7, h: 6, O)
        fill(cg, x: 21, y: 11 + bob, w: 5, h: 4, plate)
        fill(cg, x: 24, y: 13 + bob, w: 1, h: 1, lamp)
        // Barrel chest + hazard core + vent slats.
        fill(cg, x: 8, y: 16 + bob, w: 14, h: 10, O)
        fill(cg, x: 9, y: 17 + bob, w: 12, h: 8, plate)
        fill(cg, x: 9, y: 17 + bob, w: 3, h: 8, plateD)
        fill(cg, x: 9, y: 18 + bob, w: 3, h: 1, lamp)
        fill(cg, x: 14, y: 19 + bob, w: 4, h: 4, O)
        fill(cg, x: 14, y: 19 + bob, w: 4, h: 3, lamp)
        fill(cg, x: 14, y: 19 + bob, w: 4, h: 1, white)
        fill(cg, x: 14, y: 23 + bob, w: 4, h: 1, hazard)
        // Belt + stomping walk legs.
        fill(cg, x: 8, y: 26 + bob, w: 14, h: 2, suitD)
        fill(cg, x: 13, y: 26 + bob, w: 4, h: 2, plateD)
        marchLegs(cg, step: step, cx: 13, top: 28 + bob, len: 6, main: suit,
                  shade: suitD, pad: plate, boot: suitD, sole: plateD, wide: true)
    }

    // MARK: - Ranger (hooded marksman: moss cloak over scout shell)

    private static func ranger(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let cloak = UIColor(red: 0.32, green: 0.44, blue: 0.25, alpha: 1)
        let cloakD = UIColor(red: 0.17, green: 0.26, blue: 0.15, alpha: 1)
        let shell = UIColor(red: 0.30, green: 0.42, blue: 0.38, alpha: 1)
        let suit = UIColor(red: 0.18, green: 0.20, blue: 0.19, alpha: 1)
        let suitD = UIColor(red: 0.10, green: 0.11, blue: 0.11, alpha: 1)
        let lens = UIColor(red: 1.0, green: 0.80, blue: 0.35, alpha: 1)
        let O = outline
        // Scout backpack + quiver of marks.
        pack(cg, x: 7, top: 15 + bob, w: 3, h: 8, shell: suit, stripe: lens)
        fill(cg, x: 22, y: 14 + bob, w: 3, h: 8, O)
        fill(cg, x: 23, y: 13 + bob, w: 1, h: 2, lens)
        // Stitched hood + amber lens.
        fill(cg, x: 10, y: 1 + bob, w: 12, h: 9, O)
        fill(cg, x: 11, y: 2 + bob, w: 10, h: 7, cloak)
        fill(cg, x: 11, y: 2 + bob, w: 10, h: 1, white.withAlphaComponent(0.3))
        fill(cg, x: 11, y: 8 + bob, w: 1, h: 1, cloakD)
        fill(cg, x: 20, y: 8 + bob, w: 1, h: 1, cloakD)
        fill(cg, x: 16, y: 5 + bob, w: 5, h: blink ? 1 : 3, O)
        if !blink { fill(cg, x: 17, y: 5 + bob, w: 3, h: 2, lens) }
        // Cloak mantle + brass clasp.
        fill(cg, x: 7, y: 10 + bob, w: 15, h: 5, O)
        fill(cg, x: 8, y: 10 + bob, w: 13, h: 4, cloak)
        fill(cg, x: 14, y: 11 + bob, w: 3, h: 2, lens)
        // Torso + cloak tail + rangefinder.
        fill(cg, x: 11, y: 15 + bob, w: 9, h: 9, O)
        fill(cg, x: 12, y: 16 + bob, w: 7, h: 7, shell)
        fill(cg, x: 12, y: 16 + bob, w: 1, h: 7, cloakD)
        fill(cg, x: 15, y: 17 + bob, w: 2, h: 2, lens)
        fill(cg, x: 6, y: 15 + bob, w: 4, h: 11, cloakD)
        // Belt + striding walk legs.
        fill(cg, x: 11, y: 24 + bob, w: 9, h: 2, suitD)
        fill(cg, x: 14, y: 24 + bob, w: 2, h: 2, cloak)
        marchLegs(cg, step: step, cx: 14, top: 26 + bob, len: 7, main: suit,
                  shade: suitD, pad: cloak, boot: suitD, sole: lens)
    }

    // MARK: - Saboteur (demo expert: violet shell + live charges)

    private static func saboteur(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let shell = UIColor(red: 0.30, green: 0.18, blue: 0.42, alpha: 1)
        let shellD = UIColor(red: 0.17, green: 0.10, blue: 0.25, alpha: 1)
        let suit = UIColor(red: 0.16, green: 0.13, blue: 0.20, alpha: 1)
        let suitD = UIColor(red: 0.09, green: 0.07, blue: 0.12, alpha: 1)
        let charge = UIColor(red: 1.0, green: 0.25, blue: 0.15, alpha: 1)
        let lens = UIColor(red: 1.0, green: 0.45, blue: 0.6, alpha: 1)
        let O = outline
        // Charge backpack: cells + blinking fuses + hazard foot.
        fill(cg, x: 5, y: 12 + bob, w: 5, h: 10, O)
        fill(cg, x: 6, y: 13 + bob, w: 3, h: 8, shellD)
        fill(cg, x: 6, y: 15 + bob, w: 3, h: 2, charge)
        fill(cg, x: 6, y: 18 + bob, w: 3, h: 1, charge)
        fill(cg, x: 6, y: 10 + bob, w: 1, h: 3, charge)
        fill(cg, x: 8, y: 11 + bob, w: 1, h: 2, charge)
        if !blink {
            fill(cg, x: 6, y: 10 + bob, w: 1, h: 1, white)
            fill(cg, x: 8, y: 11 + bob, w: 1, h: 1, white)
        }
        fill(cg, x: 5, y: 21 + bob, w: 5, h: 1, charge)
        // Goggled hood + triple lens.
        fill(cg, x: 10, y: 3 + bob, w: 12, h: 8, O)
        fill(cg, x: 11, y: 4 + bob, w: 10, h: 6, shell)
        fill(cg, x: 11, y: 4 + bob, w: 10, h: 1, white.withAlphaComponent(0.3))
        fill(cg, x: 13, y: 6 + bob, w: 3, h: blink ? 1 : 2, O)
        fill(cg, x: 17, y: 6 + bob, w: 3, h: blink ? 1 : 2, O)
        if !blink {
            fill(cg, x: 13, y: 6 + bob, w: 3, h: 1, lens)
            fill(cg, x: 17, y: 6 + bob, w: 3, h: 1, lens)
        }
        // Rebreather grille.
        fill(cg, x: 17, y: 9 + bob, w: 4, h: 2, suitD)
        fill(cg, x: 18, y: 9 + bob, w: 1, h: 2, lens)
        // Torso rigged with demo charges.
        fill(cg, x: 11, y: 12 + bob, w: 10, h: 10, O)
        fill(cg, x: 12, y: 13 + bob, w: 8, h: 8, shell)
        fill(cg, x: 12, y: 13 + bob, w: 2, h: 8, shellD)
        fill(cg, x: 14, y: 15 + bob, w: 3, h: 3, charge)
        fill(cg, x: 17, y: 18 + bob, w: 2, h: 2, charge)
        if !blink {
            fill(cg, x: 14, y: 15 + bob, w: 3, h: 1, white)
            fill(cg, x: 17, y: 18 + bob, w: 2, h: 1, white)
        }
        // Belt + nimble walk legs.
        fill(cg, x: 11, y: 22 + bob, w: 10, h: 2, suitD)
        fill(cg, x: 14, y: 22 + bob, w: 3, h: 2, charge)
        marchLegs(cg, step: step, cx: 14, top: 24 + bob, len: 7, main: suit,
                  shade: suitD, pad: shellD, boot: suitD, sole: charge)
    }

    // MARK: - Warlord (tyrant plate: crimson + bronze + cape)

    private static func warlord(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let armor = UIColor(red: 0.58, green: 0.15, blue: 0.15, alpha: 1)
        let armorD = UIColor(red: 0.34, green: 0.09, blue: 0.10, alpha: 1)
        let suit = UIColor(red: 0.16, green: 0.11, blue: 0.12, alpha: 1)
        let suitD = UIColor(red: 0.09, green: 0.06, blue: 0.07, alpha: 1)
        let bronze = UIColor(red: 0.80, green: 0.52, blue: 0.22, alpha: 1)
        let glow = UIColor(red: 1.0, green: 0.35, blue: 0.1, alpha: 1)
        let O = outline
        // Swept war horns.
        fill(cg, x: 6, y: 1 + bob, w: 4, h: 4, O)
        fill(cg, x: 6, y: 1 + bob, w: 3, h: 3, bronze)
        fill(cg, x: 5, y: 0 + bob, w: 2, h: 2, bronze)
        fill(cg, x: 21, y: 1 + bob, w: 4, h: 4, O)
        fill(cg, x: 22, y: 1 + bob, w: 3, h: 3, bronze)
        fill(cg, x: 24, y: 0 + bob, w: 2, h: 2, bronze)
        // Tyrant helm + burning eyes + breath grille.
        fill(cg, x: 10, y: 3 + bob, w: 11, h: 8, O)
        fill(cg, x: 11, y: 4 + bob, w: 9, h: 6, armor)
        fill(cg, x: 11, y: 4 + bob, w: 9, h: 1, white.withAlphaComponent(0.3))
        fill(cg, x: 14, y: 2 + bob, w: 3, h: 2, bronze)
        fill(cg, x: 13, y: 6 + bob, w: 3, h: blink ? 1 : 2, glow)
        fill(cg, x: 17, y: 6 + bob, w: 3, h: blink ? 1 : 2, glow)
        fill(cg, x: 15, y: 9 + bob, w: 3, h: 2, suitD)
        fill(cg, x: 15, y: 9 + bob, w: 3, h: 1, bronze)
        // War cape with bronze hem.
        fill(cg, x: 5, y: 11 + bob, w: 5, h: 19, armorD)
        fill(cg, x: 5, y: 11 + bob, w: 1, h: 19, bronze)
        fill(cg, x: 5, y: 28 + bob, w: 5, h: 2, bronze)
        // Throne pauldrons with bronze trim.
        fill(cg, x: 4, y: 11 + bob, w: 8, h: 5, O)
        fill(cg, x: 5, y: 11 + bob, w: 6, h: 4, armor)
        fill(cg, x: 5, y: 11 + bob, w: 6, h: 1, bronze)
        fill(cg, x: 19, y: 11 + bob, w: 7, h: 5, O)
        fill(cg, x: 20, y: 11 + bob, w: 5, h: 4, armor)
        fill(cg, x: 20, y: 11 + bob, w: 5, h: 1, bronze)
        // Broad torso + war core + medal studs.
        fill(cg, x: 9, y: 16 + bob, w: 13, h: 10, O)
        fill(cg, x: 10, y: 17 + bob, w: 11, h: 8, armor)
        fill(cg, x: 10, y: 17 + bob, w: 2, h: 8, armorD)
        fill(cg, x: 14, y: 19 + bob, w: 4, h: 4, O)
        fill(cg, x: 14, y: 19 + bob, w: 4, h: 3, glow)
        fill(cg, x: 14, y: 19 + bob, w: 4, h: 1, white)
        fill(cg, x: 19, y: 18 + bob, w: 1, h: 1, bronze)
        fill(cg, x: 19, y: 20 + bob, w: 1, h: 1, bronze)
        // Belt + pillar walk legs with bronze greaves.
        fill(cg, x: 9, y: 26 + bob, w: 13, h: 2, suitD)
        fill(cg, x: 13, y: 26 + bob, w: 4, h: 2, bronze)
        marchLegs(cg, step: step, cx: 13, top: 28 + bob, len: 6, main: armorD,
                  shade: suitD, pad: bronze, boot: suitD, sole: bronze, wide: true)
    }

    // MARK: - Titan (siege wall: granite bulk + magma seams)

    private static func titan(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let stone = UIColor(red: 0.38, green: 0.38, blue: 0.44, alpha: 1)
        let stoneD = UIColor(red: 0.22, green: 0.22, blue: 0.28, alpha: 1)
        let magma = UIColor(red: 1.0, green: 0.45, blue: 0.10, alpha: 1)
        let ember = UIColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1)
        let O = outline
        // Reactor block with a live ember line.
        pack(cg, x: 1, top: 18 + bob, w: 5, h: 11, shell: stoneD, stripe: magma)
        fill(cg, x: 2, y: 23 + bob, w: 3, h: 1, ember)
        // Wall pauldrons bleeding off both edges, magma studs.
        fill(cg, x: 0, y: 11 + bob, w: 10, h: 8, O)
        fill(cg, x: 1, y: 12 + bob, w: 8, h: 6, stone)
        fill(cg, x: 1, y: 12 + bob, w: 8, h: 1, white.withAlphaComponent(0.3))
        fill(cg, x: 3, y: 15 + bob, w: 2, h: 2, magma)
        fill(cg, x: 6, y: 15 + bob, w: 2, h: 2, magma)
        fill(cg, x: 20, y: 11 + bob, w: 10, h: 8, O)
        fill(cg, x: 21, y: 12 + bob, w: 8, h: 6, stone)
        fill(cg, x: 22, y: 15 + bob, w: 2, h: 2, magma)
        fill(cg, x: 25, y: 15 + bob, w: 2, h: 2, magma)
        // Heavy-brow helm sunk deep + ember slit.
        fill(cg, x: 11, y: 3 + bob, w: 9, h: 8, O)
        fill(cg, x: 12, y: 4 + bob, w: 7, h: 6, stoneD)
        fill(cg, x: 12, y: 4 + bob, w: 7, h: 2, stone) // brow shelf
        fill(cg, x: 13, y: 7 + bob, w: 5, h: blink ? 1 : 2, O)
        if !blink { fill(cg, x: 14, y: 7 + bob, w: 3, h: 1, magma) }
        fill(cg, x: 9, y: 11 + bob, w: 12, h: 3, stone) // gorget
        fill(cg, x: 14, y: 12 + bob, w: 3, h: 1, ember)  // throat glow
        // Chest bridge: solid stone from gorget to torso, no gap.
        fill(cg, x: 10, y: 14 + bob, w: 11, h: 4, stone)
        fill(cg, x: 10, y: 14 + bob, w: 2, h: 4, stoneD)
        fill(cg, x: 15, y: 15 + bob, w: 1, h: 2, magma)
        // Broad torso wall + magma seams + big furnace core.
        fill(cg, x: 6, y: 18 + bob, w: 18, h: 10, O)
        fill(cg, x: 7, y: 19 + bob, w: 16, h: 8, stone)
        fill(cg, x: 7, y: 19 + bob, w: 3, h: 8, stoneD)
        fill(cg, x: 10, y: 20 + bob, w: 1, h: 6, magma)
        fill(cg, x: 19, y: 20 + bob, w: 1, h: 6, magma)
        fill(cg, x: 12, y: 21 + bob, w: 6, h: 5, O)
        fill(cg, x: 12, y: 21 + bob, w: 6, h: 4, magma)
        fill(cg, x: 12, y: 21 + bob, w: 6, h: 1, ember)
        // Belt + thick siege-stump legs.
        fill(cg, x: 6, y: 28 + bob, w: 18, h: 2, stoneD)
        fill(cg, x: 12, y: 28 + bob, w: 6, h: 2, magma)
        marchLegs(cg, step: step, cx: 14, top: 30 + bob, len: 6, main: stone,
                  shade: stoneD, pad: stone, boot: stoneD, sole: magma, wide: true)
    }

    // MARK: - Wraith (ghost infiltrator: tattered teal cloak, ember eyes)

    private static func wraith(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let shroud = UIColor(red: 0.16, green: 0.38, blue: 0.42, alpha: 1)
        let shroudD = UIColor(red: 0.08, green: 0.20, blue: 0.24, alpha: 1)
        let mist = UIColor(red: 0.55, green: 0.95, blue: 0.95, alpha: 1)
        let O = outline
        // Ragged hood + deep cowl + burning eyes.
        fill(cg, x: 10, y: 2 + bob, w: 12, h: 9, O)
        fill(cg, x: 11, y: 3 + bob, w: 10, h: 7, shroud)
        fill(cg, x: 11, y: 3 + bob, w: 2, h: 7, shroudD)
        fill(cg, x: 10, y: 9 + bob, w: 2, h: 3, shroudD) // hood tear
        fill(cg, x: 21, y: 8 + bob, w: 2, h: 4, shroudD) // hood tear
        fill(cg, x: 15, y: 6 + bob, w: 6, h: blink ? 1 : 3, O)
        if !blink {
            fill(cg, x: 16, y: 6 + bob, w: 2, h: 2, mist)
            fill(cg, x: 19, y: 6 + bob, w: 1, h: 2, mist)
        }
        // Tattered cloak: layered tails that shred toward the legs.
        fill(cg, x: 8, y: 11 + bob, w: 14, h: 14, O)
        fill(cg, x: 9, y: 12 + bob, w: 12, h: 12, shroud)
        fill(cg, x: 9, y: 12 + bob, w: 2, h: 12, shroudD)
        fill(cg, x: 13, y: 14 + bob, w: 2, h: 6, mist) // spirit seam
        fill(cg, x: 9, y: 24 + bob, w: 3, h: 4, shroudD)
        fill(cg, x: 13, y: 25 + bob, w: 3, h: 3, shroudD)
        fill(cg, x: 18, y: 24 + bob, w: 3, h: 4, shroudD)
        // Wisp clasp + faint chest glow.
        fill(cg, x: 14, y: 13 + bob, w: 3, h: 2, mist)
        fill(cg, x: 15, y: 17 + bob, w: 2, h: 3, mist)
        // Wisp-thin striding legs fading into mist.
        marchLegs(cg, step: step, cx: 14, top: 26 + bob, len: 7, main: shroudD,
                  shade: shroudD, pad: shroud, boot: shroudD, sole: mist)
    }

    // MARK: - Paladin (oathbound guard: winged helm, gold + white plate)

    private static func paladin(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let plate = UIColor(red: 0.90, green: 0.90, blue: 0.94, alpha: 1)
        let plateD = UIColor(red: 0.58, green: 0.60, blue: 0.68, alpha: 1)
        let gold = UIColor(red: 1.0, green: 0.78, blue: 0.30, alpha: 1)
        let tabard = UIColor(red: 0.20, green: 0.35, blue: 0.75, alpha: 1)
        let lens = UIColor(red: 0.55, green: 0.9, blue: 1.0, alpha: 1)
        let O = outline
        // Reliquary pack with a gold seal.
        pack(cg, x: 7, top: 15 + bob, w: 4, h: 9, shell: plateD, stripe: gold)
        // Winged helm: white wings fanning both sides.
        fill(cg, x: 3, y: 4 + bob, w: 7, h: 3, plate)
        fill(cg, x: 3, y: 4 + bob, w: 7, h: 1, white)
        fill(cg, x: 20, y: 4 + bob, w: 7, h: 3, plate)
        fill(cg, x: 20, y: 4 + bob, w: 7, h: 1, white)
        fill(cg, x: 10, y: 2 + bob, w: 11, h: 9, O)
        fill(cg, x: 11, y: 3 + bob, w: 9, h: 7, plate)
        fill(cg, x: 11, y: 3 + bob, w: 2, h: 7, plateD)
        fill(cg, x: 14, y: 6 + bob, w: 6, h: blink ? 1 : 3, O)
        if !blink { fill(cg, x: 15, y: 6 + bob, w: 4, h: 2, lens) }
        fill(cg, x: 14, y: 2 + bob, w: 3, h: 2, gold) // crest
        // Gilded pauldrons.
        fill(cg, x: 5, y: 12 + bob, w: 7, h: 6, O)
        fill(cg, x: 6, y: 13 + bob, w: 5, h: 4, plate)
        fill(cg, x: 6, y: 13 + bob, w: 5, h: 1, gold)
        fill(cg, x: 19, y: 12 + bob, w: 7, h: 6, O)
        fill(cg, x: 20, y: 13 + bob, w: 5, h: 4, plate)
        fill(cg, x: 20, y: 13 + bob, w: 5, h: 1, gold)
        // Gorget bridge: armor from collar to torso with no gap.
        fill(cg, x: 11, y: 15 + bob, w: 9, h: 3, plate)
        fill(cg, x: 11, y: 15 + bob, w: 9, h: 1, gold)
        fill(cg, x: 14, y: 16 + bob, w: 3, h: 1, gold)
        // White plate + blue tabard + broad gold cross.
        fill(cg, x: 10, y: 18 + bob, w: 11, h: 9, O)
        fill(cg, x: 11, y: 19 + bob, w: 9, h: 7, plate)
        fill(cg, x: 11, y: 19 + bob, w: 1, h: 7, plateD)
        fill(cg, x: 19, y: 19 + bob, w: 1, h: 7, plateD)
        fill(cg, x: 13, y: 19 + bob, w: 5, h: 7, tabard)
        fill(cg, x: 14, y: 20 + bob, w: 3, h: 5, gold)
        fill(cg, x: 13, y: 21 + bob, w: 5, h: 1, gold)
        fill(cg, x: 11, y: 20 + bob, w: 1, h: 1, gold)
        fill(cg, x: 11, y: 24 + bob, w: 1, h: 1, gold)
        fill(cg, x: 19, y: 20 + bob, w: 1, h: 1, gold)
        fill(cg, x: 19, y: 24 + bob, w: 1, h: 1, gold)
        // Chain connectors + belt + fauld tassets over the hips.
        fill(cg, x: 10, y: 17 + bob, w: 2, h: 1, gold)
        fill(cg, x: 18, y: 17 + bob, w: 2, h: 1, gold)
        // Belt + buckle + fauld tassets guarding the hips.
        fill(cg, x: 10, y: 27 + bob, w: 11, h: 2, plateD)
        fill(cg, x: 14, y: 27 + bob, w: 3, h: 2, gold)
        fill(cg, x: 11, y: 29 + bob, w: 4, h: 2, plate)
        fill(cg, x: 11, y: 30 + bob, w: 4, h: 1, gold)
        fill(cg, x: 16, y: 29 + bob, w: 4, h: 2, plate)
        fill(cg, x: 16, y: 30 + bob, w: 4, h: 1, gold)
        marchLegs(cg, step: step, cx: 14, top: 29 + bob, len: 6, main: plateD,
                  shade: plateD, pad: plate, boot: plateD, sole: gold)
    }

    // MARK: - Juggernaut (demolitions: fat hazard bulk, blast shield)

    private static func juggernaut(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let rust = UIColor(red: 0.55, green: 0.33, blue: 0.15, alpha: 1)
        let rustD = UIColor(red: 0.32, green: 0.19, blue: 0.09, alpha: 1)
        let hazard = UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
        let suit = UIColor(red: 0.15, green: 0.13, blue: 0.12, alpha: 1)
        let suitD = UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
        let lens = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)
        let O = outline
        // Blast helm + wide shield visor + grille jaw.
        fill(cg, x: 9, y: 3 + bob, w: 12, h: 9, O)
        fill(cg, x: 10, y: 4 + bob, w: 10, h: 7, rust)
        fill(cg, x: 10, y: 4 + bob, w: 10, h: 1, hazard)
        fill(cg, x: 13, y: 6 + bob, w: 7, h: blink ? 1 : 3, O)
        if !blink { fill(cg, x: 14, y: 6 + bob, w: 5, h: 2, lens) }
        fill(cg, x: 11, y: 10 + bob, w: 8, h: 2, suitD)
        fill(cg, x: 12, y: 10 + bob, w: 1, h: 2, lens)
        fill(cg, x: 15, y: 10 + bob, w: 1, h: 2, lens)
        fill(cg, x: 18, y: 10 + bob, w: 1, h: 2, lens)
        // Hazard-chevron pauldrons.
        fill(cg, x: 1, y: 12 + bob, w: 9, h: 7, O)
        fill(cg, x: 2, y: 13 + bob, w: 7, h: 5, rust)
        fill(cg, x: 2, y: 16 + bob, w: 2, h: 2, hazard)
        fill(cg, x: 4, y: 14 + bob, w: 2, h: 2, suitD)
        fill(cg, x: 6, y: 16 + bob, w: 2, h: 2, hazard)
        fill(cg, x: 21, y: 12 + bob, w: 8, h: 7, O)
        fill(cg, x: 22, y: 13 + bob, w: 6, h: 5, rust)
        fill(cg, x: 22, y: 13 + bob, w: 6, h: 1, hazard)
        fill(cg, x: 25, y: 15 + bob, w: 2, h: 2, lens)
        // Upper chest bridge: armor from pauldron to gut with no
        // background gap between (the old hollow read as a hole).
        fill(cg, x: 8, y: 14 + bob, w: 14, h: 5, O)
        fill(cg, x: 9, y: 15 + bob, w: 12, h: 3, rust)
        fill(cg, x: 9, y: 15 + bob, w: 12, h: 1, hazard)
        fill(cg, x: 9, y: 17 + bob, w: 2, h: 1, rustD)
        fill(cg, x: 19, y: 17 + bob, w: 2, h: 1, rustD)
        fill(cg, x: 13, y: 16 + bob, w: 4, h: 1, rustD)
        // Demo charge block + ammo drum strapped OVER the armor.
        fill(cg, x: 2, y: 15 + bob, w: 6, h: 11, O)
        fill(cg, x: 3, y: 16 + bob, w: 4, h: 9, rustD)
        fill(cg, x: 3, y: 18 + bob, w: 4, h: 2, hazard)
        fill(cg, x: 3, y: 22 + bob, w: 4, h: 1, hazard)
        fill(cg, x: 3, y: 24 + bob, w: 4, h: 1, hazard)
        fill(cg, x: 4, y: 13 + bob, w: 1, h: 3, hazard)
        if !blink { fill(cg, x: 4, y: 13 + bob, w: 1, h: 1, white) }
        fill(cg, x: 24, y: 17 + bob, w: 5, h: 9, O)
        fill(cg, x: 25, y: 18 + bob, w: 3, h: 7, rust)
        fill(cg, x: 25, y: 21 + bob, w: 3, h: 2, hazard)
        fill(cg, x: 25, y: 22 + bob, w: 1, h: 1, suitD)
        // FAT gut: plated belly with seams, rivets, gauge cluster,
        // charge blocks and lamp — dressed on every row.
        fill(cg, x: 5, y: 19 + bob, w: 20, h: 9, O)
        fill(cg, x: 6, y: 20 + bob, w: 18, h: 7, rust)
        fill(cg, x: 6, y: 20 + bob, w: 3, h: 7, rustD)
        fill(cg, x: 21, y: 20 + bob, w: 3, h: 7, rustD)
        // Belly plate seams.
        fill(cg, x: 9, y: 22 + bob, w: 12, h: 1, rustD)
        fill(cg, x: 9, y: 25 + bob, w: 12, h: 1, rustD)
        // Flank rivets.
        fill(cg, x: 6, y: 21 + bob, w: 1, h: 1, hazard)
        fill(cg, x: 6, y: 24 + bob, w: 1, h: 1, hazard)
        fill(cg, x: 23, y: 21 + bob, w: 1, h: 1, hazard)
        fill(cg, x: 23, y: 24 + bob, w: 1, h: 1, hazard)
        // Collar hazard band + ribs so the upper chest never sits flat.
        fill(cg, x: 9, y: 20 + bob, w: 12, h: 1, hazard)
        fill(cg, x: 11, y: 21 + bob, w: 1, h: 3, rustD)
        fill(cg, x: 20, y: 22 + bob, w: 1, h: 1, hazard)
        // Gauge cluster: bright live dial (dark read as a hollow).
        fill(cg, x: 12, y: 21 + bob, w: 6, h: 4, O)
        fill(cg, x: 13, y: 22 + bob, w: 4, h: 2, lens)
        fill(cg, x: 13, y: 22 + bob, w: 2, h: 1, white)
        fill(cg, x: 19, y: 21 + bob, w: 1, h: 2, hazard)
        fill(cg, x: 10, y: 24 + bob, w: 3, h: 2, hazard)
        fill(cg, x: 10, y: 24 + bob, w: 3, h: 1, white.withAlphaComponent(0.5))
        fill(cg, x: 18, y: 24 + bob, w: 3, h: 2, hazard)
        // Thick hazard belt + demolition stump legs.
        fill(cg, x: 5, y: 28 + bob, w: 20, h: 2, suitD)
        fill(cg, x: 6, y: 28 + bob, w: 2, h: 2, hazard)
        fill(cg, x: 10, y: 28 + bob, w: 2, h: 2, hazard)
        fill(cg, x: 14, y: 28 + bob, w: 2, h: 2, hazard)
        fill(cg, x: 18, y: 28 + bob, w: 2, h: 2, hazard)
        fill(cg, x: 22, y: 28 + bob, w: 2, h: 2, hazard)
        marchLegs(cg, step: step, cx: 14, top: 30 + bob, len: 6, main: suit,
                  shade: suitD, pad: rust, boot: suitD, sole: hazard, wide: true)
    }

    // MARK: - Spectre (RIG engineer: spine health bar, slit visor)

    private static func spectre(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let metal = UIColor(red: 0.36, green: 0.34, blue: 0.31, alpha: 1)
        let metalD = UIColor(red: 0.20, green: 0.19, blue: 0.18, alpha: 1)
        let bronze = UIColor(red: 0.66, green: 0.43, blue: 0.22, alpha: 1)
        let rig = UIColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 1)
        let visor = UIColor(red: 1.0, green: 0.65, blue: 0.20, alpha: 1)
        let O = outline
        // Helm + the iconic horizontal visor slit.
        fill(cg, x: 10, y: 2 + bob, w: 11, h: 9, O)
        fill(cg, x: 11, y: 3 + bob, w: 9, h: 7, metal)
        fill(cg, x: 11, y: 3 + bob, w: 2, h: 7, metalD)
        fill(cg, x: 11, y: 9 + bob, w: 9, h: 1, metalD)
        fill(cg, x: 14, y: 5 + bob, w: 6, h: blink ? 1 : 3, O)
        if !blink {
            fill(cg, x: 15, y: 6 + bob, w: 4, h: 1, visor)
        }
        fill(cg, x: 15, y: 3 + bob, w: 2, h: 1, bronze) // helm crest
        // Collar seal.
        fill(cg, x: 13, y: 11 + bob, w: 6, h: 2, metalD)
        fill(cg, x: 14, y: 11 + bob, w: 1, h: 2, rig)
        // Pauldrons with bronze trim + shoulder lamp.
        fill(cg, x: 5, y: 12 + bob, w: 7, h: 6, O)
        fill(cg, x: 6, y: 13 + bob, w: 5, h: 4, metal)
        fill(cg, x: 6, y: 13 + bob, w: 5, h: 1, bronze)
        fill(cg, x: 19, y: 12 + bob, w: 7, h: 6, O)
        fill(cg, x: 20, y: 13 + bob, w: 5, h: 4, metal)
        fill(cg, x: 20, y: 13 + bob, w: 5, h: 1, bronze)
        fill(cg, x: 23, y: 14 + bob, w: 2, h: 2, white) // lamp
        // Upper chest: solid armor from collar to gut (no hollow), with
        // a bronze yoke line and a RIG seal at the throat.
        fill(cg, x: 10, y: 13 + bob, w: 11, h: 5, O)
        fill(cg, x: 11, y: 14 + bob, w: 9, h: 3, metal)
        fill(cg, x: 11, y: 14 + bob, w: 9, h: 1, bronze)
        fill(cg, x: 11, y: 14 + bob, w: 1, h: 3, metalD)
        fill(cg, x: 14, y: 15 + bob, w: 3, h: 1, rig)
        fill(cg, x: 14, y: 15 + bob, w: 1, h: 1, white)
        // Spine health bar hugging the ribs: dark slot tight to the torso
        // with four glowing segments, clear of the pauldron above.
        fill(cg, x: 8, y: 18 + bob, w: 2, h: 8, metalD)
        for i in 0..<4 {
            fill(cg, x: 8, y: 18 + bob + i * 2, w: 2, h: 1, rig)
        }
        fill(cg, x: 8, y: 18 + bob, w: 2, h: 1, white) // top segment hot
        // Segmented engineering torso + bronze edges + chest projector.
        fill(cg, x: 10, y: 18 + bob, w: 11, h: 9, O)
        fill(cg, x: 11, y: 19 + bob, w: 9, h: 7, metal)
        fill(cg, x: 11, y: 19 + bob, w: 1, h: 7, metalD)
        fill(cg, x: 19, y: 19 + bob, w: 1, h: 7, bronze)
        fill(cg, x: 12, y: 20 + bob, w: 7, h: 1, metalD)
        fill(cg, x: 12, y: 21 + bob, w: 7, h: 1, bronze)
        fill(cg, x: 12, y: 24 + bob, w: 7, h: 1, metalD)
        fill(cg, x: 12, y: 25 + bob, w: 1, h: 1, bronze)
        fill(cg, x: 18, y: 25 + bob, w: 1, h: 1, bronze)
        fill(cg, x: 14, y: 20 + bob, w: 2, h: 2, O)
        fill(cg, x: 14, y: 20 + bob, w: 2, h: 1, rig) // projector
        // Belt + heavy armored legs.
        fill(cg, x: 10, y: 27 + bob, w: 11, h: 2, metalD)
        fill(cg, x: 14, y: 27 + bob, w: 3, h: 2, bronze)
        marchLegs(cg, step: step, cx: 14, top: 29 + bob, len: 6, main: metal,
                  shade: metalD, pad: bronze, boot: metalD, sole: bronze, wide: true)
    }

    // MARK: - Inferno (pyro veteran: furnace visor, pilot tank, fuel hose)

    private static func inferno(_ cg: CGContext, bob: Int, blink: Bool, step: Int) {
        let rust = UIColor(red: 0.62, green: 0.30, blue: 0.12, alpha: 1)
        let rustD = UIColor(red: 0.36, green: 0.17, blue: 0.07, alpha: 1)
        let soot = UIColor(red: 0.12, green: 0.10, blue: 0.10, alpha: 1)
        let flame = UIColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 1)
        let core = UIColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 1)
        let O = outline
        // Fuel tank with a live pilot flame.
        fill(cg, x: 4, y: 13 + bob, w: 5, h: 11, O)
        fill(cg, x: 5, y: 14 + bob, w: 3, h: 9, rustD)
        fill(cg, x: 5, y: 16 + bob, w: 3, h: 4, flame)
        fill(cg, x: 6, y: 17 + bob, w: 1, h: 2, core)
        fill(cg, x: 5, y: 11 + bob, w: 2, h: 3, flame)
        fill(cg, x: 5, y: 11 + bob, w: 1, h: 1, core)
        // Fuel hose looping tank -> torso.
        segment(cg, x0: 8, y0: 22 + bob, x1: 11, y1: 20 + bob, w: 2, color: soot)
        // Scorched helm + furnace visor slit.
        fill(cg, x: 10, y: 2 + bob, w: 12, h: 9, O)
        fill(cg, x: 11, y: 3 + bob, w: 10, h: 7, rust)
        fill(cg, x: 11, y: 3 + bob, w: 3, h: 7, rustD)
        fill(cg, x: 11, y: 9 + bob, w: 10, h: 1, soot)
        fill(cg, x: 14, y: 5 + bob, w: 7, h: blink ? 1 : 3, O)
        if !blink {
            fill(cg, x: 15, y: 5 + bob, w: 5, h: 2, flame)
            fill(cg, x: 15, y: 5 + bob, w: 5, h: 1, core)
        }
        // Heat-vent collar.
        fill(cg, x: 12, y: 11 + bob, w: 8, h: 2, soot)
        fill(cg, x: 13, y: 11 + bob, w: 1, h: 2, flame)
        fill(cg, x: 16, y: 11 + bob, w: 1, h: 2, flame)
        // Soot-stained torso + pressure gauge.
        fill(cg, x: 10, y: 13 + bob, w: 11, h: 11, O)
        fill(cg, x: 11, y: 14 + bob, w: 9, h: 9, rust)
        fill(cg, x: 11, y: 20 + bob, w: 9, h: 3, soot)
        fill(cg, x: 15, y: 15 + bob, w: 4, h: 4, O)
        fill(cg, x: 16, y: 16 + bob, w: 2, h: 2, core)
        fill(cg, x: 16, y: 16 + bob, w: 2, h: 1, white)
        // Belt + stomp legs with ember soles.
        fill(cg, x: 10, y: 24 + bob, w: 11, h: 2, soot)
        fill(cg, x: 14, y: 24 + bob, w: 3, h: 2, rustD)
        marchLegs(cg, step: step, cx: 14, top: 26 + bob, len: 6, main: rustD,
                  shade: soot, pad: rust, boot: soot, sole: flame)
    }
}
