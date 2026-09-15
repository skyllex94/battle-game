import SpriteKit

/// Which side fired this projectile. Towers only hit enemies;
/// hero bolts hit enemy structures (friendly fire off).
enum Team {
    case player
    case enemy
    case neutral // hero bolts before teams matter; hits enemies only
}

/// Projectile bullets + impact puffs. Purely visual/manual sim (no physics bodies):
/// the scene moves them each frame and kills them on ground/platform/lifetime.
/// Damage vs units/towers lands in the combat stage.
struct Projectile {
    var node: SKShapeNode
    var dir: CGVector
    var life: TimeInterval
    var speed: CGFloat
    var damage: CGFloat
    var team: Team
}

enum ProjectileFactory {
    /// Glowing bolt, 18x5pt, oriented along +x (scene sets zRotation).
    static func makeBolt() -> SKShapeNode {
        let bolt = SKShapeNode(ellipseOf: CGSize(width: 18, height: 5))
        bolt.fillColor = SKColor(red: 1, green: 0.87, blue: 0.35, alpha: 1)
        bolt.strokeColor = SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
        bolt.lineWidth = 1.5
        bolt.zPosition = 15
        let glow = SKShapeNode(ellipseOf: CGSize(width: 27, height: 13))
        glow.fillColor = SKColor(red: 1, green: 0.7, blue: 0.2, alpha: 0.35)
        glow.strokeColor = .clear
        bolt.addChild(glow)
        return bolt
    }

    /// Quick expanding spark on impact. Runs its own remove action.
    static func makeImpactPuff() -> SKShapeNode {
        let puff = SKShapeNode(circleOfRadius: 6)
        puff.fillColor = SKColor(red: 1, green: 0.8, blue: 0.4, alpha: 0.9)
        puff.strokeColor = .clear
        puff.zPosition = 16
        let pop = SKAction.group([
            .scale(to: 2.4, duration: 0.18),
            .fadeOut(withDuration: 0.18),
        ])
        puff.run(.sequence([pop, .removeFromParent()]))
        return puff
    }

    /// Muzzle flash: bright dot at the gun tip, gone in a blink.
    static func makeMuzzleFlash() -> SKShapeNode {
        let flash = SKShapeNode(circleOfRadius: 8)
        flash.fillColor = SKColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
        flash.strokeColor = .clear
        flash.zPosition = 16
        let blink = SKAction.group([
            .scale(to: 0.2, duration: 0.09),
            .fadeOut(withDuration: 0.09),
        ])
        flash.run(.sequence([blink, .removeFromParent()]))
        return flash
    }

    /// Tower bolt, team-tinted so ownership reads at a glance:
    /// blue for player tower, red for enemy tower. Same 24x7 shape as hero bolts.
    static func makeTowerBolt(team: Team) -> SKShapeNode {
        let bolt = SKShapeNode(ellipseOf: CGSize(width: 26, height: 9))
        switch team {
        case .player:
            bolt.fillColor = SKColor(red: 0.45, green: 0.7, blue: 1.0, alpha: 1)
            bolt.strokeColor = SKColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1)
        case .enemy:
            bolt.fillColor = SKColor(red: 1.0, green: 0.45, blue: 0.35, alpha: 1)
            bolt.strokeColor = SKColor(red: 1.0, green: 0.2, blue: 0.15, alpha: 1)
        case .neutral:
            bolt.fillColor = SKColor(red: 1, green: 0.87, blue: 0.35, alpha: 1)
            bolt.strokeColor = SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
        }
        bolt.lineWidth = 2
        bolt.zPosition = 15
        let glow = SKShapeNode(ellipseOf: CGSize(width: 38, height: 20))
        glow.fillColor = bolt.fillColor.withAlphaComponent(0.35)
        glow.strokeColor = .clear
        bolt.addChild(glow)
        return bolt
    }
}
