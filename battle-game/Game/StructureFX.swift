import SpriteKit

/// Shared death FX for structures (towers + HQ bases).
/// Spawns a pixel-chunky explosion at a world position: white flash,
/// fireball, flying debris squares, rising smoke and a shockwave ring.
/// Everything removes itself; the caller only schedules rubble fade-out.
enum StructureFX {

    /// Full explosion sized for the structure (`size` ≈ its height in points).
    static func explode(at pos: CGPoint, in parent: SKNode, team: Team, size: CGFloat) {
        let s = size / 190 // 1.0 for towers, ~0.9 for the HQ
        flash(at: pos, in: parent, scale: s)
        fireball(at: pos, in: parent, scale: s)
        shockwave(at: pos, in: parent, scale: s)
        debris(at: pos, in: parent, team: team, scale: s)
        smoke(at: pos, in: parent, scale: s)
    }

    // MARK: - Pieces

    private static func flash(at pos: CGPoint, in parent: SKNode, scale: CGFloat) {
        let flash = SKShapeNode(circleOfRadius: 34 * scale)
        flash.fillColor = SKColor(red: 1, green: 0.95, blue: 0.8, alpha: 1)
        flash.strokeColor = .clear
        flash.position = pos
        flash.zPosition = 30
        parent.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 2.2, duration: 0.16), .fadeOut(withDuration: 0.16)]),
            .removeFromParent(),
        ]))
    }

    private static func fireball(at pos: CGPoint, in parent: SKNode, scale: CGFloat) {
        let ball = SKShapeNode(circleOfRadius: 26 * scale)
        ball.fillColor = SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
        ball.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
        ball.lineWidth = 3
        ball.position = pos
        ball.zPosition = 29
        parent.addChild(ball)
        ball.run(.sequence([
            .group([.scale(to: 1.9, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
    }

    private static func shockwave(at pos: CGPoint, in parent: SKNode, scale: CGFloat) {
        let ring = SKShapeNode(circleOfRadius: 20 * scale)
        ring.fillColor = .clear
        ring.strokeColor = SKColor(white: 1, alpha: 0.8)
        ring.lineWidth = 5
        ring.position = pos
        ring.zPosition = 28
        parent.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 4.5, duration: 0.45), .fadeOut(withDuration: 0.45)]),
            .removeFromParent(),
        ]))
    }

    /// Pixel debris squares flung upward/outward, fading as they fall.
    private static func debris(at pos: CGPoint, in parent: SKNode, team: Team, scale: CGFloat) {
        let trim: SKColor = team == .player ? SKColor(red: 0.3, green: 0.65, blue: 1, alpha: 1)
                                            : SKColor(red: 1, green: 0.35, blue: 0.25, alpha: 1)
        let colors: [SKColor] = [
            SKColor(white: 0.16, alpha: 1), // dark stone
            SKColor(red: 0.45, green: 0.48, blue: 0.56, alpha: 1), // mid stone
            trim,                            // team chunk
            SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 1), // ember
        ]
        for _ in 0..<14 {
            let side = CGFloat.random(in: 6...14) * scale
            let chunk = SKSpriteNode(color: colors.randomElement()!, size: CGSize(width: side, height: side))
            chunk.position = pos + CGVector(dx: CGFloat.random(in: -20...20) * scale,
                                            dy: CGFloat.random(in: 0...40) * scale)
            chunk.zPosition = 27
            chunk.zRotation = CGFloat.random(in: 0...(.pi * 2))
            parent.addChild(chunk)
            let dx = CGFloat.random(in: -160...160) * scale
            let up = CGFloat.random(in: 120...320) * scale
            let duration = TimeInterval.random(in: 0.5...0.9)
            chunk.run(.sequence([
                .group([
                    .move(by: CGVector(dx: dx, dy: up), duration: duration),
                    .rotate(byAngle: CGFloat.random(in: -3...3), duration: duration),
                    .sequence([.wait(forDuration: duration * 0.5),
                               .fadeOut(withDuration: duration * 0.5)]),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    /// Grey smoke columns rising from the rubble, staggered.
    private static func smoke(at pos: CGPoint, in parent: SKNode, scale: CGFloat) {
        for i in 0..<6 {
            let puff = SKShapeNode(circleOfRadius: CGFloat.random(in: 10...18) * scale)
            puff.fillColor = SKColor(white: 0.25, alpha: 0.7)
            puff.strokeColor = .clear
            puff.position = pos + CGVector(dx: CGFloat.random(in: -40...40) * scale,
                                           dy: CGFloat.random(in: 0...30) * scale)
            puff.zPosition = 26
            parent.addChild(puff)
            let rise: CGFloat = CGFloat.random(in: 60...120) * scale
            let duration = TimeInterval.random(in: 0.9...1.5)
            puff.run(.sequence([
                .wait(forDuration: Double(i) * 0.08),
                .group([
                    .moveBy(x: CGFloat.random(in: -20...20), y: rise, duration: duration),
                    .sequence([.scale(to: 2.2, duration: duration),
                               .fadeOut(withDuration: duration)]),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}

// MARK: - CGPoint helpers (file-local)

private func +(lhs: CGPoint, rhs: CGVector) -> CGPoint {
    CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
}
