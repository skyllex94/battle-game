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
    // MARK: - Effects settings

    /// Number of widgets to spawn for an effect authored with `n` parts:
    /// particle scale follows Graphics → Effects Quality, and 0 means the
    /// player turned Particle Effects off.
    private static func fxCount(_ n: Int) -> Int {
        let scale = GameSettings.particleScale
        guard scale > 0 else { return 0 }
        return max(1, Int((Double(n) * scale).rounded()))
    }

    /// Self-removing invisible node returned when a particle effect is off.
    private static func suppressedFX() -> SKShapeNode {
        let node = SKShapeNode()
        node.isHidden = true
        node.run(.sequence([.wait(forDuration: 0.01), .removeFromParent()]))
        return node
    }

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
        guard GameSettings.particlesEnabled else { return suppressedFX() }
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
        guard GameSettings.particlesEnabled else {
            root.run(.sequence([.wait(forDuration: 0.01), .removeFromParent()]))
            return root
        }
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
        guard GameSettings.particlesEnabled else { return suppressedFX() }
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
        guard GameSettings.muzzleFlashEnabled else { return suppressedFX() }
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

    /// Beige dust kicked up behind rolling wheels. Drifts back, grows,
    /// fades. Runs its own remove action.
    static func makeDustPuff() -> SKShapeNode {
        guard GameSettings.particlesEnabled else { return suppressedFX() }
        let puff = SKShapeNode(circleOfRadius: 7)
        puff.fillColor = SKColor(red: 0.78, green: 0.70, blue: 0.53, alpha: 0.55)
        puff.strokeColor = .clear
        puff.zPosition = 8
        let drift = SKAction.moveBy(x: -34, y: 20, duration: 0.55)
        let grow = SKAction.group([
            .scale(to: 2.2, duration: 0.55),
            .fadeOut(withDuration: 0.55),
        ])
        puff.run(.sequence([.group([drift, grow]), .removeFromParent()]))
        return puff
    }

    /// Jetpack exhaust: hot orange flicker + a wisp of smoke trailing
    /// down behind the thrusters. Self-removes (~0.5s).
    static func makeJetExhaust() -> SKNode {
        let root = SKNode()
        guard GameSettings.particlesEnabled else {
            root.run(.sequence([.wait(forDuration: 0.01), .removeFromParent()]))
            return root
        }
        root.zPosition = 8
        let flame = SKShapeNode(circleOfRadius: 4)
        flame.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.15, alpha: 0.95)
        flame.strokeColor = .clear
        root.addChild(flame)
        flame.run(.sequence([
            .group([.moveBy(x: 0, y: -22, duration: 0.3),
                    .scale(to: 0.2, duration: 0.3),
                    .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]))
        let smoke = SKShapeNode(circleOfRadius: 5)
        smoke.fillColor = SKColor(white: 0.25, alpha: 0.5)
        smoke.strokeColor = .clear
        root.addChild(smoke)
        smoke.run(.sequence([
            .wait(forDuration: 0.08),
            .group([.moveBy(x: 6, y: -30, duration: 0.45),
                    .scale(to: 1.8, duration: 0.45),
                    .fadeOut(withDuration: 0.45)]),
            .removeFromParent(),
        ]))
        root.run(.sequence([.wait(forDuration: 0.6), .removeFromParent()]))
        return root
    }

    /// Jetpack-droid airburst: core flash + fireballs + smoke plume +
    /// wreck chunks raining down + spark spray. Self-removes (~1.4s).
    static func makeJetExplosion() -> SKNode {
        let root = SKNode()
        // Core flash.
        let flash = SKShapeNode(circleOfRadius: 20)
        flash.fillColor = SKColor(red: 1, green: 0.85, blue: 0.5, alpha: 1)
        flash.strokeColor = .clear
        flash.zPosition = 16
        root.addChild(flash)
        flash.run(.sequence([.group([.scale(to: 1.8, duration: 0.2),
                                     .fadeOut(withDuration: 0.2)]),
                             .removeFromParent()]))
        // Fireballs blooming outward.
        let fireOffsets = [CGPoint(x: -20, y: 8), CGPoint(x: 18, y: 16),
                           CGPoint(x: 2, y: 26), CGPoint(x: -6, y: -10)]
        for i in 0..<fxCount(fireOffsets.count) {
            let off = fireOffsets[i]
            let fire = SKShapeNode(circleOfRadius: 10)
            fire.fillColor = SKColor(red: 1, green: 0.45 + CGFloat(i) * 0.08,
                                     blue: 0.12, alpha: 1)
            fire.strokeColor = .clear
            fire.position = .zero
            fire.zPosition = 16
            root.addChild(fire)
            fire.run(.sequence([
                .wait(forDuration: Double(i) * 0.05),
                .group([.move(to: off, duration: 0.32),
                        .scale(to: 0.3, duration: 0.32),
                        .fadeOut(withDuration: 0.32)]),
                .removeFromParent(),
            ]))
        }
        // Smoke plume rising off the blast.
        for i in 0..<fxCount(4) {
            let smoke = SKShapeNode(circleOfRadius: 9)
            smoke.fillColor = SKColor(white: 0.16, alpha: 0.75)
            smoke.strokeColor = .clear
            smoke.position = CGPoint(x: CGFloat(i - 1) * 8, y: 6)
            smoke.zPosition = 15
            root.addChild(smoke)
            smoke.run(.sequence([
                .wait(forDuration: 0.08 + Double(i) * 0.06),
                .group([.moveBy(x: CGFloat(i - 1) * 10, y: 90, duration: 0.9),
                        .scale(to: 2.4, duration: 0.9),
                        .fadeOut(withDuration: 0.9)]),
                .removeFromParent(),
            ]))
        }
        // Burning wreck chunks raining down.
        let debrisKicks = [CGVector(dx: -70, dy: -140), CGVector(dx: -30, dy: -180),
                           CGVector(dx: 25, dy: -160), CGVector(dx: 60, dy: -120),
                           CGVector(dx: 0, dy: -200)]
        for i in 0..<fxCount(debrisKicks.count) {
            let kick = debrisKicks[i]
            let chunk = SKSpriteNode(color: SKColor(white: 0.1, alpha: 1),
                                     size: CGSize(width: 7, height: 5))
            chunk.position = .zero
            chunk.zPosition = 16
            chunk.zRotation = CGFloat(i) * 0.6
            root.addChild(chunk)
            chunk.run(.sequence([
                .wait(forDuration: Double(i) * 0.03),
                .group([.moveBy(x: kick.dx, y: kick.dy, duration: 0.65),
                        .rotate(byAngle: CGFloat(i + 1) * 1.4, duration: 0.65),
                        .sequence([.wait(forDuration: 0.35),
                                   .fadeOut(withDuration: 0.3)])]),
                .removeFromParent(),
            ]))
        }
        // Spark spray.
        for i in 0..<fxCount(6) {
            let spark = SKShapeNode(circleOfRadius: 2.5)
            spark.fillColor = SKColor(red: 1, green: 0.8, blue: 0.3, alpha: 1)
            spark.strokeColor = .clear
            spark.position = .zero
            spark.zPosition = 17
            root.addChild(spark)
            let a = CGFloat(i) * .pi / 3
            spark.run(.sequence([
                .group([.moveBy(x: cos(a) * 60, y: sin(a) * 45, duration: 0.38),
                        .fadeOut(withDuration: 0.38)]),
                .removeFromParent(),
            ]))
        }
        root.run(.sequence([.wait(forDuration: 1.4), .removeFromParent()]))
        return root
    }

    /// Vehicle kill: core flash + fireballs + rising smoke + arcing debris
    /// + spark spray, all looping-free SKActions. Self-removes (~1.6s).
    static func makeTruckExplosion() -> SKNode {
        let root = SKNode()
        // Core flash.
        let flash = SKShapeNode(circleOfRadius: 26)
        flash.fillColor = SKColor(red: 1, green: 0.85, blue: 0.5, alpha: 1)
        flash.strokeColor = .clear
        flash.zPosition = 16
        root.addChild(flash)
        flash.run(.sequence([.group([.scale(to: 1.8, duration: 0.22),
                                     .fadeOut(withDuration: 0.22)]),
                             .removeFromParent()]))
        // Fireballs: orange, staggered outward.
        let fireOffsets = [CGPoint(x: -24, y: 10), CGPoint(x: 20, y: 22),
                           CGPoint(x: 4, y: 34), CGPoint(x: -8, y: -6)]
        for i in 0..<fxCount(fireOffsets.count) {
            let off = fireOffsets[i]
            let fire = SKShapeNode(circleOfRadius: 12)
            fire.fillColor = SKColor(red: 1, green: 0.45 + CGFloat(i) * 0.08,
                                     blue: 0.12, alpha: 1)
            fire.strokeColor = .clear
            fire.position = .zero
            fire.zPosition = 16
            root.addChild(fire)
            fire.run(.sequence([
                .wait(forDuration: Double(i) * 0.05),
                .group([.move(to: off, duration: 0.35),
                        .scale(to: 0.3, duration: 0.35),
                        .fadeOut(withDuration: 0.35)]),
                .removeFromParent(),
            ]))
        }
        // Smoke: dark gray, rising + growing + fading over ~1.2s.
        let smokeOffsets = [CGPoint(x: -30, y: 90), CGPoint(x: -10, y: 110),
                            CGPoint(x: 12, y: 100), CGPoint(x: 28, y: 85),
                            CGPoint(x: 0, y: 120)]
        for i in 0..<fxCount(smokeOffsets.count) {
            let off = smokeOffsets[i]
            let smoke = SKShapeNode(circleOfRadius: 10)
            smoke.fillColor = SKColor(white: 0.16, alpha: 0.75)
            smoke.strokeColor = .clear
            smoke.position = CGPoint(x: CGFloat(i - 2) * 8, y: 10)
            smoke.zPosition = 15
            root.addChild(smoke)
            smoke.run(.sequence([
                .wait(forDuration: 0.1 + Double(i) * 0.06),
                .group([.move(to: off, duration: 1.0),
                        .scale(to: 2.6, duration: 1.0),
                        .fadeOut(withDuration: 1.0)]),
                .removeFromParent(),
            ]))
        }
        // Debris: small dark hull chunks arcing out.
        let debrisKicks = [CGVector(dx: -90, dy: 120), CGVector(dx: -40, dy: 160),
                           CGVector(dx: 30, dy: 150), CGVector(dx: 80, dy: 110),
                           CGVector(dx: 0, dy: 180), CGVector(dx: -70, dy: 70)]
        for i in 0..<fxCount(debrisKicks.count) {
            let kick = debrisKicks[i]
            let chunk = SKSpriteNode(color: SKColor(white: 0.1, alpha: 1),
                                     size: CGSize(width: 8, height: 6))
            chunk.position = .zero
            chunk.zPosition = 16
            chunk.zRotation = CGFloat(i) * 0.5
            root.addChild(chunk)
            chunk.run(.sequence([
                .wait(forDuration: Double(i) * 0.03),
                .group([.moveBy(x: kick.dx, y: kick.dy, duration: 0.7),
                        .rotate(byAngle: CGFloat(i + 1) * 1.2, duration: 0.7),
                        .sequence([.wait(forDuration: 0.4),
                                   .fadeOut(withDuration: 0.3)])]),
                .removeFromParent(),
            ]))
        }
        // Spark spray: tiny hot dots, fast outward.
        for i in 0..<fxCount(6) {
            let spark = SKShapeNode(circleOfRadius: 2.5)
            spark.fillColor = SKColor(red: 1, green: 0.8, blue: 0.3, alpha: 1)
            spark.strokeColor = .clear
            spark.position = .zero
            spark.zPosition = 17
            root.addChild(spark)
            let a = CGFloat(i) * .pi / 3
            spark.run(.sequence([
                .group([.moveBy(x: cos(a) * 70, y: sin(a) * 50 + 30, duration: 0.4),
                        .fadeOut(withDuration: 0.4)]),
                .removeFromParent(),
            ]))
        }
        root.run(.sequence([.wait(forDuration: 1.6), .removeFromParent()]))
        return root
    }

    /// Mech kill: big shockwave + core flash + heavy fireballs + rolling
    /// smoke + big armored debris chunks + spark shower. Self-removes (~1.8s).
    static func makeMechExplosion() -> SKNode {
        let root = SKNode()
        // Shockwave ring first (it reads as the impact).
        let ring = SKShapeNode(circleOfRadius: 34)
        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 1, green: 0.6, blue: 0.25, alpha: 0.9)
        ring.lineWidth = 5
        ring.setScale(0.25)
        root.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 3.2, duration: 0.42), .fadeOut(withDuration: 0.42)]),
            .removeFromParent(),
        ]))
        // Core flash.
        let flash = SKShapeNode(circleOfRadius: 34)
        flash.fillColor = SKColor(red: 1, green: 0.88, blue: 0.55, alpha: 1)
        flash.strokeColor = .clear
        flash.zPosition = 16
        root.addChild(flash)
        flash.run(.sequence([.group([.scale(to: 2.1, duration: 0.24),
                                     .fadeOut(withDuration: 0.24)]),
                             .removeFromParent()]))
        // Fireballs blooming outward.
        let fireOffsets = [CGPoint(x: -40, y: 14), CGPoint(x: 34, y: 26),
                           CGPoint(x: 6, y: 44), CGPoint(x: -14, y: -10),
                           CGPoint(x: 18, y: 6), CGPoint(x: -26, y: 34)]
        for i in 0..<fxCount(fireOffsets.count) {
            let off = fireOffsets[i]
            let fire = SKShapeNode(circleOfRadius: 16)
            fire.fillColor = SKColor(red: 1, green: 0.42 + CGFloat(i % 3) * 0.09,
                                     blue: 0.10, alpha: 1)
            fire.strokeColor = .clear
            fire.position = .zero
            fire.zPosition = 16
            root.addChild(fire)
            fire.run(.sequence([
                .wait(forDuration: Double(i) * 0.05),
                .group([.move(to: off, duration: 0.4),
                        .scale(to: 0.28, duration: 0.4),
                        .fadeOut(withDuration: 0.4)]),
                .removeFromParent(),
            ]))
        }
        // Rolling smoke plume.
        for i in 0..<fxCount(6) {
            let smoke = SKShapeNode(circleOfRadius: 13)
            smoke.fillColor = SKColor(white: 0.15, alpha: 0.78)
            smoke.strokeColor = .clear
            smoke.position = CGPoint(x: CGFloat(i - 3) * 9, y: 10)
            smoke.zPosition = 15
            root.addChild(smoke)
            smoke.run(.sequence([
                .wait(forDuration: 0.08 + Double(i) * 0.06),
                .group([.moveBy(x: CGFloat(i - 3) * 12, y: 120, duration: 1.15),
                        .scale(to: 3.0, duration: 1.15),
                        .fadeOut(withDuration: 1.15)]),
                .removeFromParent(),
            ]))
        }
        // Heavy armored debris chunks.
        let debrisKicks = [CGVector(dx: -120, dy: 170), CGVector(dx: -60, dy: 210),
                           CGVector(dx: 40, dy: 200), CGVector(dx: 120, dy: 160),
                           CGVector(dx: 10, dy: 240), CGVector(dx: -95, dy: 110),
                           CGVector(dx: 90, dy: 100)]
        for i in 0..<fxCount(debrisKicks.count) {
            let kick = debrisKicks[i]
            let chunk = SKSpriteNode(color: SKColor(red: 0.22, green: 0.22, blue: 0.27, alpha: 1),
                                     size: CGSize(width: 12, height: 9))
            chunk.position = .zero
            chunk.zPosition = 16
            chunk.zRotation = CGFloat(i) * 0.5
            root.addChild(chunk)
            chunk.run(.sequence([
                .wait(forDuration: Double(i) * 0.035),
                .group([.moveBy(x: kick.dx, y: kick.dy, duration: 0.85),
                        .rotate(byAngle: CGFloat(i + 1) * 1.5, duration: 0.85),
                        .sequence([.wait(forDuration: 0.5),
                                   .fadeOut(withDuration: 0.3)])]),
                .removeFromParent(),
            ]))
        }
        // Spark shower.
        for i in 0..<fxCount(10) {
            let spark = SKShapeNode(circleOfRadius: 3)
            spark.fillColor = SKColor(red: 1, green: 0.72, blue: 0.25, alpha: 1)
            spark.strokeColor = .clear
            spark.position = .zero
            spark.zPosition = 17
            root.addChild(spark)
            let a = CGFloat(i) * .pi / 5
            spark.run(.sequence([
                .group([.moveBy(x: cos(a) * 95, y: sin(a) * 70 + 25, duration: 0.5),
                        .fadeOut(withDuration: 0.5)]),
                .removeFromParent(),
            ]))
        }
        root.run(.sequence([.wait(forDuration: 1.8), .removeFromParent()]))
        return root
    }

    /// Heavy footfall: a wide dust kick + grit specks under a mech step.
    static func makeFootfallDust() -> SKNode {
        let root = SKNode()
        guard GameSettings.particlesEnabled else {
            root.run(.sequence([.wait(forDuration: 0.01), .removeFromParent()]))
            return root
        }
        root.zPosition = 8
        let puff = SKShapeNode(ellipseOf: CGSize(width: 26, height: 12))
        puff.fillColor = SKColor(red: 0.80, green: 0.70, blue: 0.50, alpha: 0.55)
        puff.strokeColor = .clear
        root.addChild(puff)
        puff.run(.sequence([
            .group([.scale(to: 2.3, duration: 0.5),
                    .moveBy(x: -14, y: 12, duration: 0.5),
                    .fadeOut(withDuration: 0.5)]),
            .removeFromParent(),
        ]))
        for i in 0..<3 {
            let grit = SKSpriteNode(color: SKColor(red: 0.58, green: 0.44, blue: 0.28, alpha: 0.9),
                                    size: CGSize(width: 3, height: 3))
            grit.position = CGPoint(x: CGFloat(i - 1) * 7, y: 2)
            root.addChild(grit)
            grit.run(.sequence([
                .group([.moveBy(x: CGFloat(i - 1) * 16, y: 18, duration: 0.45),
                        .fadeOut(withDuration: 0.45)]),
                .removeFromParent(),
            ]))
        }
        root.run(.sequence([.wait(forDuration: 0.6), .removeFromParent()]))
        return root
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
