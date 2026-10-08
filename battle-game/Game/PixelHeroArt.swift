import SpriteKit
import UIKit

/// Code-drawn pixel-art hero (Vanguard look: silver-white armor, gold
/// V-visor, gold chest core, dark joints) in the same style as the pixel
/// towers/bases. No image assets: every frame is rendered once into
/// cached textures.
///
/// Body canvas is 30x46 (row 0 = top), origin at hero center. Legs are
/// parameterized so idle/run/jump/fall all come from one drawing routine.
/// Guns live on a 34x14 canvas with the grip at x=10 (rotation pivot).
enum PixelHeroArt {

    // MARK: - Palette (vanguard white/gold on dark)

    private static let outline = UIColor(red: 0.05, green: 0.04, blue: 0.08, alpha: 1)
    private static let armorL = UIColor(red: 0.93, green: 0.94, blue: 0.97, alpha: 1)
    private static let armorM = UIColor(red: 0.78, green: 0.80, blue: 0.86, alpha: 1)
    private static let armorD = UIColor(red: 0.55, green: 0.57, blue: 0.65, alpha: 1)
    private static let gold = UIColor(red: 1.0, green: 0.74, blue: 0.28, alpha: 1)
    private static let goldD = UIColor(red: 0.78, green: 0.45, blue: 0.12, alpha: 1)
    private static let suit = UIColor(red: 0.13, green: 0.12, blue: 0.19, alpha: 1)
    private static let suitD = UIColor(red: 0.07, green: 0.06, blue: 0.11, alpha: 1)
    private static let visor = UIColor(red: 0.03, green: 0.02, blue: 0.06, alpha: 1)
    private static let eye = UIColor(red: 1.0, green: 0.70, blue: 0.22, alpha: 1)
    private static let tank = UIColor(red: 0.32, green: 0.86, blue: 1.0, alpha: 1)
    private static let metalD = UIColor(red: 0.16, green: 0.16, blue: 0.21, alpha: 1)
    private static let metalM = UIColor(red: 0.42, green: 0.44, blue: 0.52, alpha: 1)
    private static let metalL = UIColor(red: 0.72, green: 0.74, blue: 0.82, alpha: 1)
    private static let yellow = UIColor(red: 1.0, green: 0.82, blue: 0.32, alpha: 1)
    private static let orange = UIColor(red: 1.0, green: 0.55, blue: 0.16, alpha: 1)
    private static let red = UIColor(red: 1.0, green: 0.24, blue: 0.20, alpha: 1)

    // MARK: - Canvas helper

    private static func fill(_ cg: CGContext, _ x: Int, _ y: Int, _ w: Int, _ h: Int,
                             _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    private static func render(w: Int, h: Int, key: String? = nil,
                               draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format)
        let img = renderer.image { ctx in
            // UIKit coords: row 0 = top. (Do NOT flip: SKTexture(image:)
            // displays upright, same as the tower/base art.)
            draw(ctx.cgContext)
        }
        if let key { imageCache[key] = img }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
    }

    /// Raw pixel images behind the cached textures (for SwiftUI icons).
    private static var imageCache: [String: UIImage] = [:]

    /// Pixel gun icon for the HUD weapon button — the same art as the
    /// aimed rifle. gunW x gunH px; show with `.interpolation(.none)`.
    static func gunImage(_ gun: HeroWeapon) -> UIImage {
        _ = gunTexture(gun) // warm the cache
        switch gun {
        case .blaster: return imageCache["gun-blaster"] ?? UIImage()
        case .scatter: return imageCache["gun-scatter"] ?? UIImage()
        case .cannon: return imageCache["gun-cannon"] ?? UIImage()
        case .repeater: return imageCache["gun-repeater"] ?? UIImage()
        case .piercer: return imageCache["gun-piercer"] ?? UIImage()
        case .shredder: return imageCache["gun-shredder"] ?? UIImage()
        case .sunder: return imageCache["gun-sunder"] ?? UIImage()
        case .hornet: return imageCache["gun-hornet"] ?? UIImage()
        case .lancer: return imageCache["gun-lancer"] ?? UIImage()
        case .tempest: return imageCache["gun-tempest"] ?? UIImage()
        case .mauler: return imageCache["gun-mauler"] ?? UIImage()
        case .nova: return imageCache["gun-nova"] ?? UIImage()
        case .requiem: return imageCache["gun-requiem"] ?? UIImage()
        case .oblivion: return imageCache["gun-oblivion"] ?? UIImage()
        }
    }

