import SpriteKit
import UIKit

/// Loot kind shared by the scene's drop spawner + this art factory.
enum DropKind { case health, ammo, money }

/// Pixel-art pickups in the tower/HQ style (low-res textures, `.nearest`
/// filtering): a white medkit with a green cross, and an ammo crate with
/// brass rounds. Displayed ~40pt; the scene keeps its glow + bob + blink.
enum DropArt {

    private static var cache: [DropKind: SKTexture] = [:]

    static func texture(for kind: DropKind) -> SKTexture {
        if let tex = cache[kind] { return tex }
        let tex: SKTexture
        switch kind {
        case .health: tex = makeMedkit()
        case .ammo: tex = makeAmmoCrate()
        case .money: tex = makeCoin()
        }
        tex.filteringMode = .nearest
        cache[kind] = tex
        return tex
    }

    // MARK: - Canvas

    private static func pixelTexture(w: Int, h: Int,
                                     draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h),
                                           format: format).image { ctx in
            draw(ctx.cgContext) // UIKit coords: row 0 = top
        }
        return SKTexture(image: img)
    }

    private static func fill(_ cg: CGContext, x: Int, y: Int, w: Int, h: Int,
                             _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    private static let outline = UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
    private static let dark = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)

    // MARK: - Medkit (20x18): white case, handle, green cross

    private static func makeMedkit() -> SKTexture {
        pixelTexture(w: 20, h: 18) { cg in
            let O = outline
            let shell = UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1)
            let shellD = UIColor(red: 0.70, green: 0.72, blue: 0.80, alpha: 1)
            let cross = UIColor(red: 0.20, green: 0.85, blue: 0.35, alpha: 1)
            let crossD = UIColor(red: 0.10, green: 0.55, blue: 0.22, alpha: 1)
            // Carry handle.
            fill(cg, x: 7, y: 1, w: 6, h: 3, O)
            fill(cg, x: 8, y: 2, w: 4, h: 1, shellD)
            // Case.
            fill(cg, x: 2, y: 4, w: 16, h: 13, O)
            fill(cg, x: 3, y: 5, w: 14, h: 11, shell)
            fill(cg, x: 3, y: 5, w: 14, h: 1, .white)
            fill(cg, x: 3, y: 15, w: 14, h: 1, shellD)
            fill(cg, x: 3, y: 5, w: 1, h: 11, shellD)
            // Latches.
            fill(cg, x: 4, y: 4, w: 2, h: 2, dark)
            fill(cg, x: 14, y: 4, w: 2, h: 2, dark)
            // Green cross + shade + glint.
            fill(cg, x: 9, y: 7, w: 2, h: 7, cross)
            fill(cg, x: 6, y: 9, w: 8, h: 3, cross)
            fill(cg, x: 6, y: 11, w: 8, h: 1, crossD)
            fill(cg, x: 9, y: 13, w: 2, h: 1, crossD)
            fill(cg, x: 9, y: 7, w: 2, h: 1, .white)
            fill(cg, x: 6, y: 9, w: 8, h: 1, .white)
        }
    }

    // MARK: - Ammo crate (20x18): brass rounds over a riveted box

    private static func makeAmmoCrate() -> SKTexture {
        pixelTexture(w: 20, h: 18) { cg in
            let O = outline
            let brass = UIColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1)
            let brassD = UIColor(red: 0.75, green: 0.52, blue: 0.15, alpha: 1)
            let tip = UIColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 1)
            let metal = UIColor(red: 0.25, green: 0.27, blue: 0.34, alpha: 1)
            let metalL = UIColor(red: 0.45, green: 0.48, blue: 0.56, alpha: 1)
            // Three brass rounds behind the rim.
            for rx in [4, 9, 14] {
                fill(cg, x: rx, y: 1, w: 3, h: 8, O)
                fill(cg, x: rx + 1, y: 3, w: 1, h: 5, brass)
                fill(cg, x: rx + 1, y: 3, w: 1, h: 1, .white)
                fill(cg, x: rx + 1, y: 1, w: 1, h: 2, tip) // hot tip
            }
            // Crate body.
            fill(cg, x: 2, y: 8, w: 16, h: 9, O)
            fill(cg, x: 3, y: 9, w: 14, h: 7, metal)
            fill(cg, x: 3, y: 9, w: 14, h: 1, metalL)
            fill(cg, x: 3, y: 15, w: 14, h: 1, dark)
            // Rivets + stencil stripe.
            for r in [(4, 10), (14, 10), (4, 14), (14, 14)] {
                fill(cg, x: r.0, y: r.1, w: 1, h: 1, metalL)
            }
            fill(cg, x: 7, y: 12, w: 6, h: 2, brassD)
            fill(cg, x: 7, y: 12, w: 6, h: 1, brass)
        }
    }

    // MARK: - Gold coin (20x18): rimmed coin with a diamond emblem

    private static func makeCoin() -> SKTexture {
        pixelTexture(w: 20, h: 18) { cg in
            let O = outline
            let gold = UIColor(red: 1.0, green: 0.78, blue: 0.25, alpha: 1)
            let goldD = UIColor(red: 0.72, green: 0.48, blue: 0.12, alpha: 1)
            let light = UIColor(red: 1.0, green: 0.90, blue: 0.55, alpha: 1)
            // Rim.
            fill(cg, x: 8, y: 3, w: 4, h: 1, O)
            fill(cg, x: 6, y: 4, w: 8, h: 1, O)
            fill(cg, x: 4, y: 5, w: 12, h: 9, O)
            fill(cg, x: 6, y: 14, w: 8, h: 1, O)
            fill(cg, x: 8, y: 15, w: 4, h: 1, O)
            // Face.
            fill(cg, x: 8, y: 4, w: 4, h: 1, gold)
            fill(cg, x: 6, y: 5, w: 8, h: 8, gold)
            fill(cg, x: 8, y: 13, w: 4, h: 1, gold)
            // Right/bottom shade + top-left light.
            fill(cg, x: 13, y: 6, w: 1, h: 6, goldD)
            fill(cg, x: 6, y: 12, w: 8, h: 1, goldD)
            fill(cg, x: 5, y: 6, w: 2, h: 3, light)
            fill(cg, x: 5, y: 6, w: 1, h: 1, .white)
            // Diamond emblem.
            fill(cg, x: 9, y: 7, w: 2, h: 5, goldD)
            fill(cg, x: 8, y: 9, w: 4, h: 1, goldD)
            fill(cg, x: 9, y: 8, w: 1, h: 1, light)
        }
    }
}
