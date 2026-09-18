import SpriteKit

/// Main-menu battlefield: a living pixel-art diorama behind the menu UI.
///
/// Same Twilight Ruins art language as the game (dusk sky, mountain + ruin
/// panorama, treeline, moss lane) but staged as a menu backdrop:
/// - Blue tower (left) vs red tower (right) with idle-scanning turrets.
/// - Looping skirmish: blue troopers march in from the left, red raiders
///   from the right, they halt mid-field and trade tracer fire with muzzle
///   flashes + impact puffs, then fall back and loop.
/// - True multi-depth parallax: the camera slowly pans and each layer
///   drifts at its own factor (sky 0, far 0.15, mid 0.35, world 1.0,
///   foreground 1.28), so mountains / trees / grass separate in depth.
/// - Ambient life: twinkling stars, drifting clouds + mist, fireflies,
///   swaying foreground grass, pulsing tower beacons — all SKActions.
final class MainMenuBattleScene: SKScene {

    // MARK: - Layers (parallax factors mirror Balance)

    private let skyLayer = SKNode()
    private let farLayer = SKNode()
    private let midLayer = SKNode()
    private let world = SKNode()
    private let foregroundLayer = SKNode()

    private var towers: [TowerNode] = []
    private var lastUpdate: TimeInterval = 0
    private var panTime: TimeInterval = 0
    /// SpriteView can present the same scene instance again when the user
    /// navigates back and forth (SwiftUI reuses the @State scene). Re-adding
    /// the layer nodes would crash ("already has a parent"), so build once.
    private var didBuild = false

    /// Slow cinematic pan amplitude (points). Small so the towers never
    /// leave the frame; layers scale it by their parallax factor.
    private let panAmplitude: CGFloat = 130

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func didMove(to view: SKView) {
        guard !didBuild else { return }
        didBuild = true
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(skyLayer)
        addChild(farLayer)
        addChild(midLayer)
        addChild(world)
        addChild(foregroundLayer)

        skyLayer.zPosition = -30
        farLayer.zPosition = -20
        midLayer.zPosition = -10
        world.zPosition = 0
        foregroundLayer.zPosition = 20

        // Sky is screen-locked (factor 0): center it on the scene.
        TwilightRuinsBG.buildSky(in: skyLayer, sceneSize: size)
        skyLayer.position = .zero

        // Far + mid panoramas paint their own wide strips internally
        // (Balance.levelWidth-based); pin them at mid-height like GameScene.
        TwilightRuinsBG.buildFar(in: farLayer, sceneSize: size)
        farLayer.position = CGPoint(x: 0, y: size.height * 0.06)
        TwilightRuinsBG.buildMid(in: midLayer, sceneSize: size)
        midLayer.position = CGPoint(x: 0, y: size.height * 0.06)

        buildMenuGround()
        buildMenuTowers()
        buildSkirmish()
        // Foreground sits at the bottom edge, screen-locked in y.
        TwilightRuinsBG.buildForeground(in: foregroundLayer)
        foregroundLayer.position = CGPoint(x: -size.width * 0.7, y: -size.height * 0.5)
    }

    // MARK: - Ground strip (menu-width lane reusing the twilight tiles)