    // MARK: - Body frames

    static let bodyW = 30
    static let bodyH = 46

    /// Leg pose: foot offset from the hip + foot row per leg.
    /// Front hip sits at x=17, back hip at x=12, hip row is 30 (stubby).
    struct LegPose {
        var frontDX: Int
        var frontY: Int
        var backDX: Int
        var backY: Int
    }

    static let idlePose = LegPose(frontDX: 1, frontY: 42, backDX: -1, backY: 42)
    static let runPoses: [LegPose] = [
        // Strike: front foot planted ahead, back toe pushing off behind.
        LegPose(frontDX: 5, frontY: 42, backDX: -4, backY: 40),
        // Passing: both feet tucked under the body.
        LegPose(frontDX: 1, frontY: 39, backDX: -2, backY: 39),
        // Strike, legs swapped.
        LegPose(frontDX: -4, frontY: 41, backDX: 5, backY: 42),
        // Passing, mirrored.
        LegPose(frontDX: -1, frontY: 39, backDX: 1, backY: 39),
    ]
    static let jumpPose = LegPose(frontDX: 2, frontY: 37, backDX: -2, backY: 36)
    static let fallPose = LegPose(frontDX: 2, frontY: 42, backDX: -2, backY: 42)

    static let idleTex: SKTexture = renderBody(pose: idlePose)
    static let runTex: [SKTexture] = runPoses.map { renderBody(pose: $0) }
    static let jumpTex: SKTexture = renderBody(pose: jumpPose)
    static let fallTex: SKTexture = renderBody(pose: fallPose)

    /// One vanguard body frame. Big rounded helmet, bulky shoulder pads,
    /// short torso; NO arms (they ride on the rifle sprite). Facing right.
    /// Hips at row 30, boots land ~row 42-45.
    private static func renderBody(pose: LegPose) -> SKTexture {
        render(w: bodyW, h: bodyH) { cg in
            // Backpack (behind torso, left side).
            fill(cg, 3, 16, 4, 10, suit)
            fill(cg, 3, 16, 4, 1, armorD)
            fill(cg, 4, 17, 1, 7, tank) // air tank stripe
            fill(cg, 2, 25, 6, 1, outline)

            // Legs first (hips/torso overlap tops).
            drawLeg(cg, hipX: 12, footX: 12 + pose.backDX, footY: pose.backY,
                    kneeFwd: 1, main: suit, shade: suitD, pad: suitD)
            drawLeg(cg, hipX: 17, footX: 17 + pose.frontDX, footY: pose.frontY,
                    kneeFwd: 2, main: armorM, shade: armorD, pad: armorL)

            // Hips bridge belt -> legs.
            fill(cg, 11, 28, 8, 2, suitD)

            // Torso: white chest + dark vest + gold core.
            fill(cg, 9, 15, 12, 1, outline)
            fill(cg, 9, 16, 12, 10, armorL)
            fill(cg, 9, 16, 2, 10, armorM)   // left shade
            fill(cg, 19, 16, 2, 10, armorM)  // right shade
            fill(cg, 12, 18, 5, 7, suit)     // vest
            fill(cg, 12, 18, 5, 1, suitD)
            fill(cg, 14, 20, 2, 3, gold)     // chest core
            fill(cg, 14, 20, 2, 1, .white)   // core glint
            // Belt + buckle + gold hip lights.
            fill(cg, 9, 26, 12, 2, suitD)
            fill(cg, 13, 26, 3, 2, goldD)
            fill(cg, 9, 27, 2, 1, gold)
            fill(cg, 19, 27, 2, 1, gold)
            // Bulky shoulder pads + dark nubs where arms would join.
            fill(cg, 4, 14, 5, 5, armorL)
            fill(cg, 4, 14, 5, 1, .white)
            fill(cg, 5, 16, 1, 1, gold) // shoulder stud
            fill(cg, 6, 19, 2, 2, suitD)
            fill(cg, 21, 14, 4, 4, armorM)
            fill(cg, 21, 14, 4, 1, armorL)
            fill(cg, 23, 16, 1, 1, gold) // shoulder stud
            fill(cg, 22, 18, 2, 2, suitD)

            // Big rounded helmet + center ridge + gold brow light.
            fill(cg, 8, 1, 13, 1, outline)
            fill(cg, 7, 2, 15, 10, armorL)
            fill(cg, 7, 2, 2, 10, armorM)   // left shade
            fill(cg, 20, 2, 2, 10, armorD)  // right shade
            fill(cg, 7, 11, 15, 1, armorD)  // chin shade
            fill(cg, 13, 1, 3, 5, armorM)   // center ridge
            fill(cg, 13, 1, 3, 1, .white)   // ridge glint
            fill(cg, 8, 4, 2, 4, goldD)     // side lamp
            fill(cg, 14, 6, 2, 1, gold)     // brow light
            // Dark face opening + angular gold V-visor (Vanguard signature).
            fill(cg, 13, 7, 8, 5, visor)
            segment(cg, x0: 14, y0: 8, x1: 17, y1: 10, w: 2, color: gold)
            segment(cg, x0: 20, y0: 8, x1: 17, y1: 10, w: 2, color: gold)
            fill(cg, 16, 10, 2, 1, .white)  // V center glint
            // Neck bridges helmet -> torso.
            fill(cg, 12, 12, 5, 3, suit)
        }
    }

