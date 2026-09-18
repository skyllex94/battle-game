import SpriteKit

/// Per-level set dressing for battlefields that opt in via
/// `Balance.LevelLayout` (today: Level 2 Rootwall Thicket).
/// - War-banner poles along the lane + tall midfield standards.
/// - Extraterrestrial sky-flocks: manta-like rayeds with glowing eyes,
///   slow wing beats, glide + bob loops, spore trails.
/// - Glow-fern / shroom clusters + drifting spores on the ground.
///
/// All motion is looping SKActions (no per-frame code). Positions derive
/// from the active layout, keeping clear of structures.
enum LevelDressing {

    // MARK: - Deterministic RNG (local; SeededRNG is private to the BG file)

    private struct DressingRNG {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        private mutating func next() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 2685821657736338717
        }
        mutating func cgFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
            let t = CGFloat(next() % 10000) / 10000
            return range.lowerBound + t * (range.upperBound - range.lowerBound)
        }
        mutating func double(in range: ClosedRange<Double>) -> Double {
            let t = Double(next() % 10000) / 10000
            return range.lowerBound + t * (range.upperBound - range.lowerBound)
        }
        mutating func int(in range: ClosedRange<Int>) -> Int {
            let span = range.upperBound - range.lowerBound + 1
            return range.lowerBound + Int(next() % UInt64(max(1, span)))
        }
    }

    // MARK: - Clear zones

    private static var structureXs: [CGFloat] {
        Balance.playerTowerXs + Balance.enemyTowerXs
            + [Balance.playerBaseX, Balance.enemyBaseX, Balance.heroSpawnX]
    }

    private static func isClear(_ x: CGFloat, margin: CGFloat = 170) -> Bool {
        !structureXs.contains(where: { abs($0 - x) < margin })
    }

    // MARK: - War flags

    /// Banner poles beside every tower + base, plus two tall midfield
    /// standards (blue vs red) facing each other across no-man's-land.
    static func buildFlags(in world: SKNode) {
        let gy = Balance.groundTopY
        for x in Balance.playerTowerXs {
            addPennant(in: world, at: CGPoint(x: x - 95, y: gy), team: .player, tall: false)
            addPennant(in: world, at: CGPoint(x: x + 95, y: gy), team: .player, tall: false)
        }
        for x in Balance.enemyTowerXs {
            addPennant(in: world, at: CGPoint(x: x - 95, y: gy), team: .enemy, tall: false)
            addPennant(in: world, at: CGPoint(x: x + 95, y: gy), team: .enemy, tall: false)
        }
        addPennant(in: world, at: CGPoint(x: Balance.playerBaseX - 120, y: gy),
                   team: .player, tall: true)
        addPennant(in: world, at: CGPoint(x: Balance.enemyBaseX + 120, y: gy),
                   team: .enemy, tall: true)
        // Midfield standards: the two armies' colors, nose to nose.
        let mid = Balance.levelWidth / 2
        addPennant(in: world, at: CGPoint(x: mid - 130, y: gy), team: .player, tall: true)
        addPennant(in: world, at: CGPoint(x: mid + 130, y: gy), team: .enemy, tall: true)
    }

    private static func addPennant(in world: SKNode, at base: CGPoint, team: Team, tall: Bool) {
        let poleH: CGFloat = tall ? 200 : 150
        let pole = SKSpriteNode(color: SKColor(white: 0.22, alpha: 1),
                                size: CGSize(width: 5, height: poleH))
        pole.anchorPoint = CGPoint(x: 0.5, y: 0)
        pole.position = base
        pole.zPosition = 4
        world.addChild(pole)
        // Spear tip.
        let tip = SKSpriteNode(color: SKColor(white: 0.55, alpha: 1),
                               size: CGSize(width: 9, height: 9))
        tip.position = CGPoint(x: base.x, y: base.y + poleH + 4)
        tip.zRotation = .pi / 4
        tip.zPosition = 4
        world.addChild(tip)
        // Team cloth with swallowtail notch, fluttering.
        let clothW: CGFloat = tall ? 56 : 44
        let cloth = SKSpriteNode(
            color: team == .player
                ? SKColor(red: 0.3, green: 0.6, blue: 1, alpha: 1)
                : SKColor(red: 1, green: 0.32, blue: 0.22, alpha: 1),
            size: CGSize(width: clothW, height: tall ? 26 : 22))
        cloth.anchorPoint = CGPoint(x: 0, y: 0.5)
        cloth.position = CGPoint(x: base.x + 3, y: base.y + poleH - 14)
        cloth.zPosition = 4
        world.addChild(cloth)
        let notch = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55),
                                 size: CGSize(width: 12, height: 10))
        notch.position = CGPoint(x: clothW - 6, y: 0)
        cloth.addChild(notch)
        // Team emblem dot.
        let pip = SKSpriteNode(color: SKColor(white: 1, alpha: 0.85),
                               size: CGSize(width: 6, height: 6))
        pip.position = CGPoint(x: 10, y: 0)
        cloth.addChild(pip)
        cloth.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.07, duration: 0.8), .rotate(toAngle: -0.07, duration: 0.8),
        ])))
    }

    // MARK: - Alien birds (manta-rayeds)

    /// Slow extraterrestrial flocks gliding above the lane: kite bodies,
    /// beating wing triangles, glowing cyan eyes, bobbing flight, faint
    /// spore trails. Bigger and stranger than the sky layer's distant
    /// chevrons — these read as fauna, not birds.
    static func buildAlienBirds(in layer: SKNode, sceneSize: CGSize) {
        var rng = DressingRNG(seed: 424242)
        // Two flocks: near (large) + far (small, dim).
        for flock in 0..<2 {
            let n = flock == 0 ? 3 : 4
            let s: CGFloat = flock == 0 ? 1.0 : 0.55
            let alpha: CGFloat = flock == 0 ? 1.0 : 0.55
            let baseY = sceneSize.height * (flock == 0 ? 0.30 : 0.38)
            for i in 0..<n {
                let bird = makeRayed(scale: s * rng.cgFloat(in: 0.85...1.2), alpha: alpha)
                let startX = rng.cgFloat(in: -sceneSize.width * 0.6...sceneSize.width * 0.6)
                bird.position = CGPoint(x: startX,
                                        y: baseY + rng.cgFloat(in: -30...50) + CGFloat(i) * 26)
                bird.zPosition = 3
                layer.addChild(bird)
                // Glide across + bob: looped so the flock never leaves.
                let span = sceneSize.width * rng.cgFloat(in: 0.5...0.8)
                let glide = SKAction.moveBy(x: rng.cgFloat(in: -1...1) > 0 ? span : -span,
                                            y: rng.cgFloat(in: -20...10),
                                            duration: rng.double(in: 16...24))
                let bob = SKAction.repeatForever(.sequence([
                    .moveBy(x: 0, y: 14, duration: 2.1),
                    .moveBy(x: 0, y: -14, duration: 2.1),
                ]))
                bird.run(bob)
                bird.run(.repeatForever(.sequence([glide, glide.reversed()])))
                // Spore trail: faint motes shed on a loop.
                let shed = SKAction.repeatForever(.sequence([
                    .wait(forDuration: rng.double(in: 0.5...1.1)),
                    .run { [weak bird] in
                        guard let bird, let parent = bird.parent else { return }
                        let mote = SKSpriteNode(
                            color: SKColor(red: 0.5, green: 1, blue: 0.7, alpha: 0.7),
                            size: CGSize(width: 3, height: 3))
                        mote.position = bird.position
                        mote.zPosition = 2
                        parent.addChild(mote)
                        mote.run(.sequence([
                            .group([.moveBy(x: rng.cgFloat(in: (-10)...10),
                                                     y: rng.cgFloat(in: (-26)...(-12)),
                                                     duration: 1.4),
                                    .fadeOut(withDuration: 1.4)]),
                            .removeFromParent(),
                        ]))
                    },
                ]))
                layer.run(shed)
            }
        }
    }

    /// One rayed: diamond body + tail stinger, two flapping wing pivots,
    /// twin glow eyes up front. Faces +x; mirror via xScale for westbound.
    private static func makeRayed(scale s: CGFloat, alpha: CGFloat) -> SKNode {
        let root = SKNode()
        root.setScale(s)
        root.alpha = alpha
        let bodyColor = SKColor(red: 0.13, green: 0.12, blue: 0.28, alpha: 1)
        let rimColor = SKColor(red: 0.35, green: 0.9, blue: 0.75, alpha: 0.8)

        // Body kite.
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: 34, y: 0))
        bodyPath.addLine(to: CGPoint(x: 0, y: 12))
        bodyPath.addLine(to: CGPoint(x: -30, y: 0))
        bodyPath.addLine(to: CGPoint(x: 0, y: -12))
        bodyPath.closeSubpath()
        let body = SKShapeNode(path: bodyPath)
        body.fillColor = bodyColor
        body.strokeColor = rimColor
        body.lineWidth = 1.5
        root.addChild(body)
        // Tail stinger.
        let tail = SKShapeNode(rectOf: CGSize(width: 26, height: 3))
        tail.fillColor = bodyColor
        tail.strokeColor = .clear
        tail.position = CGPoint(x: -40, y: 0)
        root.addChild(tail)
        // Twin glow eyes (front, +x).
        for ey in [-4, 4] as [CGFloat] {
            let eye = SKShapeNode(circleOfRadius: 2.5)
            eye.fillColor = SKColor(red: 0.5, green: 1, blue: 0.85, alpha: 1)
            eye.strokeColor = .clear
            eye.position = CGPoint(x: 20, y: ey)
            root.addChild(eye)
            eye.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.35, duration: 1.1), .fadeAlpha(to: 1.0, duration: 1.1),
            ])))
        }
        // Wings on pivots at the body midline; flap in opposition phase.
        for side in [1, -1] as [CGFloat] {
            let pivot = SKNode()
            pivot.position = CGPoint(x: -2, y: 0)
            root.addChild(pivot)
            let wingPath = CGMutablePath()
            wingPath.move(to: CGPoint(x: 0, y: 0))
            wingPath.addLine(to: CGPoint(x: -34, y: side * 30))
            wingPath.addLine(to: CGPoint(x: -10, y: side * 6))
            wingPath.closeSubpath()
            let wing = SKShapeNode(path: wingPath)
            wing.fillColor = bodyColor
            wing.strokeColor = rimColor
            wing.lineWidth = 1
            pivot.addChild(wing)
            pivot.run(.repeatForever(.sequence([
                .rotate(toAngle: side * 0.45, duration: 0.7),
                .rotate(toAngle: -side * 0.15, duration: 0.7),
            ])))
        }
        return root
    }

    // MARK: - Lush ground flora

    /// Overgrown lane dressing: breathing glow-fern clusters + shrooms with
    /// halos, drifting green spores, and a faint jungle wash over the turf.
    static func buildGlowFlora(in world: SKNode) {
        let gy = Balance.groundTopY
        let width = Balance.levelWidth
        // Jungle wash: teal-green grade lying over the turf band.
        let wash = SKSpriteNode(color: SKColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 0.10),
                                size: CGSize(width: width, height: 104))
        wash.anchorPoint = CGPoint(x: 0, y: 1)
        wash.position = CGPoint(x: 0, y: gy)
        wash.zPosition = 2
        world.addChild(wash)

        var rng = DressingRNG(seed: 777123)
        var placed = 0, guard_ = 0
        while placed < 18, guard_ < 300 {
            guard_ += 1
            let x = rng.cgFloat(in: 60...(width - 60))
            guard isClear(x) else { continue }
            let cluster = SKNode()
            cluster.position = CGPoint(x: x, y: gy + 2)
            cluster.zPosition = 2
            world.addChild(cluster)
            // Glow fern: 5 blades fanning out, teal-green with lit tips.
            let blades = rng.int(in: 4...6)
            for b in 0..<blades {
                let h = rng.cgFloat(in: 14...30)
                let ang = CGFloat(b - blades / 2) * 0.22
                let blade = SKSpriteNode(color: SKColor(red: 0.15, green: 0.45, blue: 0.28, alpha: 1),
                                         size: CGSize(width: 4, height: h))
                blade.anchorPoint = CGPoint(x: 0.5, y: 0)
                blade.position = .zero
                blade.zRotation = ang
                cluster.addChild(blade)
                let tip = SKSpriteNode(color: SKColor(red: 0.5, green: 1, blue: 0.6, alpha: 1),
                                       size: CGSize(width: 4, height: 4))
                tip.position = CGPoint(x: -sin(ang) * h, y: cos(ang) * h)
                cluster.addChild(tip)
            }
            // Companion shroom with breathing halo.
            if rng.int(in: 0...1) == 0 {
                let stem = SKSpriteNode(color: SKColor(white: 0.85, alpha: 1),
                                        size: CGSize(width: 4, height: 10))
                stem.position = CGPoint(x: 12, y: 5)
                cluster.addChild(stem)
                let cap = SKSpriteNode(color: SKColor(red: 0.45, green: 1, blue: 0.6, alpha: 1),
                                       size: CGSize(width: 14, height: 7))
                cap.position = CGPoint(x: 12, y: 12)
                cluster.addChild(cap)
                let halo = SKShapeNode(ellipseOf: CGSize(width: 44, height: 22))
                halo.fillColor = SKColor(red: 0.45, green: 1, blue: 0.6, alpha: 0.12)
                halo.strokeColor = .clear
                halo.position = cap.position
                cluster.addChild(halo)
                halo.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.4, duration: 1.6),
                    .fadeAlpha(to: 1.0, duration: 1.6),
                ])))
            }
            // Sway the whole cluster.
            cluster.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.03, duration: 2.4), .rotate(toAngle: -0.03, duration: 2.4),
            ])))
            placed += 1
        }

        // Drifting spores rising off the lane.
        for i in 0..<16 {
            let mote = SKSpriteNode(
                color: rng.int(in: 0...2) == 0
                    ? SKColor(red: 0.6, green: 1, blue: 0.65, alpha: 0.9)
                    : SKColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.9),
                size: CGSize(width: 4, height: 4))
            let homeX = rng.cgFloat(in: 0...width)
            mote.position = CGPoint(x: homeX, y: gy + rng.cgFloat(in: 6...90))
            mote.zPosition = 3
            world.addChild(mote)
            let fly = SKAction.moveBy(x: rng.cgFloat(in: -30...30),
                                      y: rng.cgFloat(in: 40...110),
                                      duration: rng.double(in: 2.6...5.0))
            let vanish = SKAction.sequence([
                SKAction.wait(forDuration: 1.6),
                SKAction.fadeOut(withDuration: 1.6),
            ])
            mote.run(.repeatForever(.sequence([
                SKAction.wait(forDuration: Double(i) * 0.25),
                SKAction.group([fly, vanish]),
                SKAction.run { mote.position = CGPoint(x: homeX, y: gy + 6) },
                SKAction.fadeIn(withDuration: 0.4),
            ])))
        }
    }
}
