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
    var node: SKNode
    var dir: CGVector
    var life: TimeInterval
    var speed: CGFloat
    var damage: CGFloat
    var team: Team
    // MARK: - Behavior (hero special projectiles; towers fly straight)
    /// Motor acceleration along the flight line (rockets).
    var thrust: CGFloat = 0
    /// Downward pull in pts/s² (grenades).
    var gravity: CGFloat = 0
    /// Blast radius on death, 0 = plain hit (rockets, grenades, orbs…).
    var blast: CGFloat = 0
    /// Fuse countdown to detonation, nil = no fuse (grenades).
    var fuse: TimeInterval? = nil
    /// Remaining turf skips (grenades).
    var bounces: Int = 0
    /// Lateral snake amplitude/frequency/phase (choir shards).
    var weaveAmp: CGFloat = 0
    var weaveFreq: Double = 0
    var weavePhase: Double = 0
    /// Flight trail artifact.
    var trail: TrailKind = .none
    var trailAcc: TimeInterval = 0
}

/// Flight trail artifact behind special projectiles.
enum TrailKind {
    case none
    case smoke
    case ember
}

enum ProjectileFactory {
    /// Glowing bolt, 18x5pt, oriented along +x (scene sets zRotation).
    static func makeBolt() -> SKShapeNode {
        heroBolt(.blaster)
    }