    private func buildMenuGround() {
        let laneW = size.width * 2.2
        let tileW: CGFloat = 500
        let tileH: CGFloat = 104 // 125x26 @4x
        let groundY = -size.height * 0.22
        var x: CGFloat = -laneW / 2
        var i = 0
        while x < laneW / 2 {
            let tile = SKSpriteNode(texture: TwilightRuinsBG.tileTexture(variant: i))
            tile.anchorPoint = CGPoint(x: 0, y: 1)
            tile.size = CGSize(width: tileW, height: tileH)
            if i % 6 == 5 {
                tile.xScale = -1
                tile.position = CGPoint(x: x + tileW, y: groundY)
            } else {
                tile.position = CGPoint(x: x, y: groundY)
            }
            tile.zPosition = 1
            world.addChild(tile)
            x += tileW
            i += 1
        }
        // Moonlit walkable lip + soft AO so units sit grounded.
        let lip = SKSpriteNode(color: SKColor(red: 0.80, green: 0.78, blue: 0.94, alpha: 0.55),
                               size: CGSize(width: laneW, height: 3))
        lip.anchorPoint = CGPoint(x: 0.5, y: 1)
        lip.position = CGPoint(x: 0, y: groundY + 1)
        lip.zPosition = 2
        world.addChild(lip)
        // Team washes: faint blue (left) / red (right) like the real lane.
        let washL = SKSpriteNode(color: SKColor(red: 0.3, green: 0.5, blue: 1, alpha: 0.08),
                                 size: CGSize(width: laneW / 2, height: tileH))
        washL.anchorPoint = CGPoint(x: 1, y: 1)
        washL.position = CGPoint(x: 0, y: groundY)
        washL.zPosition = 2
        world.addChild(washL)
        let washR = SKSpriteNode(color: SKColor(red: 1, green: 0.3, blue: 0.25, alpha: 0.08),
                                 size: CGSize(width: laneW / 2, height: tileH))
        washR.anchorPoint = CGPoint(x: 0, y: 1)
        washR.position = CGPoint(x: 0, y: groundY)
        washR.zPosition = 2
        world.addChild(washR)
        // Dark falloff below the lane.
        let shade = SKSpriteNode(color: SKColor(white: 0, alpha: 0.5),
                                 size: CGSize(width: laneW, height: 260))
        shade.anchorPoint = CGPoint(x: 0.5, y: 1)
        shade.position = CGPoint(x: 0, y: groundY - tileH)
        shade.zPosition = 1
        world.addChild(shade)
    }

    // MARK: - Towers (the battlefield anchors)

    private func buildMenuTowers() {
        let groundY = -size.height * 0.22
        let leftX = -size.width * 0.36
        let rightX = size.width * 0.36
        let blue = TowerNode(team: .player)
        blue.position = CGPoint(x: leftX, y: groundY)
        world.addChild(blue)
        towers.append(blue)
        let red = TowerNode(team: .enemy)
        red.position = CGPoint(x: rightX, y: groundY)
        world.addChild(red)
        towers.append(red)
        // Banner poles beside each tower: team pennants fluttering.
        addPennant(at: CGPoint(x: leftX - 110, y: groundY),
                   color: SKColor(red: 0.3, green: 0.6, blue: 1, alpha: 1))
        addPennant(at: CGPoint(x: rightX + 110, y: groundY),
                   color: SKColor(red: 1, green: 0.32, blue: 0.22, alpha: 1))
    }

