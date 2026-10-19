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

    // MARK: - Dune wash (Level 4 Dune Atoll at dawn)

    /// White-sand lane dressing: a pale gold wash over the turf band plus
    /// sparse dry grass tufts swaying in the morning air. No glow flora —
    /// the atoll is open sand, not jungle.
    static func buildDuneWash(in world: SKNode) {
        let gy = Balance.groundTopY
        let width = Balance.levelWidth
        // Sand wash: pale gold grade lying over the turf band.
        let wash = SKSpriteNode(color: SKColor(red: 0.85, green: 0.72, blue: 0.48, alpha: 0.12),
                                size: CGSize(width: width, height: 104))
        wash.anchorPoint = CGPoint(x: 0, y: 1)
        wash.position = CGPoint(x: 0, y: gy)
        wash.zPosition = 2
        world.addChild(wash)

        var rng = DressingRNG(seed: 40404)
        var placed = 0, guard_ = 0
        while placed < 12, guard_ < 200 {
            guard_ += 1
            let x = rng.cgFloat(in: 60...(width - 60))
            guard isClear(x) else { continue }
            let tuft = SKNode()
            tuft.position = CGPoint(x: x, y: gy + 2)
            tuft.zPosition = 2
            world.addChild(tuft)
            // Dry grass: 3-4 straw blades leaning downwind.
            let blades = rng.int(in: 3...4)
            for b in 0..<blades {
                let h = rng.cgFloat(in: 10...20)
                let ang = 0.25 + CGFloat(b) * 0.12
                let blade = SKSpriteNode(
                    color: SKColor(red: 0.62, green: 0.52, blue: 0.32, alpha: 1),
                    size: CGSize(width: 3, height: h))
                blade.anchorPoint = CGPoint(x: 0.5, y: 0)
                blade.zRotation = ang
                tuft.addChild(blade)
                let tip = SKSpriteNode(
                    color: SKColor(red: 0.90, green: 0.80, blue: 0.55, alpha: 1),
                    size: CGSize(width: 3, height: 3))
                tip.position = CGPoint(x: -sin(ang) * h, y: cos(ang) * h)
                tuft.addChild(tip)
            }
            tuft.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.04, duration: 2.8), .rotate(toAngle: -0.04, duration: 2.8),
            ])))
            placed += 1
        }
    }

    // MARK: - Sunscorch field (Level 5 Sunscorch Expanse at high noon)

    /// Open rolling fields: a bleached noon wash over the turf band, long
    /// low swells suggesting very small dips + a gentle ascent mid-lane,
    /// and sparse sunburnt tufts. Visual only — gameplay stays flat.
    /// (No jumping platforms on this level by design.)
    static func buildSunscorchField(in world: SKNode) {
        let gy = Balance.groundTopY
        let width = Balance.levelWidth
        // Noon wash: bleached gold-white grade lying over the turf band.
        let wash = SKSpriteNode(color: SKColor(red: 1.0, green: 0.90, blue: 0.66, alpha: 0.16),
                                size: CGSize(width: width, height: 104))
        wash.anchorPoint = CGPoint(x: 0, y: 1)
        wash.position = CGPoint(x: 0, y: gy)
        wash.zPosition = 2
        world.addChild(wash)

        // Rolling swells: long shallow ellipses lying on the lane, lighter
        // crowns up, soft shadows down — reads as dips + ascending ground.
        var rng = DressingRNG(seed: 50505)
        let swells = 9
        for i in 0..<swells {
            let w = rng.cgFloat(in: 620...980)
            let h: CGFloat = rng.cgFloat(in: 16...28)
            let x = (width / CGFloat(swells)) * (CGFloat(i) + 0.5) + rng.cgFloat(in: -120...120)
            let swell = SKShapeNode(ellipseOf: CGSize(width: w, height: h * 2))
            swell.fillColor = SKColor(red: 0.55, green: 0.48, blue: 0.28, alpha: 0.35)
            swell.strokeColor = .clear
            swell.position = CGPoint(x: x, y: gy + 2)
            swell.zPosition = 1
            world.addChild(swell)
            // Sunlit crown along the swell top.
            let crown = SKSpriteNode(color: SKColor(red: 1.0, green: 0.93, blue: 0.70, alpha: 0.35),
                                     size: CGSize(width: w * 0.85, height: 4))
            crown.position = CGPoint(x: x, y: gy + h * 0.7)
            crown.zPosition = 2
            world.addChild(crown)
        }

        // Sparse sunburnt tufts, kept clear of structures.
        var placed = 0, guard_ = 0
        while placed < 10, guard_ < 200 {
            guard_ += 1
            let x = rng.cgFloat(in: 60...(width - 60))
            guard isClear(x) else { continue }
            let tuft = SKNode()
            tuft.position = CGPoint(x: x, y: gy + 2)
            tuft.zPosition = 2
            world.addChild(tuft)
            let blades = rng.int(in: 2...3)
            for b in 0..<blades {
                let h = rng.cgFloat(in: 8...16)
                let ang = 0.20 + CGFloat(b) * 0.14
                let blade = SKSpriteNode(
                    color: SKColor(red: 0.58, green: 0.50, blue: 0.30, alpha: 1),
                    size: CGSize(width: 3, height: h))
                blade.anchorPoint = CGPoint(x: 0.5, y: 0)
                blade.zRotation = ang
                tuft.addChild(blade)
            }
            tuft.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.05, duration: 2.4), .rotate(toAngle: -0.05, duration: 2.4),
            ])))
            placed += 1
        }
    }

    // MARK: - Sandhold keep (Level 6 Sandhold Citadel at ember dusk)

    /// Desert-keep dressing: a burnt-ember wash over the turf band, wall
    /// torches breathing on poles along the lane, and ember sparks rising
    /// off the sand. Visual only — gameplay stays flat.
    static func buildSandholdKeep(in world: SKNode) {
        let gy = Balance.groundTopY
        let width = Balance.levelWidth
        // Ember wash: burnt-orange grade lying over the turf band.
        let wash = SKSpriteNode(color: SKColor(red: 0.95, green: 0.45, blue: 0.18, alpha: 0.10),
                                size: CGSize(width: width, height: 104))
        wash.anchorPoint = CGPoint(x: 0, y: 1)
        wash.position = CGPoint(x: 0, y: gy)
        wash.zPosition = 2
        world.addChild(wash)

        var rng = DressingRNG(seed: 60606)
        // Wall torches: poles with breathing ember heads, clear of structures.
        var placed = 0, guard_ = 0
        while placed < 10, guard_ < 200 {
            guard_ += 1
            let x = rng.cgFloat(in: 60...(width - 60))
            guard isClear(x) else { continue }
            let pole = SKSpriteNode(color: SKColor(white: 0.15, alpha: 1),
                                    size: CGSize(width: 5, height: 64))
            pole.anchorPoint = CGPoint(x: 0.5, y: 0)
            pole.position = CGPoint(x: x, y: gy)
            pole.zPosition = 3
            world.addChild(pole)
            let flame = SKSpriteNode(color: SKColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1),
                                     size: CGSize(width: 10, height: 14))
            flame.position = CGPoint(x: x, y: gy + 70)
            flame.zPosition = 3
            world.addChild(flame)
            let halo = SKShapeNode(ellipseOf: CGSize(width: 52, height: 30))
            halo.fillColor = SKColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 0.14)
            halo.strokeColor = .clear
            halo.position = flame.position
            halo.zPosition = 3
            world.addChild(halo)
            halo.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.4, duration: 0.9),
                .fadeAlpha(to: 1.0, duration: 0.9),
            ])))
            flame.run(.repeatForever(.sequence([
                .scale(to: 1.15, duration: 0.45), .scale(to: 1.0, duration: 0.45),
            ])))
            placed += 1
        }

        // Rising ember sparks off the sand.
        for i in 0..<18 {
            let mote = SKSpriteNode(color: SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 0.9),
                                    size: CGSize(width: 3, height: 3))
            let homeX = rng.cgFloat(in: 0...width)
            mote.position = CGPoint(x: homeX, y: gy + rng.cgFloat(in: 6...60))
            mote.zPosition = 3
            world.addChild(mote)
            let fly = SKAction.moveBy(x: rng.cgFloat(in: -24...24),
                                      y: rng.cgFloat(in: 60...130),
                                      duration: rng.double(in: 2.2...4.2))
            let vanish = SKAction.sequence([
                SKAction.wait(forDuration: 1.4),
                SKAction.fadeOut(withDuration: 1.4),
            ])
            mote.run(.repeatForever(.sequence([
                SKAction.wait(forDuration: Double(i) * 0.2),
                SKAction.group([fly, vanish]),
                SKAction.run { mote.position = CGPoint(x: homeX, y: gy + 6) },
                SKAction.fadeIn(withDuration: 0.4),
            ])))
        }
    }

    // MARK: - Dune sea (Level 7 Sirocco Dunes, golden desert day)

    /// Desert dressing on the flat sand deck: dry dune-grass
    /// tufts swaying downwind, half-buried bones, scattered pebbles, and
    /// wind-blown sand streaking sideways across the lane.
    static func buildDuneSea(in world: SKNode) {
        let width = Balance.levelWidth
        var rng = DressingRNG(seed: 70707)

        // Dry dune-grass tufts: pale straw blades leaning downwind.
        var placed = 0, guard_ = 0
        while placed < 22, guard_ < 300 {
            guard_ += 1
            let x = rng.cgFloat(in: 60...(width - 60))
            guard isClear(x) else { continue }
            let tuft = SKNode()
            tuft.position = CGPoint(x: x, y: Balance.groundY(at: x) + 2)
            tuft.zPosition = 2
            world.addChild(tuft)
            let blades = rng.int(in: 3...5)
            for b in 0..<blades {
                let h = rng.cgFloat(in: 12...26)
                let ang = 0.30 + CGFloat(b) * 0.10
                let blade = SKSpriteNode(
                    color: SKColor(red: 0.72, green: 0.60, blue: 0.36, alpha: 1),
                    size: CGSize(width: 3, height: h))
                blade.anchorPoint = CGPoint(x: 0.5, y: 0)
                blade.zRotation = ang
                tuft.addChild(blade)
                let tip = SKSpriteNode(
                    color: SKColor(red: 0.98, green: 0.88, blue: 0.62, alpha: 1),
                    size: CGSize(width: 3, height: 3))
                tip.position = CGPoint(x: -sin(ang) * h, y: cos(ang) * h)
                tuft.addChild(tip)
            }
            tuft.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.05, duration: 2.2), .rotate(toAngle: -0.05, duration: 2.2),
            ])))
            placed += 1
        }

        // Half-buried bones: bleached rib arcs poking out of the sand.
        placed = 0; guard_ = 0
        while placed < 7, guard_ < 200 {
            guard_ += 1
            let x = rng.cgFloat(in: 100...(width - 100))
            guard isClear(x) else { continue }
            let gy = Balance.groundY(at: x)
            let bones = SKNode()
            bones.position = CGPoint(x: x, y: gy)
            bones.zPosition = 2
            world.addChild(bones)
            let bone = SKColor(red: 0.92, green: 0.86, blue: 0.70, alpha: 1)
            for r in 0..<3 {
                let rib = SKSpriteNode(color: bone, size: CGSize(width: 4, height: 14 + CGFloat(r) * 4))
                rib.position = CGPoint(x: CGFloat(r) * 10 - 10, y: 6)
                rib.zRotation = -0.25 + CGFloat(r) * 0.12
                bones.addChild(rib)
            }
            let spine = SKSpriteNode(color: bone, size: CGSize(width: 34, height: 4))
            spine.position = CGPoint(x: 0, y: 2)
            bones.addChild(spine)
            placed += 1
        }

        // Scattered pebbles riding the swells.
        placed = 0; guard_ = 0
        while placed < 30, guard_ < 300 {
            guard_ += 1
            let x = rng.cgFloat(in: 40...(width - 40))
            guard isClear(x) else { continue }
            let s = rng.cgFloat(in: 3...7)
            let peb = SKSpriteNode(
                color: SKColor(red: 0.45, green: 0.33, blue: 0.20, alpha: 1),
                size: CGSize(width: s, height: s * 0.7))
            peb.position = CGPoint(x: x, y: Balance.groundY(at: x) + 2)
            peb.zPosition = 2
            world.addChild(peb)
            placed += 1
        }

        // Wind-blown sand: pale grains streaking sideways, hugging the deck.
        for i in 0..<26 {
            let grain = SKSpriteNode(color: SKColor(red: 1.0, green: 0.90, blue: 0.66, alpha: 0.8),
                                     size: CGSize(width: rng.cgFloat(in: 3...6), height: 2))
            let homeX = rng.cgFloat(in: 0...width)
            let homeY = Balance.groundY(at: homeX) + rng.cgFloat(in: 4...40)
            grain.position = CGPoint(x: homeX, y: homeY)
            grain.zPosition = 3
            world.addChild(grain)
            let streak = SKAction.moveBy(x: rng.cgFloat(in: 120...260),
                                         y: rng.cgFloat(in: -8...8),
                                         duration: rng.double(in: 1.6...3.0))
            let vanish = SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.fadeOut(withDuration: 1.0),
            ])
            grain.run(.repeatForever(.sequence([
                SKAction.wait(forDuration: Double(i) * 0.12),
                SKAction.group([streak, vanish]),
                SKAction.run {
                    let nx = homeX
                    grain.position = CGPoint(x: nx, y: Balance.groundY(at: nx) + 4)
                },
                SKAction.fadeIn(withDuration: 0.4),
            ])))
        }
    }

    // MARK: - Oasis waste (Level 8, desert with life)

    /// Desert ornaments on the flat sand deck: date palms with swaying
    /// fronds, woven market-stall poles, caravan crates + barrels, and a
    /// pair of shade tents. Everything sits on the deck and clears the
    /// structures so units stay readable.
    static func buildOasisWaste(in world: SKNode) {
        let width = Balance.levelWidth
        var rng = DressingRNG(seed: 81818)

        // Date palms: trunk + frond crown, leaning with the wind.
        var placed = 0, guard_ = 0
        while placed < 12, guard_ < 300 {
            guard_ += 1
            let x = rng.cgFloat(in: 80...(width - 80))
            guard isClear(x, margin: 200) else { continue }
            let gy = Balance.groundY(at: x)
            let palm = SKNode()
            palm.position = CGPoint(x: x, y: gy)
            palm.zPosition = 3
            world.addChild(palm)
            let th: CGFloat = rng.cgFloat(in: 70...110)
            let lean = CGFloat(rng.int(in: -2...2)) * 0.06
            let trunk = SKNode()
            trunk.zRotation = lean
            palm.addChild(trunk)
            let pole = SKSpriteNode(color: SKColor(red: 0.42, green: 0.30, blue: 0.18, alpha: 1),
                                    size: CGSize(width: 8, height: th))
            pole.anchorPoint = CGPoint(x: 0.5, y: 0)
            pole.position = CGPoint(x: 0, y: 0)
            trunk.addChild(pole)
            let top = CGPoint(x: 0, y: th)
            let frond = SKColor(red: 0.20, green: 0.46, blue: 0.20, alpha: 1)
            let frondHi = SKColor(red: 0.34, green: 0.64, blue: 0.28, alpha: 1)
            let frondAngles: [Double] = [-1.0, -0.55, 0.0, 0.55, 1.0]
            let frondLens: [CGFloat] = [34, 26, 22, 26, 34]
            for i in 0..<frondAngles.count {
                let a = frondAngles[i]
                let len = frondLens[i]
                let fr = SKSpriteNode(color: i == 2 ? frondHi : frond,
                                      size: CGSize(width: len, height: 7))
                fr.anchorPoint = CGPoint(x: a < 0 ? 1 : 0, y: 0.5)
                fr.position = top
                fr.zRotation = CGFloat(a) * 0.11
                trunk.addChild(fr)
            }
            let crown = SKSpriteNode(color: frondHi, size: CGSize(width: 14, height: 11))
            crown.position = top
            trunk.addChild(crown)
            // Date clusters under the crown.
            for c in 0..<2 {
                let dates = SKSpriteNode(color: SKColor(red: 0.85, green: 0.45, blue: 0.16, alpha: 1),
                                         size: CGSize(width: 10, height: 8))
                dates.position = CGPoint(x: c == 0 ? 8 : -8, y: th - 12)
                trunk.addChild(dates)
            }
            trunk.run(.repeatForever(.sequence([
                .rotate(toAngle: lean + 0.05, duration: 2.6),
                .rotate(toAngle: lean - 0.05, duration: 2.6),
            ])))
            placed += 1
        }

        // Caravan crates + barrels beside the palms.
        placed = 0; guard_ = 0
        while placed < 16, guard_ < 300 {
            guard_ += 1
            let x = rng.cgFloat(in: 60...(width - 60))
            guard isClear(x, margin: 180) else { continue }
            let gy = Balance.groundY(at: x)
            let pile = SKNode()
            pile.position = CGPoint(x: x, y: gy)
            pile.zPosition = 3
            world.addChild(pile)
            let kind = rng.int(in: 0...1)
            if kind == 0 {
                let cw: CGFloat = rng.cgFloat(in: 22...30)
                let crate = SKSpriteNode(color: SKColor(red: 0.50, green: 0.34, blue: 0.18, alpha: 1),
                                         size: CGSize(width: cw, height: cw * 0.8))
                crate.anchorPoint = CGPoint(x: 0.5, y: 0)
                pile.addChild(crate)
                let lid = SKSpriteNode(color: SKColor(red: 0.62, green: 0.44, blue: 0.24, alpha: 1),
                                       size: CGSize(width: cw, height: 4))
                lid.anchorPoint = CGPoint(x: 0.5, y: 0)
                lid.position = CGPoint(x: 0, y: cw * 0.8 - 2)
                pile.addChild(lid)
                let strap = SKSpriteNode(color: SKColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 1),
                                         size: CGSize(width: 4, height: cw * 0.8))
                strap.position = CGPoint(x: 0, y: cw * 0.4)
                pile.addChild(strap)
            } else {
                let bw: CGFloat = rng.cgFloat(in: 16...22)
                let barrel = SKSpriteNode(color: SKColor(red: 0.55, green: 0.38, blue: 0.20, alpha: 1),
                                          size: CGSize(width: bw, height: bw * 1.3))
                barrel.anchorPoint = CGPoint(x: 0.5, y: 0)
                pile.addChild(barrel)
                let hoop = SKSpriteNode(color: SKColor(red: 0.30, green: 0.20, blue: 0.11, alpha: 1),
                                        size: CGSize(width: bw + 2, height: 3))
                hoop.anchorPoint = CGPoint(x: 0.5, y: 0)
                hoop.position = CGPoint(x: 0, y: bw * 0.7)
                pile.addChild(hoop)
                let hoop2 = SKSpriteNode(color: SKColor(red: 0.30, green: 0.20, blue: 0.11, alpha: 1),
                                         size: CGSize(width: bw + 2, height: 3))
                hoop2.anchorPoint = CGPoint(x: 0.5, y: 0)
                hoop2.position = CGPoint(x: 0, y: bw * 0.2)
                pile.addChild(hoop2)
            }
            placed += 1
        }

        // Shade tents: two poles + a striped canopy.
        placed = 0; guard_ = 0
        while placed < 6, guard_ < 300 {
            guard_ += 1
            let x = rng.cgFloat(in: 120...(width - 120))
            guard isClear(x, margin: 210) else { continue }
            let gy = Balance.groundY(at: x)
            let tent = SKNode()
            tent.position = CGPoint(x: x, y: gy)
            tent.zPosition = 3
            world.addChild(tent)
            let span: CGFloat = rng.cgFloat(in: 70...96)
            let th: CGFloat = 46
            for s in 0..<2 {
                let pole = SKSpriteNode(color: SKColor(red: 0.32, green: 0.22, blue: 0.13, alpha: 1),
                                        size: CGSize(width: 5, height: th))
                pole.anchorPoint = CGPoint(x: 0.5, y: 0)
                pole.position = CGPoint(x: s == 0 ? -span / 2 : span / 2, y: 0)
                tent.addChild(pole)
            }
            for stripe in 0..<5 {
                let cw = span / 5
                let piece = SKSpriteNode(
                    color: stripe % 2 == 0
                        ? SKColor(red: 0.88, green: 0.45, blue: 0.28, alpha: 1)
                        : SKColor(red: 0.94, green: 0.80, blue: 0.52, alpha: 1),
                    size: CGSize(width: cw, height: 14))
                piece.position = CGPoint(x: -span / 2 + cw * (CGFloat(stripe) + 0.5),
                                         y: th - 8)
                tent.addChild(piece)
            }
            placed += 1
        }
    }
}