    /// One leg with a bent knee: thigh (hip -> knee) + shin (knee -> foot),
    /// white/dark knee pad, then boot + gold sole. Knees push forward.
    private static func drawLeg(_ cg: CGContext, hipX: Int, footX: Int, footY: Int,
                                kneeFwd: Int, main: UIColor, shade: UIColor,
                                pad: UIColor) {
        let hipY = 30
        let kneeX = (hipX + footX) / 2 + kneeFwd
        let kneeY = (hipY + footY) / 2
        segment(cg, x0: hipX, y0: hipY, x1: kneeX, y1: kneeY, w: 4, color: main)
        segment(cg, x0: kneeX, y0: kneeY, x1: footX, y1: footY, w: 3, color: shade)
        fill(cg, kneeX - 1, kneeY, 3, 2, pad) // knee pad
        // Boot + highlight + gold sole.
        fill(cg, footX - 2, footY + 1, 5, 3, suitD)
        fill(cg, footX - 2, footY + 1, 5, 1, metalM) // boot highlight
        fill(cg, footX - 2, footY + 3, 5, 1, goldD)  // sole
    }

    /// Thick pixel line: paints a w-wide row per step between two points.
    private static func segment(_ cg: CGContext, x0: Int, y0: Int,
                                x1: Int, y1: Int, w: Int, color: UIColor) {
        let steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = Int(round(CGFloat(x0) + CGFloat(x1 - x0) * t))
            let y = Int(round(CGFloat(y0) + CGFloat(y1 - y0) * t))
            fill(cg, x - w / 2, y, w, 1, color)
        }
    }

    // MARK: - Display metrics (world points)

    /// Body pixels -> world: 46px canvas reads 80pt tall (matches hero body).
    static let pxScale: CGFloat = 80.0 / 46.0
    static func bodySize() -> CGSize {
        CGSize(width: CGFloat(bodyW) * pxScale, height: CGFloat(bodyH) * pxScale)
    }

    /// Guns share one scale so they match the body; lengths differ per gun.
    private static let gunScale: CGFloat = 1.9
    static func gunSize(_ gun: HeroWeapon) -> CGSize {
        CGSize(width: CGFloat(gunW) * gunScale, height: CGFloat(gunH) * gunScale)
    }

    /// Grip (x=10) -> muzzle tip, in world points. Feeds HeroNode.muzzlePosition.
    static func gunLength(_ gun: HeroWeapon) -> CGFloat {
        (gunTipX(gun) - CGFloat(gunGrip.x)) * gunScale
    }

    // MARK: - Guns (36x20 canvas: rifle + attached arms + shoulder cap)

    static let gunW = 36
    static let gunH = 20
    /// Grip center in canvas px (rotation pivot, held at the chest).
    static let gunGrip = (x: 10, y: 11)
    /// Grip x as a plain scalar (used for anchor math in HeroNode).
    static var gunGripX: CGFloat { CGFloat(gunGrip.x) }
    static var gunAnchor: CGPoint {
        CGPoint(x: CGFloat(gunGrip.x) / CGFloat(gunW),
                y: 1 - CGFloat(gunGrip.y) / CGFloat(gunH))
    }

    /// Muzzle tip x per gun (px from canvas left).
    static func gunTipX(_ gun: HeroWeapon) -> CGFloat {
        switch gun {
        case .blaster: return 32
        case .scatter: return 30
        case .cannon: return 33
        case .repeater: return 32
        case .piercer: return 34
        case .shredder: return 30
        case .sunder: return 31
        case .hornet: return 29
        case .lancer: return 35
        case .tempest: return 31
        case .mauler: return 30
        case .nova: return 32
        case .requiem: return 33
        case .oblivion: return 35
        }
    }

    /// Arms attached to the rifle: shoulder cap + back arm to the grip +
    /// long front arm to the foregrip. Shared by all three guns so the arms
    /// always match the hands, and everything rotates as one aimed unit.
    private static func drawGunArms(_ cg: CGContext) {
        // Shoulder cap (pauldron) where the arms meet the body.
        fill(cg, 1, 9, 6, 6, armorL)
        fill(cg, 1, 9, 6, 1, .white)
        fill(cg, 1, 14, 6, 1, goldD)
        fill(cg, 1, 9, 1, 6, armorM)
        // Back arm: cap -> grip glove (short, mostly behind).
        segment(cg, x0: 5, y0: 11, x1: 9, y1: 11, w: 3, color: suit)
        // Front arm: cap -> foregrip glove (long diagonal reach, dark so
        // the gun silhouette stays clean).
        segment(cg, x0: 5, y0: 13, x1: 19, y1: 9, w: 3, color: suit)
        segment(cg, x0: 5, y0: 14, x1: 17, y1: 10, w: 1, color: suitD)
        // Gloves wrapping grip + foregrip, gold knuckle lines.
        fill(cg, 8, 9, 4, 4, suitD)
        fill(cg, 8, 10, 4, 1, goldD)
        fill(cg, 18, 7, 4, 4, suitD)
        fill(cg, 18, 8, 4, 1, goldD)
        // Trigger.
        fill(cg, 12, 11, 2, 2, metalD)
    }

    static func gunTexture(_ gun: HeroWeapon) -> SKTexture {
        switch gun {
        case .blaster: return blasterTex
        case .scatter: return scatterTex
        case .cannon: return cannonTex
        case .repeater: return repeaterTex
        case .piercer: return piercerTex
        case .shredder: return shredderTex
        case .sunder: return sunderTex
        case .hornet: return hornetTex
        case .lancer: return lancerTex
        case .tempest: return tempestTex
        case .mauler: return maulerTex
        case .nova: return novaTex
        case .requiem: return requiemTex
        case .oblivion: return oblivionTex
        }
    }

    private static let blasterTex: SKTexture = render(w: gunW, h: gunH, key: "gun-blaster") { cg in
        // Stock.
        fill(cg, 1, 5, 8, 5, metalD)
        fill(cg, 1, 5, 8, 1, metalM)
        // Top sight nub.
        fill(cg, 12, 3, 2, 2, metalD)
        fill(cg, 12, 3, 2, 1, metalL)
        // Slim barrel + top highlight.
        fill(cg, 9, 5, 21, 4, outline)
        fill(cg, 10, 6, 20, 2, metalD)
        fill(cg, 10, 6, 20, 1, metalM)
        // Hot energy core + spark.
        fill(cg, 14, 6, 7, 2, tank)
        fill(cg, 16, 6, 2, 1, .white)
        // Gold muzzle crown + yellow mouth.
        fill(cg, 29, 5, 1, 4, goldD)
        fill(cg, 30, 5, 2, 4, yellow)
        fill(cg, 30, 5, 2, 1, .white)
        // Brass underbarrel weight.
        fill(cg, 20, 14, 3, 2, goldD)
        // Arms over the stock, gloves wrapping the gun.
        drawGunArms(cg)
    }

    private static let scatterTex: SKTexture = render(w: gunW, h: gunH, key: "gun-scatter") { cg in
        // Stock.
        fill(cg, 1, 5, 8, 5, metalD)
        fill(cg, 1, 5, 8, 1, metalM)
        // Top sight bridge + nubs.
        fill(cg, 12, 1, 8, 2, metalD)
        fill(cg, 13, 0, 2, 1, metalM)
        fill(cg, 18, 0, 2, 1, metalM)
        fill(cg, 15, 10, 5, 2, goldD) // pump
        // Triple barrels.
        fill(cg, 9, 3, 19, 8, outline)
        fill(cg, 10, 4, 18, 2, metalD)
        fill(cg, 10, 4, 18, 1, metalM)
        fill(cg, 10, 7, 18, 2, metalD)
        fill(cg, 10, 7, 18, 1, metalL)
        fill(cg, 10, 10, 18, 1, metalD)
        // Belly pump grip below the arms.
        fill(cg, 15, 14, 5, 3, outline)
        fill(cg, 16, 15, 3, 1, goldD)
        // Wide orange muzzle mouth + inner slit.
        fill(cg, 28, 3, 2, 8, orange)
        fill(cg, 28, 3, 2, 2, .white)
        fill(cg, 29, 5, 1, 4, suitD)
        drawGunArms(cg)
    }

    private static let cannonTex: SKTexture = render(w: gunW, h: gunH, key: "gun-cannon") { cg in
        // Heavy stock.
        fill(cg, 0, 4, 9, 6, metalD)
        fill(cg, 0, 4, 9, 1, metalM)
        // Big scope + glinting eye.
        fill(cg, 11, 1, 8, 4, metalD)
        fill(cg, 12, 2, 6, 1, metalL)
        fill(cg, 13, 2, 2, 2, eye)
        fill(cg, 13, 2, 1, 1, .white)
        // Thick barrel + highlight.
        fill(cg, 9, 5, 20, 5, outline)
        fill(cg, 10, 6, 19, 3, metalD)
        fill(cg, 10, 6, 19, 1, metalL)
        // Hazard band on the barrel.
        fill(cg, 16, 8, 2, 2, goldD)
        fill(cg, 18, 8, 2, 2, suitD)
        fill(cg, 20, 8, 2, 2, goldD)
        // Red muzzle rings + heavy mouth with a tall core.
        fill(cg, 23, 5, 2, 5, goldD)
        fill(cg, 27, 4, 2, 7, red)
        fill(cg, 30, 4, 3, 7, outline)
        fill(cg, 31, 5, 1, 5, suitD)
        fill(cg, 31, 5, 1, 3, red)
        drawGunArms(cg)
    }

    // Tier accent inks (later guns burn brighter).
    private static let plasma = UIColor(red: 0.35, green: 1.0, blue: 0.5, alpha: 1)
    private static let violet = UIColor(red: 0.7, green: 0.45, blue: 1.0, alpha: 1)

    private static let repeaterTex: SKTexture = render(w: gunW, h: gunH, key: "gun-repeater") { cg in
        // Stock.
        fill(cg, 1, 5, 8, 5, metalD)
        fill(cg, 1, 5, 8, 1, metalM)
        // Top ammo drum + cyan round dot.
        fill(cg, 12, 0, 7, 5, outline)
        fill(cg, 13, 1, 5, 3, metalM)
        fill(cg, 13, 1, 5, 1, metalL)
        fill(cg, 15, 2, 2, 1, tank)
        // Slim twin barrels + cyan twin stripes.
        fill(cg, 9, 4, 21, 3, outline)
        fill(cg, 10, 5, 20, 1, metalD)
        fill(cg, 14, 5, 8, 1, tank)
        fill(cg, 9, 8, 21, 3, outline)
        fill(cg, 10, 9, 20, 1, metalM)
        fill(cg, 14, 9, 8, 1, tank)
        // Brass ejector below the arms.
        fill(cg, 20, 14, 3, 3, outline)
        fill(cg, 21, 15, 1, 1, goldD)
        // Twin yellow mouths.
        fill(cg, 30, 4, 2, 3, yellow)
        fill(cg, 30, 8, 2, 3, yellow)
        fill(cg, 30, 4, 2, 1, .white)
        fill(cg, 30, 8, 2, 1, .white)
        drawGunArms(cg)
    }

    private static let piercerTex: SKTexture = render(w: gunW, h: gunH, key: "gun-piercer") { cg in
        // Stock.
        fill(cg, 1, 5, 8, 5, metalD)
        fill(cg, 1, 5, 8, 1, metalM)
        // Belly power cell with a hot core.
        fill(cg, 12, 14, 6, 3, outline)
        fill(cg, 13, 15, 4, 1, goldD)
        fill(cg, 14, 15, 2, 1, eye)
        // Needle rail + full-length hot slit with white dashes.
        fill(cg, 9, 6, 23, 2, outline)
        fill(cg, 10, 6, 22, 1, tank)
        fill(cg, 12, 6, 2, 1, .white)
        fill(cg, 20, 6, 2, 1, .white)
        fill(cg, 28, 6, 1, 1, .white)
        // Tall teal rail fins.
        fill(cg, 14, 2, 2, 4, tank)
        fill(cg, 20, 2, 2, 4, tank)
        fill(cg, 26, 2, 2, 4, tank)
        fill(cg, 14, 2, 2, 1, .white)
        fill(cg, 20, 2, 2, 1, .white)
        fill(cg, 26, 2, 2, 1, .white)
        // Gold needle tip + sparkles.
        fill(cg, 32, 6, 2, 2, eye)
        fill(cg, 32, 6, 2, 1, .white)
        fill(cg, 31, 5, 1, 1, .white)
        fill(cg, 31, 8, 1, 1, .white)
        drawGunArms(cg)
    }

    private static let shredderTex: SKTexture = render(w: gunW, h: gunH, key: "gun-shredder") { cg in
        // Big top ammo box + brass-tipped belt.
        fill(cg, 8, 0, 12, 4, outline)
        fill(cg, 9, 1, 10, 2, metalM)
        fill(cg, 9, 1, 10, 1, orange)
        fill(cg, 10, 2, 1, 1, yellow)
        fill(cg, 13, 2, 1, 1, yellow)
        fill(cg, 16, 2, 1, 1, yellow)
        // Rotary triple cluster.
        fill(cg, 9, 5, 19, 3, outline)
        fill(cg, 10, 6, 18, 1, metalD)
        fill(cg, 9, 9, 19, 3, outline)
        fill(cg, 10, 10, 18, 1, metalM)
        fill(cg, 9, 13, 19, 3, outline)
        fill(cg, 10, 14, 18, 1, metalD)
        // Side spin motor with a hot dot.
        fill(cg, 20, 15, 5, 3, outline)
        fill(cg, 21, 16, 3, 1, metalM)
        fill(cg, 22, 16, 1, 1, orange)
        // Triple orange mouths, all glinting.
        fill(cg, 28, 5, 2, 3, orange)
        fill(cg, 28, 9, 2, 3, orange)
        fill(cg, 28, 13, 2, 3, orange)
        fill(cg, 28, 5, 2, 1, .white)
        fill(cg, 28, 9, 2, 1, .white)
        fill(cg, 28, 13, 2, 1, .white)
        drawGunArms(cg)
    }

    private static let sunderTex: SKTexture = render(w: gunW, h: gunH, key: "gun-sunder") { cg in
        // Heavy stock.
        fill(cg, 0, 4, 9, 6, metalD)
        fill(cg, 0, 4, 9, 1, metalM)
        // Top barrel spikes.
        fill(cg, 12, 2, 2, 2, metalM)
        fill(cg, 17, 2, 2, 2, metalM)
        fill(cg, 22, 1, 2, 3, metalM)
        // Twin heavy barrels + gold rings.
        fill(cg, 9, 4, 20, 3, outline)
        fill(cg, 10, 5, 19, 1, metalD)
        fill(cg, 24, 4, 2, 3, goldD)
        fill(cg, 9, 8, 20, 3, outline)
        fill(cg, 10, 9, 19, 1, metalM)
        fill(cg, 24, 8, 2, 3, goldD)
        // Glowing vent between the barrels.
        fill(cg, 15, 7, 5, 1, outline)
        fill(cg, 16, 7, 3, 1, orange)
        // Twin yellow mouths.
        fill(cg, 29, 4, 2, 3, yellow)
        fill(cg, 29, 8, 2, 3, yellow)
        fill(cg, 29, 4, 2, 1, .white)
        fill(cg, 29, 8, 2, 1, .white)
        drawGunArms(cg)
    }

    private static let hornetTex: SKTexture = render(w: gunW, h: gunH, key: "gun-hornet") { cg in
        // Stock + rear stinger.
        fill(cg, 1, 5, 8, 5, metalD)
        fill(cg, 1, 5, 8, 1, metalM)
        fill(cg, 4, 1, 3, 3, metalD)
        fill(cg, 4, 1, 2, 1, plasma)
        // Hive comb rail with plasma cells.
        fill(cg, 10, 3, 16, 2, metalD)
        fill(cg, 12, 3, 2, 1, plasma)
        fill(cg, 16, 3, 2, 1, plasma)
        fill(cg, 20, 3, 2, 1, plasma)
        fill(cg, 24, 3, 1, 1, plasma)
        // Compact quad body + green stripes.
        fill(cg, 9, 5, 17, 7, outline)
        fill(cg, 10, 6, 16, 5, metalD)
        fill(cg, 10, 6, 16, 1, metalM)
        fill(cg, 13, 8, 6, 1, plasma)
        // Belly stinger below the arms.
        fill(cg, 14, 14, 2, 3, outline)
        fill(cg, 14, 15, 2, 1, plasma)
        // Quad plasma mouths + crown glow.
        fill(cg, 26, 5, 3, 2, plasma)
        fill(cg, 26, 9, 3, 2, plasma)
        fill(cg, 26, 5, 3, 1, .white)
        fill(cg, 26, 9, 3, 1, .white)
        fill(cg, 26, 3, 3, 1, plasma)
        drawGunArms(cg)
    }

    private static let lancerTex: SKTexture = render(w: gunW, h: gunH, key: "gun-lancer") { cg in
        // Stock.
        fill(cg, 1, 5, 8, 5, metalD)
        fill(cg, 1, 5, 8, 1, metalM)
        // War pennant on a pole.
        fill(cg, 20, 1, 1, 4, metalM)
        fill(cg, 21, 1, 5, 3, red)
        fill(cg, 24, 2, 2, 1, suitD)
        // Spear barrel + silver rings + gold filigree.
        fill(cg, 9, 6, 24, 2, outline)
        fill(cg, 10, 6, 23, 1, metalL)
        fill(cg, 10, 7, 23, 1, goldD)
        fill(cg, 16, 5, 2, 4, metalL)
        fill(cg, 22, 5, 2, 4, metalL)
        // Long bayonet under the tip.
        fill(cg, 28, 8, 6, 1, metalL)
        fill(cg, 33, 8, 1, 1, .white)
        // Gold muzzle eye.
        fill(cg, 33, 5, 2, 4, outline)
        fill(cg, 33, 6, 2, 2, eye)
        fill(cg, 33, 6, 2, 1, .white)
        drawGunArms(cg)
    }

    private static let tempestTex: SKTexture = render(w: gunW, h: gunH, key: "gun-tempest") { cg in
        // Stock.
        fill(cg, 1, 5, 8, 5, metalD)
        fill(cg, 1, 5, 8, 1, metalM)
        // Lightning zigzag above the block.
        fill(cg, 14, 1, 2, 1, .white)
        fill(cg, 16, 0, 3, 1, .white)
        fill(cg, 20, 1, 2, 1, .white)
        // Triple storm barrels.
        fill(cg, 9, 4, 20, 8, outline)
        fill(cg, 10, 5, 19, 2, metalD)
        fill(cg, 10, 5, 19, 1, metalM)
        fill(cg, 10, 8, 19, 2, metalD)
        fill(cg, 10, 8, 19, 1, metalL)
        // Twin violet storm tanks with glinting caps.
        fill(cg, 13, 2, 3, 11, outline)
        fill(cg, 14, 3, 1, 9, violet)
        fill(cg, 14, 3, 1, 2, .white)
        fill(cg, 21, 2, 3, 11, outline)
        fill(cg, 22, 3, 1, 9, violet)
        fill(cg, 22, 3, 1, 2, .white)
        // Wide orange storm mouth.
        fill(cg, 29, 4, 2, 8, orange)
        fill(cg, 29, 4, 2, 1, .white)
        drawGunArms(cg)
    }

    private static let maulerTex: SKTexture = render(w: gunW, h: gunH, key: "gun-mauler") { cg in
        // Heavy stock.
        fill(cg, 0, 4, 9, 6, metalD)
        fill(cg, 0, 4, 9, 1, metalM)
        // Top armor spikes.
        fill(cg, 12, 1, 2, 2, metalD)
        fill(cg, 17, 1, 2, 2, metalD)
        fill(cg, 22, 1, 2, 2, metalD)
        fill(cg, 12, 1, 2, 1, metalL)
        fill(cg, 17, 1, 2, 1, metalL)
        fill(cg, 22, 1, 2, 1, metalL)
        // Fat quad body + gold bands.
        fill(cg, 9, 3, 19, 10, outline)
        fill(cg, 10, 4, 18, 8, metalD)
        fill(cg, 10, 4, 18, 1, metalL)
        fill(cg, 15, 3, 2, 10, goldD)
        fill(cg, 21, 3, 2, 10, goldD)
        // Heat halo + quad red-hot mouths with white cores.
        fill(cg, 24, 2, 6, 1, yellow)
        fill(cg, 27, 4, 3, 3, red)
        fill(cg, 27, 9, 3, 3, red)
        fill(cg, 28, 5, 1, 1, .white)
        fill(cg, 28, 10, 1, 1, .white)
        fill(cg, 27, 7, 3, 2, orange)
        drawGunArms(cg)
    }

    private static let novaTex: SKTexture = render(w: gunW, h: gunH, key: "gun-nova") { cg in
        // Stock.
        fill(cg, 1, 5, 8, 5, metalD)
        fill(cg, 1, 5, 8, 1, metalM)
        // Sun rays around the chamber.
        fill(cg, 13, 1, 2, 2, gold)
        fill(cg, 17, 0, 2, 2, gold)
        fill(cg, 21, 1, 2, 2, gold)
        fill(cg, 13, 15, 2, 2, goldD)
        fill(cg, 17, 16, 2, 2, goldD)
        fill(cg, 21, 15, 2, 2, goldD)
        // Rising heat sparks.
        fill(cg, 15, 2, 1, 1, orange)
        fill(cg, 19, 1, 1, 1, orange)
        // Sun chamber + burning core.
        fill(cg, 12, 4, 10, 10, outline)
        fill(cg, 13, 5, 8, 8, goldD)
        fill(cg, 15, 7, 4, 4, yellow)
        fill(cg, 16, 7, 2, 2, .white)
        // Short fat barrel + dawn mouth.
        fill(cg, 22, 6, 8, 3, outline)
        fill(cg, 23, 7, 7, 1, metalD)
        fill(cg, 30, 6, 2, 3, orange)
        fill(cg, 30, 6, 2, 1, .white)
        drawGunArms(cg)
    }

    private static let requiemTex: SKTexture = render(w: gunW, h: gunH, key: "gun-requiem") { cg in
        // Stock.
        fill(cg, 1, 5, 8, 5, metalD)
        fill(cg, 1, 5, 8, 1, armorL)
        // Gold halo ring above the barrel.
        fill(cg, 12, 1, 14, 2, gold)
        fill(cg, 12, 1, 14, 1, .white)
        fill(cg, 12, 1, 2, 4, goldD)
        fill(cg, 24, 1, 2, 4, goldD)
        // Five choir orbs with glints.
        fill(cg, 11, 3, 2, 2, gold)
        fill(cg, 15, 3, 2, 2, gold)
        fill(cg, 19, 3, 2, 2, gold)
        fill(cg, 23, 3, 2, 2, gold)
        fill(cg, 27, 3, 2, 2, gold)
        fill(cg, 11, 3, 1, 1, .white)
        fill(cg, 15, 3, 1, 1, .white)
        fill(cg, 19, 3, 1, 1, .white)
        fill(cg, 23, 3, 1, 1, .white)
        fill(cg, 27, 3, 1, 1, .white)
        // Elegant white barrel.
        fill(cg, 9, 6, 22, 2, outline)
        fill(cg, 10, 6, 21, 1, armorL)
        // White choir mouth in a gold ring.
        fill(cg, 30, 5, 1, 4, goldD)
        fill(cg, 31, 5, 2, 4, outline)
        fill(cg, 31, 6, 2, 2, .white)
        drawGunArms(cg)
    }

    private static let oblivionTex: SKTexture = render(w: gunW, h: gunH, key: "gun-oblivion") { cg in
        // Massive stock.
        fill(cg, 0, 3, 9, 8, metalD)
        fill(cg, 0, 3, 9, 1, metalM)
        // Five-spire war crown with a red gem.
        fill(cg, 14, 1, 1, 2, gold)
        fill(cg, 16, 0, 1, 3, gold)
        fill(cg, 18, 0, 1, 3, gold)
        fill(cg, 20, 0, 1, 3, gold)
        fill(cg, 22, 1, 1, 2, gold)
        fill(cg, 18, 2, 1, 1, red)
        // Massive black-gold barrel + gold filigree.
        fill(cg, 9, 4, 22, 7, outline)
        fill(cg, 10, 5, 21, 5, metalD)
        fill(cg, 10, 5, 21, 1, metalM)
        fill(cg, 10, 9, 21, 1, goldD)
        // Void core: violet band, black slit, red spark.
        fill(cg, 12, 6, 16, 1, violet)
        fill(cg, 14, 7, 12, 1, suitD)
        fill(cg, 20, 7, 4, 1, red)
        fill(cg, 27, 3, 4, 9, goldD)
        fill(cg, 27, 4, 2, 7, red)
        // Heavy dark mouth with red core + jagged teeth.
        fill(cg, 32, 4, 1, 2, red)
        fill(cg, 32, 9, 1, 2, red)
        fill(cg, 33, 4, 2, 7, outline)
        fill(cg, 33, 5, 2, 5, suitD)
        fill(cg, 33, 6, 2, 3, red)
        drawGunArms(cg)
    }
}