    private func addPennant(at base: CGPoint, color: SKColor) {
        let pole = SKSpriteNode(color: SKColor(white: 0.25, alpha: 1),
                                size: CGSize(width: 5, height: 150))
        pole.anchorPoint = CGPoint(x: 0.5, y: 0)
        pole.position = base
        pole.zPosition = 4
        world.addChild(pole)
        let cloth = SKSpriteNode(color: color, size: CGSize(width: 44, height: 22))
        cloth.anchorPoint = CGPoint(x: 0, y: 0.5)
        cloth.position = CGPoint(x: base.x + 3, y: base.y + 138)
        cloth.zPosition = 4
        world.addChild(cloth)
        // Notched swallowtail: dark triangle bite at the fly end.
        let notch = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55),
                                 size: CGSize(width: 12, height: 10))
        notch.position = CGPoint(x: 38, y: 0)
        cloth.addChild(notch)
        cloth.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.06, duration: 0.9), .rotate(toAngle: -0.06, duration: 0.9),
        ])))
    }

    // MARK: - Looping skirmish (march -> firefight -> fall back -> loop)

    private func buildSkirmish() {
        let groundY = -size.height * 0.22
        // Two fireteams per side, staggered so the fight never fully stops.
        for (index, side) in [(-1, 0), (-1, 1), (1, 0), (1, 1)].enumerated() {
            let dir = CGFloat(side.0) // -1 = blue (faces right), +1 = red
            let kind: UnitPixelArt.Kind = dir < 0 ? (side.1 == 0 ? .trooper : .heavy) : .enemy
            let soldier = makeMarcher(kind: kind, facingRight: dir < 0)
            world.addChild(soldier)
            let startX = dir < 0 ? -size.width * 0.30 : size.width * 0.30
            let fightX = dir < 0 ? -size.width * 0.06 - CGFloat(side.1) * 44
                                 : size.width * 0.06 + CGFloat(side.1) * 44
            soldier.position = CGPoint(x: startX, y: groundY)
            let marchTime = 3.6 + Double(index) * 0.5
            // Tracer volley while holding the line.
            let volley = SKAction.run { [weak self, weak soldier] in
                guard let self, let soldier else { return }
                self.fireTracer(from: soldier, dir: dir < 0 ? 1 : -1)
            }
            let cycle = SKAction.sequence([
                .run { soldier.position.x = startX }, // reset off-screen-ish
                .fadeIn(withDuration: 0.4),
                .moveTo(x: fightX, duration: marchTime), // march in
                .repeat(.sequence([volley, .wait(forDuration: 0.55)]), count: 7), // firefight
                .fadeOut(withDuration: 0.8), // fall back into the dusk
                .wait(forDuration: 1.2 + Double(index) * 0.4),
            ])
            soldier.run(.repeatForever(cycle))
        }
        // Tower duel sparks: each turret periodically winks a tracer
        // across no-man's-land so the big guns feel alive.
        let duel = SKAction.repeatForever(.sequence([
            .wait(forDuration: 2.6),
            .run { [weak self] in self?.fireTowerDuel() },
        ]))
        run(duel)
    }

    private func makeMarcher(kind: UnitPixelArt.Kind, facingRight: Bool) -> SKNode {
        // Same construction as AllyNode/EnemyNode: an unscaled holder +
        // body container, with body + gun-arm sprites scaled once by
        // s = targetHeight / 32. (Parenting the arm to an already-scaled
        // body sprite double-scales it — that was the huge-gun bug.)
        let frames = UnitPixelArt.frames(for: kind)
        let targetHeight: CGFloat = kind == .heavy ? 64 : 52
        let s = targetHeight / 32
        let holder = SKNode()
        let body = SKNode()
        holder.addChild(body)
        let bodySprite = SKSpriteNode(texture: frames[0])
        bodySprite.setScale(s)
        body.addChild(bodySprite)
        // Scuttling march cycle through the 4 stride frames.
        let march = SKAction.repeatForever(.sequence([
            .setTexture(frames[0]), .wait(forDuration: 0.12),
            .setTexture(frames[1]), .wait(forDuration: 0.12),
            .setTexture(frames[2]), .wait(forDuration: 0.12),
            .setTexture(frames[3]), .wait(forDuration: 0.12),
        ]))
        bodySprite.run(march)
        // Small gun-arm on a shoulder pivot, levelled at the enemy.
        let armPivot = SKNode()
        armPivot.position = CGPoint(x: 6, y: 8)
        body.addChild(armPivot)
        let armSprite = SKSpriteNode(texture: UnitPixelArt.armTexture(for: kind))
        armSprite.setScale(s)
        armSprite.anchorPoint = CGPoint(x: CGFloat(UnitPixelArt.armGripX) / CGFloat(UnitPixelArt.armW), y: 0.5)
        armPivot.addChild(armSprite)
        // Muzzle socket at the barrel tip for tracer spawns.
        let tip = SKNode()
        tip.position = CGPoint(x: CGFloat(UnitPixelArt.armTipX - UnitPixelArt.armGripX) * s, y: 0)
        armPivot.addChild(tip)
        holder.userData = NSMutableDictionary()
        holder.userData?["muzzle"] = tip
        // Face by mirroring the whole holder (arm stays attached + aimed).
        if !facingRight { holder.xScale = -1 }
        holder.zPosition = 5
        return holder
    }

    private func muzzleOf(_ holder: SKNode) -> CGPoint {
        guard let tip = holder.userData?["muzzle"] as? SKNode else { return holder.position }
        return tip.convert(CGPoint.zero, to: world)
    }

    private func fireTracer(from holder: SKNode, dir: CGFloat) {
        let origin = muzzleOf(holder)
        muzzleFlash(at: origin, cyan: dir > 0)
        let length: CGFloat = 26
        let bolt = SKSpriteNode(
            color: dir > 0 ? SKColor(red: 0.4, green: 0.9, blue: 1, alpha: 1)
                           : SKColor(red: 1, green: 0.35, blue: 0.2, alpha: 1),
            size: CGSize(width: length, height: 4))
        bolt.position = origin
        bolt.zPosition = 6
        world.addChild(bolt)
        // Glow halo so tracers pop against the dusk.
        let halo = SKSpriteNode(color: bolt.color.withAlphaComponent(0.3),
                                size: CGSize(width: length + 10, height: 10))
        halo.position = .zero
        bolt.addChild(halo)
        let travel: CGFloat = 260 + CGFloat.random(in: 0...120)
        bolt.run(.sequence([
            .moveBy(x: dir * travel, y: CGFloat.random(in: -8...8), duration: 0.28),
            .run { [weak self, weak bolt] in
                guard let self, let bolt else { return }
                self.impactPuff(at: bolt.position, cyan: dir > 0)
                bolt.removeFromParent()
            },
        ]))
    }

    private func fireTowerDuel() {
        guard towers.count == 2 else { return }
        let from = towers[0].muzzlePosition()
        muzzleFlash(at: from, cyan: true, big: true)
        towers[0].recoil()
        let bolt = SKSpriteNode(color: SKColor(red: 0.5, green: 0.95, blue: 1, alpha: 1),
                                size: CGSize(width: 40, height: 6))
        bolt.position = from
        bolt.zPosition = 6
        world.addChild(bolt)
        let target = CGPoint(x: towers[1].position.x, y: towers[1].position.y + 120)
        let flight = SKAction.move(to: target, duration: 0.45)
        bolt.run(.sequence([flight, .run { [weak self, weak bolt] in
            guard let self, let bolt else { return }
            self.impactPuff(at: bolt.position, cyan: false)
            bolt.removeFromParent()
        }]))
    }

    private func muzzleFlash(at p: CGPoint, cyan: Bool, big: Bool = false) {
        let s: CGFloat = big ? 22 : 13
        let flash = SKSpriteNode(
            color: cyan ? SKColor(red: 0.7, green: 1, blue: 1, alpha: 1)
                        : SKColor(red: 1, green: 0.7, blue: 0.3, alpha: 1),
            size: CGSize(width: s, height: s))
        flash.position = p
        flash.zPosition = 7
        world.addChild(flash)
        flash.run(.sequence([.scale(to: 1.6, duration: 0.07),
                             .fadeOut(withDuration: 0.09),
                             .removeFromParent()]))
    }

    private func impactPuff(at p: CGPoint, cyan: Bool) {
        for i in 0..<5 {
            let spark = SKSpriteNode(
                color: cyan ? SKColor(red: 0.5, green: 0.9, blue: 1, alpha: 1)
                            : SKColor(red: 1, green: 0.5, blue: 0.2, alpha: 1),
                size: CGSize(width: 4, height: 4))
            spark.position = p
            spark.zPosition = 7
            world.addChild(spark)
            let ang = CGFloat(i) * 1.25 + CGFloat.random(in: -0.3...0.3)
            spark.run(.sequence([
                .group([.moveBy(x: cos(ang) * 26, y: sin(ang) * 26 + 12, duration: 0.3),
                        .fadeOut(withDuration: 0.3)]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: - Parallax drift + turret idle

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval = lastUpdate == 0 ? 1 / 60 : min(1 / 20, currentTime - lastUpdate)
        lastUpdate = currentTime
        panTime += dt
        for t in towers { t.update(dt: dt) }
        // Slow cinematic sway; each layer moves by its parallax factor so
        // near grass slides past far mountains (depth without a camera).
        let pan = sin(panTime * 0.12) * panAmplitude
        world.position.x = -pan
        midLayer.position.x = -pan * 0.35
        farLayer.position.x = -pan * 0.15
        foregroundLayer.position.x = -size.width * 0.7 - pan * 1.28
    }
}
