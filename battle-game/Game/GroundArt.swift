import SpriteKit
import UIKit

/// Ground dressing for the hell-lane battlefield.
///
/// Keeps the imported `Hell_ground` lava-crack tile as the walkable
/// surface, but breaks its repetition (aspect-correct tiles, alternating
/// mirror), then layers on: a lit top rim so the walkable edge pops,
/// a strata cliff face below (instead of a flat fill), territory washes
/// that fade toward mid, scattered rocks + lava pools, and looping
/// ember particles. All factor 1.0 world content; decorative pieces are
/// kept low-profile so units and shots stay readable.
enum GroundArt {

    // MARK: - Entry

    static func dress(in world: SKNode) {
        tileSurface(in: world)
        buildRim(in: world)
        buildCliff(in: world)
        buildTerritoryWash(in: world)
        scatterRocks(in: world)
        scatterLavaPools(in: world)
        startEmbers(in: world)
    }

    /// Thin highlight for floating platforms so their tops read too.
    static func platformRim(for rect: CGRect) -> SKSpriteNode {
        let rim = SKSpriteNode(color: SKColor(red: 0.78, green: 0.74, blue: 0.82, alpha: 0.35),
                               size: CGSize(width: rect.width, height: 4))
        rim.position = CGPoint(x: rect.midX, y: rect.maxY - 2)
        rim.zPosition = 2
        return rim
    }

    // MARK: - Surface tiling

    private static var tileH: CGFloat { 87 }

    private static func tileSurface(in world: SKNode) {
        let texture = ImportedArt.skTexture(named: "Hell_ground")
        texture.filteringMode = .nearest
        // Preserve the art's aspect instead of stretching it.
        let tileW = tileH * texture.size().width / texture.size().height
        var x: CGFloat = 0
        var i = 0
        while x < Balance.levelWidth {
            let tile = SKSpriteNode(texture: texture)
            tile.size = CGSize(width: tileW, height: tileH)
            tile.zPosition = 1
            if i % 2 == 0 {
                tile.anchorPoint = CGPoint(x: 0, y: 1)
                tile.position = CGPoint(x: x, y: Balance.groundTopY)
            } else {
                // Mirror every other tile: same seam, no visible repeat.
                tile.anchorPoint = CGPoint(x: 0, y: 1)
                tile.xScale = -1
                tile.position = CGPoint(x: x + tileW, y: Balance.groundTopY)
            }
            world.addChild(tile)
            x += tileW
            i += 1
        }
    }

    // MARK: - Walkable rim

