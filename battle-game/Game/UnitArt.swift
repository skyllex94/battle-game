import SpriteKit
import UIKit

/// Pixel-art unit sprites in the tower/HQ style (low-res textures,
/// `.nearest` filtering). Side view, facing +x; the scene mirrors them
/// via negative xScale for left-facing marchers.
///
/// Each unit has 2 walk frames (leg poses) + the nodes swap them while
/// advancing for a scuttling march cycle.
enum UnitPixelArt {

    enum Kind { case trooper, heavy, ranger, truck, bombard, tank, enemy, brute, reaver, skitter, jet, mech, heli, missileTruck, immortal }

    /// Walk frames for a kind: full 4-step stride
    /// (contact -> support -> toe-off -> swing). Generated once, shared.
    /// (Truck frames roll the wheels instead of stepping.)
    static func frames(for kind: Kind) -> [SKTexture] {
        if let cached = frameCache[kind] { return cached }
        let made: [SKTexture]
        switch kind {
        case .trooper: made = (0...3).map { trooper(pose: $0) }
        case .heavy: made = (0...3).map { heavy(pose: $0) }
        case .ranger: made = (0...3).map { ranger(pose: $0) }
        case .truck: made = (0...3).map { truck(pose: $0) }
        case .bombard: made = (0...3).map { bombard(pose: $0) }
        case .tank: made = (0...3).map { tank(pose: $0) }
        case .enemy: made = (0...3).map { enemy(pose: $0) }
        case .brute: made = (0...3).map { brute(pose: $0) }
        case .reaver: made = (0...3).map { reaver(pose: $0) }
        case .skitter: made = (0...3).map { skitter(pose: $0) }
        case .jet: made = (0...3).map { jet(pose: $0) }
        case .mech:
            let body = mechBody()
            made = [body, body, body, body]
        case .heli: made = (0...3).map { heli(pose: $0) }
        case .missileTruck: made = (0...3).map { missileTruck(pose: $0) }
        case .immortal: made = (0...3).map { immortal(pose: $0) }
        }
        frameCache[kind] = made
        return made
    }

    /// Mech torso + leg textures (the mech animates its legs separately
    /// from its body — see EnemyNode's mech visuals).
    static func mechBodyTexture() -> SKTexture { mechBody() }
    static func mechLegTexture(front: Bool, phase: Int) -> SKTexture {
        mechLeg(front: front, phase: phase)
    }

    // MARK: - Canvas

    private static let W = 24, H = 32

