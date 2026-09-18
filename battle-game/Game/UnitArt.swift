import SpriteKit
import UIKit

/// Pixel-art unit sprites in the tower/HQ style (low-res textures,
/// `.nearest` filtering). Side view, facing +x; the scene mirrors them
/// via negative xScale for left-facing marchers.
///
/// Each unit has 2 walk frames (leg poses) + the nodes swap them while
/// advancing for a scuttling march cycle.
enum UnitPixelArt {

    enum Kind { case trooper, heavy, ranger, enemy, brute }

    /// Walk frames for a kind: full 4-step stride
    /// (contact -> support -> toe-off -> swing). Generated once, shared.
    static func frames(for kind: Kind) -> [SKTexture] {
        switch kind {
        case .trooper: return (0...3).map { trooper(pose: $0) }
        case .heavy: return (0...3).map { heavy(pose: $0) }
        case .ranger: return (0...3).map { ranger(pose: $0) }
        case .enemy: return (0...3).map { enemy(pose: $0) }
        case .brute: return (0...3).map { brute(pose: $0) }
        }
    }

    // MARK: - Canvas

    private static let W = 24, H = 32

    private static func canvas(w: Int = W, h: Int = H, key: String? = nil,
                               draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h),
                                           format: format).image { ctx in
            draw(ctx.cgContext) // UIKit coords: row 0 = top
        }
        if let key { imageCache[key] = img }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
    }

    /// Raw pixel images behind the cached textures (for SwiftUI portraits).
    private static var imageCache: [String: UIImage] = [:]
    /// Composed card portraits, built once per kind.
    private static var portraitCache: [Kind: UIImage] = [:]

    /// Card portrait: torso-up crop of the real sprite + its gun-arm raised
    /// at a heroic angle, gun breaking out of frame. 36x24 px — show it
    /// with `.interpolation(.none)` so pixels stay crisp when upscaled.
    static func portraitImage(for kind: Kind) -> UIImage {
        if let cached = portraitCache[kind] { return cached }
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
        case .enemy:
            bodyKey = "body-enemy-0"; armKey = "arm-enemy"
            shoulder = CGPoint(x: 16, y: 14)
        case .brute:
            bodyKey = "body-brute-0"; armKey = "arm-brute"
            shoulder = CGPoint(x: 16, y: 15)
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

    /// Sleeve + glove + rifle pointing +x, vertically centred on row 6.
    /// Nodes mount it on a shoulder pivot and steer it at targets.
    static func armTexture(for kind: Kind) -> SKTexture {
        switch kind {
        case .trooper: return trooperArm()
        case .heavy: return heavyArm()
        case .ranger: return rangerArm()
        case .enemy: return enemyArm()
        case .brute: return bruteArm()
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
}
