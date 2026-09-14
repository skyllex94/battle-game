import SpriteKit

/// Level 1 scene — movement + shooting + tower combat: battlefield + parallax
/// + hero + camera + towers that fire team-tinted bolts at enemies in proximity.
/// Hero runs/jumps via joystick input (GameView writes hero.inputX / jumpHeld);
/// tap/drag the right half of the screen to aim + fire projectiles at the tap.
/// Towers acquire the nearest enemy (opposing tower, or the hero for the enemy
/// tower) within Balance.towerRange and fire toward it on cooldown.
/// Movement is a manual character controller (no physics bodies), so the sim
/// is fully deterministic. Enemies, army, HUD buttons land later.
///
/// World: 4000pt lane, ground strip, 3 mid platforms, 2 towers + 2 bases (dressed,
/// tinted blue/red, no collision yet). Camera follows the hero with lookahead.
final class GameScene: SKScene {

    // MARK: - Nodes
    private let world = SKNode()          // factor 1.0: ground, platforms, structures, hero
    private let skyLayer = SKNode()       // factor 0.0
    private let farLayer = SKNode()       // factor 0.15 (MapBG tiles)
    private let midLayer = SKNode()       // factor 0.35 (procedural hill silhouettes)
    private let foregroundLayer = SKNode()// factor 1.15 (subtle bottom grass, low alpha)
    private let cam = SKCameraNode()
    private var hero: HeroNode!
    private var lastUpdate: TimeInterval = 0

    // MARK: - Shooting (tap/drag right side to aim + fire)
    private var aimTouch: UITouch?
    private var aimDir = CGVector.zero
    private var fireCooldown: TimeInterval = 0
    private var projectiles: [Projectile] = []
    private var aimDots: [SKShapeNode] = []
    private var shotsFired = 0

    // MARK: - Tower combat (proximity-triggered projectiles toward enemies)
    private struct Tower {
        var node: SKSpriteNode
        var team: Team
        var hp: CGFloat
        var maxHP: CGFloat
        var cooldown: TimeInterval
        var hpBarBG: SKSpriteNode
        var hpBarFill: SKSpriteNode
        var alive: Bool { hp > 0 }
    }
    private var towers: [Tower] = []
    private var heroHP: CGFloat = Balance.heroHP