    private static func canvas(w: Int = W, h: Int = H, key: String? = nil,
                               draw: (CGContext) -> Void) -> SKTexture {
        if let key, let cached = textureCache[key] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h),
                                           format: format).image { ctx in
            draw(ctx.cgContext) // UIKit coords: row 0 = top
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        if let key {
            imageCache[key] = img
            textureCache[key] = tex
        }
        return tex
    }

    /// Raw pixel images behind the cached textures (for SwiftUI portraits).
    private static var imageCache: [String: UIImage] = [:]
    /// Textures are immutable, so every named canvas is generated once.
    private static var textureCache: [String: SKTexture] = [:]
    /// Walk cycles are shared by every unit of a kind.
    private static var frameCache: [Kind: [SKTexture]] = [:]
    /// Composed card portraits, built once per kind.
    private static var portraitCache: [Kind: UIImage] = [:]

    /// Card portrait: torso-up crop of the real sprite + its gun-arm raised
    /// at a heroic angle, gun breaking out of frame. 36x24 px — show it
    /// with `.interpolation(.none)` so pixels stay crisp when upscaled.
    static func portraitImage(for kind: Kind) -> UIImage {
        if let cached = portraitCache[kind] { return cached }
        // Gun-truck portrait: full wide body + raised turret (custom
        // compose — the truck canvas is wider than the trooper crop).
        if kind == .truck {
            _ = frames(for: kind)
            _ = armTexture(for: kind)
            guard let body = imageCache["body-truck-0"],
                  let arm = imageCache["arm-truck-v2"] else { return UIImage() }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let portrait = UIGraphicsImageRenderer(size: CGSize(width: 36, height: 24),
                                                   format: format).image { ctx in
                let cg = ctx.cgContext
                body.draw(in: CGRect(x: 0, y: 0, width: 36, height: 24))
                cg.saveGState()
                cg.translateBy(x: 18, y: 10)
                cg.rotate(by: -0.30)
                arm.draw(in: CGRect(x: -5, y: -6, width: 24, height: 12))
                cg.restoreGState()
            }
            portraitCache[kind] = portrait
            return portrait
        }
        // Bombard portrait: whole mortar carrier with the launcher tube
        // raised high for the Level 11 debut card.
        if kind == .bombard {
            _ = frames(for: kind)
            _ = armTexture(for: kind)
            guard let body = imageCache["body-bombard-0"],
                  let arm = imageCache["arm-bombard-v1"] else { return UIImage() }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let portrait = UIGraphicsImageRenderer(size: CGSize(width: 36, height: 24),
                                                   format: format).image { ctx in
                let cg = ctx.cgContext
                body.draw(in: CGRect(x: 0, y: 0, width: 36, height: 24))
                cg.saveGState()
                cg.translateBy(x: 18, y: 11)
                cg.rotate(by: -0.85)
                arm.draw(in: CGRect(x: -5, y: -6, width: 24, height: 12))
                cg.restoreGState()
            }
            portraitCache[kind] = portrait
            return portrait
        }
        // Tank portrait: the whole tracked chassis with the turret cannon
        // level and forward — the straight-flying missile shooter.
        if kind == .tank {
            _ = frames(for: kind)
            _ = armTexture(for: kind)
            guard let body = imageCache["body-tank-0"],
                  let arm = imageCache["arm-tank-v1"] else { return UIImage() }
            let m = armMetrics(for: kind)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let portrait = UIGraphicsImageRenderer(size: CGSize(width: 36, height: 24),
                                                   format: format).image { ctx in
                let cg = ctx.cgContext
                let s: CGFloat = 0.62
                let bw = 48 * s, bh = 32 * s
                let x0 = (36 - bw) / 2, y0 = (24 - bh) / 2
                body.draw(in: CGRect(x: x0, y: y0, width: bw, height: bh))
                // Cannon pivots on the turret grip.
                cg.saveGState()
                cg.translateBy(x: x0 + 20 * s, y: y0 + 8.5 * s)
                cg.rotate(by: -0.12)
                let aw = CGFloat(m.w) * s, ah = CGFloat(m.h) * s
                arm.draw(in: CGRect(x: -aw * 0.2, y: -ah / 2, width: aw, height: ah))
                cg.restoreGState()
            }
            portraitCache[kind] = portrait
            return portrait
        }
        // Mech portrait: the walker is taller + wider than the 24x32
        // trooper crop, so show the whole machine (scaled to fit) with
        // its gatling arm raised over the shoulder.
        if kind == .mech {
            _ = frames(for: kind)
            _ = armTexture(for: kind)
            // Legs live outside the body frames; generate the two pose
            // textures the portrait composes so the library isn't blank on
            // first view (before any walker has spawned).
            _ = mechLeg(front: true, phase: 1)
            _ = mechLeg(front: false, phase: 3)
            guard let body = imageCache["body-mech-v5"],
                  let arm = imageCache["arm-mech-v3"],
                  let legF = imageCache["mech-leg-f-1"],
                  let legB = imageCache["mech-leg-b-3"] else { return UIImage() }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let portrait = UIGraphicsImageRenderer(size: CGSize(width: 36, height: 24),
                                                   format: format).image { ctx in
                let cg = ctx.cgContext
                // Whole walker: two legs under the torso, aspect kept.
                let s: CGFloat = min(36.0 / 48.0, 24.0 / 46.0)
                let bw = 48 * s, bh = 26 * s, lw = 16 * s, lh = 20 * s
                let x0 = (36 - bw) / 2
                // Back leg (behind the body), then the body, then the front leg.
                legB.draw(in: CGRect(x: x0 + bw * 0.30, y: bh, width: lw, height: lh))
                body.draw(in: CGRect(x: x0, y: 0, width: bw, height: bh))
                legF.draw(in: CGRect(x: x0 + bw * 0.52, y: bh, width: lw, height: lh))
                cg.saveGState()
                cg.translateBy(x: 20, y: 8)
                cg.rotate(by: -0.20)
                arm.draw(in: CGRect(x: -3, y: -4, width: 18, height: 9))
                cg.restoreGState()
            }
            portraitCache[kind] = portrait
            return portrait
        }
        // Heli Gunship portrait: the whole aircraft, rotor included, with
        // the chin gun angled forward under the nose.
        if kind == .heli {
            _ = frames(for: kind)
            _ = armTexture(for: kind)
            guard let body = imageCache["body-heli-0"],
                  let arm = imageCache["arm-heli"] else { return UIImage() }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let portrait = UIGraphicsImageRenderer(size: CGSize(width: 36, height: 24),
                                                   format: format).image { ctx in
                let cg = ctx.cgContext
                let s: CGFloat = min(36.0 / 64.0, 24.0 / 36.0)
                let bw = 64 * s, bh = 36 * s
                let x0 = (36 - bw) / 2, y0 = (24 - bh) / 2
                body.draw(in: CGRect(x: x0, y: y0, width: bw, height: bh))
                cg.saveGState()
                cg.translateBy(x: x0 + 43 * s, y: y0 + 29 * s)
                cg.rotate(by: -0.16)
                arm.draw(in: CGRect(x: -2, y: -2, width: 12, height: 6))
                cg.restoreGState()
            }
            portraitCache[kind] = portrait
            return portrait
        }
        // Missile truck portrait: the whole chassis with the launcher rail
        // raised out of the cradle in the module's nose.
        if kind == .missileTruck {
            _ = frames(for: kind)
            _ = armTexture(for: kind)
            guard let body = imageCache["body-missile-truck-0"],
                  let arm = imageCache["arm-missile-truck"] else { return UIImage() }
            let m = armMetrics(for: kind)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let portrait = UIGraphicsImageRenderer(size: CGSize(width: 36, height: 24),
                                                   format: format).image { ctx in
                let cg = ctx.cgContext
                // Body is 64x40 px: shrink it a touch so the raised rail
                // still fits inside the card.
                let s: CGFloat = 0.42
                let bw = 64 * s, bh = 40 * s
                let x0: CGFloat = 2, y0: CGFloat = 4
                body.draw(in: CGRect(x: x0, y: y0, width: bw, height: bh))
                // Rail pivots on the hot cradle in the launcher's nose.
                cg.saveGState()
                cg.translateBy(x: x0 + 59 * s, y: y0 + 10.5 * s)
                cg.rotate(by: -0.6)
                let aw = CGFloat(m.w) * s, ah = CGFloat(m.h) * s
                arm.draw(in: CGRect(x: -aw * 0.24, y: -ah / 2, width: aw, height: ah))
                cg.restoreGState()
            }
            portraitCache[kind] = portrait
            return portrait
        }
        // Immortal portrait: the whole walker scaled to fit the card with
        // the twin-disruptor turret raised off the shoulder hump.
        if kind == .immortal {
            _ = frames(for: kind)
            _ = armTexture(for: kind)
            guard let body = imageCache["body-immortal-0"],
                  let arm = imageCache["arm-immortal"] else { return UIImage() }
            let m = armMetrics(for: kind)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let portrait = UIGraphicsImageRenderer(size: CGSize(width: 36, height: 24),
                                                   format: format).image { ctx in
                let cg = ctx.cgContext
                // Body canvas is 40x36: shrink so the raised cannon fits.
                let s: CGFloat = 0.55
                let bw = 40 * s, bh = 36 * s
                let x0 = (36 - bw) / 2, y0 = (24 - bh) / 2
                body.draw(in: CGRect(x: x0, y: y0, width: bw, height: bh))
                // Cannon pivots on the shoulder joint, breaking the frame.
                cg.saveGState()
                cg.translateBy(x: x0 + 19 * s, y: y0 + 7 * s)
                cg.rotate(by: -0.5)
                let aw = CGFloat(m.w) * s, ah = CGFloat(m.h) * s
                arm.draw(in: CGRect(x: -aw * 0.15, y: -ah / 2, width: aw, height: ah))
                cg.restoreGState()
            }
            portraitCache[kind] = portrait
            return portrait
        }
        let bodyKey: String
        let armKey: String
        let shoulder: CGPoint // grip point in portrait px
        switch kind {
        case .trooper:
            bodyKey = "body-trooper-0"; armKey = "arm-trooper"
            shoulder = CGPoint(x: 16, y: 14)
        case .heavy:
            bodyKey = "body-heavy-0"; armKey = "arm-heavy"
            shoulder = CGPoint(x: 16, y: 15)
        case .ranger:
            bodyKey = "body-ranger-0"; armKey = "arm-ranger"
            shoulder = CGPoint(x: 16, y: 14)
        case .truck:
            bodyKey = "body-truck-0"; armKey = "arm-truck-v2"
            shoulder = CGPoint(x: 16, y: 14)
        case .bombard:
            bodyKey = "body-bombard-0"; armKey = "arm-bombard-v1"
            shoulder = CGPoint(x: 16, y: 12)
        case .tank:
            bodyKey = "body-tank-0"; armKey = "arm-tank-v1"
            shoulder = CGPoint(x: 16, y: 14)
        case .enemy:
            bodyKey = "body-enemy-0"; armKey = "arm-enemy"
            shoulder = CGPoint(x: 16, y: 14)
        case .brute:
            bodyKey = "body-brute-0"; armKey = "arm-brute"
            shoulder = CGPoint(x: 16, y: 15)
        case .reaver:
            bodyKey = "body-reaver-0"; armKey = "arm-reaver"
            shoulder = CGPoint(x: 16, y: 14)
        case .skitter:
            bodyKey = "body-skitter-0"; armKey = "arm-skitter"
            shoulder = CGPoint(x: 16, y: 16)
        case .jet:
            bodyKey = "body-jet-0"; armKey = "arm-jet"
            shoulder = CGPoint(x: 14, y: 15)
        case .mech:
            bodyKey = "body-mech-v5"; armKey = "arm-mech-v3"
            shoulder = CGPoint(x: 14, y: 15)
        case .heli:
            bodyKey = "body-heli-0"; armKey = "arm-heli"
            shoulder = CGPoint(x: 14, y: 15)
        case .missileTruck:
            bodyKey = "body-missile-truck-0"; armKey = "arm-missile-truck"
            shoulder = CGPoint(x: 10, y: 8)
        case .immortal:
            bodyKey = "body-immortal-0"; armKey = "arm-immortal"
            shoulder = CGPoint(x: 20, y: 11)
        }
        // Warm the cache (no-ops once textures exist).
        _ = frames(for: kind)
        _ = armTexture(for: kind)
        guard let body = imageCache[bodyKey], let arm = imageCache[armKey] else {
            return UIImage()
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let portrait = UIGraphicsImageRenderer(size: CGSize(width: 36, height: 24),
                                               format: format).image { ctx in
            let cg = ctx.cgContext
            // Torso-up crop: full width, rows 1...18 (head through belt).
            // Renderer scale is 1, so points == pixels for the crop.
            // NOTE: draw via UIImage (not raw CGImage) so UIKit orientation
            // is honoured — CGImage draws upside-down here.
            let crop = CGRect(x: 0, y: 1, width: 24, height: 18)
            if let bust = body.cgImage?.cropping(to: crop) {
                UIImage(cgImage: bust, scale: 1, orientation: .up)
                    .draw(in: CGRect(x: 2, y: 4, width: 24, height: 18))
            }
            // Gun-arm raised high, pivoting on the shoulder grip.
            cg.saveGState()
            cg.translateBy(x: shoulder.x, y: shoulder.y)
            cg.rotate(by: -0.32)
            arm.draw(in: CGRect(x: -5, y: -6, width: 24, height: 12))
            cg.restoreGState()
        }
        portraitCache[kind] = portrait
        return portrait
    }

    private static func fill(_ cg: CGContext, x: Int, y: Int, w: Int, h: Int,
                             _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    // Shared inks.
    private static let outline = UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
    private static let dark = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)
    private static let gunMetal = UIColor(red: 0.18, green: 0.19, blue: 0.24, alpha: 1)

    // MARK: - Player trooper (blue scout)

    private static func trooper(pose: Int) -> SKTexture {
        canvas(key: "body-trooper-\(pose)") { cg in
            let armor = UIColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)
            let armorD = UIColor(red: 0.15, green: 0.30, blue: 0.65, alpha: 1)
            let suit = UIColor(red: 0.20, green: 0.28, blue: 0.45, alpha: 1)
            let visor = UIColor(red: 0.55, green: 0.95, blue: 1.0, alpha: 1)
            let O = outline

            // Backpack + antenna.
            fill(cg, x: 6, y: 9, w: 3, h: 6, O)
            fill(cg, x: 7, y: 10, w: 1, h: 4, suit)
            fill(cg, x: 7, y: 5, w: 1, h: 4, O)
            fill(cg, x: 7, y: 4, w: 1, h: 1, visor)
            // Helmet dome.
            fill(cg, x: 9, y: 2, w: 8, h: 6, O)
            fill(cg, x: 10, y: 3, w: 6, h: 4, .white)
            fill(cg, x: 10, y: 3, w: 6, h: 1, UIColor(white: 1, alpha: 1))
            // Visor slit (faces +x).
            fill(cg, x: 13, y: 4, w: 4, h: 3, O)
            fill(cg, x: 14, y: 5, w: 2, h: 1, visor)
            // Neck + torso armor.
            fill(cg, x: 10, y: 8, w: 5, h: 9, O)
            fill(cg, x: 11, y: 9, w: 3, h: 7, armor)
            fill(cg, x: 11, y: 9, w: 1, h: 7, .white.withAlphaComponent(0.4))
            fill(cg, x: 13, y: 9, w: 1, h: 7, armorD)
            // Chest light.
            fill(cg, x: 12, y: 11, w: 2, h: 2, O)
            fill(cg, x: 12, y: 11, w: 2, h: 1, visor)
            // Belt.
            fill(cg, x: 10, y: 16, w: 5, h: 2, O)
            fill(cg, x: 11, y: 16, w: 3, h: 1, armorD)
            // Firing hand at the chest — the aimable gun-arm mounts here.
            fill(cg, x: 14, y: 11, w: 3, h: 3, suit) // hand
            // Legs (4-frame stride).
            legs(cg, frame: pose, cx: 12, top: 18, len: 9,
                 pants: suit, shade: armorD, boot: dark, outline: O)
        }
    }

    // MARK: - Player heavy (bulky gunner)

    private static func heavy(pose: Int) -> SKTexture {
        canvas(key: "body-heavy-\(pose)") { cg in
            let armor = UIColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)
            let armorD = UIColor(red: 0.13, green: 0.26, blue: 0.55, alpha: 1)
            let suit = UIColor(red: 0.18, green: 0.25, blue: 0.42, alpha: 1)
            let visor = UIColor(red: 0.55, green: 0.95, blue: 1.0, alpha: 1)
            let O = outline

            // Heavy backpack block.
            fill(cg, x: 4, y: 8, w: 4, h: 8, O)
            fill(cg, x: 5, y: 9, w: 2, h: 6, suit)
            fill(cg, x: 5, y: 4, w: 1, h: 4, O)
            // Helm (wider, slit visor).
            fill(cg, x: 8, y: 2, w: 9, h: 6, O)
            fill(cg, x: 9, y: 3, w: 7, h: 4, .white)
            fill(cg, x: 12, y: 4, w: 5, h: 3, O)
            fill(cg, x: 13, y: 5, w: 3, h: 1, visor)
            // Shoulder pad.
            fill(cg, x: 8, y: 8, w: 9, h: 3, O)
            fill(cg, x: 9, y: 8, w: 7, h: 2, armor)
            fill(cg, x: 9, y: 8, w: 7, h: 1, .white.withAlphaComponent(0.4))
            // Barrel chest.
            fill(cg, x: 8, y: 11, w: 8, h: 7, O)
            fill(cg, x: 9, y: 12, w: 6, h: 5, armor)
            fill(cg, x: 9, y: 12, w: 2, h: 5, armorD)
            fill(cg, x: 14, y: 12, w: 1, h: 5, .white.withAlphaComponent(0.35))
            // Chest plate + core.
            fill(cg, x: 10, y: 13, w: 4, h: 3, armorD)
            fill(cg, x: 11, y: 13, w: 2, h: 1, visor)
            // Belt.
            fill(cg, x: 8, y: 18, w: 8, h: 2, O)
            // Firing hand at the chest — the aimable gun-arm mounts here.
            fill(cg, x: 14, y: 12, w: 3, h: 4, suit) // hand
            // Thick legs.
            legs(cg, frame: pose, cx: 12, top: 20, len: 8,
                 pants: suit, shade: armorD, boot: dark, outline: O, wide: true)
        }
    }

    // MARK: - Player ranger (lean long-rifle scout)

    private static func ranger(pose: Int) -> SKTexture {
        canvas(key: "body-ranger-\(pose)") { cg in
            let armor = UIColor(red: 0.35, green: 0.62, blue: 0.38, alpha: 1)
            let armorD = UIColor(red: 0.18, green: 0.36, blue: 0.22, alpha: 1)
            let suit = UIColor(red: 0.22, green: 0.28, blue: 0.26, alpha: 1)
            let visor = UIColor(red: 1.0, green: 0.80, blue: 0.35, alpha: 1)
            let O = outline

            // Hood + antenna nub.
            fill(cg, x: 9, y: 1, w: 8, h: 7, O)
            fill(cg, x: 10, y: 2, w: 6, h: 5, armor)
            fill(cg, x: 10, y: 2, w: 6, h: 1, .white.withAlphaComponent(0.35))
            // Visor slit (faces +x), amber marksman lens.
            fill(cg, x: 13, y: 4, w: 4, h: 2, O)
            fill(cg, x: 14, y: 4, w: 2, h: 2, visor)
            // Neck + light torso armor.
            fill(cg, x: 10, y: 8, w: 5, h: 8, O)
            fill(cg, x: 11, y: 9, w: 3, h: 6, armor)
            fill(cg, x: 11, y: 9, w: 1, h: 6, .white.withAlphaComponent(0.4))
            fill(cg, x: 13, y: 9, w: 1, h: 6, armorD)
            // Rangefinder chest pip.
            fill(cg, x: 12, y: 11, w: 2, h: 2, O)
            fill(cg, x: 12, y: 11, w: 2, h: 1, visor)
            // Belt + cloak tail fluttering behind (-x).
            fill(cg, x: 10, y: 16, w: 5, h: 2, O)
            fill(cg, x: 6, y: 12, w: 3, h: 6, armorD)
            // Firing hand at the chest — the aimable gun-arm mounts here.
            fill(cg, x: 14, y: 11, w: 3, h: 3, suit) // hand
            // Lean runner legs (4-frame stride).
            legs(cg, frame: pose, cx: 12, top: 18, len: 9,
                 pants: suit, shade: armorD, boot: dark, outline: O)
        }
    }

        // MARK: - Player Vuran (olive gun-truck, reference build)

    /// Large 48x32 canvas (dwarfs the 24x32 troopers, as armor should).
    /// Faithful to the model: olive-drab box hull with a bright khaki top
    /// strip and a bright cream lower trim, dark slit windows, the
    /// staircase bleach-diagonal sweeping down to the nose, an angled
    /// windshield + long nose at the front, black undercarriage, FOUR
    /// triple-ring wheels (tire / rim / gold hub) with rotating spokes,
    /// and a roof turret on a neck whose long thin cannon rotates to aim.
    /// Faces +x.
    private static func truck(pose: Int) -> SKTexture {
        canvas(w: 48, h: 32, key: "body-truck-\(pose)") { cg in
            // Palette sampled off the model.
            let body = UIColor(red: 0.42, green: 0.42, blue: 0.28, alpha: 1)
            let topLit = UIColor(red: 0.66, green: 0.66, blue: 0.47, alpha: 1)
            let trim = UIColor(red: 0.74, green: 0.72, blue: 0.52, alpha: 1)
            let shade = UIColor(red: 0.28, green: 0.28, blue: 0.17, alpha: 1)
            let camoD = UIColor(red: 0.25, green: 0.26, blue: 0.16, alpha: 1)
            let glass = UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1)
            let under = UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
            let tire = UIColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 1)
            let rim = UIColor(red: 0.40, green: 0.44, blue: 0.50, alpha: 1)
            let rimLit = UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
            let hub = UIColor(red: 0.80, green: 0.72, blue: 0.44, alpha: 1)
            let hubD = UIColor(red: 0.55, green: 0.48, blue: 0.26, alpha: 1)
            let lamp = UIColor(red: 1.0, green: 0.93, blue: 0.70, alpha: 1)
            let foot = UIColor(red: 0.38, green: 0.30, blue: 0.20, alpha: 1)
            let O = outline
            let y = [0, 0, 1, 0][pose] // suspension bounce

            // --- Hull: outline, body, bright top strip, bright lower trim.
            fill(cg, x: 1, y: 9 + y, w: 37, h: 12, O)
            fill(cg, x: 2, y: 10 + y, w: 35, h: 10, body)
            fill(cg, x: 2, y: 10 + y, w: 35, h: 2, topLit)      // khaki top strip
            fill(cg, x: 2, y: 19 + y, w: 35, h: 1, trim)        // cream lower trim
            // Dark camo flecks along the flank.
            fill(cg, x: 5, y: 16 + y, w: 3, h: 1, camoD)
            fill(cg, x: 11, y: 17 + y, w: 4, h: 1, camoD)
            fill(cg, x: 19, y: 16 + y, w: 3, h: 1, camoD)
            fill(cg, x: 27, y: 17 + y, w: 4, h: 1, camoD)
            fill(cg, x: 8, y: 18 + y, w: 2, h: 1, camoD)

            // --- Slit windows: khaki frame + near-black glass, 3 in the
            // main hull (the front cluster lives on the cab below).
            for wx in [5, 12, 19] {
                fill(cg, x: wx, y: 12 + y, w: 5, h: 3, shade)
                fill(cg, x: wx, y: 12 + y, w: 5, h: 1, O)
                fill(cg, x: wx + 1, y: 13 + y, w: 3, h: 1, glass)
            }

            // --- Staircase bleach-diagonal: steps down from the hull top
            // toward the nose, exactly like the model's sun-bleached wipe.
            fill(cg, x: 24, y: 10 + y, w: 2, h: 1, trim)
            fill(cg, x: 26, y: 11 + y, w: 2, h: 1, trim)
            fill(cg, x: 28, y: 12 + y, w: 2, h: 1, trim)
            fill(cg, x: 30, y: 13 + y, w: 2, h: 1, trim)
            fill(cg, x: 32, y: 14 + y, w: 2, h: 1, trim)
            fill(cg, x: 34, y: 15 + y, w: 2, h: 1, trim)
            fill(cg, x: 34, y: 16 + y, w: 2, h: 1, trim)

            // --- Front cab: shoulder step, angled windshield cluster,
            // nose block, and the dark skid under the chin.
            fill(cg, x: 38, y: 11 + y, w: 4, h: 9, O)            // shoulder
            fill(cg, x: 39, y: 12 + y, w: 2, h: 7, body)
            fill(cg, x: 39, y: 12 + y, w: 2, h: 1, topLit)
            // Angled windshield: two slanted dark panes stepping down.
            fill(cg, x: 40, y: 13 + y, w: 3, h: 2, glass)
            fill(cg, x: 41, y: 15 + y, w: 2, h: 2, glass)
            fill(cg, x: 39, y: 15 + y, w: 1, h: 1, shade)
            // Nose: long forward block with a lit top edge + headlight.
            fill(cg, x: 42, y: 14 + y, w: 5, h: 7, O)
            fill(cg, x: 43, y: 15 + y, w: 3, h: 5, body)
            fill(cg, x: 43, y: 15 + y, w: 3, h: 1, topLit)
            fill(cg, x: 45, y: 16 + y, w: 2, h: 2, O)            // lamp housing
            fill(cg, x: 46, y: 17 + y, w: 1, h: 1, lamp)
            fill(cg, x: 43, y: 18 + y, w: 3, h: 1, shade)         // lower nose
            // Chin skid: dark angled block under the front.
            fill(cg, x: 40, y: 20 + y, w: 8, h: 2, O)
            fill(cg, x: 41, y: 20 + y, w: 6, h: 1, under)

            // --- Rear taillight + black undercarriage skirt.
            fill(cg, x: 1, y: 17 + y, w: 2, h: 2, O)
            fill(cg, x: 1, y: 17 + y, w: 1, h: 1, lamp)
            fill(cg, x: 0, y: 20 + y, w: 48, h: 2, O)            // skirt band

            // --- FOUR wheels: tire / rim / gold hub, each with a lit arc
            // at the top-left and a rotating spoke cross in the rim.
            for wx in [7, 15, 24, 32] {
                fill(cg, x: wx - 4, y: 22 + y, w: 9, h: 9, O)
                fill(cg, x: wx - 3, y: 23 + y, w: 7, h: 7, tire)
                fill(cg, x: wx - 3, y: 23 + y, w: 3, h: 1, rimLit) // top arc
                fill(cg, x: wx - 2, y: 24 + y, w: 5, h: 5, rim)
                // Rotating spokes on the rim (4 phases, 45° steps).
                switch pose {
                case 0:
                    fill(cg, x: wx, y: 24 + y, w: 1, h: 5, tire)
                    fill(cg, x: wx - 2, y: 26 + y, w: 5, h: 1, tire)
                case 1:
                    fill(cg, x: wx + 1, y: 24 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx - 1, y: 26 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx - 2, y: 26 + y, w: 2, h: 1, tire)
                    fill(cg, x: wx + 1, y: 28 + y, w: 2, h: 1, tire)
                case 2:
                    fill(cg, x: wx - 2, y: 25 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx + 2, y: 25 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx - 2, y: 26 + y, w: 2, h: 1, tire)
                    fill(cg, x: wx + 1, y: 28 + y, w: 2, h: 1, tire)
                default:
                    fill(cg, x: wx - 1, y: 24 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx + 1, y: 26 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx - 2, y: 28 + y, w: 2, h: 1, tire)
                    fill(cg, x: wx + 1, y: 26 + y, w: 2, h: 1, tire)
                }
                // Gold square hub with a darker pin (model's bright centre).
                fill(cg, x: wx - 1, y: 26 + y, w: 3, h: 3, hub)
                fill(cg, x: wx - 1, y: 26 + y, w: 3, h: 1, rimLit)
                fill(cg, x: wx, y: 27 + y, w: 1, h: 1, hubD)
                // Track pad foot under each wheel.
                fill(cg, x: wx - 3, y: 31 + y, w: 7, h: 1, foot)
                fill(cg, x: wx - 2, y: 31 + y, w: 5, h: 1, hubD)
            }

            // --- Turret neck (pedestal) then the box turret.
            fill(cg, x: 15, y: 8 + y, w: 7, h: 2, O)
            fill(cg, x: 16, y: 8 + y, w: 5, h: 1, shade)
            fill(cg, x: 13, y: 1 + y, w: 11, h: 7, O)            // turret box
            fill(cg, x: 14, y: 2 + y, w: 9, h: 5, body)
            fill(cg, x: 14, y: 2 + y, w: 9, h: 2, topLit)        // lit top-left
            fill(cg, x: 14, y: 2 + y, w: 1, h: 5, shade)          // shade side
            fill(cg, x: 15, y: 4 + y, w: 3, h: 2, camoD)         // camo fleck
            fill(cg, x: 20, y: 3 + y, w: 2, h: 1, trim)
            fill(cg, x: 13, y: 1 + y, w: 11, h: 1, O)            // hatch seam
            fill(cg, x: 23, y: 3 + y, w: 2, h: 3, O)             // mantlet
            fill(cg, x: 24, y: 4 + y, w: 1, h: 1, shade)
            fill(cg, x: 25, y: 4 + y, w: 3, h: 2, O)             // barrel stub
            fill(cg, x: 26, y: 5 + y, w: 2, h: 1, shade)
        }
    }

    // MARK: - Enemy missile truck (Level 15 debut)

    /// Self-propelled missile launcher: the armored cab sits at the back,
    /// the tall launcher module rides the nose, and the big rail (the
    /// aimable arm) pivots out of the hot cradle in the module's face —
    /// so the turret always points the way the truck drives. Stowed rounds
    /// clip to the module's flank, a beacon rides its roof, and the chassis
    /// rides the suspension while the wheels stay planted on the deck.
    private static func missileTruck(pose: Int) -> SKTexture {
        canvas(w: 64, h: 40, key: "body-missile-truck-\(pose)") { cg in
            let hull = UIColor(red: 0.42, green: 0.13, blue: 0.16, alpha: 1)
            let hullLit = UIColor(red: 0.66, green: 0.25, blue: 0.23, alpha: 1)
            let hullDk = UIColor(red: 0.24, green: 0.07, blue: 0.10, alpha: 1)
            let plate = UIColor(red: 0.32, green: 0.10, blue: 0.13, alpha: 1)
            let trim = UIColor(red: 0.80, green: 0.34, blue: 0.20, alpha: 1)
            let warn = UIColor(red: 1.0, green: 0.72, blue: 0.16, alpha: 1)
            let steel = UIColor(red: 0.38, green: 0.40, blue: 0.46, alpha: 1)
            let steelLit = UIColor(red: 0.58, green: 0.60, blue: 0.66, alpha: 1)
            let glass = UIColor(red: 0.09, green: 0.07, blue: 0.10, alpha: 1)
            let glint = UIColor(red: 0.52, green: 0.78, blue: 0.88, alpha: 1)
            let under = UIColor(red: 0.05, green: 0.04, blue: 0.06, alpha: 1)
            let tire = UIColor(red: 0.11, green: 0.10, blue: 0.13, alpha: 1)
            let rim = UIColor(red: 0.30, green: 0.26, blue: 0.28, alpha: 1)
            let rimLit = UIColor(red: 0.54, green: 0.45, blue: 0.45, alpha: 1)
            let hub = UIColor(red: 0.88, green: 0.34, blue: 0.22, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.34, blue: 0.18, alpha: 1)
            let O = outline
            let y = [0, 0, 1, 0][pose] // chassis rides the suspension

            // --- TANK TRACKS: a continuous chain wraps the whole running
            // gear, with road wheels turning inside it. The chain links
            // crawl a pixel per frame phase, and the sprocket catches a
            // glint of light.
            let link = [0, 1, 2, 3][pose]
            // Track outline: a long middle run with rounded ends.
            fill(cg, x: 10, y: 25, w: 43, h: 15, O)
            fill(cg, x: 4, y: 28, w: 7, h: 10, O)
            fill(cg, x: 52, y: 28, w: 8, h: 10, O)
            // Track interior.
            fill(cg, x: 11, y: 26, w: 41, h: 13, tire)
            fill(cg, x: 5, y: 29, w: 6, h: 8, tire)
            fill(cg, x: 53, y: 29, w: 6, h: 8, tire)
            // Road wheels turning inside the chain.
            for rx in [18, 26, 34, 42] {
                fill(cg, x: rx - 3, y: 29, w: 7, h: 7, rim)
                fill(cg, x: rx - 3, y: 29, w: 3, h: 1, rimLit)
                fill(cg, x: rx - 1, y: 31, w: 3, h: 3, hub)
                fill(cg, x: rx - 1, y: 31, w: 3, h: 1, rimLit)
            }
            // Crawling chain links along the bottom run and around the
            // idler (rear) and sprocket (front).
            for i in 0..<11 {
                let lx = 12 + ((i * 4 + link) % 40)
                fill(cg, x: lx, y: 36, w: 2, h: 3, under)
            }
            for i in 0..<3 {
                let ly = 29 + ((i * 3 + link) % 7)
                fill(cg, x: 5, y: ly, w: 2, h: 2, under)
                fill(cg, x: 57, y: ly, w: 2, h: 2, under)
            }
            // Sprocket cap on the nose end.
            fill(cg, x: 55, y: 32, w: 3, h: 3, hub)
            fill(cg, x: 55, y: 32, w: 3, h: 1, rimLit)

            // --- Chassis: long armored hull, lit top deck, dark belly.
            fill(cg, x: 2, y: 16 + y, w: 60, h: 12, O)
            fill(cg, x: 3, y: 17 + y, w: 58, h: 10, hull)
            fill(cg, x: 3, y: 17 + y, w: 58, h: 2, hullLit)
            fill(cg, x: 3, y: 25 + y, w: 58, h: 2, hullDk)
            // Flank plating: ribs, warning chevrons, inspection hatch.
            for rx in [34, 44] {
                fill(cg, x: rx, y: 19 + y, w: 1, h: 6, hullDk)
            }
            fill(cg, x: 28, y: 21 + y, w: 3, h: 1, warn)
            fill(cg, x: 30, y: 22 + y, w: 3, h: 1, warn)
            fill(cg, x: 32, y: 23 + y, w: 3, h: 1, warn)
            fill(cg, x: 36, y: 20 + y, w: 6, h: 6, O)
            fill(cg, x: 37, y: 21 + y, w: 4, h: 4, plate)
            fill(cg, x: 38, y: 22 + y, w: 2, h: 2, rimLit)

            // --- Cab at the back: the crew sits behind the launcher and
            // looks forward over it. Rear glass, forward windshield, roof
            // cap, mirror and a stowed exhaust stack.
            fill(cg, x: 2, y: 8 + y, w: 26, h: 20, O)
            fill(cg, x: 3, y: 9 + y, w: 24, h: 18, hull)
            fill(cg, x: 3, y: 9 + y, w: 24, h: 2, hullLit)
            fill(cg, x: 26, y: 11 + y, w: 1, h: 15, hullDk)
            // Roof cap.
            fill(cg, x: 6, y: 5 + y, w: 16, h: 4, O)
            fill(cg, x: 7, y: 6 + y, w: 14, h: 1, hullLit)
            // Crew window at the back.
            fill(cg, x: 6, y: 12 + y, w: 5, h: 5, O)
            fill(cg, x: 7, y: 13 + y, w: 3, h: 3, glass)
            fill(cg, x: 7, y: 13 + y, w: 2, h: 1, glint)
            // Forward windshield, split by a pillar.
            fill(cg, x: 19, y: 11 + y, w: 7, h: 9, O)
            fill(cg, x: 20, y: 12 + y, w: 5, h: 7, glass)
            fill(cg, x: 20, y: 12 + y, w: 3, h: 1, glint)
            fill(cg, x: 22, y: 16 + y, w: 3, h: 3, glass)
            fill(cg, x: 20, y: 15 + y, w: 5, h: 1, hullDk)
            // Mirror arm.
            fill(cg, x: 17, y: 10 + y, w: 2, h: 1, O)
            fill(cg, x: 17, y: 11 + y, w: 2, h: 2, steel)
            // Exhaust stack at the very back, hot tip.
            fill(cg, x: 0, y: 7 + y, w: 4, h: 12, O)
            fill(cg, x: 1, y: 8 + y, w: 2, h: 10, steel)
            fill(cg, x: 1, y: 8 + y, w: 1, h: 3, steelLit)
            fill(cg, x: 0, y: 5 + y, w: 4, h: 3, O)
            fill(cg, x: 1, y: 6 + y, w: 2, h: 1, glow)
            // Rear bumper + tail lamp.
            fill(cg, x: 0, y: 22 + y, w: 3, h: 5, O)
            fill(cg, x: 0, y: 23 + y, w: 2, h: 3, steel)
            fill(cg, x: 0, y: 19 + y, w: 2, h: 2, O)
            fill(cg, x: 1, y: 20 + y, w: 1, h: 1, glow)

            // --- Deck cargo between the cab and the launcher: a strapped
            // ammo crate plus a spare can, so the hauler reads as a
            // working truck.
            fill(cg, x: 29, y: 10 + y, w: 8, h: 7, O)
            fill(cg, x: 30, y: 11 + y, w: 6, h: 5, steel)
            fill(cg, x: 30, y: 11 + y, w: 6, h: 1, steelLit)
            fill(cg, x: 30, y: 13 + y, w: 6, h: 1, warn)
            fill(cg, x: 34, y: 12 + y, w: 4, h: 5, O)
            fill(cg, x: 35, y: 13 + y, w: 2, h: 3, plate)

            // --- Launcher module at the nose: a tall armored box that
            // steps down into a narrow mantlet, so the launcher head sits
            // clear of the hull and the rail projects ahead of the body.
            // Stowed rounds clip to the flank, a hazard band runs along the
            // belly and a beacon rides the roof.
            fill(cg, x: 36, y: 1 + y, w: 22, h: 17, O)
            fill(cg, x: 37, y: 2 + y, w: 20, h: 15, hull)
            fill(cg, x: 37, y: 2 + y, w: 20, h: 2, hullLit)
            fill(cg, x: 37, y: 15 + y, w: 20, h: 1, hullDk)
            // Mantlet: the narrow nose block the rail fires out of.
            fill(cg, x: 56, y: 5 + y, w: 7, h: 11, O)
            fill(cg, x: 57, y: 6 + y, w: 5, h: 9, hull)
            fill(cg, x: 57, y: 6 + y, w: 5, h: 1, hullLit)
            fill(cg, x: 57, y: 14 + y, w: 5, h: 1, hullDk)
            // Hot cradle in the mantlet face.
            fill(cg, x: 58, y: 7 + y, w: 4, h: 7, O)
            fill(cg, x: 59, y: 8 + y, w: 2, h: 5, glow)
            // Stowed rounds: two slim missiles clipped to the flank, nose
            // cones forward, tail fins at the back.
            for ry in [4, 9] {
                fill(cg, x: 39, y: ry + y, w: 13, h: 4, O)
                fill(cg, x: 40, y: ry + 1 + y, w: 11, h: 2, steel)
                fill(cg, x: 45, y: ry + 1 + y, w: 1, h: 2, warn)
                fill(cg, x: 49, y: ry + 1 + y, w: 2, h: 2, glow)
                fill(cg, x: 39, y: ry + y, w: 2, h: 1, steelLit)
            }
            // Hazard band along the module's belly.
            for bx in Swift.stride(from: 37, to: 50, by: 3) {
                fill(cg, x: bx, y: 14 + y, w: 2, h: 2, warn)
            }
            // Roof beacon + antenna whip.
            fill(cg, x: 42, y: 0 + y, w: 3, h: 2, O)
            fill(cg, x: 43, y: 0 + y, w: 1, h: 1, glow)
            fill(cg, x: 54, y: 0 + y, w: 1, h: 2, O)

            // --- Nose: headlight, bumper tusk and chin skid.
            fill(cg, x: 60, y: 19 + y, w: 3, h: 3, O)
            fill(cg, x: 61, y: 20 + y, w: 1, h: 1, glow)
            fill(cg, x: 58, y: 23 + y, w: 6, h: 5, O)
            fill(cg, x: 59, y: 24 + y, w: 4, h: 3, steel)
            fill(cg, x: 62, y: 25 + y, w: 1, h: 2, trim)
            fill(cg, x: 54, y: 26 + y, w: 10, h: 2, O)
            fill(cg, x: 55, y: 26 + y, w: 8, h: 1, under)

        }
    }

    // MARK: - Player Bombard (Level 11 mortar carrier)

    /// Same wide chassis language as the Vuran gun-truck, rebuilt as a
    /// mortar carrier: olive hull, four wheels, roof turntable and a rear
    /// ammo rack. The launcher tube itself lives in bombardArm() and is
    /// pitched upward by AllyNode.
    private static func bombard(pose: Int) -> SKTexture {
        canvas(w: 48, h: 32, key: "body-bombard-\(pose)") { cg in
            let body = UIColor(red: 0.38, green: 0.39, blue: 0.29, alpha: 1)
            let topLit = UIColor(red: 0.62, green: 0.62, blue: 0.45, alpha: 1)
            let trim = UIColor(red: 0.78, green: 0.66, blue: 0.40, alpha: 1)
            let shade = UIColor(red: 0.25, green: 0.26, blue: 0.18, alpha: 1)
            let camoD = UIColor(red: 0.21, green: 0.22, blue: 0.15, alpha: 1)
            let glass = UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1)
            let under = UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
            let tire = UIColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 1)
            let rim = UIColor(red: 0.40, green: 0.44, blue: 0.50, alpha: 1)
            let rimLit = UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
            let hub = UIColor(red: 0.80, green: 0.72, blue: 0.44, alpha: 1)
            let hubD = UIColor(red: 0.55, green: 0.48, blue: 0.26, alpha: 1)
            let lamp = UIColor(red: 1.0, green: 0.93, blue: 0.70, alpha: 1)
            let foot = UIColor(red: 0.38, green: 0.30, blue: 0.20, alpha: 1)
            let warn = UIColor(red: 1.0, green: 0.55, blue: 0.16, alpha: 1)
            let O = outline
            let y = [0, 0, 1, 0][pose]

            // --- Hull: outline, body, bright top strip, sand lower trim.
            fill(cg, x: 1, y: 9 + y, w: 37, h: 12, O)
            fill(cg, x: 2, y: 10 + y, w: 35, h: 10, body)
            fill(cg, x: 2, y: 10 + y, w: 35, h: 2, topLit)
            fill(cg, x: 2, y: 19 + y, w: 35, h: 1, trim)
            fill(cg, x: 5, y: 16 + y, w: 3, h: 1, camoD)
            fill(cg, x: 11, y: 17 + y, w: 4, h: 1, camoD)
            fill(cg, x: 19, y: 16 + y, w: 3, h: 1, camoD)
            fill(cg, x: 27, y: 17 + y, w: 4, h: 1, camoD)

            // --- Slit windows along the hull.
            for wx in [5, 12, 19] {
                fill(cg, x: wx, y: 12 + y, w: 5, h: 3, shade)
                fill(cg, x: wx, y: 12 + y, w: 5, h: 1, O)
                fill(cg, x: wx + 1, y: 13 + y, w: 3, h: 1, glass)
            }

            // --- Staircase sun-bleach sweep toward the nose.
            fill(cg, x: 24, y: 10 + y, w: 2, h: 1, trim)
            fill(cg, x: 26, y: 11 + y, w: 2, h: 1, trim)
            fill(cg, x: 28, y: 12 + y, w: 2, h: 1, trim)
            fill(cg, x: 30, y: 13 + y, w: 2, h: 1, trim)
            fill(cg, x: 32, y: 14 + y, w: 2, h: 1, trim)
            fill(cg, x: 34, y: 15 + y, w: 2, h: 1, trim)

            // --- Front cab, angled windshield, nose + headlight.
            fill(cg, x: 38, y: 11 + y, w: 4, h: 9, O)
            fill(cg, x: 39, y: 12 + y, w: 2, h: 7, body)
            fill(cg, x: 39, y: 12 + y, w: 2, h: 1, topLit)
            fill(cg, x: 40, y: 13 + y, w: 3, h: 2, glass)
            fill(cg, x: 41, y: 15 + y, w: 2, h: 2, glass)
            fill(cg, x: 42, y: 14 + y, w: 5, h: 7, O)
            fill(cg, x: 43, y: 15 + y, w: 3, h: 5, body)
            fill(cg, x: 43, y: 15 + y, w: 3, h: 1, topLit)
            fill(cg, x: 45, y: 16 + y, w: 2, h: 2, O)
            fill(cg, x: 46, y: 17 + y, w: 1, h: 1, lamp)
            fill(cg, x: 40, y: 20 + y, w: 8, h: 2, O)
            fill(cg, x: 41, y: 20 + y, w: 6, h: 1, under)

            // --- Rear ammo rack: two upright mortar shells.
            fill(cg, x: 3, y: 5 + y, w: 7, h: 5, O)
            fill(cg, x: 4, y: 6 + y, w: 5, h: 3, shade)
            for sx in [5, 7] {
                fill(cg, x: sx, y: 4 + y, w: 1, h: 4, warn)
                fill(cg, x: sx, y: 4 + y, w: 1, h: 1, .white.withAlphaComponent(0.6))
            }

            // --- Roof turntable for the mortar tube.
            fill(cg, x: 12, y: 5 + y, w: 13, h: 4, O)
            fill(cg, x: 13, y: 6 + y, w: 11, h: 2, shade)
            fill(cg, x: 15, y: 4 + y, w: 7, h: 2, O)
            fill(cg, x: 16, y: 4 + y, w: 5, h: 1, rimLit)
            fill(cg, x: 17, y: 6 + y, w: 3, h: 1, warn)

            // --- Rear hazard chevrons + tail lamp.
            fill(cg, x: 1, y: 17 + y, w: 2, h: 2, O)
            fill(cg, x: 1, y: 17 + y, w: 1, h: 1, lamp)
            for hx in [3, 6, 9] {
                fill(cg, x: hx, y: 20 + y, w: 2, h: 1, warn)
            }
            fill(cg, x: 0, y: 20 + y, w: 48, h: 2, O)

            // --- FOUR wheels: tire / rim / gold hub + roll spokes.
            for wx in [7, 15, 24, 32] {
                fill(cg, x: wx - 4, y: 22 + y, w: 9, h: 9, O)
                fill(cg, x: wx - 3, y: 23 + y, w: 7, h: 7, tire)
                fill(cg, x: wx - 3, y: 23 + y, w: 3, h: 1, rimLit)
                fill(cg, x: wx - 2, y: 24 + y, w: 5, h: 5, rim)
                switch pose {
                case 0:
                    fill(cg, x: wx, y: 24 + y, w: 1, h: 5, tire)
                    fill(cg, x: wx - 2, y: 26 + y, w: 5, h: 1, tire)
                case 1:
                    fill(cg, x: wx + 1, y: 24 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx - 1, y: 26 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx - 2, y: 26 + y, w: 2, h: 1, tire)
                    fill(cg, x: wx + 1, y: 28 + y, w: 2, h: 1, tire)
                case 2:
                    fill(cg, x: wx - 2, y: 25 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx + 2, y: 25 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx - 2, y: 26 + y, w: 2, h: 1, tire)
                    fill(cg, x: wx + 1, y: 28 + y, w: 2, h: 1, tire)
                default:
                    fill(cg, x: wx - 1, y: 24 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx + 1, y: 26 + y, w: 1, h: 3, tire)
                    fill(cg, x: wx - 2, y: 28 + y, w: 2, h: 1, tire)
                    fill(cg, x: wx + 1, y: 26 + y, w: 2, h: 1, tire)
                }
                fill(cg, x: wx - 1, y: 26 + y, w: 3, h: 3, hub)
                fill(cg, x: wx - 1, y: 26 + y, w: 3, h: 1, rimLit)
                fill(cg, x: wx, y: 27 + y, w: 1, h: 1, hubD)
                fill(cg, x: wx - 3, y: 31 + y, w: 7, h: 1, foot)
                fill(cg, x: wx - 2, y: 31 + y, w: 5, h: 1, hubD)
            }
        }
    }

    /// Bombard mortar tube: thick olive launcher with a sand hazard band,
    /// dark bore and a reinforced collar. The shoulder pivot is raised by
    /// AllyNode so the tube points up for a lobbed shot.
    private static func bombardArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-bombard-v1") { cg in
            let olive = UIColor(red: 0.34, green: 0.34, blue: 0.24, alpha: 1)
            let oliveHi = UIColor(red: 0.58, green: 0.56, blue: 0.38, alpha: 1)
            let oliveD = UIColor(red: 0.20, green: 0.20, blue: 0.14, alpha: 1)
            let band = UIColor(red: 1.0, green: 0.55, blue: 0.16, alpha: 1)
            let O = outline
            // Reinforced mount collar around the grip (x=5).
            fill(cg, x: 2, y: 3, w: 7, h: 7, O)
            fill(cg, x: 3, y: 4, w: 5, h: 5, olive)
            fill(cg, x: 3, y: 4, w: 5, h: 1, oliveHi)
            fill(cg, x: 5, y: 5, w: 1, h: 3, oliveD)
            // Thick mortar tube pointing +x.
            fill(cg, x: 8, y: 3, w: 14, h: 6, O)
            fill(cg, x: 9, y: 4, w: 12, h: 4, olive)
            fill(cg, x: 9, y: 4, w: 12, h: 1, oliveHi)
            fill(cg, x: 9, y: 7, w: 12, h: 1, oliveD)
            // Hazard band + muzzle brake ring.
            fill(cg, x: 16, y: 4, w: 2, h: 4, band)
            fill(cg, x: 20, y: 3, w: 2, h: 6, O)
            fill(cg, x: 21, y: 4, w: 1, h: 4, oliveD)
            fill(cg, x: 21, y: 5, w: 1, h: 2, .black)
            // Top sight rib.
            fill(cg, x: 12, y: 2, w: 3, h: 1, O)
            fill(cg, x: 13, y: 2, w: 1, h: 1, oliveHi)
        }
    }

    // MARK: - Player Tank (Level 17 main-battle tank)

    /// Tracked main-battle tank in the same wide-canvas language as the
    /// Vuran gun-truck: olive hull with a khaki top strip and cream trim,
    /// a low armored turret carrying the aimable cannon (see tankArm()),
    /// a running gear of road wheels inside a continuous track, blue team
    /// stripes on the flank so it reads friendly at a glance, and a
    /// stowed missile strapped to the turret flank. Faces +x.
    private static func tank(pose: Int) -> SKTexture {
        canvas(w: 48, h: 32, key: "body-tank-\(pose)") { cg in
            let olive = UIColor(red: 0.40, green: 0.40, blue: 0.30, alpha: 1)
            let oliveLit = UIColor(red: 0.62, green: 0.62, blue: 0.45, alpha: 1)
            let oliveDk = UIColor(red: 0.25, green: 0.27, blue: 0.19, alpha: 1)
            let camoD = UIColor(red: 0.20, green: 0.22, blue: 0.15, alpha: 1)
            let team = UIColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)
            let teamLit = UIColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 1)
            let steel = UIColor(red: 0.36, green: 0.38, blue: 0.44, alpha: 1)
            let steelLit = UIColor(red: 0.58, green: 0.60, blue: 0.66, alpha: 1)
            let warn = UIColor(red: 1.0, green: 0.62, blue: 0.16, alpha: 1)
            let glass = UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1)
            let glow = UIColor(red: 0.55, green: 0.90, blue: 1.0, alpha: 1)
            let under = UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
            let tire = UIColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 1)
            let rimLit = UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
            let lamp = UIColor(red: 1.0, green: 0.93, blue: 0.70, alpha: 1)
            let O = outline
            let y = [0, 0, 1, 0][pose] // suspension bounce

            // --- TANK TRACKS: a continuous chain wrapping the running
            // gear, road wheels turning inside it, chain links crawling
            // a pixel per frame phase.
            let link = [0, 1, 2, 3][pose]
            fill(cg, x: 7, y: 22, w: 37, h: 10, O)
            fill(cg, x: 2, y: 25, w: 6, h: 6, O)
            fill(cg, x: 43, y: 25, w: 4, h: 6, O)
            fill(cg, x: 8, y: 23, w: 35, h: 8, tire)
            fill(cg, x: 3, y: 26, w: 5, h: 4, tire)
            fill(cg, x: 43, y: 26, w: 3, h: 4, tire)
            for rx in [14, 22, 30, 38] {
                fill(cg, x: rx - 3, y: 26, w: 7, h: 6, oliveDk)
                fill(cg, x: rx - 3, y: 26, w: 3, h: 1, rimLit)
                fill(cg, x: rx - 1, y: 28, w: 3, h: 2, steel)
                fill(cg, x: rx - 1, y: 28, w: 3, h: 1, steelLit)
            }
            for i in 0..<9 {
                let lx = 10 + ((i * 4 + link) % 32)
                fill(cg, x: lx, y: 29, w: 2, h: 2, under)
            }
            for i in 0..<2 {
                let ly = 26 + ((i * 3 + link) % 5)
                fill(cg, x: 3, y: ly, w: 2, h: 2, under)
                fill(cg, x: 43, y: ly, w: 2, h: 2, under)
            }

            // --- Hull: long armored flank, lit top deck, dark belly and
            // a blue team stripe down the middle.
            fill(cg, x: 2, y: 13 + y, w: 44, h: 10, O)
            fill(cg, x: 3, y: 14 + y, w: 42, h: 8, olive)
            fill(cg, x: 3, y: 14 + y, w: 42, h: 2, oliveLit)
            fill(cg, x: 3, y: 20 + y, w: 42, h: 2, oliveDk)
            fill(cg, x: 3, y: 17 + y, w: 42, h: 2, team)
            fill(cg, x: 3, y: 17 + y, w: 42, h: 1, teamLit)
            // Camo flecks along the hull shoulder.
            fill(cg, x: 7, y: 15 + y, w: 3, h: 1, camoD)
            fill(cg, x: 14, y: 16 + y, w: 4, h: 1, camoD)
            fill(cg, x: 23, y: 15 + y, w: 3, h: 1, camoD)
            fill(cg, x: 31, y: 16 + y, w: 4, h: 1, camoD)

            // --- Exhaust stack at the very back, hot tip.
            fill(cg, x: 1, y: 10 + y, w: 4, h: 6, O)
            fill(cg, x: 2, y: 11 + y, w: 2, h: 4, steel)
            fill(cg, x: 1, y: 9 + y, w: 4, h: 2, O)
            fill(cg, x: 2, y: 10 + y, w: 2, h: 1, warn)

            // --- Rear stowage bin with a spare shell nose-up.
            fill(cg, x: 5, y: 6 + y, w: 6, h: 7, O)
            fill(cg, x: 6, y: 7 + y, w: 4, h: 5, oliveDk)
            fill(cg, x: 7, y: 4 + y, w: 2, h: 3, warn)
            fill(cg, x: 7, y: 4 + y, w: 1, h: 1, .white.withAlphaComponent(0.6))

            // --- Turret: low slab with lit top, blue band, hatch ring and
            // a stowed missile clipped to the flank. The mantlet sits at
            // the nose edge of the turret and the aimable cannon fires
            // out of it (arm pivot at the turret's grip).
            fill(cg, x: 12, y: 2 + y, w: 19, h: 12, O)
            fill(cg, x: 13, y: 3 + y, w: 17, h: 10, olive)
            fill(cg, x: 13, y: 3 + y, w: 17, h: 2, oliveLit)
            fill(cg, x: 13, y: 11 + y, w: 17, h: 2, oliveDk)
            fill(cg, x: 13, y: 8 + y, w: 17, h: 2, team)
            // Turret hatch ring + periscope pip.
            fill(cg, x: 16, y: 5 + y, w: 5, h: 4, O)
            fill(cg, x: 17, y: 6 + y, w: 3, h: 2, oliveDk)
            fill(cg, x: 17, y: 5 + y, w: 1, h: 1, glow)
            // Stowed missile on the flank: slim body, nose cone, fins.
            fill(cg, x: 25, y: 6 + y, w: 9, h: 4, O)
            fill(cg, x: 26, y: 7 + y, w: 7, h: 2, steel)
            fill(cg, x: 31, y: 7 + y, w: 2, h: 2, warn)
            fill(cg, x: 25, y: 6 + y, w: 1, h: 4, steelLit)
            // Mantlet: the armored nose block the cannon mounts behind.
            fill(cg, x: 30, y: 5 + y, w: 4, h: 8, O)
            fill(cg, x: 31, y: 6 + y, w: 2, h: 6, oliveDk)

            // --- Nose: headlight, lamp housing, chin skid.
            fill(cg, x: 45, y: 16 + y, w: 2, h: 3, O)
            fill(cg, x: 45, y: 17 + y, w: 1, h: 1, lamp)
            fill(cg, x: 41, y: 22 + y, w: 6, h: 2, O)
            fill(cg, x: 42, y: 22 + y, w: 4, h: 1, under)

            // --- Antenna whip on the turret roof.
            fill(cg, x: 24, y: 0 + y, w: 1, h: 3, O)
        }
    }

    /// Tank cannon: a heavy barrel on the turret grip — reinforced breech
    /// collar, ribbed recoil sleeve, long barrel drill and a hot muzzle
    /// brake with the throat the straight-flying missile leaves from.
    private static func tankArm() -> SKTexture {
        let m = armMetrics(for: .tank)
        return canvas(w: m.w, h: m.h, key: "arm-tank-v1") { cg in
            let steel = UIColor(red: 0.34, green: 0.36, blue: 0.42, alpha: 1)
            let steelHi = UIColor(red: 0.58, green: 0.60, blue: 0.66, alpha: 1)
            let steelDk = UIColor(red: 0.17, green: 0.18, blue: 0.22, alpha: 1)
            let olive = UIColor(red: 0.40, green: 0.40, blue: 0.30, alpha: 1)
            let team = UIColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.45, blue: 0.18, alpha: 1)
            let O = outline
            // Breech collar wrapping the grip (x=6).
            fill(cg, x: 2, y: 4, w: 9, h: 8, O)
            fill(cg, x: 3, y: 5, w: 7, h: 6, olive)
            fill(cg, x: 3, y: 5, w: 7, h: 1, .white.withAlphaComponent(0.4))
            fill(cg, x: 4, y: 6, w: 2, h: 3, team)
            // Ribbed recoil sleeve along the barrel root.
            fill(cg, x: 10, y: 4, w: 8, h: 7, O)
            fill(cg, x: 11, y: 5, w: 6, h: 5, steel)
            fill(cg, x: 11, y: 5, w: 6, h: 1, steelHi)
            fill(cg, x: 11, y: 9, w: 6, h: 1, steelDk)
            for rx in [13, 15] {
                fill(cg, x: rx, y: 5, w: 1, h: 5, steelDk)
            }
            // Long barrel with a lit top line.
            fill(cg, x: 17, y: 5, w: 9, h: 5, O)
            fill(cg, x: 18, y: 6, w: 8, h: 3, steel)
            fill(cg, x: 18, y: 6, w: 8, h: 1, steelHi)
            // Muzzle brake with the hot throat inside.
            fill(cg, x: 25, y: 3, w: 4, h: 9, O)
            fill(cg, x: 26, y: 4, w: 2, h: 7, steel)
            fill(cg, x: 26, y: 6, w: 1, h: 3, glow)
        }
    }

    // MARK: - Enemy raider (red alien)

    private static func enemy(pose: Int) -> SKTexture {
        canvas(key: "body-enemy-\(pose)") { cg in
            let chitin = UIColor(red: 0.45, green: 0.12, blue: 0.14, alpha: 1)
            let chitinD = UIColor(red: 0.25, green: 0.08, blue: 0.10, alpha: 1)
            let hide = UIColor(red: 0.20, green: 0.12, blue: 0.14, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.25, blue: 0.15, alpha: 1)
            let O = outline

            // Antennae.
            fill(cg, x: 10, y: 0, w: 1, h: 3, chitin)
            fill(cg, x: 14, y: 0, w: 1, h: 3, chitin)
            fill(cg, x: 10, y: 0, w: 1, h: 1, glow)
            fill(cg, x: 14, y: 0, w: 1, h: 1, glow)
            // Angular alien skull.
            fill(cg, x: 9, y: 3, w: 8, h: 5, O)
            fill(cg, x: 10, y: 4, w: 6, h: 3, hide)
            fill(cg, x: 14, y: 2, w: 3, h: 2, hide) // brow ridge toward +x
            // Twin glowing eyes.
            fill(cg, x: 13, y: 5, w: 2, h: 2, glow)
            fill(cg, x: 16, y: 5, w: 1, h: 2, glow)
            // Jaw fangs.
            fill(cg, x: 14, y: 8, w: 1, h: 1, .white)
            fill(cg, x: 16, y: 8, w: 1, h: 1, .white)
            // Torso carapace.
            fill(cg, x: 9, y: 9, w: 6, h: 8, O)
            fill(cg, x: 10, y: 10, w: 4, h: 6, chitin)
            fill(cg, x: 10, y: 10, w: 1, h: 6, chitinD)
            // Glowing chest core.
            fill(cg, x: 12, y: 12, w: 2, h: 3, O)
            fill(cg, x: 12, y: 12, w: 2, h: 2, glow)
            // Claw hand at the chest — the aimable spike-arm mounts here.
            fill(cg, x: 14, y: 11, w: 3, h: 3, hide) // claw
            // Digitigrade legs (4-frame stride).
            legs(cg, frame: pose, cx: 11, top: 17, len: 10,
                 pants: hide, shade: chitinD, boot: dark, outline: O)
        }
    }

    // MARK: - Enemy brute (bulky siege crusher)

    /// Twice the presence of a raider: low heavy skull, shoulder slabs,
    /// barrel torso with a furnace core, thick stomping legs.
    private static func brute(pose: Int) -> SKTexture {
        canvas(key: "body-brute-\(pose)") { cg in
            let chitin = UIColor(red: 0.52, green: 0.14, blue: 0.16, alpha: 1)
            let chitinD = UIColor(red: 0.28, green: 0.09, blue: 0.11, alpha: 1)
            let hide = UIColor(red: 0.22, green: 0.13, blue: 0.15, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.35, blue: 0.10, alpha: 1)
            let O = outline

            // Low heavy skull with brow horns.
            fill(cg, x: 8, y: 3, w: 10, h: 6, O)
            fill(cg, x: 9, y: 4, w: 8, h: 4, hide)
            fill(cg, x: 6, y: 2, w: 3, h: 2, chitinD) // rear horn
            fill(cg, x: 17, y: 2, w: 3, h: 2, chitinD) // brow horn toward +x
            // Triple glowing eyes.
            fill(cg, x: 13, y: 5, w: 2, h: 2, glow)
            fill(cg, x: 16, y: 5, w: 2, h: 2, glow)
            fill(cg, x: 15, y: 7, w: 1, h: 1, glow)
            // Shoulder slabs.
            fill(cg, x: 5, y: 9, w: 5, h: 4, O)
            fill(cg, x: 6, y: 9, w: 3, h: 3, chitin)
            fill(cg, x: 14, y: 9, w: 5, h: 4, O)
            fill(cg, x: 15, y: 9, w: 3, h: 3, chitin)
            fill(cg, x: 15, y: 9, w: 3, h: 1, .white.withAlphaComponent(0.3))
            // Barrel torso carapace.
            fill(cg, x: 7, y: 12, w: 10, h: 8, O)
            fill(cg, x: 8, y: 13, w: 8, h: 6, chitin)
            fill(cg, x: 8, y: 13, w: 2, h: 6, chitinD)
            // Furnace core.
            fill(cg, x: 11, y: 14, w: 3, h: 4, O)
            fill(cg, x: 11, y: 14, w: 3, h: 3, glow)
            // Claw hand at the chest — the aimable spike-arm mounts here.
            fill(cg, x: 16, y: 13, w: 3, h: 4, hide) // claw
            // Thick stomping legs (4-frame stride).
            legs(cg, frame: pose, cx: 12, top: 20, len: 8,
                 pants: hide, shade: chitinD, boot: dark, outline: O, wide: true)
        }
    }

    // MARK: - Enemy immortal (crimson battle walker)

    /// Heavy humanoid battle walker in armored crimson: huge rounded
    /// shoulder pauldrons, helmet with a glowing visor, missile-pod racks
    /// crowding the back, armored chest, and the whole left flank slung
    /// with the giant rail cannon (the aimable arm mounts at that
    /// shoulder). Digitigrade metal legs stomp on the 4-frame stride.
    private static func immortal(pose: Int) -> SKTexture {
        canvas(w: 40, h: 36, key: "body-immortal-\(pose)") { cg in
            // Red family with a hot pink-red glow trim (the enemy ray).
            let armor = UIColor(red: 0.74, green: 0.22, blue: 0.25, alpha: 1)   // lit plates
            let armorMid = UIColor(red: 0.52, green: 0.14, blue: 0.18, alpha: 1)
            let armorDk = UIColor(red: 0.30, green: 0.08, blue: 0.12, alpha: 1)
            let armorUltra = UIColor(red: 0.17, green: 0.05, blue: 0.08, alpha: 1)
            let mechDark = UIColor(red: 0.16, green: 0.13, blue: 0.15, alpha: 1)
            let mechDk2 = UIColor(red: 0.10, green: 0.08, blue: 0.10, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.38, blue: 0.50, alpha: 1)
            let O = outline

            // Missile-pod racks crowding the back of the shoulders:
            // two stacked rounded racks behind the pauldron, ports lit.
            fill(cg, x: 3, y: 1, w: 9, h: 5, O)
            fill(cg, x: 4, y: 2, w: 7, h: 3, armorMid)
            fill(cg, x: 4, y: 2, w: 7, h: 1, armor)
            for px in [5, 8, 10] {
                fill(cg, x: px, y: 3, w: 1, h: 1, glow)
            }
            fill(cg, x: 4, y: 6, w: 8, h: 5, O)
            fill(cg, x: 5, y: 7, w: 6, h: 3, armorMid)
            fill(cg, x: 5, y: 7, w: 6, h: 1, armorDk)
            for px in [6, 9] {
                fill(cg, x: px, y: 9, w: 1, h: 1, glow)
            }
            // Pod strut down to the shoulder line.
            fill(cg, x: 9, y: 10, w: 4, h: 2, mechDk2)

            // Helmet: angular, tucked between the pauldron and the arm.
            fill(cg, x: 23, y: 4, w: 8, h: 6, O)
            fill(cg, x: 24, y: 5, w: 6, h: 4, armor)
            fill(cg, x: 24, y: 5, w: 6, h: 1, .white.withAlphaComponent(0.45))
            fill(cg, x: 24, y: 8, w: 6, h: 1, armorDk)
            // Glowing visor slit toward +x.
            fill(cg, x: 27, y: 6, w: 3, h: 2, glow)
            fill(cg, x: 30, y: 6, w: 1, h: 1, glow)
            // Chin vent.
            fill(cg, x: 26, y: 10, w: 4, h: 1, mechDk2)

            // Giant shoulder pauldron: the walker's crown.
            fill(cg, x: 12, y: 3, w: 13, h: 8, O)
            fill(cg, x: 13, y: 4, w: 11, h: 6, armor)
            fill(cg, x: 13, y: 4, w: 11, h: 1, .white.withAlphaComponent(0.5))
            fill(cg, x: 13, y: 8, w: 11, h: 2, armorMid)
            fill(cg, x: 14, y: 9, w: 9, h: 1, armorDk)
            // Pink accent stripe across the pauldron face.
            fill(cg, x: 15, y: 6, w: 6, h: 1, glow)
            fill(cg, x: 15, y: 5, w: 1, h: 3, glow)
            // Front edge shading down to the arm joint.
            fill(cg, x: 23, y: 9, w: 3, h: 2, armorDk)

            // Chest block under the pauldron, dark armored plates.
            fill(cg, x: 14, y: 11, w: 10, h: 7, O)
            fill(cg, x: 15, y: 12, w: 8, h: 5, armorMid)
            fill(cg, x: 15, y: 12, w: 3, h: 5, armorDk)
            fill(cg, x: 15, y: 12, w: 8, h: 1, armor)
            // Glowing reactor core.
            fill(cg, x: 18, y: 13, w: 3, h: 3, O)
            fill(cg, x: 19, y: 14, w: 1, h: 1, glow)
            fill(cg, x: 18, y: 13, w: 2, h: 1, glow.withAlphaComponent(0.7))
            // Abdomen.
            fill(cg, x: 15, y: 18, w: 8, h: 3, mechDk2)
            fill(cg, x: 16, y: 19, w: 6, h: 1, armorDk)
            // Cable noose: dark wires with a hot dangling socket.
            segment(cg, x0: 17, y0: 21, x1: 21, y1: 23, w: 1, color: mechDk2)
            fill(cg, x: 21, y: 23, w: 1, h: 1, glow)

            // Shoulder joint block the cannon cradle rides on.
            fill(cg, x: 23, y: 11, w: 6, h: 6, O)
            fill(cg, x: 24, y: 12, w: 4, h: 4, mechDark)

            // Pelvis under the abdomen.
            fill(cg, x: 14, y: 21, w: 9, h: 4, O)
            fill(cg, x: 15, y: 22, w: 7, h: 2, armorMid)
            fill(cg, x: 15, y: 22, w: 2, h: 2, armorDk)

            // Digitigrade metal legs, stomp gait: thigh armor, pink knee
            // light, segmented dark shin, two-toed foot.
            immortalWalkLeg(cg, hipX: 20, frame: pose,
                            thigh: armor, thighD: armorDk, metal: mechDark,
                            metalDk: mechDk2, glow: glow, O: O)
            immortalWalkLeg(cg, hipX: 16, frame: (pose + 2) % 4,
                            thigh: armor, thighD: armorDk, metal: mechDark,
                            metalDk: mechDk2, glow: glow, O: O, front: false)
        }
    }

    /// One digitigrade leg: hip -> forward knee -> down shin -> toe. The
    /// knee carries a hot glow stripe; the shin is segmented metal.
    private static func immortalWalkLeg(_ cg: CGContext, hipX: Int, frame: Int,
                                        thigh: UIColor, thighD: UIColor,
                                        metal: UIColor, metalDk: UIColor,
                                        glow: UIColor, O: UIColor,
                                        front: Bool = true) {
        let s = stride(frame, back: false)
        let dx = s.dx * (front ? 1 : -1)
        // Hip -> knee (thigh, angling forward), knee -> ankle (shin).
        let kneeX = hipX + dx + (front ? 2 : -1)
        let kneeY = 26
        let ankleX = kneeX + (front ? 1 : -2)
        let ankleY = 31
        segment(cg, x0: hipX, y0: 23, x1: kneeX, y1: kneeY, w: 5, color: O)
        segment(cg, x0: hipX, y0: 23, x1: kneeX, y1: kneeY, w: 3, color: thigh)
        segment(cg, x0: hipX, y0: 23, x1: hipX, y1: 25, w: 1, color: thighD)
        // Knee joint + glow stripe.
        fill(cg, x: kneeX - 2, y: kneeY - 1, w: 4, h: 3, O)
        fill(cg, x: kneeX - 1, y: kneeY - 1, w: 2, h: 1, glow)
        // Segmented shin down to the ankle.
        segment(cg, x0: kneeX, y0: kneeY + 1, x1: ankleX, y1: ankleY, w: 4, color: O)
        segment(cg, x0: kneeX, y0: kneeY + 1, x1: ankleX, y1: ankleY, w: 2, color: metal)
        for sy in [kneeY + 3, kneeY + 5, kneeY + 7] {
            fill(cg, x: min(kneeX, ankleX), y: sy, w: abs(ankleX - kneeX) + 3, h: 1, metalDk)
        }
        // Two-toed foot on the ground line.
        fill(cg, x: ankleX - 3, y: ankleY, w: 6, h: 3, O)
        fill(cg, x: ankleX - 2, y: ankleY, w: 5, h: 2, metal)
        fill(cg, x: ankleX + (front ? 1 : -2), y: ankleY, w: 2, h: 1, metalDk)
    }

    /// The walker's whole weapon unit rides the aimable pivot: a black
    /// rail cannon with a hot band under the shoulder, plus the
    /// triple-barrel gatling cluster hung beneath it. Both muzzles burn.
    private static func immortalArm() -> SKTexture {
        let m = armMetrics(for: .immortal)
        return canvas(w: m.w, h: m.h, key: "arm-immortal") { cg in
            let armorDk = UIColor(red: 0.30, green: 0.08, blue: 0.12, alpha: 1)
            let mechDark = UIColor(red: 0.16, green: 0.13, blue: 0.15, alpha: 1)
            let mechDk2 = UIColor(red: 0.10, green: 0.08, blue: 0.10, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.38, blue: 0.50, alpha: 1)
            let O = outline
            // Cradle gripping the shoulder joint (grip x=6).
            fill(cg, x: 2, y: 4, w: 8, h: 9, O)
            fill(cg, x: 3, y: 5, w: 6, h: 7, armorDk)
            fill(cg, x: 3, y: 5, w: 6, h: 1, .white.withAlphaComponent(0.3))
            fill(cg, x: 4, y: 10, w: 4, h: 2, mechDk2)
            // Rail cannon: long black barrel along the top.
            fill(cg, x: 8, y: 2, w: 26, h: 5, O)
            fill(cg, x: 9, y: 3, w: 24, h: 3, mechDk2)
            fill(cg, x: 9, y: 3, w: 24, h: 1, mechDark)
            // Muzzle ring + hot band near the tip.
            fill(cg, x: 29, y: 3, w: 2, h: 3, mechDark)
            fill(cg, x: 24, y: 3, w: 3, h: 3, glow)
            fill(cg, x: 33, y: 3, w: 1, h: 3, glow)
            // Under-hung gatling: receiver + triple barrel cluster.
            fill(cg, x: 10, y: 7, w: 8, h: 6, O)
            fill(cg, x: 11, y: 8, w: 6, h: 4, mechDk2)
            fill(cg, x: 18, y: 8, w: 4, h: 5, O)
            fill(cg, x: 19, y: 9, w: 3, h: 3, mechDark)
            // Three tube mouths, lit.
            for py in [8, 10, 12] {
                fill(cg, x: 22, y: py, w: 1, h: 1, glow)
            }
            // Power feed running back to the walker.
            fill(cg, x: 3, y: 12, w: 6, h: 1, mechDk2)
        }
    }

    // MARK: - Enemy reaver (bone-plated axe executioner)

    /// Deliberately outside the red raider/brute family: ivory bone plates
    /// over dark ash flesh, twin ember eyes, great backward + forward swept
    /// horns, hunched plated back. Reads as executioner at a glance.
    /// Wields the double-bladed bone axe (see reaverArm) on the arm pivot.
    private static func reaver(pose: Int) -> SKTexture {
        canvas(key: "body-reaver-\(pose)") { cg in
            let bone = UIColor(red: 0.82, green: 0.76, blue: 0.62, alpha: 1)
            let boneD = UIColor(red: 0.55, green: 0.48, blue: 0.36, alpha: 1)
            let flesh = UIColor(red: 0.16, green: 0.10, blue: 0.11, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 1)
            let O = outline

            // Rear horn sweeping up-back.
            fill(cg, x: 4, y: 1, w: 3, h: 3, O)
            fill(cg, x: 4, y: 1, w: 2, h: 2, bone)
            fill(cg, x: 3, y: 0, w: 2, h: 1, bone)
            // Front horn sweeping up-forward over the brow.
            fill(cg, x: 17, y: 0, w: 4, h: 3, O)
            fill(cg, x: 18, y: 0, w: 3, h: 2, bone)
            fill(cg, x: 20, y: 0, w: 2, h: 1, bone)
            // Low ash skull.
            fill(cg, x: 8, y: 3, w: 10, h: 6, O)
            fill(cg, x: 9, y: 4, w: 8, h: 4, flesh)
            // Twin ember eyes.
            fill(cg, x: 12, y: 5, w: 2, h: 2, O)
            fill(cg, x: 12, y: 5, w: 2, h: 2, glow)
            fill(cg, x: 15, y: 5, w: 2, h: 2, O)
            fill(cg, x: 15, y: 5, w: 2, h: 2, glow)
            // Fanged maw.
            fill(cg, x: 13, y: 9, w: 1, h: 1, .white)
            fill(cg, x: 15, y: 9, w: 1, h: 1, .white)
            fill(cg, x: 17, y: 9, w: 1, h: 1, .white)
            // Hunched bone back: stacked plates over the shoulders.
            fill(cg, x: 4, y: 9, w: 8, h: 4, O)
            fill(cg, x: 5, y: 9, w: 6, h: 3, bone)
            fill(cg, x: 5, y: 9, w: 6, h: 1, .white.withAlphaComponent(0.5))
            fill(cg, x: 5, y: 12, w: 6, h: 3, O)
            fill(cg, x: 6, y: 12, w: 4, h: 2, boneD)
            // Torso: dark flesh with bone rib guards + ember core.
            fill(cg, x: 8, y: 13, w: 8, h: 7, O)
            fill(cg, x: 9, y: 14, w: 6, h: 5, flesh)
            fill(cg, x: 9, y: 14, w: 1, h: 5, bone)
            fill(cg, x: 12, y: 14, w: 1, h: 5, bone)
            fill(cg, x: 14, y: 15, w: 2, h: 3, O)
            fill(cg, x: 14, y: 15, w: 2, h: 2, glow)
            // Belt.
            fill(cg, x: 8, y: 20, w: 8, h: 2, O)
            // Axe hand at the chest — the bone axe mounts here.
            fill(cg, x: 16, y: 14, w: 3, h: 3, flesh) // claw
            // Digitigrade sprinter legs (4-frame stride).
            legs(cg, frame: pose, cx: 12, top: 22, len: 6,
                 pants: flesh, shade: boneD, boot: dark, outline: O)
        }
    }

    // MARK: - Enemy skitter (violet zergling rusher)

    /// Low fast quadruped: fanged head, ember-magenta eyes, plated back,
    /// tail stinger, two pairs of scuttling legs. Faces +x; the hooked
    /// talon mounts on the shoulder pivot and chops like the axe.
    private static func skitter(pose: Int) -> SKTexture {
        canvas(key: "body-skitter-\(pose)") { cg in
            let chitin = UIColor(red: 0.48, green: 0.22, blue: 0.58, alpha: 1)
            let chitinD = UIColor(red: 0.28, green: 0.12, blue: 0.34, alpha: 1)
            let hide = UIColor(red: 0.18, green: 0.10, blue: 0.22, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.30, blue: 0.75, alpha: 1)
            let O = outline

            // Tail stinger sweeping back (-x) with a hot barb.
            fill(cg, x: 1, y: 13, w: 7, h: 2, O)
            fill(cg, x: 2, y: 13, w: 5, h: 1, chitinD)
            fill(cg, x: 0, y: 12, w: 2, h: 2, O)
            fill(cg, x: 0, y: 12, w: 1, h: 1, glow)
            // Segmented back plates (3) with rim light.
            for i in 0..<3 {
                let px = 7 + i * 4
                fill(cg, x: px, y: 11, w: 4, h: 4, O)
                fill(cg, x: px + 1, y: 11, w: 2, h: 3, chitin)
                fill(cg, x: px + 1, y: 11, w: 2, h: 1, .white.withAlphaComponent(0.4))
            }
            // Dorsal spikes.
            for sx in [8, 12, 16] {
                fill(cg, x: sx, y: 8, w: 1, h: 3, O)
                fill(cg, x: sx, y: 8, w: 1, h: 2, chitinD)
            }
            // Low skull + snout toward +x.
            fill(cg, x: 15, y: 12, w: 7, h: 5, O)
            fill(cg, x: 16, y: 13, w: 5, h: 3, hide)
            // Twin magenta eyes.
            fill(cg, x: 17, y: 13, w: 2, h: 2, glow)
            fill(cg, x: 20, y: 13, w: 1, h: 2, glow)
            // Fangs.
            fill(cg, x: 21, y: 16, w: 1, h: 2, .white)
            fill(cg, x: 19, y: 16, w: 1, h: 1, .white)
            // Fore talons + belly plate.
            fill(cg, x: 16, y: 17, w: 4, h: 3, O)
            fill(cg, x: 17, y: 18, w: 3, h: 1, chitin)
            fill(cg, x: 10, y: 16, w: 6, h: 2, chitinD)
            // Two pairs of scuttling legs, offset phases.
            legs(cg, frame: pose, cx: 10, top: 20, len: 8,
                 pants: hide, shade: chitinD, boot: dark, outline: O)
            legs(cg, frame: (pose + 2) % 4, cx: 15, top: 20, len: 8,
                 pants: hide, shade: chitinD, boot: dark, outline: O)
        }
    }

    // MARK: - Marching legs (4-frame stride)

    /// Thick pixel line between two points (w-wide row per step).
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

    /// One stride phase: foot offset ahead of the hip + lift off the ground.
    /// contact -> support -> toe-off -> swing; back leg runs 2 phases behind.
    private static func stride(_ frame: Int, back: Bool) -> (dx: Int, lift: Int) {
        let table = [(4, 0), (0, 0), (-4, 1), (1, 3)]
        return table[(frame + (back ? 2 : 0)) % 4]
    }

    /// Two legs under body centre `cx` from `top` down `len` px, with bent
    /// knees pushing forward: outlined thigh + darker shin + boot with sole.
    private static func legs(_ cg: CGContext, frame: Int, cx: Int, top: Int, len: Int,
                             pants: UIColor, shade: UIColor, boot: UIColor,
                             outline O: UIColor, wide: Bool = false) {
        let w = wide ? 3 : 2
        let back = stride(frame, back: true)
        let front = stride(frame, back: false)
        drawLeg(cg, hipX: cx - 2, dx: back.dx, lift: back.lift,
                top: top, len: len, w: w,
                pants: pants, shade: shade, boot: boot, outline: O)
        drawLeg(cg, hipX: cx + 1, dx: front.dx, lift: front.lift,
                top: top, len: len, w: w,
                pants: pants, shade: shade, boot: boot, outline: O)
    }

    private static func drawLeg(_ cg: CGContext, hipX: Int, dx: Int, lift: Int,
                                top: Int, len: Int, w: Int,
                                pants: UIColor, shade: UIColor, boot: UIColor,
                                outline O: UIColor) {
        let footX = hipX + dx
        let footY = top + len - lift
        let kneeX = (hipX + footX) / 2 + 1
        let kneeY = (top + footY) / 2
        segment(cg, x0: hipX, y0: top, x1: kneeX, y1: kneeY, w: w + 1, color: O)
        segment(cg, x0: hipX, y0: top, x1: kneeX, y1: kneeY, w: w - 1, color: pants)
        segment(cg, x0: kneeX, y0: kneeY, x1: footX, y1: footY, w: w - 1, color: shade)
        fill(cg, x: footX - 2, y: footY, w: w + 3, h: 2, O)
        fill(cg, x: footX - 1, y: footY, w: w + 1, h: 1, boot)
    }

    // MARK: - Aimable gun-arms (pivot sprite per kind)

    static let armW = 24
    static let armH = 12
    /// Grip (rotation pivot) + muzzle tip x in arm-canvas px.
    static let armGripX = 5
    static let armTipX = 21

    /// Arm canvas metrics per kind: pixel size plus the grip (rotation
    /// pivot) and muzzle tip x. Most units share the rifle-sized default;
    /// the missile truck mounts a much bigger launcher rail.
    struct ArmMetrics {
        let w: Int
        let h: Int
        let gripX: Int
        let tipX: Int
    }

    /// Metrics for a kind's aimable arm. Nodes use these to place the
    /// pivot anchor and the muzzle socket.
    static func armMetrics(for kind: Kind) -> ArmMetrics {
        switch kind {
        case .missileTruck:
            return ArmMetrics(w: 34, h: 16, gripX: 8, tipX: 30)
        case .immortal:
            return ArmMetrics(w: 40, h: 16, gripX: 6, tipX: 35)
        case .tank:
            return ArmMetrics(w: 30, h: 14, gripX: 6, tipX: 27)
        default:
            return ArmMetrics(w: armW, h: armH, gripX: armGripX, tipX: armTipX)
        }
    }

    /// Sleeve + glove + rifle pointing +x, vertically centred on row 6.
    /// Nodes mount it on a shoulder pivot and steer it at targets.
    static func armTexture(for kind: Kind) -> SKTexture {
        switch kind {
        case .trooper: return trooperArm()
        case .heavy: return heavyArm()
        case .ranger: return rangerArm()
        case .truck: return truckArm()
        case .bombard: return bombardArm()
        case .tank: return tankArm()
        case .enemy: return enemyArm()
        case .brute: return bruteArm()
        case .reaver: return reaverArm()
        case .skitter: return skitterArm()
        case .jet: return jetArm()
        case .mech: return mechArm()
        case .heli: return heliArm()
        case .missileTruck: return missileTruckArm()
        case .immortal: return immortalArm()
        }
    }

    /// Missile truck launcher: a heavy rail gun on a yoke — armored
    /// cradle block, ribbed heat jacket, blast deflector fins and a hot
    /// muzzle brake. The scene aims it like any other arm and the
    /// missiles fly out of the brake.
    private static func missileTruckArm() -> SKTexture {
        let m = armMetrics(for: .missileTruck)
        return canvas(w: m.w, h: m.h, key: "arm-missile-truck") { cg in
            let steel = UIColor(red: 0.34, green: 0.36, blue: 0.42, alpha: 1)
            let steelHi = UIColor(red: 0.58, green: 0.60, blue: 0.66, alpha: 1)
            let steelDk = UIColor(red: 0.17, green: 0.18, blue: 0.22, alpha: 1)
            let hull = UIColor(red: 0.40, green: 0.13, blue: 0.16, alpha: 1)
            let warn = UIColor(red: 1.0, green: 0.72, blue: 0.16, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.42, blue: 0.18, alpha: 1)
            let O = outline
            // Yoke block wrapping the grip (x=8).
            fill(cg, x: 3, y: 5, w: 9, h: 7, O)
            fill(cg, x: 4, y: 6, w: 7, h: 5, steel)
            fill(cg, x: 4, y: 6, w: 7, h: 1, steelHi)
            fill(cg, x: 5, y: 9, w: 2, h: 2, hull)
            // Rail body with a ribbed heat jacket.
            fill(cg, x: 11, y: 4, w: 16, h: 9, O)
            fill(cg, x: 12, y: 5, w: 14, h: 7, steel)
            fill(cg, x: 12, y: 5, w: 14, h: 2, steelHi)
            fill(cg, x: 12, y: 10, w: 14, h: 2, steelDk)
            for rx in [15, 19, 23] {
                fill(cg, x: rx, y: 5, w: 1, h: 7, steelDk)
            }
            // Hazard band at the breech.
            fill(cg, x: 12, y: 5, w: 2, h: 7, warn)
            // Blast deflector fins above and below the brake.
            fill(cg, x: 24, y: 1, w: 4, h: 4, O)
            fill(cg, x: 25, y: 2, w: 3, h: 2, steel)
            fill(cg, x: 24, y: 12, w: 4, h: 4, O)
            fill(cg, x: 25, y: 12, w: 3, h: 2, steel)
            // Muzzle brake with the hot throat inside it.
            fill(cg, x: 27, y: 2, w: 6, h: 13, O)
            fill(cg, x: 28, y: 3, w: 4, h: 11, steel)
            fill(cg, x: 28, y: 3, w: 4, h: 1, steelHi)
            fill(cg, x: 29, y: 4, w: 2, h: 9, glow)
        }
    }

    private static func trooperArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-trooper") { cg in
            let armor = UIColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)
            let suit = UIColor(red: 0.20, green: 0.28, blue: 0.45, alpha: 1)
            let O = outline
            // Sleeve + glove wrapping the grip (x=5).
            fill(cg, x: 2, y: 5, w: 6, h: 3, O)
            fill(cg, x: 3, y: 5, w: 4, h: 2, armor)
            fill(cg, x: 5, y: 4, w: 3, h: 4, O)
            fill(cg, x: 6, y: 5, w: 1, h: 2, suit)
            // Rifle + highlight + team muzzle block.
            fill(cg, x: 8, y: 4, w: 12, h: 4, O)
            fill(cg, x: 9, y: 5, w: 10, h: 2, gunMetal)
            fill(cg, x: 9, y: 5, w: 10, h: 1, UIColor(white: 0.6, alpha: 1))
            fill(cg, x: 18, y: 4, w: 3, h: 4, armor)
            fill(cg, x: 20, y: 5, w: 1, h: 2, .black) // mouth
        }
    }

    private static func heavyArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-heavy") { cg in
            let armor = UIColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)
            let suit = UIColor(red: 0.18, green: 0.25, blue: 0.42, alpha: 1)
            let O = outline
            // Thick sleeve + glove wrapping the grip (x=5).
            fill(cg, x: 2, y: 4, w: 7, h: 5, O)
            fill(cg, x: 3, y: 5, w: 5, h: 3, armor)
            fill(cg, x: 3, y: 5, w: 5, h: 1, .white.withAlphaComponent(0.4))
            fill(cg, x: 5, y: 4, w: 3, h: 5, O)
            fill(cg, x: 6, y: 5, w: 1, h: 3, suit)
            // Support gun + highlight + heavy muzzle.
            fill(cg, x: 8, y: 4, w: 12, h: 5, O)
            fill(cg, x: 9, y: 5, w: 10, h: 3, gunMetal)
            fill(cg, x: 9, y: 5, w: 10, h: 1, UIColor(white: 0.6, alpha: 1))
            fill(cg, x: 18, y: 4, w: 3, h: 5, armor)
        }
    }

    private static func enemyArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-enemy") { cg in
            let chitin = UIColor(red: 0.45, green: 0.12, blue: 0.14, alpha: 1)
            let chitinD = UIColor(red: 0.25, green: 0.08, blue: 0.10, alpha: 1)
            let hide = UIColor(red: 0.20, green: 0.12, blue: 0.14, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.25, blue: 0.15, alpha: 1)
            let O = outline
            // Wiry arm + claw wrapping the grip (x=5).
            fill(cg, x: 2, y: 5, w: 6, h: 3, O)
            fill(cg, x: 3, y: 5, w: 4, h: 2, hide)
            fill(cg, x: 5, y: 4, w: 3, h: 4, O)
            fill(cg, x: 6, y: 5, w: 1, h: 2, chitin)
            // Spike rifle + red tip block + hot tip.
            fill(cg, x: 8, y: 4, w: 12, h: 4, O)
            fill(cg, x: 9, y: 5, w: 10, h: 2, chitinD)
            fill(cg, x: 18, y: 4, w: 3, h: 4, chitin)
            fill(cg, x: 20, y: 3, w: 1, h: 2, glow)
        }
    }

    /// Ranger long rifle: slim stock + extended barrel with amber sight dot.
    private static func rangerArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-ranger") { cg in
            let armor = UIColor(red: 0.35, green: 0.62, blue: 0.38, alpha: 1)
            let suit = UIColor(red: 0.22, green: 0.28, blue: 0.26, alpha: 1)
            let sight = UIColor(red: 1.0, green: 0.80, blue: 0.35, alpha: 1)
            let O = outline
            // Sleeve + glove wrapping the grip (x=5).
            fill(cg, x: 2, y: 5, w: 6, h: 3, O)
            fill(cg, x: 3, y: 5, w: 4, h: 2, armor)
            fill(cg, x: 5, y: 4, w: 3, h: 4, O)
            fill(cg, x: 6, y: 5, w: 1, h: 2, suit)
            // Long barrel + highlight + sight dot + slim muzzle.
            fill(cg, x: 8, y: 5, w: 13, h: 3, O)
            fill(cg, x: 9, y: 5, w: 12, h: 2, gunMetal)
            fill(cg, x: 9, y: 5, w: 12, h: 1, UIColor(white: 0.6, alpha: 1))
            fill(cg, x: 12, y: 3, w: 2, h: 2, O)
            fill(cg, x: 12, y: 3, w: 2, h: 1, sight)
            fill(cg, x: 20, y: 5, w: 2, h: 3, armor)
        }
    }

    /// Brute siege cannon: fat spiked barrel with a furnace-hot muzzle ring.
    private static func bruteArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-brute") { cg in
            let chitin = UIColor(red: 0.52, green: 0.14, blue: 0.16, alpha: 1)
            let chitinD = UIColor(red: 0.28, green: 0.09, blue: 0.11, alpha: 1)
            let hide = UIColor(red: 0.22, green: 0.13, blue: 0.15, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.35, blue: 0.10, alpha: 1)
            let O = outline
            // Thick arm + claw wrapping the grip (x=5).
            fill(cg, x: 2, y: 4, w: 7, h: 5, O)
            fill(cg, x: 3, y: 5, w: 5, h: 3, hide)
            fill(cg, x: 5, y: 4, w: 3, h: 5, O)
            fill(cg, x: 6, y: 5, w: 1, h: 3, chitin)
            // Fat cannon + top spike + furnace muzzle ring.
            fill(cg, x: 8, y: 3, w: 11, h: 6, O)
            fill(cg, x: 9, y: 4, w: 9, h: 4, chitinD)
            fill(cg, x: 12, y: 1, w: 2, h: 3, chitin)
            fill(cg, x: 18, y: 3, w: 3, h: 6, chitin)
            fill(cg, x: 18, y: 4, w: 3, h: 4, glow)
        }
    }

    /// Reaver bone axe: haft pointing +x with twin crescent bone blades
    /// (high + low) at the tip, ember cutting edges. Mounts on the arm
    /// pivot; swung overhead via swing().
    private static func reaverArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-reaver") { cg in
            let haft = UIColor(red: 0.30, green: 0.20, blue: 0.12, alpha: 1)
            let bone = UIColor(red: 0.82, green: 0.76, blue: 0.62, alpha: 1)
            let edge = UIColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 1)
            let flesh = UIColor(red: 0.16, green: 0.10, blue: 0.11, alpha: 1)
            let guard_ = UIColor(red: 0.55, green: 0.48, blue: 0.36, alpha: 1)
            let O = outline
            // Ashen arm + claw wrapping the grip (x=5).
            fill(cg, x: 2, y: 5, w: 6, h: 3, O)
            fill(cg, x: 3, y: 5, w: 4, h: 2, flesh)
            fill(cg, x: 5, y: 4, w: 3, h: 4, O)
            fill(cg, x: 6, y: 5, w: 1, h: 2, guard_)
            // Haft to the tip.
            fill(cg, x: 8, y: 5, w: 10, h: 2, O)
            fill(cg, x: 8, y: 5, w: 10, h: 1, haft)
            // High crescent blade.
            fill(cg, x: 16, y: 0, w: 6, h: 6, O)
            fill(cg, x: 17, y: 1, w: 4, h: 4, bone)
            fill(cg, x: 17, y: 1, w: 4, h: 1, edge) // hot upper edge
            fill(cg, x: 17, y: 1, w: 1, h: 4, .white.withAlphaComponent(0.5))
            // Low crescent blade.
            fill(cg, x: 16, y: 6, w: 6, h: 6, O)
            fill(cg, x: 17, y: 7, w: 4, h: 4, bone)
            fill(cg, x: 17, y: 10, w: 4, h: 1, edge) // hot lower edge
            fill(cg, x: 17, y: 7, w: 1, h: 4, .white.withAlphaComponent(0.5))
        }
    }

    /// Reference turret cannon: compact mantlet + a short, thin olive
    /// barrel with a top highlight and a small muzzle brake. Mounts on
    /// the roof mantlet and steers at targets like a gun-arm.
    private static func truckArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-truck-v2") { cg in
            let olive = UIColor(red: 0.32, green: 0.31, blue: 0.21, alpha: 1)
            let oliveHi = UIColor(red: 0.55, green: 0.54, blue: 0.38, alpha: 1)
            let O = outline
            // Compact mantlet block wrapping the grip (x=5).
            fill(cg, x: 3, y: 5, w: 5, h: 4, O)
            fill(cg, x: 4, y: 6, w: 3, h: 2, olive)
            fill(cg, x: 4, y: 6, w: 3, h: 1, oliveHi)
            // Short thin barrel (2px tall) + highlight + small muzzle brake.
            fill(cg, x: 8, y: 6, w: 9, h: 2, O)
            fill(cg, x: 9, y: 6, w: 8, h: 1, oliveHi)
            fill(cg, x: 9, y: 7, w: 8, h: 1, olive)
            fill(cg, x: 16, y: 5, w: 2, h: 4, O)
            fill(cg, x: 17, y: 6, w: 1, h: 2, olive)
        }
    }

    /// Skitter talon: wiry forelimb ending in a hooked chitin claw with a
    /// hot magenta cutting edge. Mounts on the shoulder pivot and chops
    /// via the same swing() as the reaver axe.
    private static func skitterArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-skitter") { cg in
            let chitin = UIColor(red: 0.48, green: 0.22, blue: 0.58, alpha: 1)
            let hide = UIColor(red: 0.18, green: 0.10, blue: 0.22, alpha: 1)
            let glow = UIColor(red: 1.0, green: 0.30, blue: 0.75, alpha: 1)
            let O = outline
            // Wiry forelimb wrapping the grip (x=5).
            fill(cg, x: 2, y: 5, w: 6, h: 3, O)
            fill(cg, x: 3, y: 5, w: 4, h: 2, hide)
            fill(cg, x: 5, y: 4, w: 3, h: 4, O)
            fill(cg, x: 6, y: 5, w: 1, h: 2, chitin)
            // Hooked talon sweeping up-forward with a hot edge.
            fill(cg, x: 8, y: 3, w: 10, h: 6, O)
            fill(cg, x: 9, y: 4, w: 8, h: 4, chitin)
            fill(cg, x: 9, y: 4, w: 8, h: 1, glow)
            fill(cg, x: 15, y: 1, w: 4, h: 3, O)
            fill(cg, x: 16, y: 1, w: 2, h: 2, .white.withAlphaComponent(0.5))
        }
    }

    // MARK: - Jetpack droid (Level 7 flying enemy)

    /// Bulky flying droid with a propellant jetpack, side view facing +x:
    /// angular helm with a blazing visor, armored torso with a burning
    /// chest core, pauldron + forward gun arm, flight-tucked legs, and a
    /// twin-tank jetpack with flared thruster bells + long exhaust
    /// flames. Poses vary the flames + leg tuck so the hover cycle reads.
    /// The steerable blaster lives in jetArm(); the shoulder joint sits
    /// at canvas (19, 16).
    private static func jet(pose: Int) -> SKTexture {
        canvas(key: "body-jet-\(pose)") { cg in
            let metal = UIColor(red: 0.36, green: 0.38, blue: 0.46, alpha: 1)
            let metalD = UIColor(red: 0.17, green: 0.18, blue: 0.24, alpha: 1)
            let trim = UIColor(red: 0.88, green: 0.22, blue: 0.14, alpha: 1)
            let trimD = UIColor(red: 0.52, green: 0.12, blue: 0.10, alpha: 1)
            let eye = UIColor(red: 1.0, green: 0.22, blue: 0.12, alpha: 1)
            let core = UIColor(red: 1.0, green: 0.50, blue: 0.15, alpha: 1)
            let flame = UIColor(red: 1.0, green: 0.60, blue: 0.16, alpha: 1)
            let flameHi = UIColor(red: 1.0, green: 0.92, blue: 0.60, alpha: 1)
            let O = outline
            let flameLen = [3, 4, 5, 4][pose]
            let tuck = [0, 1, 0, -1][pose] // leg-tuck sway

            // Jetpack: twin armored tanks + frame on the droid's back.
            fill(cg, x: 4, y: 10, w: 6, h: 9, O)
            fill(cg, x: 5, y: 11, w: 4, h: 7, metalD)
            fill(cg, x: 5, y: 11, w: 1, h: 7, metal)
            fill(cg, x: 7, y: 11, w: 1, h: 7, metal)
            fill(cg, x: 5, y: 10, w: 4, h: 1, metal)      // tank caps
            fill(cg, x: 4, y: 14, w: 6, h: 2, trimD)       // warning band
            fill(cg, x: 5, y: 14, w: 1, h: 2, trim)
            fill(cg, x: 8, y: 14, w: 1, h: 2, trim)
            // Stabilizer fin on top.
            fill(cg, x: 5, y: 7, w: 2, h: 3, O)
            fill(cg, x: 5, y: 7, w: 1, h: 3, trim)
            // Flared thruster bells + long exhaust flames below.
            for (nx, extra) in [(4, 0), (7, -1)] {
                fill(cg, x: nx, y: 19, w: 3, h: 2, O)
                fill(cg, x: nx, y: 19, w: 3, h: 1, metalD)
                fill(cg, x: nx + 1, y: 20, w: 1, h: 1, core)
                let len = max(2, flameLen + extra)
                fill(cg, x: nx, y: 21, w: 3, h: len, flame)
                fill(cg, x: nx + 1, y: 21, w: 1, h: len, flameHi)
            }
            // Bulky armored torso: pec plates, burning core, waist trim.
            fill(cg, x: 10, y: 13, w: 9, h: 9, O)
            fill(cg, x: 11, y: 14, w: 7, h: 7, metal)
            fill(cg, x: 11, y: 14, w: 7, h: 1, .white.withAlphaComponent(0.45))
            fill(cg, x: 11, y: 16, w: 7, h: 1, metalD)     // plate seam
            fill(cg, x: 13, y: 17, w: 3, h: 3, O)
            fill(cg, x: 14, y: 18, w: 2, h: 2, core)
            fill(cg, x: 14, y: 18, w: 2, h: 1, flameHi)
            fill(cg, x: 11, y: 20, w: 7, h: 1, trimD)      // waist band
            fill(cg, x: 11, y: 21, w: 7, h: 1, metalD)
            // Angular helm: heavy brow, blazing visor, chin guard.
            fill(cg, x: 12, y: 6, w: 7, h: 7, O)
            fill(cg, x: 13, y: 7, w: 5, h: 5, metal)
            fill(cg, x: 13, y: 7, w: 5, h: 1, .white.withAlphaComponent(0.45))
            fill(cg, x: 13, y: 9, w: 6, h: 3, O)
            fill(cg, x: 14, y: 10, w: 4, h: 1, eye)
            fill(cg, x: 17, y: 10, w: 1, h: 1, .white)
            fill(cg, x: 13, y: 12, w: 4, h: 1, metalD)     // chin guard
            // Sensor antenna with a blinking-red tip.
            fill(cg, x: 13, y: 4, w: 1, h: 2, O)
            fill(cg, x: 16, y: 3, w: 1, h: 3, O)
            fill(cg, x: 16, y: 2, w: 1, h: 1, pose % 2 == 0 ? trim : trimD)
            // Front pauldron + gun arm reaching toward +x.
            fill(cg, x: 18, y: 13, w: 3, h: 4, O)
            fill(cg, x: 19, y: 14, w: 1, h: 2, trim)
            fill(cg, x: 19, y: 16, w: 4, h: 3, O)
            fill(cg, x: 20, y: 17, w: 3, h: 1, metal)
            // Flight-tucked legs: knees kicked back, boots trailing.
            fill(cg, x: 10 - tuck, y: 22, w: 3, h: 2, O)
            fill(cg, x: 10 - tuck, y: 22, w: 2, h: 1, metalD)
            fill(cg, x: 7 - tuck, y: 23, w: 4, h: 2, O)
            fill(cg, x: 7 - tuck, y: 24, w: 3, h: 1, metalD)
            fill(cg, x: 5 - tuck, y: 23, w: 2, h: 2, O)
            fill(cg, x: 5 - tuck, y: 24, w: 1, h: 1, trim)
            fill(cg, x: 13 + tuck, y: 22, w: 3, h: 2, O)
            fill(cg, x: 14 + tuck, y: 22, w: 2, h: 1, metalD)
            fill(cg, x: 13 + tuck, y: 24, w: 4, h: 2, O)
            fill(cg, x: 14 + tuck, y: 25, w: 3, h: 1, metalD)
            fill(cg, x: 16 + tuck, y: 24, w: 2, h: 2, O)
            fill(cg, x: 17 + tuck, y: 25, w: 1, h: 1, trim)
        }
    }

    /// Droid blaster: compact receiver + thin barrel with a red tip.
    /// Mounts on the shoulder joint and steers at targets like a gun-arm.
    private static func jetArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-jet") { cg in
            let metal = UIColor(red: 0.34, green: 0.36, blue: 0.44, alpha: 1)
            let metalD = UIColor(red: 0.17, green: 0.18, blue: 0.24, alpha: 1)
            let trim = UIColor(red: 0.85, green: 0.20, blue: 0.14, alpha: 1)
            let O = outline
            // Grip mount wrapping the shoulder joint (x=5).
            fill(cg, x: 2, y: 4, w: 6, h: 5, O)
            fill(cg, x: 3, y: 5, w: 4, h: 3, metal)
            fill(cg, x: 3, y: 5, w: 4, h: 1, .white.withAlphaComponent(0.4))
            // Receiver + power cell.
            fill(cg, x: 8, y: 5, w: 7, h: 3, O)
            fill(cg, x: 9, y: 6, w: 5, h: 1, metalD)
            fill(cg, x: 12, y: 5, w: 2, h: 3, trim)
            // Thin barrel + red tip at the muzzle (x=21).
            fill(cg, x: 15, y: 5, w: 6, h: 3, O)
            fill(cg, x: 16, y: 6, w: 4, h: 1, metalD)
            fill(cg, x: 19, y: 5, w: 2, h: 3, trim)
        }
    }

    // MARK: - Heli Gunship (Level 13 flying enemy)

    /// Futuristic attack helicopter (64x36), side view facing +x: a long
    /// tail boom with a spinning tail rotor, dark angular fuselage with
    /// crimson warning trim, amber canopy, engine nacelle with a hot
    /// exhaust, stub wings with a missile pod, and a chin gun mount.
    /// The 4 poses flicker the main/tail rotor blades so the hover reads
    /// in motion even while holding station. The aimable chin gun lives
    /// in heliArm(); the pivot sits at canvas (43, 29).
    private static func heli(pose: Int) -> SKTexture {
        canvas(w: 64, h: 36, key: "body-heli-\(pose)") { cg in
            let hull = UIColor(red: 0.24, green: 0.28, blue: 0.35, alpha: 1)
            let hullHi = UIColor(red: 0.40, green: 0.47, blue: 0.56, alpha: 1)
            let hullD = UIColor(red: 0.13, green: 0.16, blue: 0.21, alpha: 1)
            let hullLt = UIColor(red: 0.52, green: 0.59, blue: 0.67, alpha: 1)
            let trim = UIColor(red: 0.90, green: 0.22, blue: 0.16, alpha: 1)
            let trimD = UIColor(red: 0.48, green: 0.10, blue: 0.09, alpha: 1)
            let glass = UIColor(red: 1.0, green: 0.62, blue: 0.16, alpha: 1)
            let glassHi = UIColor(red: 1.0, green: 0.90, blue: 0.58, alpha: 1)
            let blade = UIColor(red: 0.34, green: 0.38, blue: 0.45, alpha: 1)
            let bladeD = UIColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1)
            let bladeHi = UIColor(red: 0.64, green: 0.70, blue: 0.78, alpha: 1)
            let hot = UIColor(red: 1.0, green: 0.48, blue: 0.12, alpha: 1)
            let O = outline

            let rotorLift = [0, 1, 0, -1][pose]
            let tailLift = [0, 1, 2, 1][pose]

            // --- Tail rotor: vertical blur disc + flickering cross blades.
            fill(cg, x: 2, y: 7 + tailLift, w: 2, h: 11, bladeD)
            fill(cg, x: 4, y: 8 + tailLift, w: 1, h: 9, blade)
            fill(cg, x: 1, y: 11 + tailLift, w: 6, h: 1, blade)
            if pose % 2 == 0 {
                fill(cg, x: 3, y: 6 + tailLift, w: 1, h: 2, bladeHi)
            } else {
                fill(cg, x: 2, y: 14 + tailLift, w: 3, h: 1, bladeHi)
            }

            // --- Tail boom, swept fin, and stabilizer.
            fill(cg, x: 7, y: 18, w: 17, h: 5, O)
            fill(cg, x: 8, y: 19, w: 16, h: 3, hullD)
            fill(cg, x: 8, y: 19, w: 16, h: 1, hull)
            fill(cg, x: 10, y: 20, w: 13, h: 1, trim)
            fill(cg, x: 6, y: 10, w: 5, h: 10, O)
            fill(cg, x: 7, y: 11, w: 3, h: 8, hullD)
            fill(cg, x: 7, y: 11, w: 1, h: 4, trim)
            fill(cg, x: 5, y: 16, w: 2, h: 4, O)
            fill(cg, x: 5, y: 17, w: 2, h: 2, trimD)

            // --- Main rotor: a wide blurred disc that shimmers per pose.
            fill(cg, x: 5, y: 2 + rotorLift, w: 54, h: 1, bladeD)
            fill(cg, x: 8, y: 3 + rotorLift, w: 48, h: 1, blade)
            fill(cg, x: 15, y: 4 + rotorLift, w: 35, h: 1, bladeHi)
            fill(cg, x: 11, y: 2 + rotorLift, w: 40, h: 1,
                 blade.withAlphaComponent(0.35))
            if pose == 1 || pose == 3 {
                fill(cg, x: 2, y: 3 + rotorLift, w: 3, h: 1, blade)
                fill(cg, x: 60, y: 3 + rotorLift, w: 3, h: 1, blade)
            }
            fill(cg, x: 32, y: 4, w: 6, h: 3, O)
            fill(cg, x: 33, y: 4, w: 4, h: 2, hullHi)
            fill(cg, x: 34, y: 5, w: 3, h: 9, O)
            fill(cg, x: 35, y: 5, w: 1, h: 8, hullLt)

            // --- Engine nacelle + exhaust glow on the rear deck.
            fill(cg, x: 22, y: 10, w: 11, h: 6, O)
            fill(cg, x: 23, y: 11, w: 9, h: 4, hullHi)
            fill(cg, x: 23, y: 13, w: 9, h: 2, hullD)
            fill(cg, x: 24, y: 11, w: 2, h: 2, hullLt)
            fill(cg, x: 21, y: 12, w: 1, h: 3, hot)
            fill(cg, x: 22, y: 12, w: 1, h: 2, trim)

            // --- Angular fuselage silhouette.
            fill(cg, x: 22, y: 14, w: 28, h: 13, O)
            fill(cg, x: 25, y: 12, w: 20, h: 2, O)
            fill(cg, x: 19, y: 17, w: 4, h: 8, O)
            fill(cg, x: 49, y: 16, w: 6, h: 11, O)
            fill(cg, x: 53, y: 19, w: 2, h: 5, O)
            fill(cg, x: 23, y: 15, w: 26, h: 11, hull)
            fill(cg, x: 26, y: 13, w: 19, h: 2, hullHi)
            fill(cg, x: 20, y: 18, w: 3, h: 6, hullD)
            fill(cg, x: 49, y: 17, w: 5, h: 9, hull)
            fill(cg, x: 53, y: 20, w: 1, h: 3, hull)
            fill(cg, x: 24, y: 15, w: 22, h: 1, .white.withAlphaComponent(0.28))
            fill(cg, x: 24, y: 24, w: 22, h: 2, hullD)
            fill(cg, x: 49, y: 23, w: 5, h: 3, hullD)
            fill(cg, x: 26, y: 13, w: 14, h: 1, hullLt)

            // --- Armor panel, vents, insignia + crimson warning stripe.
            fill(cg, x: 28, y: 18, w: 14, h: 6, O)
            fill(cg, x: 29, y: 19, w: 12, h: 4, hullD)
            fill(cg, x: 29, y: 20, w: 12, h: 1, trim)
            fill(cg, x: 30, y: 22, w: 5, h: 1, hull)
            fill(cg, x: 39, y: 20, w: 2, h: 2, trim)
            fill(cg, x: 40, y: 20, w: 1, h: 1, glass)

            // --- Amber canopy at the nose with a pilot silhouette.
            fill(cg, x: 45, y: 16, w: 6, h: 7, O)
            fill(cg, x: 46, y: 17, w: 4, h: 5, glass)
            fill(cg, x: 47, y: 17, w: 2, h: 1, glassHi)
            fill(cg, x: 46, y: 19, w: 1, h: 3, glassHi.withAlphaComponent(0.55))
            fill(cg, x: 49, y: 18, w: 1, h: 3, hullD)
            fill(cg, x: 54, y: 20, w: 1, h: 1, pose % 2 == 0 ? trim : .white)

            // --- Stub wing + missile pod under the mid-body.
            fill(cg, x: 29, y: 24, w: 14, h: 3, O)
            fill(cg, x: 30, y: 24, w: 12, h: 2, hullLt)
            fill(cg, x: 31, y: 26, w: 8, h: 4, O)
            fill(cg, x: 32, y: 27, w: 6, h: 2, hullD)
            fill(cg, x: 36, y: 27, w: 2, h: 2, trim)
            fill(cg, x: 34, y: 27, w: 1, h: 1, hullHi)

            // --- Chin gun mount; the aimable barrels are heliArm().
            fill(cg, x: 41, y: 25, w: 6, h: 4, O)
            fill(cg, x: 42, y: 26, w: 4, h: 2, hullHi)
            fill(cg, x: 43, y: 27, w: 2, h: 1, trimD)
        }
    }

    /// Chin-mounted rotary machine gun: armored mount + power cell +
    /// three stacked barrels. Mounts at the nose belly (pivot canvas x=5)
    /// and steers with the scene's aimAt(_) just like the other gun-arms.
    private static func heliArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-heli") { cg in
            let hull = UIColor(red: 0.26, green: 0.30, blue: 0.37, alpha: 1)
            let hullHi = UIColor(red: 0.48, green: 0.55, blue: 0.63, alpha: 1)
            let hullD = UIColor(red: 0.13, green: 0.16, blue: 0.21, alpha: 1)
            let trim = UIColor(red: 0.90, green: 0.22, blue: 0.16, alpha: 1)
            let metal = UIColor(red: 0.18, green: 0.20, blue: 0.25, alpha: 1)
            let hot = UIColor(red: 1.0, green: 0.58, blue: 0.16, alpha: 1)
            let O = outline
            // Armored mount wrapping the grip (x=5).
            fill(cg, x: 1, y: 2, w: 8, h: 8, O)
            fill(cg, x: 2, y: 3, w: 6, h: 6, hull)
            fill(cg, x: 2, y: 3, w: 6, h: 1, hullHi)
            fill(cg, x: 2, y: 7, w: 6, h: 1, trim)
            // Receiver + hot power cell.
            fill(cg, x: 8, y: 3, w: 7, h: 6, O)
            fill(cg, x: 9, y: 4, w: 5, h: 4, hullD)
            fill(cg, x: 9, y: 4, w: 5, h: 1, hull)
            fill(cg, x: 12, y: 5, w: 1, h: 2, hot)
            // Triple rotary barrels + muzzle block.
            fill(cg, x: 14, y: 3, w: 8, h: 2, O)
            fill(cg, x: 15, y: 3, w: 6, h: 1, metal)
            fill(cg, x: 14, y: 5, w: 8, h: 2, O)
            fill(cg, x: 15, y: 5, w: 6, h: 1, hullHi)
            fill(cg, x: 14, y: 7, w: 8, h: 2, O)
            fill(cg, x: 15, y: 7, w: 6, h: 1, metal)
            fill(cg, x: 20, y: 3, w: 2, h: 6, trim)
        }
    }

    // MARK: - Mech walker (Level 9 heavy robot)

    /// Mech torso (48x26): a squat olive siege walker in the reference
    /// style — rounded carapace, big ball pauldron on the back side, pale
    /// racing stripes, a front sensor eye + grille, a hanging fist arm, and
    /// a top turret ring. The shooting cannon is a separate arm sprite
    /// (see mechArm); the legs are separate too (see mechLeg) so the gait
    /// can articulate instead of sliding.
    private static func mechBody() -> SKTexture {
        canvas(w: 48, h: 26, key: "body-mech-v5") { cg in
            let olive = UIColor(red: 0.31, green: 0.36, blue: 0.19, alpha: 1)
            let oliveHi = UIColor(red: 0.48, green: 0.54, blue: 0.29, alpha: 1)
            let oliveLt = UIColor(red: 0.62, green: 0.66, blue: 0.42, alpha: 1)
            let oliveD = UIColor(red: 0.19, green: 0.23, blue: 0.11, alpha: 1)
            let oliveDk = UIColor(red: 0.11, green: 0.14, blue: 0.07, alpha: 1)
            let yellow = UIColor(red: 0.94, green: 0.71, blue: 0.16, alpha: 1)
            let eye = UIColor(red: 0.24, green: 0.56, blue: 1.0, alpha: 1)
            let eyeHi = UIColor(red: 0.75, green: 0.92, blue: 1.0, alpha: 1)
            let metal = UIColor(red: 0.30, green: 0.33, blue: 0.29, alpha: 1)
            let metalHi = UIColor(red: 0.56, green: 0.59, blue: 0.52, alpha: 1)
            let black = UIColor(red: 0.07, green: 0.08, blue: 0.07, alpha: 1)
            let O = outline

            // --- Big ball pauldron on the back side.
            fill(cg, x: 5, y: 6, w: 9, h: 2, O)
            fill(cg, x: 3, y: 8, w: 13, h: 3, O)
            fill(cg, x: 2, y: 11, w: 15, h: 9, O)
            fill(cg, x: 4, y: 20, w: 11, h: 2, O)
            fill(cg, x: 6, y: 22, w: 7, h: 1, O)
            fill(cg, x: 4, y: 9, w: 11, h: 10, olive)
            fill(cg, x: 6, y: 7, w: 7, h: 1, oliveHi)
            fill(cg, x: 4, y: 9, w: 4, h: 2, oliveLt)
            fill(cg, x: 5, y: 12, w: 2, h: 5, oliveLt)
            fill(cg, x: 4, y: 18, w: 10, h: 2, oliveD)
            fill(cg, x: 6, y: 21, w: 7, h: 1, oliveDk)
            // Yellow stripe wrapping the visible crescent of the ball.
            fill(cg, x: 5, y: 8, w: 2, h: 2, yellow)
            fill(cg, x: 6, y: 10, w: 1, h: 5, yellow)
            fill(cg, x: 5, y: 15, w: 2, h: 2, yellow)
            fill(cg, x: 6, y: 12, w: 1, h: 1, oliveDk)
            fill(cg, x: 7, y: 11, w: 1, h: 1, oliveHi)

            // --- Rear arm + black fist hanging below the ball.
            fill(cg, x: 3, y: 19, w: 7, h: 4, O)
            fill(cg, x: 4, y: 20, w: 5, h: 2, oliveD)
            fill(cg, x: 4, y: 20, w: 5, h: 1, olive)
            fill(cg, x: 1, y: 22, w: 9, h: 4, O)
            fill(cg, x: 2, y: 23, w: 7, h: 2, black)
            fill(cg, x: 3, y: 23, w: 1, h: 1, metal)
            fill(cg, x: 6, y: 23, w: 1, h: 1, metal)
            fill(cg, x: 9, y: 22, w: 1, h: 2, oliveD)

            // --- Rounded main carapace.
            fill(cg, x: 13, y: 0, w: 22, h: 2, O)
            fill(cg, x: 10, y: 2, w: 28, h: 2, O)
            fill(cg, x: 8, y: 4, w: 34, h: 2, O)
            fill(cg, x: 7, y: 6, w: 36, h: 12, O)
            fill(cg, x: 8, y: 18, w: 34, h: 2, O)
            fill(cg, x: 11, y: 20, w: 28, h: 1, O)
            fill(cg, x: 13, y: 1, w: 22, h: 1, olive)
            fill(cg, x: 11, y: 3, w: 26, h: 1, olive)
            fill(cg, x: 9, y: 5, w: 32, h: 1, olive)
            fill(cg, x: 8, y: 7, w: 34, h: 10, olive)
            fill(cg, x: 9, y: 17, w: 32, h: 2, olive)
            fill(cg, x: 12, y: 19, w: 26, h: 1, olive)
            fill(cg, x: 13, y: 1, w: 18, h: 1, oliveHi)
            fill(cg, x: 11, y: 3, w: 16, h: 1, oliveHi)
            fill(cg, x: 9, y: 5, w: 12, h: 1, oliveHi)
            fill(cg, x: 9, y: 7, w: 3, h: 8, oliveLt)
            fill(cg, x: 10, y: 17, w: 30, h: 1, oliveD)
            fill(cg, x: 10, y: 18, w: 30, h: 1, oliveD)
            fill(cg, x: 12, y: 19, w: 26, h: 1, oliveDk)

            // --- Pelvis skirt down to the leg sockets (keeps the body
            // visually bolted to the legs instead of floating above them).
            fill(cg, x: 17, y: 19, w: 14, h: 7, O)
            fill(cg, x: 18, y: 20, w: 12, h: 5, oliveD)
            fill(cg, x: 19, y: 20, w: 10, h: 2, olive)
            fill(cg, x: 19, y: 20, w: 10, h: 1, oliveHi)
            fill(cg, x: 18, y: 24, w: 12, h: 1, oliveDk)
            fill(cg, x: 18, y: 23, w: 5, h: 3, O)
            fill(cg, x: 19, y: 24, w: 3, h: 1, metal)
            fill(cg, x: 25, y: 23, w: 5, h: 3, O)
            fill(cg, x: 26, y: 24, w: 3, h: 1, metal)

            // --- Panel lines, hatch, bolts, racing stripes.
            fill(cg, x: 24, y: 7, w: 1, h: 10, oliveD)
            fill(cg, x: 12, y: 9, w: 11, h: 1, oliveD)
            fill(cg, x: 26, y: 12, w: 10, h: 1, oliveD)
            fill(cg, x: 12, y: 11, w: 7, h: 4, oliveD)
            fill(cg, x: 13, y: 12, w: 5, h: 2, olive)
            fill(cg, x: 13, y: 12, w: 5, h: 1, oliveHi)
            fill(cg, x: 11, y: 7, w: 1, h: 1, oliveLt)
            fill(cg, x: 40, y: 7, w: 1, h: 1, oliveLt)
            fill(cg, x: 11, y: 16, w: 1, h: 1, oliveLt)
            fill(cg, x: 30, y: 6, w: 2, h: 10, oliveLt)
            fill(cg, x: 34, y: 6, w: 1, h: 10, oliveLt)
            fill(cg, x: 12, y: 18, w: 3, h: 1, yellow)
            fill(cg, x: 17, y: 18, w: 3, h: 1, yellow)

            // --- Front face: grille + round blue sensor eye.
            fill(cg, x: 37, y: 7, w: 7, h: 9, O)
            fill(cg, x: 38, y: 8, w: 5, h: 7, oliveDk)
            fill(cg, x: 38, y: 9, w: 2, h: 1, metal)
            fill(cg, x: 38, y: 11, w: 2, h: 1, metal)
            fill(cg, x: 38, y: 13, w: 2, h: 1, metal)
            fill(cg, x: 40, y: 9, w: 4, h: 4, O)
            fill(cg, x: 41, y: 10, w: 2, h: 2, eye)
            fill(cg, x: 41, y: 10, w: 1, h: 1, eyeHi)

            // --- Turret ring on top (the animated cannon mounts here).
            fill(cg, x: 33, y: 1, w: 10, h: 4, O)
            fill(cg, x: 34, y: 2, w: 8, h: 2, metal)
            fill(cg, x: 35, y: 2, w: 6, h: 1, metalHi)
            fill(cg, x: 34, y: 4, w: 8, h: 1, oliveD)

            // --- Front arm + black fist hanging under the shoulder.
            fill(cg, x: 34, y: 13, w: 9, h: 6, O)
            fill(cg, x: 35, y: 14, w: 7, h: 4, oliveD)
            fill(cg, x: 35, y: 14, w: 7, h: 1, olive)
            fill(cg, x: 33, y: 18, w: 12, h: 5, O)
            fill(cg, x: 34, y: 19, w: 10, h: 3, olive)
            fill(cg, x: 34, y: 19, w: 10, h: 1, oliveHi)
            fill(cg, x: 34, y: 21, w: 10, h: 1, yellow)
        }
    }

    /// One hero-style mech leg (16x20): thigh + shin with a forward-bent
    /// knee, armored knee pad, and a boot with a yellow cap, black sole and
    /// a pointed toe claw. The stride table mirrors the astronaut walk
    /// cycle (contact / support / toe-off / swing) so it reads as the same
    /// gait, just slower and heavier.
    private static func mechLeg(front: Bool, phase: Int) -> SKTexture {
        canvas(w: 16, h: 20, key: "mech-leg-\(front ? "f" : "b")-\(phase)") { cg in
            let olive = front
                ? UIColor(red: 0.31, green: 0.36, blue: 0.19, alpha: 1)
                : UIColor(red: 0.17, green: 0.21, blue: 0.10, alpha: 1)
            let oliveHi = front
                ? UIColor(red: 0.50, green: 0.56, blue: 0.30, alpha: 1)
                : UIColor(red: 0.27, green: 0.31, blue: 0.16, alpha: 1)
            let oliveD = front
                ? UIColor(red: 0.18, green: 0.22, blue: 0.10, alpha: 1)
                : UIColor(red: 0.10, green: 0.12, blue: 0.06, alpha: 1)
            let yellow = front
                ? UIColor(red: 0.94, green: 0.71, blue: 0.16, alpha: 1)
                : UIColor(red: 0.52, green: 0.38, blue: 0.10, alpha: 1)
            let black = UIColor(red: 0.06, green: 0.07, blue: 0.06, alpha: 1)
            let O = outline
            // Astronaut-style stride: (forward offset, foot lift).
            let strides = [(3, 0), (0, 0), (-3, 1), (1, 3)]
            let stride = strides[phase % 4]
            let hipX = 8, top = 1, len = 16
            let footX = hipX + stride.0
            let footY = top + len - stride.1
            let kneeX = (hipX + footX) / 2 + 1
            let kneeY = (top + footY) / 2

            // Hip ball joint.
            fill(cg, x: 5, y: 0, w: 7, h: 4, O)
            fill(cg, x: 6, y: 1, w: 5, h: 2, oliveD)
            fill(cg, x: 6, y: 1, w: 2, h: 1, oliveHi)

            // Thigh + shin.
            segment(cg, x0: hipX, y0: top, x1: kneeX, y1: kneeY, w: 6, color: O)
            segment(cg, x0: hipX, y0: top, x1: kneeX, y1: kneeY, w: 4, color: olive)
            segment(cg, x0: kneeX, y0: kneeY, x1: footX, y1: footY, w: 5, color: O)
            segment(cg, x0: kneeX, y0: kneeY, x1: footX, y1: footY, w: 3, color: oliveD)

            // Armored knee pad with a yellow accent.
            fill(cg, x: kneeX - 3, y: kneeY - 2, w: 6, h: 5, O)
            fill(cg, x: kneeX - 2, y: kneeY - 1, w: 4, h: 3, oliveHi)
            fill(cg, x: kneeX - 2, y: kneeY - 1, w: 4, h: 1, olive)
            fill(cg, x: kneeX - 1, y: kneeY + 1, w: 2, h: 1, yellow)

            // Boot: yellow cap, olive body, black sole.
            fill(cg, x: footX - 3, y: footY, w: 7, h: 3, O)
            fill(cg, x: footX - 2, y: footY, w: 5, h: 2, olive)
            fill(cg, x: footX - 2, y: footY, w: 5, h: 1, yellow)
            fill(cg, x: footX - 2, y: footY + 2, w: 5, h: 1, black)
            // Pointed toe claw + heel.
            fill(cg, x: footX + 2, y: footY + 1, w: 2, h: 2, O)
            fill(cg, x: footX + 2, y: footY + 2, w: 1, h: 1, black)
            fill(cg, x: footX - 3, y: footY + 1, w: 1, h: 2, black)
            fill(cg, x: hipX + 2, y: top + 1, w: 1, h: 1, yellow)
        }
    }

    /// Mech turret cannon: an olive armored mantlet wrapping the grip with
    /// a yellow hazard band, feeding three stacked gatling barrels with
    /// ring bands and a hot muzzle block. Mounts on the top turret ring and
    /// steers/fires like the truck's cannon.
    private static func mechArm() -> SKTexture {
        canvas(w: armW, h: armH, key: "arm-mech-v3") { cg in
            let olive = UIColor(red: 0.31, green: 0.36, blue: 0.19, alpha: 1)
            let oliveHi = UIColor(red: 0.50, green: 0.56, blue: 0.30, alpha: 1)
            let oliveD = UIColor(red: 0.16, green: 0.20, blue: 0.09, alpha: 1)
            let yellow = UIColor(red: 0.94, green: 0.71, blue: 0.16, alpha: 1)
            let metal = UIColor(red: 0.24, green: 0.27, blue: 0.25, alpha: 1)
            let metalHi = UIColor(red: 0.55, green: 0.58, blue: 0.52, alpha: 1)
            let hot = UIColor(red: 1.0, green: 0.50, blue: 0.14, alpha: 1)
            let O = outline
            // Rounded mantlet wrapping the grip (x=5).
            fill(cg, x: 1, y: 2, w: 10, h: 8, O)
            fill(cg, x: 2, y: 3, w: 8, h: 6, olive)
            fill(cg, x: 2, y: 3, w: 8, h: 1, oliveHi)
            fill(cg, x: 2, y: 6, w: 8, h: 1, yellow)
            fill(cg, x: 2, y: 8, w: 8, h: 1, oliveD)
            fill(cg, x: 4, y: 4, w: 1, h: 1, oliveHi)
            // Three stacked gatling barrels.
            fill(cg, x: 10, y: 3, w: 12, h: 2, O)
            fill(cg, x: 11, y: 3, w: 11, h: 1, metalHi)
            fill(cg, x: 10, y: 5, w: 12, h: 2, O)
            fill(cg, x: 11, y: 5, w: 11, h: 1, metal)
            fill(cg, x: 10, y: 7, w: 12, h: 2, O)
            fill(cg, x: 11, y: 7, w: 11, h: 1, metalHi)
            // Ring bands around the cluster.
            fill(cg, x: 15, y: 2, w: 1, h: 8, metal)
            fill(cg, x: 19, y: 2, w: 1, h: 8, metal)
            // Muzzle block + hot bore.
            fill(cg, x: 21, y: 2, w: 3, h: 8, O)
            fill(cg, x: 22, y: 3, w: 1, h: 6, metal)
            fill(cg, x: 22, y: 5, w: 1, h: 2, hot)
        }
    }
}