    private static func buildRim(in world: SKNode) {
        // Bright rock lip on the walkable edge…
        let lip = SKSpriteNode(color: SKColor(red: 0.82, green: 0.78, blue: 0.86, alpha: 0.55),
                               size: CGSize(width: Balance.levelWidth, height: 3))
        lip.anchorPoint = CGPoint(x: 0, y: 1)
        lip.position = CGPoint(x: 0, y: Balance.groundTopY + 1)
        lip.zPosition = 2
        world.addChild(lip)
        // …with a faint heat shimmer just beneath it.
        let glow = SKSpriteNode(color: SKColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 0.10),
                                size: CGSize(width: Balance.levelWidth, height: 10))
        glow.anchorPoint = CGPoint(x: 0, y: 1)
        glow.position = CGPoint(x: 0, y: Balance.groundTopY - 3)
        glow.zPosition = 2
        world.addChild(glow)
    }

    // MARK: - Cliff face (strata bands under the surface)

    private static func buildCliff(in world: SKNode) {
        let top = Balance.groundTopY - tileH
        let bands: [(depth: CGFloat, color: SKColor)] = [
            (44, SKColor(red: 0.17, green: 0.10, blue: 0.11, alpha: 1)),
            (50, SKColor(red: 0.11, green: 0.07, blue: 0.08, alpha: 1)),
            (top, SKColor(red: 0.05, green: 0.035, blue: 0.045, alpha: 1)),
        ]
        var y = top
        for (i, band) in bands.enumerated() {
            let depth = min(band.depth, y)
            guard depth > 0 else { break }
            let node = SKSpriteNode(color: band.color,
                                    size: CGSize(width: Balance.levelWidth, height: depth))
            node.anchorPoint = CGPoint(x: 0, y: 1)
            node.position = CGPoint(x: 0, y: y)
            node.zPosition = 0
            world.addChild(node)
            // Strata seam between bands.
            if i < bands.count - 1, y - depth > 0 {
                let seam = SKSpriteNode(color: SKColor(white: 1, alpha: 0.06),
                                        size: CGSize(width: Balance.levelWidth, height: 2))
                seam.anchorPoint = CGPoint(x: 0, y: 1)
                seam.position = CGPoint(x: 0, y: y - depth)
                seam.zPosition = 1
                world.addChild(seam)
            }
            y -= depth
        }
        // Faint embedded embers glowing inside the rock.
        var rng = SeededRNG(seed: 1337)
        for _ in 0..<16 {
            let s: CGFloat = rng.cgFloat(in: 3...6)
            let ember = SKSpriteNode(color: SKColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 0.8),
                                     size: CGSize(width: s, height: s))
            ember.position = CGPoint(x: rng.cgFloat(in: 0...Balance.levelWidth),
                                     y: rng.cgFloat(in: 8...(top - 6)))
            ember.zPosition = 1
            world.addChild(ember)
            let down = SKAction.fadeAlpha(to: 0.25, duration: rng.double(in: 0.6...1.4))
            let up = SKAction.fadeAlpha(to: 0.9, duration: rng.double(in: 0.6...1.4))
            ember.run(SKAction.repeatForever(SKAction.sequence([down, up])))
        }
    }

    // MARK: - Territory wash (fades toward mid so mid feels contested)

    private static func horizontalFadeTexture(color: SKColor, fadeToRight: Bool) -> SKTexture {
        let w = 64, h = 4
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h),
                                           format: format).image { ctx in
            let cg = ctx.cgContext
            guard let comps = color.cgColor.components else { return }
            for x in 0..<w {
                // 0.14 at home edge -> 0 at mid.
                let t = CGFloat(fadeToRight ? x : (w - 1 - x)) / CGFloat(w - 1)
                cg.setFillColor(red: comps[0], green: comps[1], blue: comps[2],
                                alpha: 0.14 * t)
                cg.fill(CGRect(x: x, y: 0, width: 1, height: h))
            }
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return tex
    }

    private static func buildTerritoryWash(in world: SKNode) {
        let half = Balance.levelWidth / 2
        let left = SKSpriteNode(texture: horizontalFadeTexture(
            color: SKColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1), fadeToRight: false))
        left.anchorPoint = CGPoint(x: 0, y: 1)
        left.size = CGSize(width: half, height: tileH)
        left.position = CGPoint(x: 0, y: Balance.groundTopY)
        left.zPosition = 2
        world.addChild(left)
        let right = SKSpriteNode(texture: horizontalFadeTexture(
            color: SKColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 1), fadeToRight: true))
        right.anchorPoint = CGPoint(x: 0, y: 1)
        right.size = CGSize(width: half, height: tileH)
        right.position = CGPoint(x: half, y: Balance.groundTopY)
        right.zPosition = 2
        world.addChild(right)
    }

    // MARK: - Scatter (kept clear of structures + spawn)

    /// X-centres to keep decoration out of (bases, towers, hero spawn).
    private static var clearZones: [ClosedRange<CGFloat>] {
        (Balance.playerTowerXs + Balance.enemyTowerXs
         + [Balance.playerBaseX, Balance.heroSpawnX, Balance.enemyBaseX])
            .map { ($0 - 150)...($0 + 150) }
    }

    private static func isClear(_ x: CGFloat) -> Bool {
        !clearZones.contains(where: { $0.contains(x) })
    }

    /// Low basalt rocks studding the surface (never taller than a boot).
    private static func scatterRocks(in world: SKNode) {
        var rng = SeededRNG(seed: 4242)
        var placed = 0
        var guard_ = 0
        while placed < 26, guard_ < 200 {
            guard_ += 1
            let x = rng.cgFloat(in: 40...(Balance.levelWidth - 40))
            guard isClear(x) else { continue }
            let rock = SKNode()
            rock.position = CGPoint(x: x, y: Balance.groundTopY + 2)
            rock.zPosition = 2
            let lumps = rng.int(in: 2...4)
            for _ in 0..<lumps {
                let s = rng.cgFloat(in: 4...10)
                let lump = SKSpriteNode(
                    color: SKColor(white: rng.cgFloat(in: 0.10...0.22), alpha: 1),
                    size: CGSize(width: s, height: s * 0.8))
                lump.position = CGPoint(x: rng.cgFloat(in: -10...10),
                                        y: rng.cgFloat(in: 1...7))
                rock.addChild(lump)
            }
            // Lit top pixel so rocks catch the rim light.
            let cap = SKSpriteNode(color: SKColor(white: 1, alpha: 0.18),
                                   size: CGSize(width: 8, height: 2))
            cap.position = CGPoint(x: 0, y: 9)
            rock.addChild(cap)
            world.addChild(rock)
            placed += 1
        }
    }

    /// Glowing lava pools breathing slowly in the hollows.
    private static func scatterLavaPools(in world: SKNode) {
        var rng = SeededRNG(seed: 9001)
        var x: CGFloat = 500
        var k = 0
        while x < Balance.levelWidth - 300 {
            x += rng.cgFloat(in: 480...720)
            k += 1
            guard x < Balance.levelWidth - 200, isClear(x) else { continue }
            let w = rng.cgFloat(in: 70...120)
            let pool = SKNode()
            pool.position = CGPoint(x: x, y: Balance.groundTopY + 3)
            pool.zPosition = 2
            // Dark crater…
            let crater = SKShapeNode(ellipseOf: CGSize(width: w, height: 14))
            crater.fillColor = SKColor(white: 0, alpha: 0.55)
            crater.strokeColor = .clear
            pool.addChild(crater)
            // …molten core…
            let lava = SKShapeNode(ellipseOf: CGSize(width: w * 0.7, height: 9))
            lava.fillColor = SKColor(red: 1.0, green: 0.42, blue: 0.12, alpha: 1)
            lava.strokeColor = SKColor(red: 1.0, green: 0.75, blue: 0.3, alpha: 0.9)
            lava.lineWidth = 1.5
            lava.position = CGPoint(x: 0, y: 1)
            pool.addChild(lava)
            // …soft heat halo.
            let halo = SKShapeNode(ellipseOf: CGSize(width: w * 1.5, height: 24))
            halo.fillColor = SKColor(red: 1.0, green: 0.4, blue: 0.12, alpha: 0.12)
            halo.strokeColor = .clear
            pool.addChild(halo)
            world.addChild(pool)
            lava.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.65, duration: 1.1 + Double(k % 3) * 0.3),
                .fadeAlpha(to: 1.0, duration: 1.1 + Double(k % 3) * 0.3),
            ])))
        }
    }

    // MARK: - Embers

    /// Rising sparks looping forever across the lane.
    private static func startEmbers(in world: SKNode) {
        var rng = SeededRNG(seed: 777)
        for i in 0..<18 {
            let s: CGFloat = rng.cgFloat(in: 2...4)
            let ember = SKSpriteNode(color: SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1),
                                     size: CGSize(width: s, height: s))
            let x = rng.cgFloat(in: 0...Balance.levelWidth)
            ember.position = CGPoint(x: x, y: Balance.groundTopY + rng.cgFloat(in: 0...60))
            ember.zPosition = 3
            world.addChild(ember)
            let rise = rng.cgFloat(in: 60...160)
            let drift = rng.cgFloat(in: -30...30)
            let duration = rng.double(in: 2.0...4.5)
            let fly = SKAction.moveBy(x: drift, y: rise, duration: duration)
            let vanish = SKAction.sequence([
                SKAction.wait(forDuration: duration * 0.55),
                SKAction.fadeOut(withDuration: duration * 0.45),
            ])
            let homeX = x
            let reset = SKAction.run {
                ember.position = CGPoint(x: homeX, y: Balance.groundTopY + 4)
            }
            let loop = SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.22),
                SKAction.group([fly, vanish]),
                reset,
                SKAction.fadeIn(withDuration: 0.4),
            ])
            ember.run(SKAction.repeatForever(loop))
        }
    }
}

// MARK: - Deterministic RNG (stable dressing across resets)

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