    // MARK: - Setup
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0, y: 0)
        addChild(skyLayer)
        addChild(farLayer)
        addChild(midLayer)
        addChild(world)
        addChild(foregroundLayer)
        camera = cam
        addChild(cam)

        buildSky()
        buildFar()
        buildMid()
        buildGround()
        buildPlatforms()
        buildStructures()
        buildHero()
        buildAimGuide()
        buildForeground()
        snapCamera()
        updateParallax()
    }

    // MARK: - Layer 0: sky gradient (static, factor 0.0)
    private func buildSky() {
        skyLayer.zPosition = -30
        // Vertical gradient via a tall stretched texture drawn once into a sprite.
        let gradient = makeVerticalGradientTexture(
            size: CGSize(width: 4, height: 256),
            top: SKColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1),
            bottom: SKColor(red: 0.35, green: 0.12, blue: 0.16, alpha: 1) // hellish dusk, matches Hell_ground
        )
        let sky = SKSpriteNode(texture: gradient)
        sky.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sky.size = CGSize(width: size.width * 1.2, height: size.height * 1.4)
        sky.zPosition = 0
        skyLayer.addChild(sky)
        skyLayer.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    // MARK: - Layer 1: far MapBG tiles (factor 0.15)
    private func buildFar() {
        farLayer.zPosition = -20
        let texture = ImportedArt.skTexture(named: "MapBG")
        texture.filteringMode = .linear
        // Scale to scene height; tile enough copies to cover the parallax-travelled range.
        let targetH = size.height * 1.05
        let scale = targetH / texture.size().height
        let tileW = texture.size().width * scale
        let needed = Int(ceil((size.width + Balance.levelWidth * Balance.parallaxFar) / tileW)) + 2
        let startX = -size.width // overhang left so the view is covered at min camera
        for i in 0..<needed {
            let tile = SKSpriteNode(texture: texture)
            tile.setScale(scale)
            tile.anchorPoint = CGPoint(x: 0, y: 0.5)
            tile.position = CGPoint(x: startX + CGFloat(i) * tileW, y: 0)
            tile.alpha = 0.38
            farLayer.addChild(tile)
        }
        // Dark veil so the bright map art sits behind the action, not over it.
        let veil = SKSpriteNode(color: SKColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 0.55),
                                size: CGSize(width: CGFloat(needed) * tileW, height: targetH))
        veil.anchorPoint = CGPoint(x: 0, y: 0.5)
        veil.position = CGPoint(x: startX, y: 0)
        veil.zPosition = 1
        farLayer.addChild(veil)
        farLayer.position = CGPoint(x: 0, y: size.height * 0.5)
    }

    // MARK: - Layer 2: mid hill silhouettes (factor 0.35, procedural)
    private func buildMid() {
        midLayer.zPosition = -10
        let hillColor = SKColor(red: 0.10, green: 0.08, blue: 0.14, alpha: 1)
        // Repeating rounded hills across the travelled range.
        let range = size.width + Balance.levelWidth * Balance.parallaxMid
        var x: CGFloat = 0
        var flip = false
        while x < range + 400 {
            let w: CGFloat = flip ? 520 : 380
            let h: CGFloat = flip ? 130 : 190
            let hill = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
            hill.fillColor = hillColor
            hill.strokeColor = .clear
            hill.position = CGPoint(x: x + w / 2, y: -size.height * 0.36)
            midLayer.addChild(hill)
            x += w * 0.75
            flip.toggle()
        }
        // A few dead-tree spikes for the hell-ground mood.
        for i in 0..<12 {
            let spike = SKShapeNode(rectOf: CGSize(width: 14, height: 120 + CGFloat(i % 3) * 40))
            spike.fillColor = hillColor
            spike.strokeColor = .clear
            spike.position = CGPoint(x: CGFloat(i) * (range / 12), y: -size.height * 0.18)
            spike.zRotation = CGFloat(i % 2 == 0 ? 0.08 : -0.08)
            midLayer.addChild(spike)
        }
        midLayer.position = CGPoint(x: 0, y: size.height * 0.5)
    }

    // MARK: - Playfield: ground (factor 1.0)
    private func buildGround() {
        world.zPosition = 0
        let texture = ImportedArt.skTexture(named: "Hell_ground")
        texture.filteringMode = .nearest
        let tileW: CGFloat = 500
        let tileH: CGFloat = 87
        var x: CGFloat = 0
        while x < Balance.levelWidth {
            let tile = SKSpriteNode(texture: texture)
            tile.anchorPoint = CGPoint(x: 0, y: 1) // top edge = walkable surface
            tile.size = CGSize(width: tileW, height: tileH)
            tile.position = CGPoint(x: x, y: Balance.groundTopY)
            tile.zPosition = 1
            world.addChild(tile)
            x += tileW
        }
        // Solid under-fill so gaps below the strip never show sky.
        let fill = SKSpriteNode(color: SKColor(red: 0.13, green: 0.07, blue: 0.08, alpha: 1),
                                size: CGSize(width: Balance.levelWidth, height: Balance.groundTopY))
        fill.anchorPoint = CGPoint(x: 0, y: 1)
        fill.position = CGPoint(x: 0, y: Balance.groundTopY - tileH)
        fill.zPosition = 0
        world.addChild(fill)

        // Team-side ground tint: subtle blue (left half) / red (right half) wash.
        let washL = SKSpriteNode(color: SKColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 0.10),
                                 size: CGSize(width: Balance.levelWidth / 2, height: tileH))
        washL.anchorPoint = CGPoint(x: 0, y: 1)
        washL.position = CGPoint(x: 0, y: Balance.groundTopY)
        washL.zPosition = 2
        world.addChild(washL)
        let washR = SKSpriteNode(color: SKColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 0.10),
                                 size: CGSize(width: Balance.levelWidth / 2, height: tileH))
        washR.anchorPoint = CGPoint(x: 0, y: 1)
        washR.position = CGPoint(x: Balance.levelWidth / 2, y: Balance.groundTopY)
        washR.zPosition = 2
        world.addChild(washR)
    }

    // MARK: - Playfield: floating platforms
    private func buildPlatforms() {
        let texture = ImportedArt.skTexture(named: "Hell_ground")
        for rect in Balance.platforms {
            let platform = SKSpriteNode(texture: texture)
            platform.size = CGSize(width: rect.width, height: rect.height)
            platform.position = CGPoint(x: rect.midX, y: rect.midY)
            platform.color = SKColor(white: 0, alpha: 0.25)
            platform.colorBlendFactor = 0.4
            platform.zPosition = 1
            platform.name = "platform"
            world.addChild(platform)
        }
    }

    // MARK: - Playfield: towers + bases (towers fight; bases are dressing for now)
    private func buildStructures() {
        // Towers fight: blue (player) at left, red (enemy) at right.
        addTower(at: Balance.playerTowerX, team: .player)
        addTower(at: Balance.enemyTowerX, team: .enemy)
        // Bases (Base.png is huge -> ~170pt tall)
        addStructureart(named: "Base", at: Balance.playerBaseX, height: 170,
                        tint: SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1), name: "playerBase")
        addStructureart(named: "Base", at: Balance.enemyBaseX, height: 170,
                        tint: SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 1), name: "enemyBase")
    }

    /// Tower sprite + drop shadow + HP bar. Muzzle is at the tower top
    /// (Balance.towerMuzzleHeight above ground); shots originate there.
    private func addTower(at x: CGFloat, team: Team) {
        let tint: SKColor
        let name: String
        switch team {
        case .player:
            tint = SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1)
            name = "playerTower"
        case .enemy:
            tint = SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 1)
            name = "enemyTower"
        case .neutral:
            tint = SKColor(white: 0.8, alpha: 1)
            name = "tower"
        }
        let node = addStructureart(named: "Tower", at: x, height: 190, tint: tint, name: name)
        // HP bar floats just above the tower.
        let barW: CGFloat = 110
        let barBG = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6),
                                 size: CGSize(width: barW, height: 10))
        barBG.position = CGPoint(x: x, y: Balance.groundTopY + 205)
        barBG.zPosition = 6
        world.addChild(barBG)
        let barFill = SKSpriteNode(color: team == .player ? .cyan : .red,
                                   size: CGSize(width: barW, height: 10))
        barFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        barFill.position = CGPoint(x: x - barW / 2, y: Balance.groundTopY + 205)
        barFill.zPosition = 7
        world.addChild(barFill)
        // Stagger first shots so both towers don't volley on the same frame.
        let stagger = team == .player ? 0.0 : Balance.towerFireCooldown / 2
        towers.append(Tower(node: node, team: team, hp: Balance.towerHP,
                            maxHP: Balance.towerHP, cooldown: stagger,
                            hpBarBG: barBG, hpBarFill: barFill))
    }

    private func addStructureart(named: String, at x: CGFloat, height: CGFloat, tint: SKColor, name: String) -> SKSpriteNode {
        let texture = ImportedArt.skTexture(named: named)
        texture.filteringMode = .linear
        let node = SKSpriteNode(texture: texture)
        node.setScale(height / texture.size().height)
        node.position = CGPoint(x: x, y: Balance.groundTopY + node.size.height / 2)
        node.color = tint
        node.colorBlendFactor = 0.25
        node.zPosition = 5
        node.name = name
        world.addChild(node)
        // Drop shadow ellipse for 2.5D grounding.
        let shadow = SKShapeNode(ellipseOf: CGSize(width: node.size.width * 0.9, height: 18))
        shadow.fillColor = SKColor(white: 0, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: x, y: Balance.groundTopY + 6)
        shadow.zPosition = 4
        world.addChild(shadow)
        return node
    }

    // MARK: - Playfield: hero
    /// Exposed so GameView can stream joystick state into the hero.
    var heroInputX: CGFloat {
        get { hero?.inputX ?? 0 }
        set { hero?.inputX = newValue }
    }
    var heroJumpHeld: Bool {
        get { hero?.jumpHeld ?? false }
        set { hero?.jumpHeld = newValue }
    }

    private func buildHero() {
        hero = HeroNode()
        hero.position = CGPoint(x: Balance.heroSpawnX,
                                y: Balance.groundTopY + Balance.heroHeight / 2 + 4)
        world.addChild(hero)
    }

    // MARK: - Foreground layer (factor 1.15, subtle)
    private func buildForeground() {
        foregroundLayer.zPosition = 20
        // Dark grass tufts along the bottom, drifting slightly faster than the world.
        let bladeCount = 90
        for i in 0..<bladeCount {
            let x = CGFloat(i) * (Balance.levelWidth * Balance.parallaxForeground / CGFloat(bladeCount))
            let blade = SKShapeNode(rectOf: CGSize(width: 6, height: 30 + CGFloat(i % 4) * 8))
            blade.fillColor = SKColor(red: 0.05, green: 0.10, blue: 0.06, alpha: 0.4)
            blade.strokeColor = .clear
            blade.position = CGPoint(x: x, y: 18)
            blade.zRotation = CGFloat((i % 5) - 2) * 0.06
            foregroundLayer.addChild(blade)
        }
        foregroundLayer.position = CGPoint(x: 0, y: 0)
    }

    // MARK: - Camera + parallax update
    private var halfViewWidth: CGFloat { size.width * cam.xScale / 2 }
    private var halfViewHeight: CGFloat { size.height * cam.xScale / 2 }

    private func cameraTarget() -> CGPoint {
        let lookahead = hero.velocity.dx * 0.22
        let desiredX = hero.position.x + lookahead
        let x = min(max(desiredX, halfViewWidth), Balance.levelWidth - halfViewWidth)
        // Follow the hero vertically a little so jumps stay framed, but never
        // show below the ground or above the sky.
        // Zoomed views are short: park the ground line near the bottom quarter.
        let baseY: CGFloat = Balance.groundTopY + halfViewHeight * 0.28
        let lift = max(0, hero.position.y - (Balance.groundTopY + Balance.heroHeight)) * 0.35
        let y = min(baseY + lift, size.height - halfViewHeight)
        return CGPoint(x: x, y: max(y, halfViewHeight * 0.6))
    }

    private func snapCamera() {
        cam.setScale(Balance.cameraZoom)
        cam.position = cameraTarget()
    }

    private func smoothCamera(dt: TimeInterval) {
        let target = cameraTarget()
        let rate = min(1, 6 * dt) // ~6/s smoothing: tight but not rigid
        cam.position = CGPoint(x: cam.position.x + (target.x - cam.position.x) * rate,
                               y: cam.position.y + (target.y - cam.position.y) * rate)
    }

    private func updateParallax() {
        let camX = cam.position.x
        // Layer offset = camX * (1 - factor): factor 1.0 -> 0 (locked to world),
        // factor 0.0 -> full camX (static on screen).
        skyLayer.position.x = size.width / 2 // recentred on camera each frame
        // skyLayer is screen-locked: counter-move by full camX relative to scene origin.
        // Since layers live in scene space, screen-locked means position.x = camX.
        skyLayer.position = CGPoint(x: camX, y: size.height / 2)
        farLayer.position.x = camX * (1 - Balance.parallaxFar)
        midLayer.position.x = camX * (1 - Balance.parallaxMid)
        foregroundLayer.position.x = -camX * (Balance.parallaxForeground - 1)
    }

    override func update(_ currentTime: TimeInterval) {
        frameCount += 1
        let dt = lastUpdate > 0 ? currentTime - lastUpdate : 1.0 / 60
        lastUpdate = currentTime
        hero.step(dt: dt, now: currentTime)
        updateShooting(dt: dt)
        updateTowers(dt: dt)
        stepProjectiles(dt: dt)
        smoothCamera(dt: dt)
        updateParallax()
    }

    // MARK: - Shooting: aim touch, fire cadence, projectile sim
    /// Right-half touches aim + fire. Left half belongs to the SwiftUI joystick
    /// (filtered here too in case a touch leaks through the overlay).
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches where aimTouch == nil {
            let loc = touch.location(in: view)
            guard loc.x > view.bounds.width / 2 else { continue }
            aimTouch = touch
            fireCooldown = 0 // first tap fires instantly
            trackAim(touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let aimTouch else { return }
        if touches.contains(aimTouch) { trackAim(aimTouch) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseAim(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseAim(touches)
    }

    private func releaseAim(_ touches: Set<UITouch>) {
        guard let aimTouch, touches.contains(aimTouch) else { return }
        self.aimTouch = nil
        hero.clearAim()
        aimDots.forEach { $0.isHidden = true }
    }

    private func trackAim(_ touch: UITouch) {
        guard let view else { return }
        let target = convertPoint(fromView: touch.location(in: view))
        let muzzle = muzzlePosition(for: provisionalDir(to: target))
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        aimDir = dir
        hero.aimToward(dir)
        updateAimDots(muzzle: muzzle, dir: dir)
    }

    /// Aim direction guess before the muzzle is known (muzzle barely offsets it).
    private func provisionalDir(to target: CGPoint) -> CGVector {
        var d = CGVector(dx: target.x - hero.position.x, dy: target.y - hero.position.y)
        let len = max(1, hypot(d.dx, d.dy))
        d = CGVector(dx: d.dx / len, dy: d.dy / len)
        return d
    }

    private func muzzlePosition(for dir: CGVector) -> CGPoint {
        CGPoint(x: hero.position.x + dir.dx * 36, y: hero.position.y + 8 + dir.dy * 36)
    }

    private func buildAimGuide() {
        for i in 0..<3 {
            let dot = SKShapeNode(circleOfRadius: 5 - CGFloat(i))
            dot.fillColor = SKColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.8 - CGFloat(i) * 0.2)
            dot.strokeColor = .clear
            dot.zPosition = 14
            dot.isHidden = true
            world.addChild(dot)
            aimDots.append(dot)
        }
    }

    private func updateAimDots(muzzle: CGPoint, dir: CGVector) {
        for (i, dot) in aimDots.enumerated() {
            let dist: CGFloat = 55 + CGFloat(i) * 42
            dot.position = CGPoint(x: muzzle.x + dir.dx * dist, y: muzzle.y + dir.dy * dist)
            dot.isHidden = false
        }
    }

    private func updateShooting(dt: TimeInterval) {
        guard aimTouch != nil else { return }
        fireCooldown -= dt
        guard fireCooldown <= 0 else { return }
        fireCooldown = Balance.fireCooldown
        fireBullet()
    }

    private func fireBullet() {
        let muzzle = muzzlePosition(for: aimDir)
        let bolt = ProjectileFactory.makeBolt()
        bolt.position = muzzle
        bolt.zRotation = atan2(aimDir.dy, aimDir.dx)
        world.addChild(bolt)
        projectiles.append(Projectile(node: bolt, dir: aimDir, life: Balance.bulletLife,
                                      speed: Balance.bulletSpeed, damage: Balance.heroDamage,
                                      team: .neutral))
        shotsFired += 1
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.position = muzzle
        world.addChild(flash)
    }

    // MARK: - Tower combat: proximity targeting + firing toward enemies
    /// Each alive tower fires a team-tinted bolt at its nearest enemy within
    /// Balance.towerRange. Enemy tower targets the hero + player tower;
    /// player tower targets the enemy tower (friendly fire off vs own hero).
    /// Towers aim muzzle -> target center so shots arc flat toward each other.
    private func updateTowers(dt: TimeInterval) {
        for i in towers.indices {
            guard towers[i].alive else { continue }
            towers[i].cooldown -= dt
            guard towers[i].cooldown <= 0 else { continue }
            guard let target = acquireTarget(for: towers[i]) else { continue }
            towers[i].cooldown = Balance.towerFireCooldown
            fireTowerBolt(from: towers[i], to: target)
        }
    }

    /// Nearest enemy point within range, or nil when nothing is in proximity.
    private func acquireTarget(for tower: Tower) -> CGPoint? {
        var best: CGPoint?
        var bestDist = Balance.towerRange
        // Opposing tower: both towers fire toward each other once in range.
        for other in towers where other.team != tower.team && other.alive {
            let d = abs(other.node.position.x - tower.node.position.x)
            if d <= bestDist {
                bestDist = d
                best = CGPoint(x: other.node.position.x,
                               y: Balance.groundTopY + 100)
            }
        }
        // Enemy tower hunts the hero too — player tower holds fire vs own hero.
        if tower.team == .enemy && heroHP > 0 {
            let d = hypot(hero.position.x - tower.node.position.x,
                          hero.position.y - (Balance.groundTopY + Balance.towerMuzzleHeight))
            if d <= Balance.towerRange, d < bestDist {
                bestDist = d
                best = hero.position
            }
        }
        return best
    }

    private func towerMuzzle(for tower: Tower) -> CGPoint {
        CGPoint(x: tower.node.position.x, y: Balance.groundTopY + Balance.towerMuzzleHeight)
    }

    private func fireTowerBolt(from tower: Tower, to target: CGPoint) {
        let muzzle = towerMuzzle(for: tower)
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        let bolt = ProjectileFactory.makeTowerBolt(team: tower.team)
        bolt.position = muzzle
        bolt.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(bolt)
        projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.towerBulletLife,
                                      speed: Balance.towerBulletSpeed, damage: Balance.towerDamage,
                                      team: tower.team))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.position = muzzle
        world.addChild(flash)
    }

    private func damageTower(at index: Int, amount: CGFloat) {
        guard towers[index].alive else { return }
        towers[index].hp = max(0, towers[index].hp - amount)
        updateTowerHPBar(at: index)
        if !towers[index].alive {
            // Rubble look: grey out + sink the HP bar. Revive/respawn lands later.
            towers[index].node.color = SKColor(white: 0.3, alpha: 1)
            towers[index].node.colorBlendFactor = 0.7
            towers[index].node.alpha = 0.75
            towers[index].hpBarFill.isHidden = true
            towers[index].hpBarBG.alpha = 0.25
        }
    }

    private func updateTowerHPBar(at index: Int) {
        let frac = max(0, towers[index].hp / towers[index].maxHP)
        let fullW: CGFloat = 110
        towers[index].hpBarFill.size.width = fullW * frac
    }

    private func damageHero(amount: CGFloat) {
        guard heroHP > 0 else { return }
        heroHP = max(0, heroHP - amount)
        // Hit flash so damage reads instantly.
        hero.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.06),
                            .fadeAlpha(to: 1.0, duration: 0.12)]))
    }

    private func stepProjectiles(dt: TimeInterval) {
        var alive: [Projectile] = []
        alive.reserveCapacity(projectiles.count)
        for var p in projectiles {
            let step = p.speed * CGFloat(dt)
            p.node.position.x += p.dir.dx * step
            p.node.position.y += p.dir.dy * step
            p.life -= dt
            if p.life <= 0 {
                p.node.removeFromParent() // expired mid-air: just fade, no puff
                continue
            }
            if hitsGroundOrPlatform(p.node.position) {
                impact(at: p.node.position)
                p.node.removeFromParent()
                continue
            }
            if hitEnemy(p) {
                impact(at: p.node.position)
                p.node.removeFromParent()
                continue
            }
            alive.append(p)
        }
        projectiles = alive
    }

    /// Team-aware hit test. Hero (neutral) bolts hit the enemy tower;
    /// player bolts hit the enemy tower; enemy bolts hit the player tower + hero.
    /// Returns true when the projectile struck something (caller removes it).
    private func hitEnemy(_ p: Projectile) -> Bool {
        let pt = p.node.position
        switch p.team {
        case .neutral:
            if let idx = towerIndex(at: pt, team: .enemy) {
                damageTower(at: idx, amount: p.damage)
                return true
            }
        case .player:
            if let idx = towerIndex(at: pt, team: .enemy) {
                damageTower(at: idx, amount: p.damage)
                return true
            }
        case .enemy:
            if let idx = towerIndex(at: pt, team: .player) {
                damageTower(at: idx, amount: p.damage)
                return true
            }
            // Hero body: ~44 wide, Balance.heroHeight tall, centered on position.
            if heroHP > 0,
               abs(pt.x - hero.position.x) < 34,
               abs(pt.y - hero.position.y) < Balance.heroHeight / 2 + 6 {
                damageHero(amount: p.damage)
                return true
            }
        }
        return false
    }

    /// Point-in-tower test for one team's alive towers.
    /// Towers are ~60pt half-width, 190pt tall sitting on groundTopY.
    private func towerIndex(at pt: CGPoint, team: Team) -> Int? {
        for (i, t) in towers.enumerated() where t.team == team && t.alive {
            let dx = abs(pt.x - t.node.position.x)
            let inX = dx < 62
            let inY = pt.y >= Balance.groundTopY && pt.y <= Balance.groundTopY + 195
            if inX && inY { return i }
        }
        return nil
    }

    private func hitsGroundOrPlatform(_ pt: CGPoint) -> Bool {
        if pt.y <= Balance.groundTopY + 3 { return true }
        if pt.x < 0 || pt.x > Balance.levelWidth { return true }
        for rect in Balance.platforms where rect.insetBy(dx: -4, dy: -4).contains(pt) {
            return true
        }
        return false
    }

    private func impact(at pt: CGPoint) {
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = pt
        world.addChild(puff)
    }

    // MARK: - Debug (temporary HUD readout)
    private var frameCount = 0
    var debugLine: String {
        let v = hero?.velocity ?? .zero
        let g = hero?.isGrounded ?? false
        let p = hero?.position ?? .zero
        let ptHP = towers.first(where: { $0.team == .player })?.hp ?? 0
        let etHP = towers.first(where: { $0.team == .enemy })?.hp ?? 0
        return String(format: "f%d pos %4.0f,%4.0f in %+.2f jmp %@ | v %+4.0f,%+5.0f gnd %@ shots %d hero %3.0f tw P %3.0f/E %3.0f",
                      frameCount, p.x, p.y, heroInputX, heroJumpHeld ? "Y" : "n",
                      v.dx, v.dy, g ? "Y" : "n", shotsFired, heroHP, ptHP, etHP)
    }

    // MARK: - Minimap snapshot (polled by the SwiftUI MinimapView ~7Hz)
    var minimap: MinimapSnapshot {
        MinimapSnapshot(
            levelWidth: Balance.levelWidth,
            heroX: hero?.position.x ?? 0,
            cameraX: cam.position.x,
            viewWidth: size.width * cam.xScale,
            playerBaseX: Balance.playerBaseX,
            playerTowerX: Balance.playerTowerX,
            enemyTowerX: Balance.enemyTowerX,
            enemyBaseX: Balance.enemyBaseX
        )
    }

    // MARK: - Helpers
    private func makeVerticalGradientTexture(size: CGSize, top: SKColor, bottom: SKColor) -> SKTexture {
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: 1, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 4, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let topC = top.cgColor.converted(to: colorSpace, intent: .defaultIntent, options: nil),
              let botC = bottom.cgColor.converted(to: colorSpace, intent: .defaultIntent, options: nil),
              let topComps = topC.components, let botComps = botC.components else {
            return ImportedArt.skTexture(named: "MapBG")
        }
        for y in 0..<height {
            let t = CGFloat(y) / CGFloat(height - 1) // 0 bottom -> 1 top
            let r = botComps[0] + (topComps[0] - botComps[0]) * t
            let g = botComps[1] + (topComps[1] - botComps[1]) * t
            let b = botComps[2] + (topComps[2] - botComps[2]) * t
            ctx.setFillColor(red: r, green: g, blue: b, alpha: 1)
            ctx.fill(CGRect(x: 0, y: y, width: 1, height: 1))
        }
        guard let img = ctx.makeImage() else { return ImportedArt.skTexture(named: "MapBG") }
        return SKTexture(cgImage: img)
    }
}
