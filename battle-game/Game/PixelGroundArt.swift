import SpriteKit
import UIKit

/// Code-drawn green pasture ground in the pixel-tower style. No image assets:
/// tiles render once and cache. Two variants alternate along the lane (every
/// 4th mirrored) so the repeat never reads as a pattern.
///
/// Tile canvas is 125x22, displayed at 500x88 (4x). Edge columns are kept
/// clean so any variant/flip adjacency stays seamless.
enum PixelGroundArt {

    // MARK: - Palette (sunlit pasture)

    private static let grassHi = UIColor(red: 0.52, green: 0.85, blue: 0.44, alpha: 1)
    private static let grass = UIColor(red: 0.34, green: 0.69, blue: 0.32, alpha: 1)
    private static let grassDk = UIColor(red: 0.23, green: 0.51, blue: 0.23, alpha: 1)
    private static let dirt = UIColor(red: 0.55, green: 0.41, blue: 0.28, alpha: 1)
    private static let dirtDk = UIColor(red: 0.41, green: 0.29, blue: 0.19, alpha: 1)
    private static let dirtLt = UIColor(red: 0.66, green: 0.52, blue: 0.36, alpha: 1)
    private static let pebble = UIColor(red: 0.71, green: 0.68, blue: 0.63, alpha: 1)
    private static let flowerW = UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1)
    private static let flowerY = UIColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 1)
    private static let flowerP = UIColor(red: 1.0, green: 0.55, blue: 0.70, alpha: 1)
    private static let outline = UIColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1)

    // MARK: - Canvas helpers

    private static func fill(_ cg: CGContext, _ x: Int, _ y: Int, _ w: Int, _ h: Int,
                             _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    private static func render(w: Int, h: Int, draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format)
        // Row 0 = top, upright (same as tower/base art).
        let img = renderer.image { ctx in draw(ctx.cgContext) }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
    }

    /// Deterministic speckle hash (wrapping arithmetic, no traps).
    private static func hash(_ x: Int, _ y: Int, _ variant: Int) -> Int {
        let h = (x &* 73856093) ^ (y &* 19349663) ^ (variant &* 83492791)
        return abs(h % 100)
    }

    /// True inside the 3px quiet margins that keep tile edges seamless.
    private static func edged(_ x: Int, _ w: Int) -> Bool {
        x < 3 || x >= w - 3
    }

    // MARK: - Ground tile (125x22 -> 500x88)

    static let tileW = 125
    static let tileH = 22
    static let tileScale: CGFloat = 4

    private static var tileCache: [SKTexture] = []

    static func tileTexture(variant: Int) -> SKTexture {
        let v = variant % 2
        while tileCache.count <= v { tileCache.append(renderTile(variant: tileCache.count)) }
        return tileCache[v]
    }

    private static func renderTile(variant: Int) -> SKTexture {
        render(w: tileW, h: tileH) { cg in
            let W = tileW, H = tileH
            // Grass body.
            fill(cg, 0, 0, W, 7, grass)
            // Sunlit top lip.
            fill(cg, 0, 0, W, 2, grassHi)
            // Blades sticking up along the lip.
            var x = 4 + variant * 3
            while x < W - 3 {
                fill(cg, x, 0, 1, 2, grassHi)
                x += 7
            }
            // Speckles + pebbles in the grass (never at the edges).
            for px in 3..<(W - 3) {
                for py in 2..<7 {
                    let r = hash(px, py, variant)
                    if r < 8 {
                        fill(cg, px, py, 1, 1, grassDk)
                    } else if r > 95 && py > 4 {
                        fill(cg, px, py, 2, 1, pebble)
                    }
                }
            }
            // Flowers (variant-specific spots, clear of the edges).
            let spots = variant == 0 ? [18, 64, 105] : [40, 88, 110]
            for (i, fx) in spots.enumerated() {
                let petal = i % 2 == 0 ? flowerW : flowerP
                fill(cg, fx, 4, 1, 2, grassDk)   // stem
                fill(cg, fx - 1, 2, 3, 2, petal) // bloom
                fill(cg, fx, 2, 1, 1, flowerY)   // heart
            }
            // Dithered grass -> dirt transition.
            for px in 0..<W {
                for py in 7..<10 {
                    fill(cg, px, py, 1, 1, (px + py) % 2 == 0 ? grassDk : dirt)
                }
            }
            // Dirt body with clods + roots.
            fill(cg, 0, 10, W, H - 10, dirt)
            for px in 3..<(W - 3) {
                for py in 10..<(H - 1) {
                    let r = hash(px, py, variant + 7)
                    if r < 10 {
                        fill(cg, px, py, 2, 2, dirtDk)
                    } else if r > 93 {
                        fill(cg, px, py, 2, 1, dirtLt)
                    } else if r >= 40 && r < 42 {
                        fill(cg, px, py, 1, 3, dirtDk) // root
                    }
                }
            }
            // Dark base row grounds the strip.
            fill(cg, 0, H - 1, W, 1, outline)
        }
    }

    // MARK: - Platform block (80x12 -> 320x36, exact 4x/3x so pixels stay crisp)

    private static var blockTex: SKTexture?

    static func blockTexture() -> SKTexture {
        if let blockTex { return blockTex }
        let tex = render(w: 80, h: 12) { cg in
            // Grass cap.
            fill(cg, 0, 0, 80, 4, grass)
            fill(cg, 0, 0, 80, 2, grassHi)
            var x = 3
            while x < 77 {
                fill(cg, x, 0, 1, 2, grassHi)
                x += 6
            }
            for px in 2..<78 {
                if hash(px, 3, 1) < 14 { fill(cg, px, 3, 1, 1, grassDk) }
            }
            fill(cg, 20, 2, 3, 2, flowerW)
            fill(cg, 21, 2, 1, 1, flowerY)
            // Dirt chunk with dark rim (floating-island read).
            fill(cg, 0, 4, 80, 8, dirt)
            for px in 2..<78 {
                for py in 4..<11 {
                    let r = hash(px, py, 3)
                    if r < 12 { fill(cg, px, py, 2, 2, dirtDk) }
                    else if r > 92 { fill(cg, px, py, 2, 1, dirtLt) }
                }
            }
            fill(cg, 0, 4, 2, 8, dirtDk)   // left rim
            fill(cg, 78, 4, 2, 8, dirtDk)  // right rim
            fill(cg, 0, 11, 80, 1, outline) // base
        }
        blockTex = tex
        return tex
    }
}
