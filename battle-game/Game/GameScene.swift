import SpriteKit

/// Level 1 scene — movement + shooting + tower/base combat + summoned enemies:
/// battlefield + parallax + hero + camera + towers that fire team-tinted bolts,
/// an enemy main base that fans 3 bolts + summons alien marchers toward your base.
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
    /// Active hero gun. The HUD weapon button cycles it via cycleWeapon().
    var heroWeapon: HeroWeapon = .blaster
    // MARK: - Gun ammo (mag + reserve per gun, indexed by HeroWeapon.rawValue)
    private var mags: [Int] = HeroWeapon.allCases.map { $0.magSize }
    private var reserves: [Int] = HeroWeapon.allCases.map { $0.startReserve }
    /// Gun currently reloading (background reloads keep running), if any.
    private var reloadingWeapon: HeroWeapon?
    private var reloadEndsAt: TimeInterval = -1
    /// Desperation trickle for fully-starved guns (mag 0 + reserve 0).
    private var regenAccumulator: TimeInterval = 0

    /// Switches to the next hero gun (blaster -> scatter -> cannon -> ...).
    /// Called by the HUD weapon button; the swapped gun fires instantly.
    /// A swapped-in gun with an empty mag starts reloading on the spot.
    @discardableResult
    func cycleWeapon() -> HeroWeapon {
        let all = HeroWeapon.allCases
        heroWeapon = all[(heroWeapon.rawValue + 1) % all.count]
        hero?.setWeapon(heroWeapon)
        fireCooldown = 0
        if mags[heroWeapon.rawValue] == 0 { startReload(gun: heroWeapon) }
        SoundEngine.shared.weaponSwitch()
        return heroWeapon
    }

    /// Begins a reload for one gun. One reload at a time; no-op when the mag
    /// is already full, the reserve is dry, or another gun is reloading.
    @discardableResult
    private func startReload(gun: HeroWeapon) -> Bool {
        guard reloadingWeapon == nil,
              mags[gun.rawValue] < gun.magSize,
              reserves[gun.rawValue] > 0 else { return false }
        reloadingWeapon = gun
        reloadEndsAt = sceneTime + gun.reloadTime
        SoundEngine.shared.reloadStart()
        return true
    }

    // MARK: - Tower combat (proximity-triggered projectiles toward enemies)
    private struct Tower {
        var node: TowerNode
        var team: Team
        var hp: CGFloat
        var maxHP: CGFloat
        var cooldown: TimeInterval
        var alive: Bool { hp > 0 }
    }
    private var towers: [Tower] = []
    private var heroHP: CGFloat = Balance.heroHP
    /// Spendable gold for the army (unit shop lands next). Starts at your Unity value.
    private var money: Int = Balance.startingGold

    // MARK: - Main bases (enemy base fans bolts + summons marchers)
    private struct Base {
        var node: BaseNode
        var team: Team
        var hp: CGFloat
        var maxHP: CGFloat
        var cooldown: TimeInterval
        var summonTimer: TimeInterval
        var alive: Bool { hp > 0 }
    }
    private var bases: [Base] = []

    // MARK: - Summoned enemies
    private var enemies: [EnemyNode] = []
    // MARK: - Player army (summoned from cards, marches toward the enemy base)
    private var allies: [AllyNode] = []
    // MARK: - Hero death/respawn
    private var sceneTime: TimeInterval = 0
    private var respawnAt: TimeInterval = -1 // <0 = no pending respawn
    private var graceUntil: TimeInterval = -1

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

    // MARK: - Restart (in-place full reset)
    /// Rebuilds the level from scratch inside the same scene instance.
    /// (Swapping the SKScene object doesn't reliably update SpriteView, so
    /// restart tears down and rebuilds all content instead.)
    /// Unpausing invalidates the frame clock so the first post-resume frame
    /// runs a normal 1/60 step instead of a seconds-long catch-up (which is
    /// what snapped the camera to the hero).
    override var isPaused: Bool {
        didSet {
            if !isPaused { lastUpdate = 0 }
        }
    }
    func resetLevel() {
        isPaused = false
        world.removeAllChildren()
        skyLayer.removeAllChildren()
        farLayer.removeAllChildren()
        midLayer.removeAllChildren()
        foregroundLayer.removeAllChildren()
        projectiles = []
        aimDots = []
        towers = []
        bases = []
        enemies = []
        allies = []
        drops = []
        heroHP = Balance.heroHP
        money = Balance.startingGold
        sceneTime = 0
        lastUpdate = 0
        respawnAt = -1
        graceUntil = -1
        aimTouch = nil
        aimDir = .zero
        fireCooldown = 0
        shotsFired = 0
        frameCount = 0
        heroWeapon = .blaster
        mags = HeroWeapon.allCases.map { $0.magSize }
        reserves = HeroWeapon.allCases.map { $0.startReserve }
        reloadingWeapon = nil
        reloadEndsAt = -1
        regenAccumulator = 0
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

    // MARK: - Layer 0: twilight ruins sky (static, factor 0.0)
    private func buildSky() {
        skyLayer.zPosition = -30
        TwilightRuinsBG.buildSky(in: skyLayer, sceneSize: size)
        skyLayer.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    // MARK: - Layer 1: far mountain + ruin panorama (factor 0.15, NOT tiled)
    private func buildFar() {
        farLayer.zPosition = -20
        TwilightRuinsBG.buildFar(in: farLayer, sceneSize: size)
        farLayer.position = CGPoint(x: 0, y: size.height * 0.5)
    }

    // MARK: - Layer 2: mid treeline panorama (factor 0.35, NOT tiled)
    private func buildMid() {
        midLayer.zPosition = -10
        TwilightRuinsBG.buildMid(in: midLayer, sceneSize: size)
        midLayer.position = CGPoint(x: 0, y: size.height * 0.5)
    }

    // MARK: - Playfield: ground (factor 1.0)
    /// Twilight moss lane (see TwilightRuinsBG): 4 variants (= 8 unique
    /// faces with mirroring) over a brick cliff, moonlit lip, faint team
    /// washes, vines + shroom glows + pollen.
    private func buildGround() {
        world.zPosition = 0
        TwilightRuinsBG.buildGround(in: world)
    }

    // MARK: - Playfield: floating platforms
    /// Twilight moss-capped brick blocks (see TwilightRuinsBG): the 80x12
    /// chunk maps to 320x36 at exact integer scale so pixels stay crisp.
    private func buildPlatforms() {
        let texture = TwilightRuinsBG.platformTexture()
        for rect in Balance.platforms {
            let platform = SKSpriteNode(texture: texture)
            platform.size = CGSize(width: rect.width, height: rect.height)
            platform.position = CGPoint(x: rect.midX, y: rect.midY)
            platform.zPosition = 1
            platform.name = "platform"
            world.addChild(platform)
        }
    }

    // MARK: - Playfield: towers + bases (towers fight; enemy base fans + summons)
    private func buildStructures() {
        // Towers fight: blue pair (player) at left, red pair (enemy) at right.
        for x in Balance.playerTowerXs { addTower(at: x, team: .player) }
        for x in Balance.enemyTowerXs { addTower(at: x, team: .enemy) }
        // Main HQs (pixel-art BaseNodes): the enemy base is the encounter
        // (HP bar, 3-bolt fan, summoner). Player base tracks HP for
        // enemy attacks; no shooting (lose screen lands later).
        addBase(at: Balance.playerBaseX, team: .player)
        addBase(at: Balance.enemyBaseX, team: .enemy)
    }

    /// Pixel-art HQ (see BaseNode): spawn gate + roof cannon + wide HP bar.
    /// Enemy muzzle is the cannon tip; fan shots originate there.
    private func addBase(at x: CGFloat, team: Team) {
        let base = BaseNode(team: team)
        base.position = CGPoint(x: x, y: Balance.groundTopY)
        world.addChild(base)
        bases.append(Base(node: base, team: team, hp: Balance.baseHP,
                          maxHP: Balance.baseHP, cooldown: Balance.baseFireCooldown,
                          summonTimer: Balance.firstSummonDelay))
    }

    private func baseMuzzle(for base: Base) -> CGPoint {
        base.node.muzzlePosition()
    }

    /// Pixel-art tower + turning turret head (see TowerNode).
    /// Muzzle is the barrel tip; shots originate there.
    private func addTower(at x: CGFloat, team: Team) {
        let tower = TowerNode(team: team)
        tower.position = CGPoint(x: x, y: Balance.groundTopY)
        world.addChild(tower)
        // Stagger first shots round-robin so the line doesn't volley
        // on the same frame.
        let stagger = Double(towers.count) * Balance.towerFireCooldown / 4
        towers.append(Tower(node: tower, team: team, hp: Balance.towerHP,
                            maxHP: Balance.towerHP, cooldown: stagger))
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
        hero.setWeapon(heroWeapon)
        hero.position = CGPoint(x: Balance.heroSpawnX,
                                y: Balance.groundTopY + Balance.heroHeight / 2 + 4)
        world.addChild(hero)
    }

    // MARK: - Foreground layer (factor 1.15, subtle)
    private func buildForeground() {
        foregroundLayer.zPosition = 20
        TwilightRuinsBG.buildForeground(in: foregroundLayer)
        foregroundLayer.position = CGPoint(x: 0, y: 0)
    }

    // MARK: - Camera + parallax update
    private var halfViewWidth: CGFloat { size.width * cam.xScale / 2 }

    /// World x-range currently on screen (plus a margin). Victory-marching
    /// armies leave the field once they step outside it.
    private func cameraSpan(margin: CGFloat) -> ClosedRange<CGFloat> {
        let hw = halfViewWidth + margin
        return (cam.position.x - hw)...(cam.position.x + hw)
    }
    private var halfViewHeight: CGFloat { size.height * cam.xScale / 2 }

    private func cameraTarget() -> CGPoint {
        let lookahead = hero.velocity.dx * 0.22
        let desiredX = hero.position.x + lookahead
        let x = min(max(desiredX, halfViewWidth), Balance.levelWidth - halfViewWidth)
        // Follow the hero vertically a little so jumps stay framed, but never
        // show below the ground or above the sky.
        // Camera rides high: ground line sits ~22% up from the bottom so
        // more of the action reads above it.
        let baseY: CGFloat = Balance.groundTopY + halfViewHeight * 0.55
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
        var dt = lastUpdate > 0 ? currentTime - lastUpdate : 1.0 / 60
        // Pause/hitch guard: while the pause menu is up update() stops, so
        // the first frame after resume would see a seconds-long dt — snapping
        // the camera (rate = min(1, 6*dt) = 1) and teleporting the sim.
        // Clamp it so resume continues exactly where the frame froze.
        // (Unpausing also invalidates lastUpdate; see isPaused override.)
        if dt > 1.0 / 30 || dt < 0 { dt = 1.0 / 60 }
        lastUpdate = currentTime
        sceneTime += dt
        hero.step(dt: dt, now: currentTime)
        // Listener for positional audio: everything attenuates + pans
        // relative to the hero, so distant battles rumble quietly.
        SoundEngine.shared.listenerX = hero.position.x
        updateRespawn()
        updateReload(dt: dt)
        updateShooting(dt: dt)
        updateTowers(dt: dt)
        updateBases(dt: dt)
        updateEnemies(dt: dt)
        updateAllies(dt: dt)
        updateDrops(dt: dt)
        stepProjectiles(dt: dt)
        updateGraceBlink()
        smoothCamera(dt: dt)
        updateParallax()
    }

    /// Death → wait → drop from above in front of the player base → land → grace.
    private func updateRespawn() {
        guard respawnAt >= 0, sceneTime >= respawnAt else { return }
        respawnAt = -1
        hero.respawn(at: CGPoint(x: Balance.playerBaseX + Balance.respawnOffsetX,
                                 y: Balance.groundTopY + Balance.respawnDropHeight))
        heroHP = Balance.heroHP
        graceUntil = sceneTime + Balance.respawnGrace
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = hero.position
        world.addChild(puff)
    }

    /// Blink while invulnerable after respawn so the grace reads clearly.
    private func updateGraceBlink() {
        guard hero.alive else { return }
        if sceneTime < graceUntil {
            hero.alpha = sin(sceneTime * 20) > 0 ? 0.45 : 1.0
        } else {
            hero.alpha = 1.0
        }
    }

    private var heroProtected: Bool {
        !hero.alive || sceneTime < graceUntil
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
        releaseAimTouch()
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
        hero.muzzlePosition(for: dir)
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
        guard aimTouch != nil, hero.alive else { return }
        // This gun is mid-reload, or the mag is dry (reload kicks in via
        // updateReload): hold fire until rounds are back.
        guard reloadingWeapon != heroWeapon,
              mags[heroWeapon.rawValue] > 0 else { return }
        fireCooldown -= dt
        guard fireCooldown <= 0 else { return }
        fireCooldown = heroWeapon.cooldown
        fireBullet()
    }

    /// Reload sim: finishes the active reload, auto-reloads the dry active
    /// gun, and trickles reserve rounds to fully-starved guns so no gun can
    /// stay bricked forever (desperation mode, capped low).
    private func updateReload(dt: TimeInterval) {
        // Finish the active reload.
        if let gun = reloadingWeapon, sceneTime >= reloadEndsAt {
            let need = gun.magSize - mags[gun.rawValue]
            let take = min(need, reserves[gun.rawValue])
            mags[gun.rawValue] += take
            reserves[gun.rawValue] -= take
            reloadingWeapon = nil
            SoundEngine.shared.reloadDone()
        }
        // The dry active gun reloads on its own, even when not aiming.
        if reloadingWeapon == nil,
           mags[heroWeapon.rawValue] == 0,
           reserves[heroWeapon.rawValue] > 0 {
            startReload(gun: heroWeapon)
        }
        // Desperation trickle: +1 reserve every 2s per starved gun, capped.
        regenAccumulator += dt
        if regenAccumulator >= 2.0 {
            regenAccumulator = 0
            for gun in HeroWeapon.allCases
            where mags[gun.rawValue] == 0
                && reserves[gun.rawValue] == 0
                && reloadingWeapon != gun {
                reserves[gun.rawValue] = min(reserves[gun.rawValue] + 1, 6)
            }
        }
    }

    private func fireBullet() {
        mags[heroWeapon.rawValue] -= 1 // one trigger pull = one round
        SoundEngine.shared.heroShot(heroWeapon, at: hero.position.x)
        let muzzle = muzzlePosition(for: aimDir)
        let baseAngle = atan2(aimDir.dy, aimDir.dx)
        let pellets = heroWeapon.pelletCount
        for k in 0..<pellets {
            // Symmetric fan: e.g. 3 pellets at -spread, 0, +spread.
            let offset = (CGFloat(k) - CGFloat(pellets - 1) / 2) * heroWeapon.spread
            let a = baseAngle + offset
            let dir = CGVector(dx: cos(a), dy: sin(a))
            let bolt = ProjectileFactory.makeBolt()
            bolt.setScale(heroWeapon.boltScale)
            bolt.position = muzzle
            bolt.zRotation = a
            world.addChild(bolt)
            projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.bulletLife,
                                          speed: heroWeapon.bulletSpeed, damage: heroWeapon.damage,
                                          team: .neutral))
        }
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
            // Smooth turret tracking runs every frame, even between shots.
            let tracked = acquireTarget(for: towers[i])
            towers[i].node.aimAt(tracked)
            towers[i].node.update(dt: dt)
            towers[i].cooldown -= dt
            guard towers[i].cooldown <= 0 else { continue }
            guard let target = tracked else { continue }
            towers[i].cooldown = Balance.towerFireCooldown
            fireTowerBolt(from: towers[i], to: target)
            towers[i].node.recoil()
        }
    }

    /// Nearest enemy point within range, or nil when nothing is in proximity.
    /// Player tower hunts enemy marchers first, then the enemy tower.
    /// Enemy tower hunts player allies first, then the hero, then the player tower.
    private func acquireTarget(for tower: Tower) -> CGPoint? {
        var best: CGPoint?
        var bestDist = Balance.towerRange
        let muzzleY = Balance.groundTopY + Balance.towerMuzzleHeight
        if tower.team == .player {
            for e in enemies where e.alive {
                let d = hypot(e.position.x - tower.node.position.x,
                              e.position.y - muzzleY)
                if d <= bestDist {
                    bestDist = d
                    best = e.position
                }
            }
        } else {
            for a in allies where a.alive {
                let d = hypot(a.position.x - tower.node.position.x,
                              a.position.y - muzzleY)
                if d <= bestDist {
                    bestDist = d
                    best = a.position
                }
            }
        }
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
        tower.node.muzzlePosition()
    }

    private func fireTowerBolt(from tower: Tower, to target: CGPoint) {
        let muzzle = towerMuzzle(for: tower)
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.towerFire(at: muzzle.x)
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
            // TowerNode handles the rubble look (grey + slumped turret).
            towers[index].node.setDestroyed()
            SoundEngine.shared.structureDestroyed(playerOwned: towers[index].team == .player,
                                                  at: towers[index].node.position.x)
        }
    }

    private func updateTowerHPBar(at index: Int) {
        let frac = max(0, towers[index].hp / towers[index].maxHP)
        towers[index].node.setHPFraction(frac)
    }

    // MARK: - Main bases: 3-bolt fan on both HQs + summoning (enemy only)
    private func updateBases(dt: TimeInterval) {
        // Gate shimmer + beacons animate on both HQs every frame.
        for base in bases { base.node.update(dt: dt) }
        for i in bases.indices {
            guard bases[i].alive else { continue }
            // Traverse the roof cannon at whoever is pushing in (nil parks
            // it toward mid); fan fires once aimed + cooled down.
            // Enemy HQ hunts hero/allies; player HQ fires back at marchers.
            let fanTarget = baseFanTarget(for: bases[i])
            bases[i].node.aimAt(fanTarget)
            bases[i].cooldown -= dt
            if bases[i].cooldown <= 0, let target = fanTarget {
                bases[i].cooldown = Balance.baseFireCooldown
                fireBaseFan(from: bases[i], at: target)
            }
            guard bases[i].team == .enemy else { continue }
            // Summon marchers toward the player base, capped.
            bases[i].summonTimer -= dt
            if bases[i].summonTimer <= 0 {
                bases[i].summonTimer = Balance.summonInterval
                if enemies.count < Balance.maxEnemies { summonEnemy(from: bases[i]) }
            }
        }
    }

    /// Base fan target: enemy HQ hunts the exposed hero in range, else the
    /// nearest ally in range; player HQ hunts the nearest enemy marcher.
    private func baseFanTarget(for base: Base) -> CGPoint? {
        let muzzleY = Balance.groundTopY + Balance.baseMuzzleHeight
        if base.team == .player {
            var best: CGPoint?
            var bestDist = Balance.baseRange
            for e in enemies where e.alive {
                let d = hypot(e.position.x - base.node.position.x, e.position.y - muzzleY)
                if d < bestDist {
                    bestDist = d
                    best = e.position
                }
            }
            return best
        }
        if hero.alive, !heroProtected,
           hypot(hero.position.x - base.node.position.x,
                 hero.position.y - muzzleY) <= Balance.baseRange {
            return hero.position
        }
        var best: CGPoint?
        var bestDist = Balance.baseRange
        for a in allies where a.alive {
            let d = hypot(a.position.x - base.node.position.x, a.position.y - muzzleY)
            if d < bestDist {
                bestDist = d
                best = a.position
            }
        }
        return best
    }

    /// 3 blasts from the same muzzle, spread out around the target direction.
    /// Bolt team matches the firing HQ so hits land on the right side.
    private func fireBaseFan(from base: Base, at target: CGPoint) {
        let muzzle = baseMuzzle(for: base)
        var baseDir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(baseDir.dx, baseDir.dy))
        baseDir = CGVector(dx: baseDir.dx / len, dy: baseDir.dy / len)
        SoundEngine.shared.baseFire(at: muzzle.x)
        let baseAngle = atan2(baseDir.dy, baseDir.dx)
        let count = Balance.baseFanCount
        for k in 0..<count {
            // Symmetric fan: e.g. 3 bolts at -spread, 0, +spread.
            let offset = (CGFloat(k) - CGFloat(count - 1) / 2) * Balance.baseFanSpread
            let a = baseAngle + offset
            let dir = CGVector(dx: cos(a), dy: sin(a))
            let bolt = ProjectileFactory.makeTowerBolt(team: base.team)
            bolt.position = muzzle
            bolt.zRotation = a
            world.addChild(bolt)
            projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.towerBulletLife,
                                          speed: Balance.towerBulletSpeed, damage: Balance.baseBoltDamage,
                                          team: base.team))
        }
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.position = muzzle
        world.addChild(flash)
        base.node.fireFlash()
    }

    private func summonEnemy(from base: Base) {
        let e = EnemyNode()
        e.position = CGPoint(x: base.node.position.x - 120,
                             y: Balance.groundTopY + e.size.height / 2)
        world.addChild(e)
        enemies.append(e)
        base.node.spawnPulse()
        SoundEngine.shared.summon(at: e.position.x)
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = e.position
        world.addChild(puff)
    }

    /// Nearest alive tower of a team to a world x — layered defense
    /// falls outer-first as marchers chew inward.
    private func nearestTower(team: Team, toX x: CGFloat) -> Tower? {
        towers.filter { $0.team == team && $0.alive }
            .min(by: { abs($0.node.position.x - x) < abs($1.node.position.x - x) })
    }

    // MARK: - Summoned enemies: advance, stop at range, shoot bolts
    private func updateEnemies(dt: TimeInterval) {
        let playerBase = bases.first(where: { $0.team == .player })
        for e in enemies {
            guard e.alive else { continue }
            e.fireCooldown -= dt

            // Target priority: exposed hero in sight > nearest ally in sight
            // > player tower > player base.
            var target: CGPoint? = nil
            if hero.alive, !heroProtected,
               hypot(hero.position.x - e.position.x,
                     hero.position.y - e.position.y) < Balance.enemySightRange {
                target = hero.position
            } else {
                var bestAlly: CGPoint?
                var bestDist = Balance.enemySightRange
                for a in allies where a.alive {
                    let d = hypot(a.position.x - e.position.x, a.position.y - e.position.y)
                    if d < bestDist {
                        bestDist = d
                        bestAlly = a.position
                    }
                }
                if let bestAlly {
                    target = bestAlly
                } else if let tower = nearestTower(team: .player, toX: e.position.x) {
                    target = CGPoint(x: tower.node.position.x,
                                     y: Balance.groundTopY + 100)
                } else if let base = playerBase, base.alive {
                    target = CGPoint(x: base.node.position.x,
                                     y: Balance.groundTopY + 100)
                }
            }
            guard let aim = target else {
                // Nothing left to fight: hold position.
                e.aimAt(nil)
                // ...unless the player HQ is rubble: victory march past it
                // until out of the camera view, then leave the field.
                if playerBase?.alive == false {
                    e.face(-1)
                    e.position.x = max(40, e.position.x - Balance.enemySpeed * CGFloat(dt))
                    e.animateMarch(dt: dt, advancing: true)
                    e.position.y = Balance.groundTopY + e.size.height / 2 + e.yBob
                    if !cameraSpan(margin: 80).contains(e.position.x)
                        || e.position.x <= 50 {
                        e.marchedOff = true
                        e.removeFromParent()
                    }
                    continue
                }
                e.animateMarch(dt: dt, advancing: false)
                e.position.y = Balance.groundTopY + e.size.height / 2
                continue
            }

            let dist = hypot(aim.x - e.position.x, aim.y - e.position.y)
            e.face(aim.x - e.position.x)
            e.aimAt(CGVector(dx: aim.x - e.position.x, dy: aim.y - e.position.y))
            if dist > Balance.enemyShootRange {
                // Advance on the target (never past the lane edge).
                let dir: CGFloat = aim.x > e.position.x ? 1 : -1
                e.position.x = max(40, e.position.x + dir * Balance.enemySpeed * CGFloat(dt))
                e.animateMarch(dt: dt, advancing: true)
            } else {
                // In range: stop and shoot.
                e.animateMarch(dt: dt, advancing: false)
                if e.fireCooldown <= 0 {
                    e.fireCooldown = Balance.enemyFireCooldown
                    fireEnemyBolt(from: e, to: aim)
                }
            }
            e.position.y = Balance.groundTopY + e.size.height / 2 + e.yBob
        }
        // Sweep the dead (gold was already paid at kill time).
        enemies.removeAll { !$0.alive || $0.marchedOff }
    }

    /// Enemy trooper bolt: from the rifle tip toward the target, enemy team.
    private func fireEnemyBolt(from e: EnemyNode, to target: CGPoint) {
        let muzzle = e.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.enemyFire(at: muzzle.x)
        let bolt = ProjectileFactory.makeTowerBolt(team: .enemy)
        bolt.setScale(0.8)
        bolt.position = muzzle
        bolt.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(bolt)
        projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.enemyBoltLife,
                                      speed: Balance.enemyBoltSpeed, damage: Balance.enemyBoltDamage,
                                      team: .enemy))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.7)
        flash.position = muzzle
        world.addChild(flash)
    }

    // MARK: - Player army: summon + march toward the enemy base
    /// Called by the SwiftUI cards. Returns false when broke or capped.
    @discardableResult
    func summonAlly(kind: ArmyKind) -> Bool {
        guard money >= kind.cost, allies.count < Balance.maxAllies else { return false }
        guard let homeBase = bases.first(where: { $0.team == .player }),
              homeBase.alive else { return false }
        money -= kind.cost
        let a = AllyNode(kind: kind)
        // Stagger spawn positions so stacked summons don't overlap.
        let offset = CGFloat(allies.count % 4) * 46
        a.position = CGPoint(x: Balance.playerBaseX + 120 + offset,
                             y: Balance.groundTopY + a.size.height / 2)
        world.addChild(a)
        allies.append(a)
        homeBase.node.spawnPulse()
        SoundEngine.shared.summon(at: a.position.x)
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = a.position
        world.addChild(puff)
        return true
    }

    private func updateAllies(dt: TimeInterval) {
        let enemyBase = bases.first(where: { $0.team == .enemy })
        for a in allies {
            guard a.alive else { continue }
            a.fireCooldown -= dt

            // Target priority: nearest enemy marcher in sight > enemy tower
            // > enemy base. Marches right toward the enemy base.
            var target: CGPoint? = nil
            var bestEnemy: CGPoint?
            var bestDist = a.kind.sightRange
            for e in enemies where e.alive {
                let d = hypot(e.position.x - a.position.x, e.position.y - a.position.y)
                if d < bestDist {
                    bestDist = d
                    bestEnemy = e.position
                }
            }
            if let bestEnemy {
                target = bestEnemy
            } else if let tower = nearestTower(team: .enemy, toX: a.position.x) {
                target = CGPoint(x: tower.node.position.x, y: Balance.groundTopY + 100)
            } else if let base = enemyBase, base.alive {
                target = CGPoint(x: base.node.position.x, y: Balance.groundTopY + 100)
            }
            guard let aim = target else {
                a.aimAt(nil)
                // ...unless the enemy HQ is rubble: victory march past it
                // until out of the camera view, then leave the field.
                if enemyBase?.alive == false {
                    a.face(1)
                    a.position.x = min(Balance.levelWidth - 40,
                                       a.position.x + a.kind.speed * CGFloat(dt))
                    a.animateMarch(dt: dt, advancing: true)
                    a.position.y = Balance.groundTopY + a.size.height / 2 + a.yBob
                    if !cameraSpan(margin: 80).contains(a.position.x)
                        || a.position.x >= Balance.levelWidth - 50 {
                        a.marchedOff = true
                        a.removeFromParent()
                    }
                    continue
                }
                a.animateMarch(dt: dt, advancing: false)
                a.position.y = Balance.groundTopY + a.size.height / 2
                continue
            }

            let dist = hypot(aim.x - a.position.x, aim.y - a.position.y)
            a.face(aim.x - a.position.x)
            a.aimAt(CGVector(dx: aim.x - a.position.x, dy: aim.y - a.position.y))
            if dist > a.kind.shootRange {
                let dir: CGFloat = aim.x > a.position.x ? 1 : -1
                a.position.x = min(Balance.levelWidth - 40,
                                   a.position.x + dir * a.kind.speed * CGFloat(dt))
                a.animateMarch(dt: dt, advancing: true)
            } else {
                a.animateMarch(dt: dt, advancing: false)
                if a.fireCooldown <= 0 {
                    a.fireCooldown = a.kind.fireCooldown
                    fireAllyBolt(from: a, to: aim)
                }
            }
            a.position.y = Balance.groundTopY + a.size.height / 2 + a.yBob
        }
        allies.removeAll { !$0.alive || $0.marchedOff }
    }

    /// Friendly bolt: player team so it hurts marchers + enemy structures.
    private func fireAllyBolt(from a: AllyNode, to target: CGPoint) {
        let muzzle = a.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.allyFire(at: muzzle.x)
        let bolt = ProjectileFactory.makeTowerBolt(team: .player)
        bolt.setScale(a.kind == .heavy ? 1.0 : 0.8)
        bolt.position = muzzle
        bolt.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(bolt)
        projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.enemyBoltLife,
                                      speed: Balance.enemyBoltSpeed + 60, damage: a.kind.damage,
                                      team: .player))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.7)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Enemy-bolt vs player army. Returns true when it struck an ally.
    private func hitAlly(at pt: CGPoint, amount: CGFloat) -> Bool {
        for a in allies where a.alive {
            if abs(pt.x - a.position.x) < a.size.width / 2 + 12,
               abs(pt.y - a.position.y) < a.size.height / 2 + 8 {
                a.hp = max(0, a.hp - amount)
                a.refreshHPBar()
                if !a.alive {
                    let puff = ProjectileFactory.makeImpactPuff()
                    puff.position = a.position
                    puff.setScale(1.4)
                    world.addChild(puff)
                    a.removeFromParent()
                    SoundEngine.shared.troopDown(at: a.position.x)
                }
                return true
            }
        }
        return false
    }

    private func damageBase(at index: Int, amount: CGFloat) {
        guard bases[index].alive else { return }
        bases[index].hp = max(0, bases[index].hp - amount)
        let frac = max(0, bases[index].hp / bases[index].maxHP)
        bases[index].node.setHPFraction(frac)
        if !bases[index].alive {
            // BaseNode handles the rubble look (grey + dark gate). Win/lose screens land later.
            bases[index].node.setDestroyed()
            SoundEngine.shared.structureDestroyed(playerOwned: bases[index].team == .player,
                                                  at: bases[index].node.position.x)
        }
    }

    /// Point-in-base test for one team's alive bases. HQ is ~227 wide, 170 tall.
    private func baseIndex(at pt: CGPoint, team: Team) -> Int? {
        for (i, b) in bases.enumerated() where b.team == team && b.alive {
            let dx = abs(pt.x - b.node.position.x)
            let inX = dx < 110
            let inY = pt.y >= Balance.groundTopY && pt.y <= Balance.groundTopY + 175
            if inX && inY { return i }
        }
        return nil
    }

    private func damageHero(amount: CGFloat) {
        guard hero.alive, heroHP > 0 else { return }
        heroHP = max(0, heroHP - amount)
        if heroHP <= 0 {
            killHero()
            return
        }
        SoundEngine.shared.heroHurt()
        // Hit flash so damage reads instantly.
        hero.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.06),
                            .fadeAlpha(to: 1.0, duration: 0.12)]))
    }

    private func killHero() {
        let deathSpot = hero.position
        hero.die()
        hero.isHidden = true
        releaseAimTouch()
        respawnAt = sceneTime + Balance.respawnDelay
        SoundEngine.shared.heroDeath()
        // Death poof.
        for i in 0..<2 {
            let puff = ProjectileFactory.makeImpactPuff()
            puff.position = CGPoint(x: deathSpot.x + CGFloat(i * 10 - 5), y: deathSpot.y)
            world.addChild(puff)
        }
    }

    /// Shared cleanup when the aim touch ends (release or death).
    private func releaseAimTouch() {
        aimTouch = nil
        hero.clearAim()
        aimDots.forEach { $0.isHidden = true }
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

    /// Team-aware hit test. Hero (neutral) + ally (player) bolts hit marchers,
    /// the enemy tower and the enemy base; enemy bolts hit the player tower,
    /// player base, player army + hero.
    /// Returns true when the projectile struck something (caller removes it).
    private func hitEnemy(_ p: Projectile) -> Bool {
        let pt = p.node.position
        switch p.team {
        case .neutral:
            if hitMarcher(at: pt, amount: p.damage, fromHero: true) { return true }
            if let idx = towerIndex(at: pt, team: .enemy) {
                damageTower(at: idx, amount: p.damage)
                return true
            }
            if let idx = baseIndex(at: pt, team: .enemy) {
                damageBase(at: idx, amount: p.damage)
                return true
            }
        case .player:
            if hitMarcher(at: pt, amount: p.damage, fromHero: false) { return true }
            if let idx = towerIndex(at: pt, team: .enemy) {
                damageTower(at: idx, amount: p.damage)
                return true
            }
            if let idx = baseIndex(at: pt, team: .enemy) {
                damageBase(at: idx, amount: p.damage)
                return true
            }
        case .enemy:
            if hitAlly(at: pt, amount: p.damage) { return true }
            if let idx = towerIndex(at: pt, team: .player) {
                damageTower(at: idx, amount: p.damage)
                return true
            }
            if let idx = baseIndex(at: pt, team: .player) {
                damageBase(at: idx, amount: p.damage)
                return true
            }
            // Hero body: ~44 wide, Balance.heroHeight tall, centered on position.
            // Skipped while dead or grace-blinking after respawn.
            if !heroProtected,
               abs(pt.x - hero.position.x) < 34,
               abs(pt.y - hero.position.y) < Balance.heroHeight / 2 + 6 {
                damageHero(amount: p.damage)
                return true
            }
        }
        return false
    }

    /// Bolt vs summoned marchers. Kills pay Unity's +100 gold, plus reserve
    /// ammo for the active hero gun on hero-gun kills (capped at 2x start).
    private func hitMarcher(at pt: CGPoint, amount: CGFloat, fromHero: Bool) -> Bool {
        for e in enemies where e.alive {
            if abs(pt.x - e.position.x) < 42,
               abs(pt.y - e.position.y) < e.size.height / 2 + 8 {
                e.hp = max(0, e.hp - amount)
                e.refreshHPBar()
                if !e.alive {
                    money += Balance.killReward
                    if fromHero {
                        let i = heroWeapon.rawValue
                        reserves[i] = min(reserves[i] + heroWeapon.killAmmo,
                                          heroWeapon.startReserve * 2)
                    }
                    maybeSpawnDrop(at: e.position)
                    let puff = ProjectileFactory.makeImpactPuff()
                    puff.position = e.position
                    puff.setScale(1.6)
                    world.addChild(puff)
                    e.removeFromParent()
                    SoundEngine.shared.enemyDown(at: e.position.x)
                }
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
        SoundEngine.shared.impact(at: pt.x)
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
        let ptHP = towers.filter { $0.team == .player }.map { String(Int($0.hp)) }.joined(separator: "+")
        let etHP = towers.filter { $0.team == .enemy }.map { String(Int($0.hp)) }.joined(separator: "+")
        let ebHP = bases.first(where: { $0.team == .enemy })?.hp ?? 0
        return String(format: "f%d pos %4.0f,%4.0f in %+.2f jmp %@ | v %+4.0f,%+5.0f gnd %@ shots %d hero %3.0f tw P %@/E %@ ebase %3.0f en %d al %d $%d",
                      frameCount, p.x, p.y, heroInputX, heroJumpHeld ? "Y" : "n",
                      v.dx, v.dy, g ? "Y" : "n", shotsFired, heroHP, ptHP, etHP, ebHP, enemies.count, allies.count, money)
    }

    // MARK: - Minimap snapshot (polled by the SwiftUI MinimapView ~7Hz)
    var minimap: MinimapSnapshot {
        MinimapSnapshot(
            levelWidth: Balance.levelWidth,
            heroX: hero?.position.x ?? 0,
            cameraX: cam.position.x,
            viewWidth: size.width * cam.xScale,
            playerBaseX: Balance.playerBaseX,
            playerTowerXs: Balance.playerTowerXs,
            enemyTowerXs: Balance.enemyTowerXs,
            enemyBaseX: Balance.enemyBaseX,
            heroHP: heroHP,
            heroMaxHP: Balance.heroHP,
            money: money,
            allyXs: allies.filter { $0.alive }.map { $0.position.x },
            enemyXs: enemies.filter { $0.alive }.map { $0.position.x },
            ammoText: ammoDisplayText,
            ammoMag: mags[heroWeapon.rawValue],
            reloading: reloadingWeapon == heroWeapon
        )
    }

    // MARK: - Gun ammo readout (shown as 12/90 on the HUD gun button)
    private var ammoDisplayText: String {
        let i = heroWeapon.rawValue
        if reloadingWeapon == heroWeapon { return "REL \(mags[i])/\(reserves[i])" }
        return "\(mags[i])/\(reserves[i])"
    }

    // MARK: - Drops (dead enemies randomly leave ammo/health for the hero)
    private struct Drop {
        var node: SKNode
        var kind: DropKind
        var life: TimeInterval
        var baseY: CGFloat
        var phase: TimeInterval
    }
    private var drops: [Drop] = []

    /// Rolls a drop at the dead enemy's spot. The overall chance never
    /// changes (Balance.dropChance); money just joins the table.
    /// Full-HP heroes split ammo/money; otherwise health/ammo/money thirds.
    private func maybeSpawnDrop(at pos: CGPoint) {
        guard Double.random(in: 0..<1) < Balance.dropChance else { return }
        let kind: DropKind
        if heroHP >= Balance.heroHP {
            kind = Bool.random() ? .ammo : .money
        } else {
            switch Int.random(in: 0..<3) {
            case 0: kind = .health
            case 1: kind = .ammo
            default: kind = .money
            }
        }
        let node = makeDropNode(kind: kind)
        node.position = CGPoint(
            x: min(max(pos.x, 60), Balance.levelWidth - 60),
            y: Balance.groundTopY + 16)
        node.zPosition = 8
        world.addChild(node)
        drops.append(Drop(node: node, kind: kind, life: Balance.dropLifetime,
                          baseY: node.position.y,
                          phase: Double.random(in: 0..<(2 * .pi))))
    }

    /// Floating pickup visual: pixel medkit / ammo crate (see DropArt)
    /// over a soft team glow, bobbed by updateDrops.
    private func makeDropNode(kind: DropKind) -> SKNode {
        let root = SKNode()
        let glowColor: SKColor
        switch kind {
        case .health:
            glowColor = SKColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 1)
        case .ammo:
            glowColor = SKColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1)
        case .money:
            glowColor = SKColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1)
        }
        let glow = SKShapeNode(circleOfRadius: 17)
        glow.fillColor = glowColor.withAlphaComponent(0.25)
        glow.strokeColor = glowColor.withAlphaComponent(0.9)
        glow.lineWidth = 2
        root.addChild(glow)
        let sprite = SKSpriteNode(texture: DropArt.texture(for: kind))
        sprite.setScale(2) // 20px canvas -> ~40pt pickup
        sprite.position = CGPoint(x: 0, y: 2)
        root.addChild(sprite)
        return root
    }

    /// Bob, expiry blink, and hero pickup (walk over it to collect).
    private func updateDrops(dt: TimeInterval) {
        var alive: [Drop] = []
        alive.reserveCapacity(drops.count)
        for var d in drops {
            d.life -= dt
            d.phase += dt * 4
            if d.life <= 0 {
                d.node.removeFromParent()
                continue
            }
            d.node.position.y = d.baseY + sin(d.phase) * 4
            d.node.alpha = d.life < 3 ? (sin(d.phase * 3) > 0 ? 1.0 : 0.35) : 1.0
            if hero.alive,
               abs(hero.position.x - d.node.position.x) < 46,
               abs(hero.position.y - d.node.position.y) < 70 {
                collectDrop(d)
                d.node.removeFromParent()
                continue
            }
            alive.append(d)
        }
        drops = alive
    }

    private func collectDrop(_ d: Drop) {
        SoundEngine.shared.pickup()
        switch d.kind {
        case .health:
            heroHP = min(Balance.heroHP, heroHP + Balance.dropHeal)
            floatText("+\(Int(Balance.dropHeal)) HP",
                      color: SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 1),
                      at: d.node.position)
        case .ammo:
            for gun in HeroWeapon.allCases {
                let i = gun.rawValue
                reserves[i] = min(reserves[i] + gun.killAmmo * Balance.dropAmmoMultiplier,
                                  gun.startReserve * 2)
            }
            floatText("+AMMO",
                      color: SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1),
                      at: d.node.position)
        case .money:
            money += Balance.dropMoney
            floatText("+\(Balance.dropMoney)",
                      color: SKColor(red: 1.0, green: 0.75, blue: 0.25, alpha: 1),
                      at: d.node.position)
        }
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = d.node.position
        world.addChild(puff)
    }

    /// Small floating pickup label: rises and fades on its own.
    private func floatText(_ text: String, color: SKColor, at pos: CGPoint) {
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.text = text
        label.fontSize = 14
        label.fontColor = color
        label.position = pos
        label.zPosition = 20
        world.addChild(label)
        label.run(.sequence([
            .group([
                .moveBy(x: 0, y: 44, duration: 0.8),
                .fadeOut(withDuration: 0.8),
            ]),
            .removeFromParent(),
        ]))
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
