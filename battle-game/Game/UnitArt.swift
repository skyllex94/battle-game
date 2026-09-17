import SpriteKit
import UIKit

/// Pixel-art unit sprites in the tower/HQ style (low-res textures,
/// `.nearest` filtering). Side view, facing +x; the scene mirrors them
/// via negative xScale for left-facing marchers.
///
/// Each unit has 2 walk frames (leg poses) + the nodes swap them while
/// advancing for a scuttling march cycle.
enum UnitPixelArt {

    enum Kind { case trooper, heavy, enemy }

    /// Walk frames for a kind. Generated once, shared by all units.
    static func frames(for kind: Kind) -> [SKTexture] {
        switch kind {
        case .trooper: return [trooper(pose: 0), trooper(pose: 1)]
        case .heavy: return [heavy(pose: 0), heavy(pose: 1)]
        case .enemy: return [enemy(pose: 0), enemy(pose: 1)]
        }
    }

    // MARK: - Canvas

    private static let W = 24, H = 32

    private static func canvas(_ draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: W, height: H),
                                           format: format).image { ctx in
            draw(ctx.cgContext) // UIKit coords: row 0 = top
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
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
        canvas { cg in
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
            // Rifle pointing +x + arm.
            fill(cg, x: 14, y: 11, w: 3, h: 3, suit) // arm
            fill(cg, x: 15, y: 12, w: 8, h: 3, O)
            fill(cg, x: 16, y: 13, w: 6, h: 1, gunMetal)
            fill(cg, x: 21, y: 12, w: 2, h: 3, armor) // muzzle block
            // Legs (march poses).
            legs(cg, pose: pose, cx: 12, top: 18, len: 9,
                 pants: suit, boots: dark, outline: O)
        }
    }

    // MARK: - Player heavy (bulky gunner)

    private static func heavy(pose: Int) -> SKTexture {
        canvas { cg in
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
            // Big gun + supporting arm.
            fill(cg, x: 14, y: 12, w: 3, h: 4, suit)
            fill(cg, x: 15, y: 13, w: 8, h: 4, O)
            fill(cg, x: 16, y: 14, w: 6, h: 2, gunMetal)
            fill(cg, x: 16, y: 14, w: 6, h: 1, UIColor(white: 0.6, alpha: 1))
            fill(cg, x: 21, y: 13, w: 2, h: 4, armor)
            // Thick legs.
            legs(cg, pose: pose, cx: 12, top: 20, len: 8,
                 pants: suit, boots: dark, outline: O, wide: true)
        }
    }

    // MARK: - Enemy raider (red alien)

    private static func enemy(pose: Int) -> SKTexture {
        canvas { cg in
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
            // Claw arm + spike rifle.
            fill(cg, x: 14, y: 11, w: 3, h: 3, hide)
            fill(cg, x: 15, y: 12, w: 7, h: 3, O)
            fill(cg, x: 16, y: 13, w: 5, h: 1, hide)
            fill(cg, x: 20, y: 12, w: 2, h: 3, chitin) // spike tip block
            fill(cg, x: 21, y: 11, w: 1, h: 1, glow)   // hot tip
            // Digitigrade legs (march poses).
            legs(cg, pose: pose, cx: 11, top: 17, len: 10,
                 pants: hide, boots: chitinD, outline: O)
        }
    }

    // MARK: - Marching legs

    /// Two legs under body centre `cx` from `top` down `len` px.
    /// Pose 0 = left leg forward, 1 = right leg forward.
    private static func legs(_ cg: CGContext, pose: Int, cx: Int, top: Int, len: Int,
                             pants: UIColor, boots: UIColor, outline O: UIColor,
                             wide: Bool = false) {
        let w = wide ? 3 : 2
        // Back leg (darker) + front leg.
        let backX: Int, frontX: Int, liftBack: Int, liftFront: Int
        if pose == 0 {
            backX = cx - 3; frontX = cx + 1; liftBack = 0; liftFront = 3
        } else {
            backX = cx - 1; frontX = cx - 1; liftBack = 3; liftFront = 0
        }
        // Back leg.
        fill(cg, x: backX, y: top, w: w, h: len - liftBack, O)
        fill(cg, x: backX, y: top, w: max(1, w - 1), h: max(1, len - liftBack - 2), pants)
        fill(cg, x: backX - 1, y: top + len - liftBack - 2, w: w + 2, h: 2, boots) // foot
        // Front leg.
        fill(cg, x: frontX + 1, y: top, w: w, h: len - liftFront, O)
        fill(cg, x: frontX + 1, y: top, w: max(1, w - 1), h: max(1, len - liftFront - 2), pants)
        fill(cg, x: frontX, y: top + len - liftFront - 2, w: w + 2, h: 2, boots)
    }
}