    /// Per-gun hero bolts: distinct silhouette, size and heat per weapon
    /// so the active gun reads mid-flight. Orb guns (nova) are round;
    /// rails (piercer/lancer) are long needles; heavies are fat slugs.
    static func heroBolt(_ gun: HeroWeapon) -> SKShapeNode {
        switch gun {
        case .blaster:
            return bolt(w: 18, h: 5,
                        fill: SKColor(red: 1, green: 0.87, blue: 0.35, alpha: 1),
                        stroke: SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1))
        case .scatter:
            return bolt(w: 12, h: 8,
                        fill: SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 1),
                        stroke: SKColor(red: 0.9, green: 0.35, blue: 0.1, alpha: 1))
        case .cannon:
            return bolt(w: 22, h: 12,
                        fill: SKColor(red: 1, green: 0.45, blue: 0.2, alpha: 1),
                        stroke: SKColor(red: 0.8, green: 0.15, blue: 0.1, alpha: 1),
                        glowScale: 1.4)
        case .repeater:
            return bolt(w: 14, h: 4,
                        fill: SKColor(red: 0.4, green: 0.9, blue: 1, alpha: 1),
                        stroke: SKColor(red: 0.1, green: 0.5, blue: 1, alpha: 1),
                        glowScale: 0.8)
        case .piercer:
            return bolt(w: 24, h: 3,
                        fill: SKColor(red: 0.85, green: 1, blue: 1, alpha: 1),
                        stroke: SKColor(red: 0.3, green: 0.85, blue: 1, alpha: 1),
                        glowScale: 0.7)
        case .shredder:
            return bolt(w: 10, h: 4,
                        fill: SKColor(red: 1, green: 0.65, blue: 0.25, alpha: 1),
                        stroke: SKColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 1),
                        glowScale: 0.7)
        case .sunder:
            return bolt(w: 16, h: 8,
                        fill: SKColor(red: 1, green: 0.8, blue: 0.35, alpha: 1),
                        stroke: SKColor(red: 0.75, green: 0.5, blue: 0.1, alpha: 1))
        case .hornet:
            return bolt(w: 10, h: 7,
                        fill: SKColor(red: 0.4, green: 1, blue: 0.55, alpha: 1),
                        stroke: SKColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1))
        case .lancer:
            return bolt(w: 26, h: 4,
                        fill: SKColor(red: 0.92, green: 0.94, blue: 1, alpha: 1),
                        stroke: SKColor(red: 0.6, green: 0.65, blue: 0.9, alpha: 1),
                        glowScale: 0.9)
        case .tempest:
            return bolt(w: 14, h: 6,
                        fill: SKColor(red: 0.7, green: 0.5, blue: 1, alpha: 1),
                        stroke: SKColor(red: 0.45, green: 0.2, blue: 1, alpha: 1))
        case .mauler:
            return bolt(w: 18, h: 10,
                        fill: SKColor(red: 1, green: 0.4, blue: 0.2, alpha: 1),
                        stroke: SKColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1),
                        glowScale: 1.2)
        case .nova:
            return bolt(w: 20, h: 20,
                        fill: SKColor(red: 1, green: 0.8, blue: 0.35, alpha: 1),
                        stroke: SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1),
                        glowScale: 1.5)
        case .requiem:
            return bolt(w: 14, h: 6,
                        fill: SKColor(white: 1, alpha: 1),
                        stroke: SKColor(red: 1, green: 0.8, blue: 0.35, alpha: 1))
        case .oblivion:
            return bolt(w: 26, h: 14,
                        fill: SKColor(red: 0.15, green: 0.05, blue: 0.12, alpha: 1),
                        stroke: SKColor(red: 1, green: 0.2, blue: 0.15, alpha: 1),
                        glowScale: 1.5)
        }
    }

    /// Bolt builder: hot core ellipse + matching stroke + soft halo.
    /// glowScale sizes the halo relative to the core (heavies burn bigger).
    private static func bolt(w: CGFloat, h: CGFloat, fill: SKColor,
                             stroke: SKColor, glowScale: CGFloat = 1.0) -> SKShapeNode {
        let bolt = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        bolt.fillColor = fill
        bolt.strokeColor = stroke
        bolt.lineWidth = 1.5
        bolt.zPosition = 15
        let glow = SKShapeNode(ellipseOf: CGSize(width: (w + 9) * glowScale,
                                                 height: (h + 8) * glowScale))
        glow.fillColor = SKColor(red: 1, green: 0.7, blue: 0.2, alpha: 0.35)
        glow.strokeColor = .clear
        bolt.addChild(glow)
        return bolt
    }

    /// Full hero projectile for a gun: rockets and grenades get bespoke
    /// bodies, everything else flies its bolt.
    static func heroProjectile(_ gun: HeroWeapon) -> SKNode {
        switch gun {
        case .cannon: return makeRocket(bodyW: 24, bodyH: 9,
                                        fill: SKColor(red: 1, green: 0.45, blue: 0.2, alpha: 1),
                                        flame: SKColor(red: 1, green: 0.7, blue: 0.2, alpha: 1))
        case .oblivion: return makeRocket(bodyW: 28, bodyH: 12,
                                          fill: SKColor(red: 0.15, green: 0.05, blue: 0.12, alpha: 1),
                                          flame: SKColor(red: 1, green: 0.2, blue: 0.15, alpha: 1))
        case .sunder: return makeGrenade()
        default: return heroBolt(gun)
        }
    }

    /// Rocket body + flickering motor flame at the tail (-x, since the
    /// scene rotates the node along the flight dir).
    private static func makeRocket(bodyW: CGFloat, bodyH: CGFloat,
                                   fill: SKColor, flame: SKColor) -> SKNode {
        let root = SKNode()
        root.zPosition = 15
        let body = SKShapeNode(ellipseOf: CGSize(width: bodyW, height: bodyH))
        body.fillColor = fill
        body.strokeColor = SKColor(white: 1, alpha: 0.7)
        body.lineWidth = 1.5
        root.addChild(body)
        let flamePath = CGMutablePath()
        flamePath.move(to: CGPoint(x: -bodyW / 2 + 2, y: -bodyH / 4))
        flamePath.addLine(to: CGPoint(x: -bodyW / 2 - 12, y: 0))
        flamePath.addLine(to: CGPoint(x: -bodyW / 2 + 2, y: bodyH / 4))
        flamePath.closeSubpath()
        let tongue = SKShapeNode(path: flamePath)
        tongue.fillColor = flame
        tongue.strokeColor = .clear
        root.addChild(tongue)
        tongue.run(.repeatForever(.sequence([
            .scaleX(to: 0.6, duration: 0.07),
            .scaleX(to: 1.15, duration: 0.07),
        ])))
        return root
    }

    /// Lobbed grenade: dark bomblet + gold band + pulsing primer dot.
    private static func makeGrenade() -> SKNode {
        let root = SKNode()
        root.zPosition = 15
        let shell = SKShapeNode(circleOfRadius: 7)
        shell.fillColor = SKColor(red: 0.16, green: 0.16, blue: 0.2, alpha: 1)
        shell.strokeColor = SKColor(red: 0.75, green: 0.6, blue: 0.2, alpha: 1)
        shell.lineWidth = 2
        root.addChild(shell)
        let primer = SKShapeNode(circleOfRadius: 2.5)
        primer.fillColor = SKColor(red: 1, green: 0.4, blue: 0.1, alpha: 1)
        primer.strokeColor = .clear
        primer.position = CGPoint(x: 0, y: 4)
        root.addChild(primer)
        primer.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: 0.25),
            .fadeAlpha(to: 1.0, duration: 0.25),
        ])))
        return root
    }

    /// Trail mote shed in flight. Self-removing.
    static func makeTrailPuff(_ trail: TrailKind) -> SKShapeNode {
        let puff: SKShapeNode
        switch trail {
        case .smoke:
            puff = SKShapeNode(circleOfRadius: 5)
            puff.fillColor = SKColor(white: 0.6, alpha: 0.5)
            puff.strokeColor = .clear
            puff.run(.sequence([
                .group([.scale(to: 2.0, duration: 0.5),
                        .fadeOut(withDuration: 0.5)]),
                .removeFromParent(),
            ]))
        case .ember:
            puff = SKShapeNode(circleOfRadius: 3)
            puff.fillColor = SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.9)
            puff.strokeColor = .clear
            puff.run(.sequence([
                .group([.moveBy(x: 0, y: 14, duration: 0.4),
                        .fadeOut(withDuration: 0.4)]),
                .removeFromParent(),
            ]))
        case .none:
            puff = SKShapeNode(circleOfRadius: 1)
            puff.alpha = 0
            puff.run(.removeFromParent())
        }
        puff.zPosition = 14
        return puff
    }

    /// Detonation: core puff + hot flash + expanding shockwave ring.
    /// Self-removing container; the scene adds damage + boom separately.
    static func makeExplosion(radius: CGFloat) -> SKNode {
        let root = SKNode()
        root.zPosition = 16
        let puff = SKShapeNode(circleOfRadius: radius * 0.35)
        puff.fillColor = SKColor(red: 1, green: 0.65, blue: 0.25, alpha: 0.95)
        puff.strokeColor = .clear
        root.addChild(puff)
        puff.run(.sequence([
            .group([.scale(to: 2.2, duration: 0.3),
                    .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]))
        let flash = SKShapeNode(circleOfRadius: radius * 0.25)
        flash.fillColor = SKColor(red: 1, green: 0.95, blue: 0.8, alpha: 1)
        flash.strokeColor = .clear
        root.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 0.2, duration: 0.15),
                    .fadeOut(withDuration: 0.15)]),
            .removeFromParent(),
        ]))
        let ring = SKShapeNode(circleOfRadius: radius * 0.9)
        ring.fillColor = .clear
        ring.strokeColor = SKColor(white: 1, alpha: 0.8)
        ring.lineWidth = 3
        ring.setScale(0.3)
        root.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.35),
                    .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
        root.run(.sequence([.wait(forDuration: 0.5), .removeFromParent()]))
        return root
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
