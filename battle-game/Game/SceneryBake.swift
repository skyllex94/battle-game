import SpriteKit
import UIKit

/// Bakes static SpriteKit node trees into cached textures.
///
/// Decorative scenery (grass blades, rocks, pines, cairns, etc.) is authored
/// as many tiny sprite/shape nodes. Left live, those nodes dominate the scene
/// graph and per-frame draw submission even though they never move. Baking a
/// motif once into a texture lets us draw the same pixels with one node.
///
/// Only colour sprites, shape nodes and their transforms are rasterized.
/// Labels and textured sprites are intentionally not supported; the scenery
/// builders that use this helper are all rectangles, ellipses and polygons.
enum SceneryBake {
    struct Baked {
        let texture: SKTexture
        let frame: CGRect

        var size: CGSize { frame.size }
    }

    private static var cache: [String: Baked] = [:]

    /// Bake (or return the cached bake of) a node tree. The key must uniquely
    /// identify the artwork; callers use level/theme + variant names.
    static func baked(key: String, build: () -> SKNode) -> Baked? {
        if let cached = cache[key] { return cached }
        let root = build()
        guard let baked = rasterize(root) else { return nil }
        cache[key] = baked
        return baked
    }

    /// Add a baked texture to a parent. `origin` is the coordinate where the
    /// baked node's local (0, 0) should land; the sprite is positioned from
    /// the baked frame so centre/anchor choices never shift the artwork.
    @discardableResult
    static func add(_ baked: Baked, to parent: SKNode,
                    origin: CGPoint = .zero,
                    zPosition: CGFloat) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: baked.texture)
        sprite.size = baked.size
        sprite.position = CGPoint(x: origin.x + baked.frame.midX,
                                  y: origin.y + baked.frame.midY)
        sprite.zPosition = zPosition
        parent.addChild(sprite)
        return sprite
    }

    /// Add a baked texture anchored at the baked node's local (0, 0). Use
    /// this for motifs that rotate/sway around their base.
    @discardableResult
    static func addAtRoot(_ baked: Baked, to parent: SKNode,
                          at position: CGPoint,
                          zPosition: CGFloat) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: baked.texture)
        sprite.size = baked.size
        sprite.anchorPoint = CGPoint(x: -baked.frame.minX / baked.frame.width,
                                     y: -baked.frame.minY / baked.frame.height)
        sprite.position = position
        sprite.zPosition = zPosition
        parent.addChild(sprite)
        return sprite
    }

    // MARK: - Rasterizer

    private static func rasterize(_ root: SKNode) -> Baked? {
        let frame = root.calculateAccumulatedFrame()
        guard frame.width >= 0.5, frame.height >= 0.5 else { return nil }

        let w = max(1, Int(ceil(frame.width)))
        let h = max(1, Int(ceil(frame.height)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: CGSize(width: w, height: h),
                                            format: format).image { ctx in
            let cg = ctx.cgContext
            // UIKit draws top-down; SpriteKit/motif coordinates are bottom-up.
            cg.translateBy(x: 0, y: CGFloat(h))
            cg.scaleBy(x: 1, y: -1)
            cg.translateBy(x: -frame.minX, y: -frame.minY)
            draw(root, in: cg, inheritedAlpha: 1)
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return Baked(texture: texture, frame: frame)
    }

    private static func draw(_ node: SKNode, in cg: CGContext,
                             inheritedAlpha: CGFloat) {
        guard !node.isHidden else { return }
        let alpha = inheritedAlpha * node.alpha
        guard alpha > 0.001 else { return }

        cg.saveGState()
        cg.translateBy(x: node.position.x, y: node.position.y)
        if node.zRotation != 0 { cg.rotate(by: node.zRotation) }
        if node.xScale != 1 || node.yScale != 1 {
            cg.scaleBy(x: node.xScale, y: node.yScale)
        }

        if let sprite = node as? SKSpriteNode {
            draw(sprite, in: cg, alpha: alpha)
        } else if let shape = node as? SKShapeNode {
            draw(shape, in: cg, alpha: alpha)
        }

        for child in orderedChildren(node) {
            draw(child, in: cg, inheritedAlpha: alpha)
        }
        cg.restoreGState()
    }

    private static func orderedChildren(_ node: SKNode) -> [SKNode] {
        node.children.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.zPosition == rhs.element.zPosition {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.zPosition < rhs.element.zPosition
            }
            .map(\.element)
    }

    private static func draw(_ sprite: SKSpriteNode, in cg: CGContext,
                             alpha: CGFloat) {
        let w = sprite.size.width
        let h = sprite.size.height
        guard w > 0, h > 0 else { return }
        let rect = CGRect(x: -sprite.anchorPoint.x * w,
                          y: -sprite.anchorPoint.y * h,
                          width: w, height: h)

        if let texture = sprite.texture {
            let image = texture.cgImage()
            cg.saveGState()
            cg.setAlpha(alpha)
            cg.translateBy(x: rect.midX, y: rect.midY)
            cg.scaleBy(x: 1, y: -1)
            cg.draw(image, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
            cg.restoreGState()
        } else {
            cg.saveGState()
            cg.setAlpha(alpha)
            cg.setFillColor(sprite.color.cgColor)
            cg.fill(rect)
            cg.restoreGState()
        }
    }

    private static func draw(_ shape: SKShapeNode, in cg: CGContext,
                             alpha: CGFloat) {
        guard let path = shape.path else { return }
        cg.saveGState()
        cg.setAlpha(alpha)

        if shape.fillColor.cgColor.alpha > 0 {
            cg.addPath(path)
            cg.setFillColor(shape.fillColor.cgColor)
            cg.fillPath()
        }
        if shape.strokeColor.cgColor.alpha > 0, shape.lineWidth > 0 {
            cg.addPath(path)
            cg.setStrokeColor(shape.strokeColor.cgColor)
            cg.setLineWidth(shape.lineWidth)
            cg.strokePath()
        }
        cg.restoreGState()
    }
}
