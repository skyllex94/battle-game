import QuartzCore
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
    /// Gun the attempt starts (and restarts) with — the level-screen pick.
    private var startingWeapon: HeroWeapon = .blaster
    // MARK: - Gun ammo (mag + reserve per gun, indexed by HeroWeapon.rawValue)
    private var mags: [Int] = HeroWeapon.allCases.map { $0.magSize }
    private var reserves: [Int] = HeroWeapon.allCases.map { $0.startReserve }
    /// Gun currently reloading (background reloads keep running), if any.
    private var reloadingWeapon: HeroWeapon?
    private var reloadEndsAt: TimeInterval = -1
    /// Halfway mark of the active reload: fires the mag-seat clack once.
    private var reloadMidAt: TimeInterval = -1
    /// Desperation trickle for fully-starved guns (mag 0 + reserve 0).
    private var regenAccumulator: TimeInterval = 0

    /// Switches to the next LOADOUT hero gun (slot order, wraps around).
    /// Called by the HUD weapon button; the swapped gun fires instantly.
    /// A swapped-in gun with an empty mag starts reloading on the spot.
    /// Single-gun loadouts stay put (button hides in that case anyway).
    @discardableResult
    func cycleWeapon() -> HeroWeapon {
        let slotted = LoadoutStore.loadout
        guard slotted.count > 1,
              let idx = slotted.firstIndex(of: heroWeapon) else { return heroWeapon }
        heroWeapon = slotted[(idx + 1) % slotted.count]
        hero?.setWeapon(heroWeapon)
        fireCooldown = 0
        if mags[heroWeapon.rawValue] == 0 { startReload(gun: heroWeapon) }
        SoundEngine.shared.weaponSwitch()
        return heroWeapon
    }

    /// Begins a reload for one gun. One reload at a time; no-op when the mag
    /// is already full, the reserve is dry, or another gun is reloading.
    /// Infinite-reserve guns (Blaster) always have stock to draw on.
    @discardableResult
    private func startReload(gun: HeroWeapon) -> Bool {
        guard reloadingWeapon == nil,
              mags[gun.rawValue] < gun.magSize,
              gun.hasInfiniteAmmo || reserves[gun.rawValue] > 0 else { return false }
        reloadingWeapon = gun
        reloadEndsAt = sceneTime + gun.reloadTime
        reloadMidAt = sceneTime + gun.reloadTime / 2
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
    /// Effective max HP from hero HP tiers (100 stock — today's value).
    private var heroMaxHP: CGFloat = Balance.heroHP
    /// Energy shield pool (0 max = no shield mechanic). Absorbs damage
    /// first, recharges after 4s without a hit.
    private var shieldHP: CGFloat = 0
    private var shieldMax: CGFloat = 0
    private var lastShieldHitAt: TimeInterval = -10
    /// Spendable gold for the army (unit shop lands next). Starts at your Unity value.
    /// Playground pays the fat dev stack (see Balance.startingGold(for:)).
    /// The pinned levelId isn't set yet at property-init time, so this
    /// default is corrected in init + resetLevel once levelId is known.
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
    /// Total marchers gated out so far (drives the Brute cadence:
    /// every bruteEvery-th summon is a Brute on levels that field them).
    private var summonCount: Int = 0
    // MARK: - Player army (summoned from cards, marches toward the enemy base)
    private var allies: [AllyNode] = []
    /// Revrent interceptors: independent flying droids owned by carriers.
    /// They have their own HP, deploy ahead of the hull to shoot, dock
    /// back when clear, and rebuild 5s after dying.
    private var interceptors: [RevrentInterceptorNode] = []
    /// Per-unit deploy cooldowns (seconds left; pricier units wait longer).
    private var summonCooldowns: [ArmyKind: TimeInterval] = [:]
    // MARK: - Droid companion (owned battle buddy over the back shoulder)
    private var droid: DroidNode?
    /// Screen-locked snowfall overlay (Level 20+ snow fields), camera-pinned
    /// once per frame in updateParallax. Nil on non-snowy levels.
    private var snowNode: SKNode?
    // MARK: - Hero death/respawn
    private var sceneTime: TimeInterval = 0
    private var respawnAt: TimeInterval = -1 // <0 = no pending respawn
    private var graceUntil: TimeInterval = -1
    /// Hearts remaining this attempt. Each death costs one; at zero the
    /// hero stays down and the run ends in defeat (see lostAt).
    private var heroLives: Int = Balance.heroLives
    /// Health pack armed this attempt (booster add-on). One HUD-tapped
    /// heal per run; rearmed every attempt, not every respawn.
    private var heroPackArmed: Bool = false
    // MARK: - Bomber support strike (Level 25+ HUD ability)
    /// Recharge left (0 = a strike is ready).
    private var bomberCooldownLeft: Double = 0
    /// Targeting mode: the next right-half touch picks the strike zone
    /// instead of aiming the hero's gun.
    private var bomberTargeting = false
    private var bomberTouch: UITouch?
    /// Pulsing strike-zone reticle while targeting.
    private var bomberReticle: SKNode?
    /// Live bombing run: the plane node, the tapped zone, drops left.
    private struct BomberRun {
        var node: SKNode
        var targetX: CGFloat
        var bombsLeft: Int
        var dropAcc: Double
        var trailAcc: Double
    }
    private var bomberRun: BomberRun?
    // MARK: - Victory (enemy HQ destroyed -> level won)
    /// sceneTime of the winning blow; nil until the enemy HQ falls.
    private(set) var wonAt: TimeInterval?
    // MARK: - Defeat (last hero heart lost -> no respawn)
    /// sceneTime of the final death; nil while hearts remain.
    private(set) var lostAt: TimeInterval?
    /// Same re-presentation crash as the menu scene (SwiftUI reusing a scene
    /// whose layer nodes already have parents): build content exactly once.
    /// Restarts go through resetLevel(), which tears down first.
    private var didBuild = false
    /// True until the first buildHero: only a fresh level entry consumes
    /// the banked shield carryover (retries start full).
    private var freshEntry = true
    /// Level this scene is pinned to (drives Balance.active on every entry).
    private var levelId: Int = 1
    /// Hero id driving upgrade tiers (effective HP/speed/damage/shield).
    private var heroId: String = "vanguard"

    // MARK: - Setup
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = .black
    }

    /// Designated entry: pins the battlefield layout for this level before
    /// anything builds or simulates (all Balance layout reads follow it).
    init(size: CGSize, levelId: Int, weapon: HeroWeapon = .blaster,
         heroId: String = "vanguard") {
        self.levelId = levelId
        self.heroId = heroId
        // Never start on a locked gun (stale picks, future grants).
        let pick = GunLocker.isUnlocked(weapon) ? weapon : .blaster
        self.startingWeapon = pick
        self.heroWeapon = pick
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = .black
        // The battle owns the global layout while it runs.
        Balance.battleOwnsLayout = true
        Balance.active = Balance.layout(for: levelId)
        money = Balance.startingGold(for: levelId)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func didMove(to view: SKView) {
        guard !didBuild else { return }
        didBuild = true
        Balance.battleOwnsLayout = true
        Balance.active = Balance.layout(for: levelId)
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
        buildDressing()
        snapCamera()
        updateParallax()
        SoundEngine.shared.listenerX = hero.position.x
        SoundEngine.shared.startBattleMusic()
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

    /// Reads hero upgrade tiers into battle stats. Full restores refill HP
    /// + shield (reset/revive); respawns refill through the same path.
    private func applyHeroUpgrades(fullRestore: Bool) {
        heroMaxHP = HeroUpgrades.maxHP(heroId: heroId)
        shieldMax = HeroUpgrades.shieldMax(heroId: heroId)
        if fullRestore {
            heroHP = heroMaxHP
            shieldHP = shieldMax
            lastShieldHitAt = -10
        } else {
            heroHP = min(heroHP, heroMaxHP)
            shieldHP = min(shieldHP, shieldMax)
        }
        hero.speedMultiplier = HeroUpgrades.speedMultiplier(heroId: heroId)
    }

    /// Mid-battle hero swap (milestone unlock modal): repoints the tier
    /// lookups, redresses the on-field sprite, refreshes the booster +
    /// droid companion, and refills the new hero's HP + shield so the
    /// deploy starts clean.
    func setHero(_ id: String) {
        guard id != heroId else { return }
        heroId = id
        hero.setHero(HeroPixelArt.kind(for: id))
        heroPackArmed = HeroAddons.boosterTier(heroId: id) > 0
        applyHeroUpgrades(fullRestore: true)
        ensureDroid()
    }

    func resetLevel() {
        isPaused = false
        // Retry path: banked carry is for fresh entries only — a restarted
        // run always opens on a full shield.
        freshEntry = false
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
        interceptors = []
        summonCooldowns = [:]
        droid = nil // world teardown removed its node; buildHero re-fields it
        drops = []
        summonCount = 0
        applyHeroUpgrades(fullRestore: true)
        heroLives = Balance.heroLives
        heroPackArmed = HeroAddons.boosterTier(heroId: heroId) > 0
        money = Balance.startingGold(for: levelId)
        sceneTime = 0
        lastUpdate = 0
        respawnAt = -1
        graceUntil = -1
        wonAt = nil
        lostAt = nil
        aimTouch = nil
        aimDir = .zero
        fireCooldown = 0
        shotsFired = 0
        frameCount = 0
        heroWeapon = startingWeapon
        mags = HeroWeapon.allCases.map { $0.magSize }
        reserves = HeroWeapon.allCases.map { $0.startReserve }
        reloadingWeapon = nil
        reloadEndsAt = -1
        reloadMidAt = -1
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
        buildDressing()
        snapCamera()
        updateParallax()
        SoundEngine.shared.listenerX = hero.position.x
        SoundEngine.shared.startBattleMusic()
    }

    // MARK: - Per-level set dressing (flags, alien sky-flocks, lush flora)
    /// Levels opt in via Balance.LevelLayout (Level 2+); Level 4's dawn
    /// atoll swaps glow flora for the dune wash, Level 5's sunscorch for
    /// the open rolling-field dressing (no platforms there), Level 6's
    /// sandhold for the ember-keep dressing. Runs after every layer
    /// exists so dressing can sit in world + sky alike.
    private func buildDressing() {
        let layout = Balance.active
        if layout.flags { LevelDressing.buildFlags(in: world) }
        if layout.alienBirds { LevelDressing.buildAlienBirds(in: skyLayer, sceneSize: size) }
        if layout.lushFlora { LevelDressing.buildGlowFlora(in: world) }
        if Balance.alpinePass { LevelDressing.buildAlpinePass(in: world) }
        if Balance.ridgeRedoubt { LevelDressing.buildRidgeRedoubt(in: world) }
        if Balance.whiteoutRedoubt { LevelDressing.buildWhiteoutRedoubt(in: world) }
        if Balance.howlingCauseway { LevelDressing.buildHowlingCauseway(in: world) }
        if Balance.rimewatchCrag { LevelDressing.buildRimewatchCrag(in: world) }
        if Balance.frozenNarrows { LevelDressing.buildFrozenNarrows(in: world) }
        if Balance.rimevault { LevelDressing.buildRimevault(in: world) }
        if Balance.paleAbyss { LevelDressing.buildPaleAbyss(in: world) }
        if Balance.umbralOutskirts { LevelDressing.buildUmbralOutskirts(in: world) }
        if Balance.ashenMarch { LevelDressing.buildAshenMarch(in: world) }
        if Balance.blackrootVale { LevelDressing.buildBlackrootVale(in: world) }
        if Balance.cinderGate { LevelDressing.buildCinderGate(in: world) }
        if Balance.shadowRift { LevelDressing.buildShadowRift(in: world) }
        if Balance.dreadHollow { LevelDressing.buildDreadHollow(in: world) }
        if Balance.obsidianGate { LevelDressing.buildObsidianGate(in: world) }
        if Balance.embralCore { LevelDressing.buildEmbralCore(in: world) }
        if Balance.active.theme == .dawn { LevelDressing.buildDuneWash(in: world) }
        if Balance.active.theme == .sunscorch { LevelDressing.buildSunscorchField(in: world) }
        if Balance.active.theme == .sandhold { LevelDressing.buildSandholdKeep(in: world) }
        if Balance.active.theme == .dunesea { LevelDressing.buildDuneSea(in: world) }
        if Balance.active.theme == .oasis { LevelDressing.buildOasisWaste(in: world) }
        if Balance.active.theme == .duskdesert { LevelDressing.buildDuskFlats(in: world) }
        if Balance.active.theme == .nightdesert { LevelDressing.buildNightFlats(in: world) }
        // Snowfall (Level 20+): screen-locked looping overlay above the
        // battle, below the foreground grass band / HUD.
        snowNode?.removeFromParent()
        snowNode = nil
        if Balance.snowfall {
            snowNode = SnowFX.buildSnow(sceneSize: size, cameraZoom: Balance.cameraZoom)
            if let snowNode { addChild(snowNode) }
        }
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
    /// From Level 20 (`Balance.upgradedBaseLevel`) on, both teams field the
    /// bigger Mk-II citadel HQ with a quad-missile rooftop battery — except
    /// the Level 35 finale, where the ALLIED HQ keeps the Mk-II kit and the
    /// ENEMY HQ fields the huge Mordor core-fortress (5-missile battery).
    private func addBase(at x: CGFloat, team: Team) {
        let base = BaseNode(team: team,
                            upgraded: levelId != Balance.playgroundLevelId
                                && levelId >= Balance.upgradedBaseLevel,
                            finale: Balance.isFinaleBase(levelId: levelId, team: team))
        base.position = CGPoint(x: x, y: Balance.groundY(at: x))
        world.addChild(base)
        let hp = Balance.baseHealth(for: team, levelId: levelId)
        bases.append(Base(node: base, team: team, hp: hp,
                          maxHP: hp, cooldown: Balance.baseFireCooldown,
                          summonTimer: Balance.firstSummonDelay))
    }

    private func baseMuzzle(for base: Base) -> CGPoint {
        base.node.muzzlePosition()
    }

    /// Pixel-art tower + turning turret head (see TowerNode).
    /// Muzzle is the barrel tip; shots originate there.
    private func addTower(at x: CGFloat, team: Team) {
        // Mk-II tower shells from the refit roster tier on (both teams);
        // Mk-III siege shells from Level 31 on; the DEV playground keeps
        // the classic Mk-I turret.
        let mega = Balance.isMegaTower(levelId: levelId)
        let tower = TowerNode(team: team,
                              upgraded: levelId != Balance.playgroundLevelId
                                  && levelId >= Balance.upgradedTowerLevel,
                              mkIII: mega)
        tower.position = CGPoint(x: x, y: Balance.groundY(at: x))
        world.addChild(tower)
        // Stagger first shots round-robin so the line doesn't volley
        // on the same frame.
        let stagger = Double(towers.count) * Balance.towerFireCooldown / 4
        let hp = Balance.towerHealth(for: team, levelId: levelId)
        towers.append(Tower(node: tower, team: team, hp: hp,
                            maxHP: hp, cooldown: stagger))
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
        hero.setHero(HeroPixelArt.kind(for: heroId))
        hero.setWeapon(heroWeapon)
        // Full battle stats from the first frame (roster HP + upgrades) —
        // otherwise the opening attempt runs on the 100 HP default.
        applyHeroUpgrades(fullRestore: true)
        // Fresh level entry (not a retry): banked leftover shield rides in
        // under anything bought since the win. Retries always start full.
        if freshEntry {
            freshEntry = false
            if let carry = HeroUpgrades.consumeShieldCarry(heroId: heroId,
                                                           cap: shieldMax) {
                shieldHP = carry
            }
        }
        // Lives per attempt + one armed heal pack (booster add-on).
        heroLives = Balance.heroLives
        heroPackArmed = HeroAddons.boosterTier(heroId: heroId) > 0
        // Owned battle buddy joins the deployment.
        ensureDroid()
        hero.position = CGPoint(x: Balance.heroSpawnX,
                                y: Balance.groundY(at: Balance.heroSpawnX)
                                    + Balance.heroHeight / 2 + 4)
        world.addChild(hero)
        // Fresh node needs the speed tier (HP/shield were set at reset).
        hero.speedMultiplier = HeroUpgrades.speedMultiplier(heroId: heroId)
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
        // more of the action reads above it. Hard landings dip the frame
        // a touch (hero.landDip decays in HeroNode.step) — impact you feel.
        let baseY: CGFloat = Balance.groundTopY + halfViewHeight * 0.55
        let lift = max(0, hero.position.y - (Balance.groundTopY + Balance.heroHeight)) * 0.35
        let dip = (hero?.landDip ?? 0) * 22
        let y = min(baseY + lift - dip, size.height - halfViewHeight)
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
        TwilightRuinsBG.updateMidParallax(in: midLayer, camX: camX)
        foregroundLayer.position.x = -camX * (Balance.parallaxForeground - 1)
        // Snow is screen-locked: re-pin to the camera like skyLayer.
        snowNode?.position = cam.position
    }

    override func update(_ currentTime: TimeInterval) {
        let cpuStart = CACurrentMediaTime()
        defer {
            let ms = (CACurrentMediaTime() - cpuStart) * 1000
            perfLastCPUms = ms
            perfCPUMs = perfCPUMs == 0 ? ms : perfCPUMs * 0.9 + ms * 0.1
        }
        frameCount += 1
        // ~1/sec: follow the music toggle without polling UserDefaults hot.
        if frameCount % 60 == 0 { SoundEngine.shared.syncMusic() }
        let rawDt = lastUpdate > 0 ? currentTime - lastUpdate : 1.0 / 60
        if rawDt > 0, rawDt < 1 {
            let ms = rawDt * 1000
            perfFrameMs = perfFrameMs == 0 ? ms : perfFrameMs * 0.9 + ms * 0.1
            fpsSmoothed = perfFrameMs > 0 ? min(240, 1000 / perfFrameMs) : 0
            perfPeakWindow += rawDt
            if perfPeakWindow >= 5 {
                perfPeakWindow = 0
                perfPeakMs = 0
                perfWorstCPUms = 0
                perfWorstDraws = 0
                perfWorstNodes = 0
                perfWorstTextures = 0
                perfWorstShapes = 0
                perfWorstProjectiles = 0
                perfWorstEnemies = 0
                perfWorstAllies = 0
            }
            perfHitchWindow += rawDt
            if perfHitchWindow >= 1 {
                perfHitchWindow = 0
                perfHitches = 0
            }
            if ms > perfPeakMs {
                perfPeakMs = ms
                perfWorstCPUms = perfLastCPUms
                perfWorstDraws = perfDraws
                perfWorstNodes = perfNodes
                perfWorstTextures = perfTextures
                perfWorstShapes = perfShapes
                perfWorstProjectiles = perfProjectiles
                perfWorstEnemies = perfEnemies
                perfWorstAllies = perfAllies
            }
            if ms > 34 { perfHitches += 1 }
            perfSampleAccum += rawDt
            if perfSampleAccum >= 0.25 {
                perfSampleAccum = 0
                refreshPerfCounts()
            }
        }
        var dt = rawDt
        // Pause/hitch guard: while the pause menu is up update() stops, so
        // the first frame after resume would see a seconds-long dt — snapping
        // the camera (rate = min(1, 6*dt) = 1) and teleporting the sim.
        // Clamp it so resume continues exactly where the frame froze.
        // (Unpausing also invalidates lastUpdate; see isPaused override.)
        if dt > 1.0 / 30 || dt < 0 { dt = 1.0 / 60 }
        lastUpdate = currentTime
        sceneTime += dt
        // Safety net: the battle owns the battlefield. Re-pin the layout
        // every frame so no other scene (menu / briefing diorama) can swap
        // the map out from under a running fight.
        Balance.active = Balance.layout(for: levelId)
        hero.step(dt: dt, now: currentTime)
        // Shield orb feed: the bubble tracks the live charge every frame.
        hero.shieldFrac = shieldMax > 0 ? max(0, shieldHP / shieldMax) : 0
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
        updateInterceptors(dt: dt)
        for kind in Array(summonCooldowns.keys) {
            summonCooldowns[kind] = max(0, (summonCooldowns[kind] ?? 0) - dt)
        }
        updateDrops(dt: dt)
        updateDroid(dt: dt)
        stepBomber(dt: dt)
        stepProjectiles(dt: dt)
        updateGraceBlink()
        updateShield(dt: dt)
        smoothCamera(dt: dt)
        updateParallax()
    }

    /// Death → wait → drop from above in front of the player base → land → grace.
    private func updateRespawn() {
        guard respawnAt >= 0, sceneTime >= respawnAt else { return }
        respawnAt = -1
        hero.respawn(at: CGPoint(x: Balance.playerBaseX + Balance.respawnOffsetX,
                                 y: Balance.groundY(at: Balance.playerBaseX + Balance.respawnOffsetX)
                                     + Balance.respawnDropHeight))
        applyHeroUpgrades(fullRestore: true)
        graceUntil = sceneTime + Balance.respawnGrace
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = hero.position
        world.addChild(puff)
        // The droid is reborn beside him: snap to the shoulder with a pop.
        if let droid {
            droid.position = CGPoint(x: hero.position.x - hero.facingX * Balance.droidFollowX,
                                     y: hero.position.y + Balance.droidHoverHeight)
            droid.isHidden = false
            droid.fireCooldown = 0.5
            let spark = ProjectileFactory.makeImpactPuff()
            spark.position = droid.position
            world.addChild(spark)
        }
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
            // Bomber targeting eats the touch: place the zone reticle,
            // release confirms the strike (moved drags the zone).
            if bomberTargeting {
                guard bomberTouch == nil else { continue }
                bomberTouch = touch
                moveBomberReticle(to: convertPoint(fromView: loc))
                return
            }
            aimTouch = touch
            fireCooldown = 0 // first tap fires instantly
            trackAim(touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if bomberTargeting, let bomberTouch, touches.contains(bomberTouch),
           let view {
            moveBomberReticle(to: convertPoint(fromView: bomberTouch.location(in: view)))
            return
        }
        guard let aimTouch else { return }
        if touches.contains(aimTouch) { trackAim(aimTouch) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if bomberTargeting, let bomberTouch, touches.contains(bomberTouch) {
            self.bomberTouch = nil
            confirmBomberStrike()
            return
        }
        releaseAim(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if bomberTargeting, let bomberTouch, touches.contains(bomberTouch) {
            self.bomberTouch = nil
            cancelBomberTargeting()
            return
        }
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
        // Bone-dry gun (mag 0 + reserve 0): hand a loaded gun over first.
        autoSwitchWhenDry()
        // This gun is mid-reload, or the mag is dry (reload kicks in via
        // updateReload): hold fire until rounds are back.
        guard reloadingWeapon != heroWeapon,
              mags[heroWeapon.rawValue] > 0 else { return }
        fireCooldown -= dt
        guard fireCooldown <= 0 else { return }
        fireCooldown = heroWeapon.cooldown
        fireBullet()
    }

    /// Auto-switch: when the active gun is bone-dry (mag 0 + reserve 0 —
    /// Blaster never qualifies), swaps to the next LOADED loadout gun in
    /// slot order with wrap. A swapped-in gun with an empty mag starts
    /// reloading on the spot. Returns false when nothing else is loaded
    /// (the desperation trickle feeds the guns instead).
    @discardableResult
    private func autoSwitchWhenDry() -> Bool {
        let i = heroWeapon.rawValue
        guard !heroWeapon.hasInfiniteAmmo,
              mags[i] == 0, reserves[i] == 0 else { return false }
        let slotted = LoadoutStore.loadout
        guard slotted.count > 1,
              let idx = slotted.firstIndex(of: heroWeapon) else { return false }
        for step in 1...slotted.count {
            let gun = slotted[(idx + step) % slotted.count]
            if gun.hasInfiniteAmmo || mags[gun.rawValue] > 0 || reserves[gun.rawValue] > 0 {
                heroWeapon = gun
                hero?.setWeapon(gun)
                fireCooldown = 0
                if mags[gun.rawValue] == 0 { startReload(gun: gun) }
                SoundEngine.shared.weaponSwitch()
                return true
            }
        }
        return false
    }

    /// Reload sim: finishes the active reload, auto-reloads the dry active
    /// gun, and trickles reserve rounds to fully-starved guns so no gun can
    /// stay bricked forever (desperation mode, capped low).
    private func updateReload(dt: TimeInterval) {
        // Finish the active reload. Infinite-reserve guns refill to full
        // without spending stock; everyone else draws from the reserve.
        if let gun = reloadingWeapon, sceneTime >= reloadEndsAt {
            let need = gun.magSize - mags[gun.rawValue]
            let take = gun.hasInfiniteAmmo ? need : min(need, reserves[gun.rawValue])
            mags[gun.rawValue] += take
            if !gun.hasInfiniteAmmo {
                reserves[gun.rawValue] -= take
            }
            reloadingWeapon = nil
            reloadMidAt = -1
            SoundEngine.shared.reloadDone()
        } else if reloadingWeapon != nil, reloadMidAt >= 0, sceneTime >= reloadMidAt {
            // Halfway through: the fresh mag seats with a clack, so long
            // reloads read audibly from rack-out to seating thump.
            reloadMidAt = -1
            SoundEngine.shared.reloadTick()
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
        let gun = heroWeapon
        mags[gun.rawValue] -= 1 // one trigger pull = one round
        SoundEngine.shared.heroShot(gun, at: hero.position.x)
        // Recoil: the hero's rifle + body absorb the shot (blast guns shove).
        hero.kick(gun.blastRadius > 0 ? 0.9 : 0.45)
        let muzzle = muzzlePosition(for: aimDir)
        let baseAngle = atan2(aimDir.dy, aimDir.dx)
        let pellets = gun.pelletCount
        for k in 0..<pellets {
            // Symmetric fan: e.g. 3 pellets at -spread, 0, +spread.
            let offset = (CGFloat(k) - CGFloat(pellets - 1) / 2) * gun.spread
            let a = baseAngle + offset
            let dir = CGVector(dx: cos(a), dy: sin(a))
            // Grenades arc from the aim line; rockets/weaves leave straight.
            var launchDir = dir
            var launchPos = muzzle
            if gun.isGrenade {
                let poor = CGVector(dx: dir.dx, dy: max(dir.dy, 0.25))
                let len = max(0.01, hypot(poor.dx, poor.dy))
                launchDir = CGVector(dx: poor.dx / len, dy: poor.dy / len)
                launchPos = CGPoint(x: muzzle.x, y: max(muzzle.y, Balance.groundTopY + 20))
            }
            let node = ProjectileFactory.heroProjectile(gun)
            node.position = launchPos
            node.zRotation = atan2(launchDir.dy, launchDir.dx)
            world.addChild(node)
            var shell = Projectile(node: node, dir: launchDir, life: gun.bulletLife,
                                   speed: gun.launchSpeed,
                                   damage: gun.damage + HeroUpgrades.damageBonus(heroId: heroId),
                                   team: .neutral)
            shell.thrust = gun.thrustAccel
            shell.gravity = gun.gravityPull
            shell.blast = gun.blastRadius
            shell.fuse = gun.fuseTime
            shell.bounces = gun.bounceCount
            shell.weaveAmp = gun.weaveAmp
            shell.weaveFreq = gun.weaveFreq
            shell.weavePhase = Double(k) * 1.3 // fan shards snake out of phase
            shell.trail = gun.trail
            projectiles.append(shell)
        }
        shotsFired += 1
        let flash = ProjectileFactory.makeMuzzleFlash()
        if gun.blastRadius > 0 {
            flash.setScale(1 + gun.blastRadius / 100)
        }
        flash.position = muzzle
        world.addChild(flash)
    }

    // MARK: - Tower combat: proximity targeting + firing toward enemies
    /// Each alive tower fires a 3-bolt fan at its nearest enemy within
    /// Balance.towerRange, matching the main HQ's spread. Enemy tower
    /// targets the hero + player tower; player tower targets the enemy
    /// tower (friendly fire off vs own hero). Towers aim muzzle -> target
    /// center so shots arc flat toward each other.
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
            for d in interceptors where d.alive {
                let dist = hypot(d.position.x - tower.node.position.x,
                                d.position.y - muzzleY)
                if dist <= bestDist {
                    bestDist = dist
                    best = d.position
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

    /// Tower volley: one bolt on the early levels, a 3-bolt fan from Level
    /// 10 on (per-level `towerFanCount`). Bolt team matches the firing
    /// tower so hits land on the right side.
    /// Mk-II turrets (Level 18+ both teams) fire a 3-missile volley instead;
    /// Mk-III siege turrets (Level 31+ both teams) fire a 4-missile volley:
    /// each missile rides a slight angle fan and weaves. The player's
    /// volley carries a much lighter payload than the enemy refit's.
    private func fireTowerBolt(from tower: Tower, to target: CGPoint) {
        let muzzle = towerMuzzle(for: tower)
        var baseDir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(baseDir.dx, baseDir.dy))
        baseDir = CGVector(dx: baseDir.dx / len, dy: baseDir.dy / len)
        let baseAngle = atan2(baseDir.dy, baseDir.dx)
        if levelId != Balance.playgroundLevelId, levelId >= Balance.upgradedTowerLevel {
            SoundEngine.shared.missileLaunch(at: muzzle.x)
            let damage = tower.team == .enemy
                ? Balance.towerDamage
                : Balance.playerTowerMissileDamage
            let missileCount = Balance.towerMissileCount(forLevel: levelId)
            for k in 0..<missileCount {
                // Common launch line, fanned symmetrically around center.
                let a = baseAngle
                    + (CGFloat(k) - CGFloat(missileCount - 1) / 2)
                    * Balance.towerMissileSpread
                let dir = CGVector(dx: cos(a), dy: sin(a))
                let missile = ProjectileFactory.makeMissile(team: tower.team)
                missile.position = muzzle
                missile.zRotation = a
                world.addChild(missile)
                projectiles.append(Projectile(node: missile, dir: dir,
                                              life: Balance.towerMissileLife,
                                              speed: Balance.towerMissileSpeed,
                                              damage: damage,
                                              team: tower.team,
                                              weaveAmp: Balance.towerMissileWeaveAmp,
                                              weaveFreq: Balance.towerMissileWeaveFreq,
                                              weavePhase: Double(k) * 1.3,
                                              weaveSteers: true,
                                              contactBlast: 34,
                                              trail: .smoke))
            }
            let flash = ProjectileFactory.makeMuzzleFlash()
            flash.setScale(Balance.isMegaTower(levelId: levelId) ? 1.35 : 1.1)
            flash.position = muzzle
            world.addChild(flash)
            return
        }
        SoundEngine.shared.towerFire(at: muzzle.x)
        let count = Balance.towerFanCount
        for k in 0..<count {
            // Symmetric fan: e.g. 3 bolts at -spread, 0, +spread.
            let offset = (CGFloat(k) - CGFloat(count - 1) / 2) * Balance.baseFanSpread
            let a = baseAngle + offset
            let dir = CGVector(dx: cos(a), dy: sin(a))
            let bolt = ProjectileFactory.makeTowerBolt(team: tower.team)
            bolt.position = muzzle
            bolt.zRotation = a
            world.addChild(bolt)
            projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.towerBulletLife,
                                          speed: Balance.towerBulletSpeed, damage: Balance.towerDamage,
                                          team: tower.team))
        }
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
            // Summon marchers toward the player base, capped. Levels with a
            // doubleChance sometimes pop a PAIR out of the gate together.
            // Priority order on a shared summon number: Heli Gunship (heliEvery),
            // then the Vesper herald (vesperEvery, Level 34+),
            // then the Phoenix strike-fighter (phoenixEvery, Level 30+),
            // then Saucer gun-drones (saucerEvery, Level 24+), then Brute
            // (bruteEvery), Reaver (reaverEvery), Mech (mechEvery,
            // only while none is alive), Skitter (skitterEvery), Jet (jetEvery).
            // The Immortal (immortalEvery, Level 19+) is a singleton like
            // the mech: it marches only while the last one stays dead.
            bases[i].summonTimer -= dt
            if bases[i].summonTimer <= 0 {
                bases[i].summonTimer = Balance.summonInterval
                // DEV playground: exactly one spawn of the unit under
                // inspection per tick — no pairs, no elite cadence.
                if Balance.playgroundMode {
                    guard enemies.count < Balance.maxEnemies else { continue }
                    summonEnemy(from: bases[i], slot: 0, kind: Balance.playgroundUnit)
                    continue
                }
                var batch = 1
                if Double.random(in: 0..<1) < Balance.summonDoubleChance { batch = 2 }
                var slot = 0
                while batch > 0, enemies.count < Balance.maxEnemies {
                    summonCount += 1
                    let kind: EnemyKind
                    if Balance.truckEvery > 0, summonCount % Balance.truckEvery == 0 {
                        // Missile-truck wave: the launcher roll out instead
                        // of the normal unit.
                        kind = .missileTruck
                    } else if Balance.immortalEvery > 0,
                              summonCount % Balance.immortalEvery == 0,
                              !enemies.contains(where: { $0.alive && $0.kind == .immortal }) {
                        // Immortal wave: the phase walker rolls out — but
                        // only ever one at a time.
                        kind = .immortal
                    } else if Balance.heliEvery > 0, summonCount % Balance.heliEvery == 0 {
                        kind = .heli
                    } else if Balance.vesperEvery > 0, summonCount % Balance.vesperEvery == 0 {
                        // Vesper wave: the violet herald drifts in — checked
                        // ahead of the phoenix cadence so the debut cadence
                        // is never swallowed by it.
                        kind = .vesper
                    } else if Balance.phoenixEvery > 0, summonCount % Balance.phoenixEvery == 0 {
                        // Phoenix wave: the red interceptor dives in — checked
                        // ahead of the saucer cadence so the debut cadence is
                        // never swallowed by it.
                        kind = .phoenix
                    } else if Balance.saucerEvery > 0, summonCount % Balance.saucerEvery == 0 {
                        kind = .saucer
                    } else if Balance.bruteEvery > 0, summonCount % Balance.bruteEvery == 0 {
                        kind = .brute
                    } else if Balance.reaverEvery > 0, summonCount % Balance.reaverEvery == 0 {
                        kind = .reaver
                    } else if Balance.mechEvery > 0, summonCount % Balance.mechEvery == 0,
                              !enemies.contains(where: { $0.alive && $0.kind == .mech }) {
                        kind = .mech
                    } else if Balance.skitterEvery > 0, summonCount % Balance.skitterEvery == 0 {
                        kind = .skitter
                    } else if Balance.jetEvery > 0, summonCount % Balance.jetEvery == 0 {
                        kind = .jet
                    } else {
                        kind = .raider
                    }
                    summonEnemy(from: bases[i], slot: slot, kind: kind)
                    slot += 1
                    // Extra missile trucks (when a level rolls out more than
                    // one): the next one rolls out of the gate a beat
                    // later, never side-by-side.
                    if kind == .missileTruck, Balance.truckCount > 1 {
                        let home = bases[i]
                        for extra in 0..<(Balance.truckCount - 1) {
                            let offset = slot + extra
                            DispatchQueue.main.asyncAfter(deadline: .now()
                                + 0.7 * Double(extra + 1)) { [weak self] in
                                guard let self, self.enemies.count < Balance.maxEnemies else { return }
                                self.summonEnemy(from: home, slot: offset, kind: .missileTruck)
                            }
                        }
                        slot += Balance.truckCount - 1
                    }
                    // Rank-and-file raiders march in twos: double the basic
                    // marcher pressure without changing elite cadence.
                    if kind == .raider, enemies.count < Balance.maxEnemies {
                        summonEnemy(from: bases[i], slot: slot, kind: .raider)
                        slot += 1
                    }
                    // Mech pairs: the partner follows the first walker out
                    // of the gate after a short delay, never side-by-side.
                    if kind == .mech, Balance.mechPairSize > 1 {
                        let home = bases[i]
                        for extra in 0..<(Balance.mechPairSize - 1) {
                            let offset = slot + extra
                            DispatchQueue.main.asyncAfter(deadline: .now()
                                + Balance.mechPairDelay * Double(extra + 1)) { [weak self] in
                                guard let self, self.enemies.count < Balance.maxEnemies else { return }
                                self.summonEnemy(from: home, slot: offset, kind: .mech)
                            }
                        }
                        slot += Balance.mechPairSize - 1
                    }
                    // Jets fly in as a pair: the second follows the first
                    // out of the gate one beat later.
                    if kind == .jet {
                        let home = bases[i]
                        for extra in 0..<(Balance.jetPairSize - 1) {
                            let offset = slot + extra + 1
                            DispatchQueue.main.asyncAfter(deadline: .now()
                                + 0.45 * Double(extra + 1)) { [weak self] in
                                guard let self, self.enemies.count < Balance.maxEnemies else { return }
                                self.summonEnemy(from: home, slot: offset, kind: .jet)
                            }
                        }
                        slot += Balance.jetPairSize - 1
                    }
                    // Level-specific bonus: an extra Brute marches out on
                    // top of this wave's normal batch.
                    if Balance.extraBruteSummons.contains(summonCount),
                       enemies.count < Balance.maxEnemies {
                        summonEnemy(from: bases[i], slot: slot, kind: .brute)
                        slot += 1
                    }
                    // Level-specific bonus: an extra Mech walker rolls out
                    // on top of this wave's normal batch.
                    if Balance.extraMechSummons.contains(summonCount),
                       enemies.count < Balance.maxEnemies {
                        summonEnemy(from: bases[i], slot: slot, kind: .mech)
                        slot += 1
                    }
                    // Level-specific bonus: an extra Gnasher crawls out on
                    // top of this wave's normal batch (Pale Abyss, L27).
                    if Balance.extraGnasherSummons.contains(summonCount),
                       enemies.count < Balance.maxEnemies {
                        summonEnemy(from: bases[i], slot: slot, kind: .gnasher)
                        slot += 1
                    }
                    batch -= 1
                }
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
        for d in interceptors where d.alive {
            let dist = hypot(d.position.x - base.node.position.x, d.position.y - muzzleY)
            if dist < bestDist {
                bestDist = dist
                best = d.position
            }
        }
        return best
    }

    /// 3 blasts from the same muzzle, spread out around the target direction.
    /// Bolt team matches the firing HQ so hits land on the right side.
    /// Mk-II HQs (Level 20+ both teams) fire a 4-missile volley instead —
    /// except the Level 35 finale enemy HQ, which fires a 5-missile salvo
    /// from its core-fortress battery. Each missile rides a slight angle
    /// fan and weaves, like the Level 18 Mk-II tower refit.
    private func fireBaseFan(from base: Base, at target: CGPoint) {
        let muzzle = baseMuzzle(for: base)
        var baseDir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(baseDir.dx, baseDir.dy))
        baseDir = CGVector(dx: baseDir.dx / len, dy: baseDir.dy / len)
        let baseAngle = atan2(baseDir.dy, baseDir.dx)
        if levelId != Balance.playgroundLevelId, levelId >= Balance.upgradedBaseLevel {
            SoundEngine.shared.missileLaunch(at: muzzle.x)
            let missileCount = Balance.baseMissileCount(forLevel: levelId, team: base.team)
            for k in 0..<missileCount {
                let a = baseAngle
                    + (CGFloat(k) - CGFloat(missileCount - 1) / 2)
                    * Balance.baseMissileSpread
                let dir = CGVector(dx: cos(a), dy: sin(a))
                let missile = ProjectileFactory.makeMissile(team: base.team)
                missile.position = muzzle
                missile.zRotation = a
                world.addChild(missile)
                projectiles.append(Projectile(node: missile, dir: dir,
                                              life: Balance.baseMissileLife,
                                              speed: Balance.baseMissileSpeed,
                                              damage: Balance.baseBoltDamage,
                                              team: base.team,
                                              weaveAmp: Balance.baseMissileWeaveAmp,
                                              weaveFreq: Balance.baseMissileWeaveFreq,
                                              weavePhase: Double(k) * 1.2,
                                              weaveSteers: true,
                                              contactBlast: 34,
                                              trail: .smoke))
            }
            let flash = ProjectileFactory.makeMuzzleFlash()
            flash.setScale(Balance.isFinaleBase(levelId: levelId, team: base.team) ? 1.6 : 1.2)
            flash.position = muzzle
            world.addChild(flash)
            base.node.fireFlash()
            return
        }
        SoundEngine.shared.baseFire(at: muzzle.x)
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

    /// One marcher out of the enemy gate. Batch slots stagger the drop so
    /// pairs don't spawn inside each other (slot 0 = the classic spot, so
    /// single-spawn levels are pixel-identical to before).
    private func summonEnemy(from base: Base, slot: Int = 0, kind: EnemyKind = .raider) {
        let e = EnemyNode(kind: kind)
        let sx = base.node.position.x - 120 - CGFloat(slot) * 55
        // Flyers leave the gate already at their cruise altitude.
        let restY = kind.isFlying
            ? Balance.groundY(at: sx) + kind.flightHeight
            : Balance.groundY(at: sx) + e.size.height / 2
        e.position = CGPoint(x: sx, y: restY)
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
    /// Rest height for a marcher: deck level for walkers, per-kind cruise
    /// altitude (+ dodge-juke offset + dive offset + hover sway) for flyers.
    private func enemyRestY(_ e: EnemyNode) -> CGFloat {
        let deck = Balance.groundY(at: e.position.x)
        guard e.kind.isFlying else { return deck + e.size.height / 2 }
        let sway = 4 * sin(sceneTime * 2.5 + e.position.x * 0.05)
        return deck + e.kind.flightHeight + e.jukeOffset + e.diveOffset + sway
    }

    /// Jet dodge AI: counts incoming player/hero shots; every 5th bullet
    /// headed its way triggers a vertical juke around the bullet lane
    /// (up when the shot runs low, down when it runs high), then relaxes
    /// back to cruise. One trigger per cooldown so a single volley can't
    /// chain-count.
    private func updateJetDodge(_ e: EnemyNode, dt: TimeInterval) {
        e.jukeCooldown = max(0, e.jukeCooldown - dt)        // Thruster exhaust puffing while flying.
        e.jetExhaustTimer -= dt
        if e.jetExhaustTimer <= 0 {
            e.jetExhaustTimer = 0.09
            let exhaust = ProjectileFactory.makeJetExhaust()
            exhaust.position = CGPoint(x: e.position.x - e.facing * e.size.width / 2,
                                       y: e.position.y - 18)
            world.addChild(exhaust)
        }
        if e.jukeCooldown <= 0 {
            for p in projectiles where p.team == .player || p.team == .neutral {
                let dx = e.position.x - p.node.position.x
                let dy = e.position.y - p.node.position.y
                let dist = hypot(dx, dy)
                guard dist < 340, dist > 1 else { continue }
                let speed = max(1, hypot(p.dir.dx, p.dir.dy))
                let dot = (p.dir.dx * dx + p.dir.dy * dy) / (speed * dist)
                guard dot > 0.85 else { continue } // actually headed at the jet
                e.incomingShots += 1
                e.jukeCooldown = Balance.jetJukeCooldown
                if e.incomingShots % 5 == 0 {
                    let away: CGFloat = p.node.position.y >= e.position.y ? -1 : 1
                    e.jukeTarget = away * Balance.jetJukeHeight
                }
                break
            }
        }
        // Chase the dodge peak, then relax back to cruise altitude.
        let k = min(1, 10 * CGFloat(dt))
        e.jukeOffset += (e.jukeTarget - e.jukeOffset) * k
        if e.jukeTarget != 0, abs(e.jukeTarget - e.jukeOffset) < 5 {
            e.jukeTarget = 0
        }
    }

    /// Gunship rotor wash: retriggers the synthesized blade-slap loop while
    /// the helicopter is on the field (positional, so it fades with range).
    private func updateHeliFlight(_ e: EnemyNode, dt: TimeInterval) {
        e.rotorSoundTimer -= dt
        if e.rotorSoundTimer <= 0 {
            e.rotorSoundTimer = 2.25
            SoundEngine.shared.heliRotor(at: e.position.x)
        }
    }

    private func updateEnemies(dt: TimeInterval) {
        let playerBase = bases.first(where: { $0.team == .player })
        for e in enemies {
            guard e.alive else { continue }
            e.fireCooldown -= dt
            if e.kind == .jet {
                updateJetDodge(e, dt: dt)
            } else if e.kind.isHelicopter {
                updateHeliFlight(e, dt: dt)
            } else if e.kind == .saucer {
                updateSaucerFlight(e, dt: dt)
            } else if e.kind == .phoenix {
                updatePhoenixFlight(e, dt: dt)
            } else if e.kind == .vesper {
                updateVesperFlight(e, dt: dt)
            }

            // Target priority: closest exposed body in sight (hero or ally)
            // > player tower > player base. Marchers chew what's nearest
            // instead of walking past your army to reach you.
            var target: CGPoint? = nil
            var bestDist = e.sightRange
            if hero.alive, !heroProtected {
                let d = hypot(hero.position.x - e.position.x,
                              hero.position.y - e.position.y)
                if d < bestDist {
                    bestDist = d
                    target = hero.position
                }
            }
            for a in allies where a.alive {
                if e.kind.isMelee && a.kind.isFlying { continue }
                let d = hypot(a.position.x - e.position.x, a.position.y - e.position.y)
                if d < bestDist {
                    bestDist = d
                    target = a.position
                }
            }
            // Revrent interceptors: shootable flyers — melee skips them,
            // gunners treat them like any other ally in sight.
            for d in interceptors where d.alive {
                if e.kind.isMelee { continue }
                let dist = hypot(d.position.x - e.position.x, d.position.y - e.position.y)
                if dist < bestDist {
                    bestDist = dist
                    target = d.position
                }
            }
            if target == nil {
                if let tower = nearestTower(team: .player, toX: e.position.x) {
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
                    e.position.x = max(40, e.position.x - e.moveSpeed * CGFloat(dt))
                    e.animateMarch(dt: dt, advancing: true)
                    e.position.y = enemyRestY(e) + e.yBob
                    if !cameraSpan(margin: 80).contains(e.position.x)
                        || e.position.x <= 50 {
                        e.marchedOff = true
                        e.removeFromParent()
                    }
                    continue
                }
                e.animateMarch(dt: dt, advancing: false)
                e.position.y = enemyRestY(e)
                continue
            }

            let dist = hypot(aim.x - e.position.x, aim.y - e.position.y)
            e.face(aim.x - e.position.x)
            e.aimAt(CGVector(dx: aim.x - e.position.x, dy: aim.y - e.position.y))
            // Melee fighters range on the ground line (horizontal gap): their
            // tower/HQ aim points float 100pt up, and the diagonal would let
            // them push inside structures without ever swinging. Shooters
            // keep the true distance so their stop line stays put.
            let rangeDist = e.kind.isMelee ? abs(aim.x - e.position.x) : dist
            if rangeDist > e.shootRange {
                // Closing burst: once per life, when the opposing army is
                // close, the reaver kicks up dust and dashes the last stretch.
                if e.kind.isMelee, !e.burstUsed, dist < Balance.reaverBurstRange {
                    e.burstUsed = true
                    e.burstTimer = Balance.reaverBurstTime
                    let dust = ProjectileFactory.makeImpactPuff()
                    dust.position = e.position
                    dust.setScale(1.4)
                    world.addChild(dust)
                    SoundEngine.shared.enemyFire(at: e.position.x)
                }
                // Advance on the target (never past the lane edge).
                let dir: CGFloat = aim.x > e.position.x ? 1 : -1
                let pace = e.burstTimer > 0 ? e.moveSpeed * Balance.reaverBurstSpeed : e.moveSpeed
                e.burstTimer = max(0, e.burstTimer - dt)
                e.position.x = max(40, e.position.x + dir * pace * CGFloat(dt))
                e.animateMarch(dt: dt, advancing: true)
                // Heavy walkers kick up dust with every step.
                if e.kind.isMech || e.kind == .immortal {
                    e.footDustTimer -= dt
                    if e.footDustTimer <= 0 {
                        e.footDustTimer = 0.34
                        let dust = ProjectileFactory.makeFootfallDust()
                        dust.position = CGPoint(x: e.position.x - e.facing * 18,
                                               y: Balance.groundY(at: e.position.x) + 6)
                        world.addChild(dust)
                    }
                }
            } else {
                // In range: stop and shoot — or stop and chop for reavers.
                e.animateMarch(dt: dt, advancing: false)
                if e.fireCooldown <= 0 {
                    e.fireCooldown = e.fireInterval
                    if e.kind.isMelee {
                        e.swing()
                        SoundEngine.shared.enemyFire(at: e.position.x)
                        meleeStrike(from: e)
                    } else if e.kind.isMech {
                        fireMechBurst(from: e, to: aim)
                    } else if e.kind.isHelicopter {
                        fireHeliBurst(from: e, to: aim)
                    } else if e.kind == .saucer {
                        fireSaucerBurst(from: e, to: aim)
                    } else if e.kind == .phoenix {
                        firePhoenixBurst(from: e, to: aim)
                    } else if e.kind == .vesper {
                        fireVesperFan(from: e, to: aim)
                    } else if e.kind == .missileTruck {
                        fireMissile(from: e, to: aim)
                    } else if e.kind == .immortal {
                        fireImmortalShellRound(from: e, to: aim)
                    } else {
                        fireEnemyBolt(from: e, to: aim)
                    }
                }
            }
            e.position.y = enemyRestY(e) + e.yBob
        }
        // Sweep the dead (gold was already paid at kill time).
        enemies.removeAll { !$0.alive || $0.marchedOff }
    }

    /// Reaver axe chop: damages the closest player-side body in reach —
    /// hero or ally, whichever is nearer — else tower, else HQ.
    /// Heavy single-target damage with an impact burst on the victim.
    private func meleeStrike(from e: EnemyNode) {
        let dmg = e.meleeDamage
        let reach = e.shootRange + 30
        // Closest body in axe reach (ties go to the hero).
        var strikeHero = false
        var strikeAlly: AllyNode?
        var best = reach
        if hero.alive, !heroProtected {
            let d = hypot(hero.position.x - e.position.x,
                          hero.position.y - e.position.y)
            if d <= best {
                best = d
                strikeHero = true
            }
        }
        for a in allies where a.alive {
            let d = hypot(a.position.x - e.position.x, a.position.y - e.position.y)
            if d < best {
                best = d
                strikeHero = false
                strikeAlly = a
            }
        }
        if strikeHero {
            damageHero(amount: dmg)
            meleeImpact(at: hero.position)
            return
        }
        if let victim = strikeAlly {
            damageAlly(victim, amount: dmg)
            meleeImpact(at: victim.position)
            return
        }
        // Player tower in axe reach (towers are ~60pt half-width).
        if let tower = nearestTower(team: .player, toX: e.position.x),
           abs(tower.node.position.x - e.position.x) <= e.shootRange + 60,
           let idx = towers.firstIndex(where: { $0.node === tower.node }) {
            damageTower(at: idx, amount: dmg)
            meleeImpact(at: CGPoint(x: tower.node.position.x,
                                    y: Balance.groundTopY + 100))
            return
        }
        // Player HQ in axe reach (HQ is ~130pt half-width).
        if let base = bases.first(where: { $0.team == .player }), base.alive,
           abs(base.node.position.x - e.position.x) <= e.shootRange + 130,
           let idx = bases.firstIndex(where: { $0.node === base.node }) {
            damageBase(at: idx, amount: dmg)
            meleeImpact(at: CGPoint(x: base.node.position.x,
                                    y: Balance.groundTopY + 100))
        }
    }

    /// Axe-impact burst: oversized puff + hot flash on the victim.
    private func meleeImpact(at pos: CGPoint) {
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = pos
        puff.setScale(1.8)
        world.addChild(puff)
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.position = pos
        world.addChild(flash)
    }

    /// Missile Truck launcher round: a twin-tube salvo — two missiles
    /// leave the rail together, offset side to side, each flying a wavy
    /// line toward the target (the weave makes them weave hard to dodge).
    private func fireMissile(from e: EnemyNode, to target: CGPoint) {
        let muzzle = e.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.missileLaunch(at: muzzle.x)
        // Both rounds ride the same line, one either side of it, so the
        // pair reads as a twin launcher instead of a single shot.
        for side in [-1.0, 1.0] {
            let offset = CGFloat(side) * 6
            let shiftX = -dir.dy * offset
            let shiftY = dir.dx * offset
            let missile = ProjectileFactory.makeMissile()
            missile.position = CGPoint(x: muzzle.x + shiftX, y: muzzle.y + shiftY)
            missile.zRotation = atan2(dir.dy, dir.dx)
            world.addChild(missile)
            projectiles.append(Projectile(node: missile, dir: dir,
                                          life: Balance.missileTruckMissileLife,
                                          speed: Balance.missileTruckMissileSpeed,
                                          damage: e.boltDamage, team: .enemy,
                                          weaveAmp: Balance.missileTruckWeaveAmp,
                                          weaveFreq: Balance.missileTruckWeaveFreq,
                                          weavePhase: side > 0 ? 0.6 : 0,
                                          weaveSteers: true,
                                          contactBlast: 34,
                                          trail: .smoke))
        }
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(1.1)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Immortal cannon: a Bombard mortar shell fired flat and fast. Unlike
    /// the Bombard's lobbed round it flies dead straight, then blasts like
    /// a mortar on impact.
    private func fireImmortalShellRound(from e: EnemyNode, to target: CGPoint) {
        let muzzle = e.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.missileLaunch(at: muzzle.x)
        SoundEngine.shared.enemyFire(at: muzzle.x)
        let shell = ProjectileFactory.makeMortarBomb()
        shell.position = muzzle
        shell.zRotation = atan2(dir.dy, dir.dx)
        shell.setScale(1.05)
        world.addChild(shell)
        projectiles.append(Projectile(node: shell, dir: dir,
                                      life: Balance.immortalShellLife,
                                      speed: Balance.immortalShellSpeed,
                                      damage: e.boltDamage, team: .enemy,
                                      contactBlast: Balance.immortalShellBlast,
                                      trail: .smoke))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(1.4)
        flash.position = muzzle
        world.addChild(flash)
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
                                      speed: Balance.enemyBoltSpeed, damage: e.boltDamage,
                                      team: .enemy))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.7)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Mech machine-gun burst: the volley ramps 1 -> 2 -> 3 rounds, each
    /// round a hair after the last (gatling chatter). The mech keeps
    /// firing at the same spot while the burst plays out.
    private func fireMechBurst(from e: EnemyNode, to target: CGPoint) {
        let rounds = min(Balance.mechBurstMax, e.mechBurstStep + 1)
        e.mechBurstStep = (e.mechBurstStep + 1) % Balance.mechBurstMax
        for r in 0..<rounds {
            let delay = Double(r) * Balance.mechBurstGap
            if delay == 0 {
                fireMechRound(from: e, to: target)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, e.alive else { return }
                    self.fireMechRound(from: e, to: target)
                }
            }
        }
    }

    /// One gatling round: fat tracer + a hot muzzle flash.
    private func fireMechRound(from e: EnemyNode, to target: CGPoint) {
        let muzzle = e.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.enemyFire(at: muzzle.x)
        let bolt = ProjectileFactory.makeTowerBolt(team: .enemy)
        bolt.setScale(1.15)
        bolt.position = muzzle
        bolt.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(bolt)
        projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.enemyBoltLife,
                                      speed: Balance.mechBoltSpeed, damage: e.boltDamage,
                                      team: .enemy))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(1.2)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Heli Gunship machine-gun burst: a tight three-round chatter from
    /// the chin gun. Unlike the mech's ramping volley this is always
    /// three rounds, so each pass is a predictable burst to dodge.
    private func fireHeliBurst(from e: EnemyNode, to target: CGPoint) {
        for r in 0..<Balance.heliBurstCount {
            let delay = Double(r) * Balance.heliBurstGap
            if delay == 0 {
                fireHeliRound(from: e, to: target)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, e.alive else { return }
                    self.fireHeliRound(from: e, to: target)
                }
            }
        }
    }

    /// One gunship round: a slim high-velocity tracer + muzzle flash.
    private func fireHeliRound(from e: EnemyNode, to target: CGPoint) {
        let muzzle = e.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.enemyFire(at: muzzle.x)
        let bolt = ProjectileFactory.makeTowerBolt(team: .enemy)
        bolt.setScale(0.9)
        bolt.position = muzzle
        bolt.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(bolt)
        projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.enemyBoltLife,
                                      speed: Balance.heliBoltSpeed, damage: e.boltDamage,
                                      team: .enemy))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.8)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Saucer hover hum: retriggers the rotor loop while the heavy drone
    /// is on the field (positional, so it fades with range). Slower than
    /// the gunship — a low lumbering wash for a bigger airframe.
    private func updateSaucerFlight(_ e: EnemyNode, dt: TimeInterval) {
        e.rotorSoundTimer -= dt
        if e.rotorSoundTimer <= 0 {
            e.rotorSoundTimer = 2.9
            SoundEngine.shared.heliRotor(at: e.position.x)
        }
    }

    /// Saucer twin-blaster burst: two blue-plasma rounds from the belly
    /// guns. Holds high station like the gunship, so each volley is a
    /// predictable 2-round snap to dodge.
    private func fireSaucerBurst(from e: EnemyNode, to target: CGPoint) {
        for r in 0..<Balance.saucerBurstCount {
            let delay = Double(r) * Balance.saucerBurstGap
            if delay == 0 {
                fireSaucerRound(from: e, to: target)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, e.alive else { return }
                    self.fireSaucerRound(from: e, to: target)
                }
            }
        }
    }

    /// One saucer round: a blue-plasma orb + muzzle flash. Small splash
    /// on impact (see splashPlayer) so grouped troops feel the blast.
    private func fireSaucerRound(from e: EnemyNode, to target: CGPoint) {
        let muzzle = e.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.enemyFire(at: muzzle.x)
        let orb = ProjectileFactory.makeSaucerPlasma()
        orb.position = muzzle
        orb.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(orb)
        projectiles.append(Projectile(node: orb, dir: dir, life: Balance.enemyBoltLife,
                                      speed: Balance.saucerBoltSpeed, damage: e.boltDamage,
                                      team: .enemy,
                                      contactBlast: Balance.saucerBlast))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.9)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Phoenix wing-wash: retriggers the rotor loop while the red
    /// interceptor is on the field (positional, so it fades with range).
    /// Quicker than the saucer's lumbering wash — a darting buzz for a
    /// smaller, faster airframe.
    private func updatePhoenixFlight(_ e: EnemyNode, dt: TimeInterval) {
        e.rotorSoundTimer -= dt
        if e.rotorSoundTimer <= 0 {
            e.rotorSoundTimer = 2.1
            SoundEngine.shared.heliRotor(at: e.position.x)
        }
    }

    /// Phoenix graviton burst: three ember-orange plasma darts from the
    /// prow emitter. A tight 3-round snap to dodge — the fastest hostile
    /// volley yet.
    private func firePhoenixBurst(from e: EnemyNode, to target: CGPoint) {
        for r in 0..<Balance.phoenixBurstCount {
            let delay = Double(r) * Balance.phoenixBurstGap
            if delay == 0 {
                firePhoenixRound(from: e, to: target)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, e.alive else { return }
                    self.firePhoenixRound(from: e, to: target)
                }
            }
        }
    }

    /// One phoenix dart: a slim ember-orange plasma round + muzzle flash.
    /// Small splash on impact (see splashPlayer) so grouped troops feel it.
    private func firePhoenixRound(from e: EnemyNode, to target: CGPoint) {
        let muzzle = e.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.enemyFire(at: muzzle.x)
        let dart = ProjectileFactory.makePhoenixPlasma()
        dart.position = muzzle
        dart.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(dart)
        projectiles.append(Projectile(node: dart, dir: dir, life: Balance.enemyBoltLife,
                                      speed: Balance.phoenixBoltSpeed, damage: e.boltDamage,
                                      team: .enemy,
                                      contactBlast: Balance.phoenixBlast))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.9)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Vesper wing-wash: retriggers the rotor loop while the violet
    /// herald is on the field (positional, so it fades with range).
    /// Slower than the phoenix's darting buzz — a deep looming hum for
    /// the biggest, slowest airframe.
    private func updateVesperFlight(_ e: EnemyNode, dt: TimeInterval) {
        e.rotorSoundTimer -= dt
        if e.rotorSoundTimer <= 0 {
            e.rotorSoundTimer = 3.2
            SoundEngine.shared.heliRotor(at: e.position.x)
        }
    }

    /// Vesper void fan: three violet void-shards from the keel caster in a
    /// small spread — the only hostile volley that sprays instead of
    /// snapping straight. Sidestep one shard and the next still tracks the
    /// lane, so the fan punishes clumped pushes.
    private func fireVesperFan(from e: EnemyNode, to target: CGPoint) {
        for r in 0..<Balance.vesperBurstCount {
            let delay = Double(r) * Balance.vesperBurstGap
            // Fan offset per shard: centered on the aim (e.g. 3 shards at
            // -spread, 0, +spread), so the volley opens downrange.
            let fan = (CGFloat(r) - CGFloat(Balance.vesperBurstCount - 1) / 2)
                * Balance.vesperFanSpread
            if delay == 0 {
                fireVesperShard(from: e, to: target, fan: fan, phase: Double(r) * 1.1)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, e.alive else { return }
                    self.fireVesperShard(from: e, to: target, fan: fan, phase: Double(r) * 1.1)
                }
            }
        }
    }

    /// One vesper shard: a weaving violet void-splinter + muzzle flash.
    /// Weaves laterally in flight and splashes on impact (see
    /// splashPlayer) so grouped troops feel the fan.
    private func fireVesperShard(from e: EnemyNode, to target: CGPoint,
                                 fan: CGFloat, phase: Double) {
        let muzzle = e.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        let baseAngle = atan2(dir.dy, dir.dx) + fan
        let fanned = CGVector(dx: cos(baseAngle), dy: sin(baseAngle))
        SoundEngine.shared.enemyFire(at: muzzle.x)
        let shard = ProjectileFactory.makeVesperShard()
        shard.position = muzzle
        shard.zRotation = baseAngle
        world.addChild(shard)
        projectiles.append(Projectile(node: shard, dir: fanned, life: Balance.enemyBoltLife,
                                      speed: Balance.vesperBoltSpeed, damage: e.boltDamage,
                                      team: .enemy,
                                      weaveAmp: Balance.vesperWeaveAmp,
                                      weaveFreq: Balance.vesperWeaveFreq,
                                      weavePhase: phase,
                                      weaveSteers: true,
                                      contactBlast: Balance.vesperBlast,
                                      blastFX: .vesper))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.9)
        flash.position = muzzle
        world.addChild(flash)
    }

    // MARK: - Player army: summon + march toward the enemy base
    /// Called by the SwiftUI cards. Returns false when broke, capped,
    /// or the unit isn't fielded on this level yet (Ranger = Level 2+,
    /// Heavy = Level 3+, Truck = Level 6+). Refusal reasons surface in
    /// the cards themselves (FULL / RECHARGE / NO GOLD / HQ DOWN chips).
    @discardableResult
    func summonAlly(kind: ArmyKind) -> Bool {
        guard ArmyKind.isUnlocked(kind, levelId: levelId),
              money >= kind.cost, allies.count < Balance.maxAllies,
              (summonCooldowns[kind] ?? 0) <= 0 else { return false }
        guard let homeBase = bases.first(where: { $0.team == .player }),
              homeBase.alive else { return false }
        money -= kind.cost
        summonCooldowns[kind] = kind.cooldown
        let a = AllyNode(kind: kind)
        // Stagger spawn positions so stacked summons don't overlap. Six
        // slots (no army cap) so a big deployment spreads out of the gate.
        let offset = CGFloat(allies.count % 6) * 50
        let ax = Balance.playerBaseX + 120 + offset
        let restY = kind.isFlying
            ? Balance.groundY(at: ax) + kind.flightHeight
            : Balance.groundY(at: ax) + a.size.height / 2
        a.position = CGPoint(x: ax, y: restY)
        world.addChild(a)
        allies.append(a)
        if kind == .revrent {
            spawnRevrentInterceptors(for: a)
        }
        homeBase.node.spawnPulse()
        SoundEngine.shared.summon(at: a.position.x)
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = a.position
        world.addChild(puff)
        return true
    }

    /// Rest height for a player unit: deck level for ground units, cruise
    /// altitude (+ gentle hover sway) for flying army units.
    private func allyRestY(_ a: AllyNode) -> CGFloat {
        let deck = Balance.groundY(at: a.position.x)
        guard a.kind.isFlying else { return deck + a.size.height / 2 }
        let sway = 4 * sin(sceneTime * 2.5 + a.position.x * 0.05)
        return deck + a.kind.flightHeight + sway
    }

    /// Friendly gunship rotor wash: retriggers the positional blade-slap loop.
    private func updateAllyHeliFlight(_ a: AllyNode, dt: TimeInterval) {
        a.rotorSoundTimer -= dt
        if a.rotorSoundTimer <= 0 {
            a.rotorSoundTimer = 2.25
            SoundEngine.shared.heliRotor(at: a.position.x)
        }
    }

    private func updateAllies(dt: TimeInterval) {        let enemyBase = bases.first(where: { $0.team == .enemy })
        for a in allies {
            guard a.alive else { continue }
            a.fireCooldown -= dt
            if a.kind == .gunship || a.kind == .tempest || a.kind == .revrent {
                updateAllyHeliFlight(a, dt: dt)
            }

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
            // Revrent screen management runs every frame: the droids fly
            // out once the carrier itself is in range, and dock back the
            // moment no enemy is in sight anymore.
            if a.kind == .revrent {
                let inRange: Bool = {
                    guard let t = target else { return false }
                    return hypot(t.x - a.position.x, t.y - a.position.y) <= a.kind.shootRange
                }()
                updateRevrentCarrier(a, dt: dt, hasTarget: target != nil, inRange: inRange)
            }
            guard let aim = target else {
                a.aimAt(nil)
                // A Tempest with nothing to shoot at drops its spin-up.
                if a.kind == .tempest {
                    clearTempestCharge(a)
                }
                // ...unless the enemy HQ is rubble: victory march past it
                // until out of the camera view, then leave the field.
                if enemyBase?.alive == false {
                    a.face(1)
                    a.position.x = min(Balance.levelWidth - 40,
                                       a.position.x + a.kind.speed * CGFloat(dt))
                    a.animateMarch(dt: dt, advancing: true)
                    truckDust(a, dt: dt)
                    a.position.y = allyRestY(a) + a.yBob
                    if !cameraSpan(margin: 80).contains(a.position.x)
                        || a.position.x >= Balance.levelWidth - 50 {
                        a.marchedOff = true
                        a.removeFromParent()
                        if a.kind == .revrent {
                            retireInterceptors(of: a)
                        }
                    }
                    continue
                }
                a.animateMarch(dt: dt, advancing: false)
                a.position.y = allyRestY(a)
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
                // Marching drops a half-spun charge — the Tempest only
                // spins up while holding station in range.
                if a.kind == .tempest {
                    clearTempestCharge(a)
                }
                truckDust(a, dt: dt)
            } else {
                a.animateMarch(dt: dt, advancing: false)
                if a.kind == .revrent {
                    // The hull holds station — its interceptor screen does
                    // the shooting (see updateInterceptors).
                } else if a.kind == .tempest {
                    updateTempestCharge(a, dt: dt, aim: aim)
                } else if a.fireCooldown <= 0 {
                    a.fireCooldown = a.kind.fireCooldown
                    if a.kind == .bombard {
                        fireAllyBomb(from: a, to: aim)
                    } else if a.kind == .tank {
                        fireAllyTankMissile(from: a, to: aim)
                    } else if a.kind == .storm {
                        fireAllyStormVolley(from: a, to: aim)
                    } else if a.kind == .gunship {
                        fireAllyGunshipBurst(from: a, to: aim)
                    } else {
                        fireAllyBolt(from: a, to: aim)
                        if a.kind == .truck {
                            // 2-round burst: the second shell follows right behind.
                            a.run(.sequence([.wait(forDuration: 0.12), .run { [weak self, weak a] in
                                guard let self, let a, a.alive else { return }
                                self.fireAllyBolt(from: a, to: aim)
                            }]))
                        }
                    }
                }
            }
            a.position.y = allyRestY(a) + a.yBob
        }
        allies.removeAll { !$0.alive || $0.marchedOff }
    }

    /// Wheeled vehicles kick up dust behind the rear wheel while rolling.
    private func truckDust(_ a: AllyNode, dt: TimeInterval) {
        guard a.kind == .truck || a.kind == .bombard || a.kind == .tank || a.kind == .storm else { return }
        a.dustTimer -= dt
        guard a.dustTimer <= 0 else { return }
        a.dustTimer = 0.22
        let dust = ProjectileFactory.makeDustPuff()
        let dx = a.position.x - a.facing * (a.size.width / 2 + 6)
        dust.position = CGPoint(x: dx, y: Balance.groundY(at: dx) + 8)
        world.addChild(dust)
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

    /// Lobbed mortar shell: solves a gravity arc that lands on the target,
    /// then detonates with splash via Projectile.blast. One shell per shot.
    private func fireAllyBomb(from a: AllyNode, to target: CGPoint) {
        let muzzle = a.muzzle()
        let dx = target.x - muzzle.x
        let dy = target.y - muzzle.y
        let g = Balance.bombardGravity
        // Longer shots stay airborne longer; short shots still pop up into
        // a readable arc instead of skimming the deck.
        let flight = min(1.9, max(0.65, abs(dx) / 430))
        let vx = dx / flight
        let vy = (dy + 0.5 * g * flight * flight) / flight
        let speed = max(1, hypot(vx, vy))
        let dir = CGVector(dx: vx / speed, dy: vy / speed)

        SoundEngine.shared.allyFire(at: muzzle.x)
        let bomb = ProjectileFactory.makeMortarBomb()
        bomb.position = muzzle
        bomb.zRotation = atan2(dir.dy, dir.dx)
        bomb.setScale(1.05)
        world.addChild(bomb)

        var shell = Projectile(node: bomb, dir: dir,
                               life: TimeInterval(flight) + 1.0,
                               speed: speed,
                               damage: a.kind.damage,
                               team: .player)
        shell.gravity = g
        shell.blast = Balance.bombardBlast
        shell.fuse = TimeInterval(flight) + 0.15
        shell.trail = .smoke
        projectiles.append(shell)

        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(1.15)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Tank missile: one trim-to-line round that flies DEAD STRAIGHT out
    /// of the turret — no gravity arc (the Bombard's lob) and no weave
    /// (the enemy launcher's snake). Detonates on contact.
    private func fireAllyTankMissile(from a: AllyNode, to target: CGPoint) {
        let muzzle = a.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.missileLaunch(at: muzzle.x)
        let missile = ProjectileFactory.makeMissile()
        missile.setScale(0.9)
        missile.position = muzzle
        missile.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(missile)
        projectiles.append(Projectile(node: missile, dir: dir,
                                      life: Balance.tankMissileLife,
                                      speed: Balance.tankMissileSpeed,
                                      damage: a.kind.damage,
                                      team: .player,
                                      contactBlast: Balance.tankMissileBlast,
                                      trail: .smoke))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(1.3)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Storm pod volley: 4 smaller missiles out of the battery in a tight
    /// angle fan, each snaking on its own weave phase with a small splash.
    /// Player-team so they hurt marchers + enemy structures.
    private func fireAllyStormVolley(from a: AllyNode, to target: CGPoint) {
        let muzzle = a.muzzle()
        let baseAngle = atan2(target.y - muzzle.y, target.x - muzzle.x)
        SoundEngine.shared.missileLaunch(at: muzzle.x)
        for k in 0..<Balance.stormMissileCount {
            let spread = (CGFloat(k) - CGFloat(Balance.stormMissileCount - 1) / 2)
                * Balance.stormMissileSpread
            let dir = CGVector(dx: cos(baseAngle + spread),
                               dy: sin(baseAngle + spread))
            let missile = ProjectileFactory.makeMissile(team: .player)
            missile.setScale(0.75)
            missile.position = muzzle
            missile.zRotation = baseAngle + spread
            world.addChild(missile)
            projectiles.append(Projectile(node: missile, dir: dir,
                                          life: Balance.stormMissileLife,
                                          speed: Balance.stormMissileSpeed,
                                          damage: a.kind.damage,
                                          team: .player,
                                          weaveAmp: Balance.stormMissileWeaveAmp,
                                          weaveFreq: Balance.stormMissileWeaveFreq,
                                          weavePhase: Double(k) * 1.7,
                                          weaveSteers: true,
                                          contactBlast: Balance.stormMissileBlast,
                                          trail: .smoke))
        }
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(1.5)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Dual-rotor gunship burst: a tight three-round chatter from the chin
    /// rotary cannon aimed at the enemy target.
    private func fireAllyGunshipBurst(from a: AllyNode, to target: CGPoint) {
        for r in 0..<Balance.gunshipBurstCount {
            let delay = Double(r) * Balance.gunshipBurstGap
            if delay == 0 {
                fireAllyGunshipRound(from: a, to: target)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, a.alive else { return }
                    self.fireAllyGunshipRound(from: a, to: target)
                }
            }
        }
    }

    /// One friendly gunship round: a high-velocity blue tracer + muzzle flash.
    private func fireAllyGunshipRound(from a: AllyNode, to target: CGPoint) {
        let muzzle = a.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.allyFire(at: muzzle.x)
        let bolt = ProjectileFactory.makeTowerBolt(team: .player)
        bolt.setScale(0.95)
        bolt.position = muzzle
        bolt.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(bolt)
        projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.enemyBoltLife,
                                      speed: Balance.gunshipBoltSpeed, damage: a.kind.damage,
                                      team: .player))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.85)
        flash.position = muzzle
        world.addChild(flash)
    }

    // MARK: - Revrent interceptors (independent droids with their own life)

    /// Spawn the full 5-droid screen docked on a fresh carrier.
    private func spawnRevrentInterceptors(for carrier: AllyNode) {
        for slot in 0..<Balance.revrentDroneCount {
            let d = RevrentInterceptorNode(owner: carrier, slotIndex: slot)
            let off = carrier.interceptorDockOffset(slot)
            d.position = CGPoint(x: carrier.position.x + off.x, y: carrier.position.y + off.y)
            world.addChild(d)
            interceptors.append(d)
        }
        // Launch puff so the screen visibly deploys from the hull.
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = carrier.position
        puff.setScale(1.4)
        world.addChild(puff)
    }

    /// Per-frame carrier screen management: tick rebuild timers, fly the
    /// screen out once the carrier itself is in firing range, recall it
    /// when no enemy is in sight anymore.
    private func updateRevrentCarrier(_ a: AllyNode, dt: TimeInterval, hasTarget: Bool, inRange: Bool) {
        // Dead droids rebuild one per slot after 5s, launching from the hull.
        for slot in 0..<a.interceptorBuildTimers.count {
            guard a.interceptorBuildTimers[slot] > 0 else { continue }
            a.interceptorBuildTimers[slot] -= dt
            if a.interceptorBuildTimers[slot] <= 0 {
                a.interceptorBuildTimers[slot] = 0
                guard a.alive, !a.marchedOff else { continue }
                let d = RevrentInterceptorNode(owner: a, slotIndex: slot)
                let off = a.interceptorDockOffset(slot)
                d.position = CGPoint(x: a.position.x + off.x, y: a.position.y + off.y)
                world.addChild(d)
                interceptors.append(d)
                let puff = ProjectileFactory.makeImpactPuff()
                puff.position = d.position
                puff.setScale(0.9)
                world.addChild(puff)
                SoundEngine.shared.summon(at: d.position.x)
            }
        }
        // No live screen to command without a hull.
        guard a.alive, !a.marchedOff else { return }
        let screen = interceptors.filter { $0.owner === a && $0.alive }
        if inRange {
            // Carrier in range: the whole screen flies out — docked and
            // returning droids (re)dock-launch so all five engage.
            for d in screen where d.mode != .deployed {
                d.mode = .deployed
            }
        } else if !hasTarget {
            for d in screen where d.mode == .deployed {
                d.mode = .returning
            }
        }
    }

    /// Remove a carrier's whole screen (carrier died / marched off).
    private func retireInterceptors(of carrier: AllyNode) {
        for d in interceptors where d.owner === carrier && d.alive {
            let puff = ProjectileFactory.makeImpactPuff()
            puff.position = d.position
            world.addChild(puff)
            d.hp = 0
            d.removeFromParent()
        }
        interceptors.removeAll { $0.owner === carrier }
    }

    /// Interceptor flight + combat: docked droids ride the carrier ring,
    /// deployed droids fly ahead of the hull, wobble, and shoot; returning
    /// droids fly home and re-dock. Dead carriers' screens are retired.
    private func updateInterceptors(dt: TimeInterval) {
        // Carrier gone (killed this frame): retire its screen first.
        for a in allies where !a.alive && a.kind == .revrent {
            retireInterceptors(of: a)
        }
        for d in interceptors {
            guard d.alive else { continue }
            guard let carrier = d.owner, carrier.alive, !carrier.marchedOff else {
                d.hp = 0
                d.removeFromParent()
                continue
            }
            d.fireCooldown -= dt
            switch d.mode {
            case .docked:
                let off = carrier.interceptorDockOffset(d.slotIndex)
                d.position = CGPoint(x: carrier.position.x + off.x,
                                     y: carrier.position.y + off.y + carrier.yBob * 0.5)
                d.zRotation = sin(carrier.interceptorOrbitPhase * 2 + CGFloat(d.slotIndex)) * 0.15
            case .deployed:
                // Each droid hunts its own nearest foe and flies a close
                // orbit around it — so the screen spreads over all of the
                // enemies ahead instead of stacking in formation. Because
                // they close to ~110pts, every droid ends up in range and
                // the whole screen keeps shooting while the carrier holds.
                guard let aim = nearestFoe(to: d.position, within: Balance.revrentInterceptorSight) else {
                    // Nothing in this droid's own sight: push toward the
                    // carrier's fight so it re-engages instead of hovering.
                    let fallback = CGPoint(x: carrier.position.x + carrier.facing * Balance.revrentScreenAhead,
                                           y: carrier.position.y + 26)
                    moveInterceptor(d, toward: fallback, dt: dt)
                    continue
                }
                // Leash: never chase beyond the carrier's own sight — hold
                // near the hull instead of flying across the map alone.
                if hypot(aim.x - carrier.position.x, aim.y - carrier.position.y) > carrier.kind.sightRange {
                    let fallback = CGPoint(x: carrier.position.x + carrier.facing * Balance.revrentScreenAhead,
                                           y: carrier.position.y + 26)
                    moveInterceptor(d, toward: fallback, dt: dt)
                    continue
                }
                let t = sceneTime * 2.0 + Double(d.slotIndex) * (Double.pi * 2 / Double(Balance.revrentDroneCount)) + Double(d.wobbleSeed)
                let anchor = CGPoint(
                    x: aim.x + CGFloat(cos(t)) * 110,
                    y: aim.y + 40 + CGFloat(sin(t * 1.3)) * 26)
                moveInterceptor(d, toward: anchor, dt: dt)
                d.zRotation = sin(CGFloat(t)) * 0.2
                if d.fireCooldown <= 0 {
                    let dist = hypot(aim.x - d.position.x, aim.y - d.position.y)
                    if dist <= Balance.revrentInterceptorRange {
                        d.fireCooldown = Balance.revrentInterceptorFireCooldown
                        fireInterceptorBolt(from: d, to: aim)
                    }
                }
            case .returning:
                let off2 = carrier.interceptorDockOffset(d.slotIndex)
                let want = CGPoint(x: carrier.position.x + off2.x, y: carrier.position.y + off2.y)
                let dist = hypot(want.x - d.position.x, want.y - d.position.y)
                if dist < 12 {
                    d.mode = .docked
                } else {
                    moveInterceptor(d, toward: want, dt: dt)
                }
            }
        }
        interceptors.removeAll { !$0.alive }
    }

    /// Eased interceptor flight: fast top speed, quick to position.
    private func moveInterceptor(_ d: RevrentInterceptorNode, toward: CGPoint, dt: TimeInterval) {
        let dx = toward.x - d.position.x, dy = toward.y - d.position.y
        let dist = max(1, hypot(dx, dy))
        let step = min(dist, Balance.revrentInterceptorSpeed * CGFloat(dt))
        d.position.x += dx / dist * step
        d.position.y += dy / dist * step
    }

    /// Nearest shootable foe for one interceptor: enemy marcher > tower > base.
    private func nearestFoe(to pos: CGPoint, within sight: CGFloat) -> CGPoint? {
        var best: CGPoint?
        var bestDist = sight
        for e in enemies where e.alive {
            let d = hypot(e.position.x - pos.x, e.position.y - pos.y)
            if d < bestDist {
                bestDist = d
                best = e.position
            }
        }
        if let best { return best }
        if let tower = nearestTower(team: .enemy, toX: pos.x) {
            return CGPoint(x: tower.node.position.x, y: Balance.groundTopY + 100)
        }
        if let base = bases.first(where: { $0.team == .enemy }), base.alive {
            return CGPoint(x: base.node.position.x, y: Balance.groundTopY + 100)
        }
        return nil
    }

    /// One interceptor round: a fast blue tracer + small muzzle flash.
    private func fireInterceptorBolt(from d: RevrentInterceptorNode, to target: CGPoint) {
        let muzzle = d.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.allyFire(at: muzzle.x)
        let bolt = ProjectileFactory.makeTowerBolt(team: .player)
        bolt.setScale(0.8)
        bolt.position = muzzle
        bolt.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(bolt)
        projectiles.append(Projectile(node: bolt, dir: dir, life: Balance.enemyBoltLife,
                                      speed: Balance.revrentBoltSpeed,
                                      damage: Balance.revrentInterceptorDamage,
                                      team: .player))
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.6)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Shared interceptor damage: drains HP, bursts + starts the 5s
    /// rebuild on death. Removal happens in updateInterceptors' sweep.
    private func damageInterceptor(_ d: RevrentInterceptorNode, amount: CGFloat) {
        guard d.alive else { return }
        d.hp = max(0, d.hp - amount)
        d.refreshHPBar()
        if !d.alive {
            let boom = ProjectileFactory.makeJetExplosion()
            boom.position = d.position
            world.addChild(boom)
            SoundEngine.shared.troopDown(at: d.position.x)
            if let carrier = d.owner {
                if slotHasLiveInterceptor(carrier: carrier, slot: d.slotIndex) == false {
                    carrier.interceptorBuildTimers[d.slotIndex] = Balance.revrentBuildTime
                }
            }
            d.removeFromParent()
        }
    }

    /// True when another live droid already covers this slot (double-kill
    /// in one frame must not double-start the rebuild timer).
    private func slotHasLiveInterceptor(carrier: AllyNode, slot: Int) -> Bool {
        interceptors.contains { $0.owner === carrier && $0.slotIndex == slot && $0.alive }
    }

    /// Tempest spin-up: holds station, grows a crackling arc-charge at the
    /// muzzle over `tempestChargeTime`, then releases one slow heavy bolt
    /// with the widest splash in the army. The long wind-up is the price
    /// of the 900-range reach and the 150px blast.
    private func updateTempestCharge(_ a: AllyNode, dt: TimeInterval, aim: CGPoint) {
        if a.chargeTime > 0 {
            a.chargeTime -= dt
            let frac = max(0, min(1, 1 - a.chargeTime / max(0.01, a.chargeTotal)))
            if a.chargeNode == nil {
                a.chargeNode = makeTempestChargeNode()
                world.addChild(a.chargeNode!)
                SoundEngine.shared.allyFire(at: a.position.x)
            }
            if let node = a.chargeNode {
                node.position = a.muzzle()
                node.setScale(0.4 + frac * 1.3)
                node.alpha = 0.6 + frac * 0.4
            }
            if a.chargeTime <= 0 {
                clearTempestCharge(a)
                fireAllyTempestOrb(from: a, to: aim)
                a.fireCooldown = a.kind.fireCooldown
            }
        } else if a.fireCooldown <= 0 {
            a.chargeTime = Balance.tempestChargeTime
            a.chargeTotal = Balance.tempestChargeTime
        }
    }

    /// Drop the spin-up glow without firing (target lost, marching on, dead).
    private func clearTempestCharge(_ a: AllyNode) {
        a.chargeTime = 0
        a.chargeNode?.removeFromParent()
        a.chargeNode = nil
    }

    /// Crackling arc-charge: cyan halo + hot pulsing core. The scene
    /// scales it with spin-up progress and parks it at the muzzle.
    private func makeTempestChargeNode() -> SKNode {
        let root = SKNode()
        root.zPosition = 15
        let halo = SKShapeNode(ellipseOf: CGSize(width: 30, height: 30))
        halo.fillColor = SKColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 0.25)
        halo.strokeColor = .clear
        root.addChild(halo)
        let core = SKShapeNode(circleOfRadius: 7)
        core.fillColor = SKColor(red: 0.85, green: 0.96, blue: 1.0, alpha: 1)
        core.strokeColor = .clear
        root.addChild(core)
        core.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.12),
            .fadeAlpha(to: 1.0, duration: 0.12),
        ])))
        return root
    }

    /// One heavy arc-bolt: slow straight flight at the aim point with a
    /// timed fuse backstop, detonating into the army's widest blast.
    /// Player-team so it hurts marchers + enemy structures.
    private func fireAllyTempestOrb(from a: AllyNode, to target: CGPoint) {
        let muzzle = a.muzzle()
        var dir = CGVector(dx: target.x - muzzle.x, dy: target.y - muzzle.y)
        let len = max(1, hypot(dir.dx, dir.dy))
        dir = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        SoundEngine.shared.missileLaunch(at: muzzle.x)
        let orb = ProjectileFactory.makeTempestOrb()
        orb.position = muzzle
        orb.zRotation = atan2(dir.dy, dir.dx)
        world.addChild(orb)
        let flight = len / Balance.tempestBoltSpeed
        var shell = Projectile(node: orb, dir: dir,
                               life: TimeInterval(flight) + 1.0,
                               speed: Balance.tempestBoltSpeed,
                               damage: a.kind.damage,
                               team: .player)
        shell.blast = Balance.tempestBlast
        shell.fuse = TimeInterval(flight) + 0.1
        shell.trail = .ember
        projectiles.append(shell)
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(1.6)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Enemy-bolt vs player army. Returns true when it struck an ally.
    /// Interceptors are small but hittable — each droid soaks its own hit.
    private func hitAlly(at pt: CGPoint, amount: CGFloat) -> Bool {
        for a in allies where a.alive {
            if abs(pt.x - a.position.x) < a.size.width / 2 + 12,
               abs(pt.y - a.position.y) < a.size.height / 2 + 8 {
                damageAlly(a, amount: amount)
                return true
            }
        }
        for d in interceptors where d.alive {
            if abs(pt.x - d.position.x) < d.size.width / 2 + 10,
               abs(pt.y - d.position.y) < d.size.height / 2 + 8 {
                damageInterceptor(d, amount: amount)
                return true
            }
        }
        return false
    }

    /// Shared ally damage (bolts + reaver axes): drains HP, bursts + howls
    /// on death. Removal from the field happens in updateAllies' sweep.
    private func damageAlly(_ a: AllyNode, amount: CGFloat) {
        guard a.alive else { return }
        a.hp = max(0, a.hp - amount)
        a.refreshHPBar()
        if !a.alive {
            // A dying Tempest drops its half-spun charge with it.
            if a.kind == .tempest {
                clearTempestCharge(a)
            }
            // A dead carrier's screen goes down with it — no orphan droids.
            if a.kind == .revrent {
                retireInterceptors(of: a)
            }
            if a.kind.isFlying {
                // Aircraft down: mid-air fireball + falling wreck.
                let boom = ProjectileFactory.makeJetExplosion()
                boom.position = a.position
                world.addChild(boom)
            } else if a.kind == .truck || a.kind == .bombard || a.kind == .tank || a.kind == .storm {
                // Armor kill: full vehicle explosion (flash + fire + smoke
                // + debris + sparks) instead of the trooper puff.
                let boom = ProjectileFactory.makeTruckExplosion()
                boom.position = a.position
                world.addChild(boom)
            } else {
                let puff = ProjectileFactory.makeImpactPuff()
                puff.position = a.position
                puff.setScale(1.4)
                world.addChild(puff)
            }
            a.removeFromParent()
            SoundEngine.shared.troopDown(at: a.position.x)
        }
    }

    private func damageBase(at index: Int, amount: CGFloat) {
        guard bases[index].alive else { return }
        bases[index].hp = max(0, bases[index].hp - amount)
        let frac = max(0, bases[index].hp / bases[index].maxHP)
        bases[index].node.setHPFraction(frac)
        if !bases[index].alive {
            bases[index].node.setDestroyed()
            SoundEngine.shared.structureDestroyed(playerOwned: bases[index].team == .player,
                                                  at: bases[index].node.position.x)
            // Enemy HQ down = level won. The SwiftUI layer picks this up
            // (~7Hz poll) and raises the victory card.
            if bases[index].team == .enemy, wonAt == nil {
                wonAt = sceneTime
                // Bank the leftover shield: it rides into the next level,
                // stacking additively under any shield bought since.
                HeroUpgrades.saveShieldCarry(heroId: heroId, amount: shieldHP,
                                             cap: shieldMax)
            }
            // Player HQ down = run lost. Same defeat channel as the last
            // hero heart (GameView raises mission-failed off minimap.lost).
            if bases[index].team == .player, lostAt == nil {
                lostAt = sceneTime
            }
        }
    }

    /// Point-in-base test for one team's alive bases. HQ is ~267 wide, 210 tall
    /// (Mk-II HQ at Level 20+ is ~325 wide, 258 tall).
    private func baseIndex(at pt: CGPoint, team: Team) -> Int? {
        for (i, b) in bases.enumerated() where b.team == team && b.alive {
            let halfW: CGFloat = b.node.upgraded ? 160 : 130
            let topH: CGFloat = b.node.upgraded ? 265 : 220
            let dx = abs(pt.x - b.node.position.x)
            let inX = dx < halfW
            let inY = pt.y >= Balance.groundTopY && pt.y <= Balance.groundTopY + topH
            if inX && inY { return i }
        }
        return nil
    }

    private func damageHero(amount: CGFloat) {
        guard hero.alive, heroHP > 0 else { return }
        var rest = amount
        // Energy shield absorbs first (cyan flash reads the save).
        if shieldHP > 0 {
            let absorbed = min(shieldHP, rest)
            shieldHP -= absorbed
            rest -= absorbed
            lastShieldHitAt = sceneTime
            hero.shieldFlash() // the orb takes the hit visibly
            hero.run(.sequence([.fadeAlpha(to: 0.6, duration: 0.05),
                                .fadeAlpha(to: 1.0, duration: 0.1)]))
        }
        heroHP = max(0, heroHP - rest)
        if heroHP <= 0 {
            killHero()
            return
        }
        SoundEngine.shared.heroHurt()
        // Hit flash so damage reads instantly.
        hero.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.06),
                            .fadeAlpha(to: 1.0, duration: 0.12)]))
    }

    /// Shield recharge: 10/s after 4s without a shield hit.
    private func updateShield(dt: TimeInterval) {
        guard shieldMax > 0, shieldHP < shieldMax,
              sceneTime - lastShieldHitAt > 4 else { return }
        shieldHP = min(shieldMax, shieldHP + 10 * CGFloat(dt))
    }

    /// Health-pack button (HUD, next to the vitals): spends the run's one
    /// armed pack for an instant heal. No-op at full HP, while dead, or
    /// once spent. Returns true when HP actually moved.
    @discardableResult
    func useHealthPack() -> Bool {
        guard hero.alive, heroPackArmed, heroHP > 0, heroHP < heroMaxHP else {
            return false
        }
        let amount = CGFloat(HeroAddons.boosterHeal(
            tier: HeroAddons.boosterTier(heroId: heroId)))
        guard amount > 0 else { return false }
        heroPackArmed = false
        heroHP = min(heroMaxHP, heroHP + amount)
        SoundEngine.shared.pickup()
        floatText("+\(Int(amount)) HP",
                  color: SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 1),
                  at: hero.position)
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = hero.position
        puff.setScale(1.4)
        world.addChild(puff)
        return true
    }

    // MARK: - Bomber support strike (Level 25+ HUD ability)
    /// True on bomber levels (never in the playground).
    var bomberUnlocked: Bool {
        levelId != Balance.playgroundLevelId && levelId >= Balance.bomberUnlockLevel
    }

    /// Enter zone-select: the next right-half touch picks the strike zone.
    /// No-op unless a strike is actually ready. Returns true when armed.
    @discardableResult
    func startBomberTargeting() -> Bool {
        guard bomberUnlocked, bomberCooldownLeft <= 0, !bomberTargeting,
              wonAt == nil, lostAt == nil else { return false }
        bomberTargeting = true
        releaseAimTouch()
        floatText("TAP THE FIELD — PICK THE STRIKE ZONE",
                  color: SKColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 1),
                  at: CGPoint(x: hero.position.x, y: hero.position.y + 190))
        SoundEngine.shared.uiTap()
        return true
    }

    /// Leave zone-select without spending the strike.
    func cancelBomberTargeting() {
        bomberTargeting = false
        bomberTouch = nil
        bomberReticle?.removeFromParent()
        bomberReticle = nil
    }

    /// Drag the pulsing zone reticle (clamped to the lane).
    private func moveBomberReticle(to worldPt: CGPoint) {
        let x = min(max(worldPt.x, 100), Balance.levelWidth - 100)
        let base = CGPoint(x: x, y: Balance.groundY(at: x) + 12)
        if bomberReticle == nil {
            bomberReticle = makeBomberReticle()
            world.addChild(bomberReticle!)
        }
        bomberReticle?.position = base
    }

    /// Strike-zone marker: orange blast ring + crosshair, breathing loop.
    private func makeBomberReticle() -> SKNode {
        let root = SKNode()
        let r = Balance.bomberBombBlast
        let ring = SKShapeNode(circleOfRadius: r)
        ring.fillColor = SKColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 0.10)
        ring.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 0.9)
        ring.lineWidth = 3
        root.addChild(ring)
        let inner = SKShapeNode(circleOfRadius: 10)
        inner.fillColor = SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 0.9)
        inner.strokeColor = .clear
        root.addChild(inner)
        for a in [0.0, Double.pi / 2] {
            let arm = SKSpriteNode(color: SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 0.9),
                                   size: CGSize(width: r * 2, height: 2))
            arm.zRotation = a
            root.addChild(arm)
        }
        root.zPosition = 14
        root.run(.repeatForever(.sequence([
            .scale(to: 1.06, duration: 0.45), .scale(to: 1.0, duration: 0.45),
        ])))
        return root
    }

    /// Release confirms: spend the strike, launch the bomber at the zone.
    private func confirmBomberStrike() {
        guard bomberTargeting, bomberCooldownLeft <= 0 else {
            cancelBomberTargeting()
            return
        }
        guard let zone = bomberReticle?.position else {
            cancelBomberTargeting()
            return
        }
        bomberTargeting = false
        bomberReticle?.removeFromParent()
        bomberReticle = nil
        bomberCooldownLeft = Balance.bomberCooldown
        // Bomber enters from the west, high above the gunships.
        let startX = min(zone.x - 1100, Balance.levelWidth - 200) - 200
        let plane = makeBomberNode()
        plane.position = CGPoint(x: max(-300, startX),
                                 y: Balance.groundTopY + Balance.bomberAltitude)
        plane.zPosition = 30
        world.addChild(plane)
        bomberRun = BomberRun(node: plane, targetX: zone.x,
                              bombsLeft: Balance.bomberBombCount,
                              dropAcc: Balance.bomberDropGap, trailAcc: 0)
        SoundEngine.shared.missileLaunch(at: zone.x)
        floatText("BOMBER INBOUND",
                  color: SKColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 1),
                  at: CGPoint(x: zone.x, y: Balance.groundTopY + 200))
    }

    /// Side-view heavy bomber in player blue: long stepped hull with a
    /// glass nose office, swept wings (near + far), four glowing engine
    /// pods, open bomb bay with a round peeking out, marked tail and
    /// strobes. Faces +x.
    private func makeBomberNode() -> SKNode {
        let root = SKNode()
        let blue = SKColor(red: 0.16, green: 0.38, blue: 0.82, alpha: 1)
        let blueD = SKColor(red: 0.08, green: 0.20, blue: 0.50, alpha: 1)
        let blueDD = SKColor(red: 0.04, green: 0.10, blue: 0.28, alpha: 1)
        let sky = SKColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 1)
        let glass = SKColor(red: 0.78, green: 0.95, blue: 1.0, alpha: 1)
        // Long hull + pale spine + navy belly.
        let body = SKSpriteNode(color: blue, size: CGSize(width: 118, height: 20))
        root.addChild(body)
        let spine = SKSpriteNode(color: sky, size: CGSize(width: 108, height: 3))
        spine.position = CGPoint(x: 0, y: 9)
        spine.alpha = 0.75
        root.addChild(spine)
        let belly = SKSpriteNode(color: blueDD, size: CGSize(width: 108, height: 6))
        belly.position = CGPoint(x: 0, y: -11)
        root.addChild(belly)
        // Glass nose office: stepped panes + frames + shine.
        let noseGlass = SKSpriteNode(color: glass, size: CGSize(width: 18, height: 12))
        noseGlass.position = CGPoint(x: 58, y: 2)
        root.addChild(noseGlass)
        let noseFrame = SKSpriteNode(color: blueD, size: CGSize(width: 3, height: 13))
        noseFrame.position = CGPoint(x: 58, y: 2)
        root.addChild(noseFrame)
        let noseShine = SKSpriteNode(color: .white, size: CGSize(width: 5, height: 3))
        noseShine.position = CGPoint(x: 55, y: 5)
        noseShine.alpha = 0.9
        root.addChild(noseShine)
        let radome = SKSpriteNode(color: blueD, size: CGSize(width: 8, height: 9))
        radome.position = CGPoint(x: 70, y: 1)
        root.addChild(radome)
        // Cockpit hump with twin panes behind the nose office.
        let hump = SKSpriteNode(color: blueD, size: CGSize(width: 30, height: 13))
        hump.position = CGPoint(x: 34, y: 14)
        root.addChild(hump)
        for px in [28, 40] as [CGFloat] {
            let pane = SKSpriteNode(color: glass, size: CGSize(width: 9, height: 8))
            pane.position = CGPoint(x: px, y: 15)
            root.addChild(pane)
        }
        let humpShine = SKSpriteNode(color: .white, size: CGSize(width: 6, height: 2))
        humpShine.position = CGPoint(x: 28, y: 18)
        humpShine.alpha = 0.85
        root.addChild(humpShine)
        // Hull panel seams + rivet dots.
        for px in [-40, -16, 8, 48] as [CGFloat] {
            let seam = SKSpriteNode(color: blueDD, size: CGSize(width: 2, height: 18))
            seam.position = CGPoint(x: px, y: 0)
            seam.alpha = 0.8
            root.addChild(seam)
        }
        for px in [-34, -10, 14, 42] as [CGFloat] {
            let rivet = SKSpriteNode(color: sky, size: CGSize(width: 1, height: 1))
            rivet.position = CGPoint(x: px, y: 6)
            rivet.alpha = 0.7
            root.addChild(rivet)
        }
        // Player roundel on the flank.
        let roundel = SKShapeNode(circleOfRadius: 7)
        roundel.fillColor = SKColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1)
        roundel.strokeColor = .white
        roundel.lineWidth = 2
        roundel.position = CGPoint(x: -26, y: 1)
        root.addChild(roundel)
        let roundelDot = SKShapeNode(circleOfRadius: 2.5)
        roundelDot.fillColor = .white
        roundelDot.strokeColor = .clear
        roundelDot.position = roundel.position
        root.addChild(roundelDot)
        // Far wing (darker, behind) + near swept wing with lit leading
        // edge and tip fence.
        let farWing = SKSpriteNode(color: blueDD, size: CGSize(width: 58, height: 9))
        farWing.position = CGPoint(x: -4, y: 22)
        farWing.zRotation = 0.52
        root.addChild(farWing)
        let wing = SKSpriteNode(color: blueD, size: CGSize(width: 64, height: 11))
        wing.position = CGPoint(x: -2, y: 15)
        wing.zRotation = 0.42
        root.addChild(wing)
        let leading = SKSpriteNode(color: sky, size: CGSize(width: 60, height: 2))
        leading.position = CGPoint(x: 2, y: 11)
        leading.zRotation = 0.42
        leading.alpha = 0.85
        root.addChild(leading)
        let fence = SKSpriteNode(color: sky, size: CGSize(width: 4, height: 12))
        fence.position = CGPoint(x: -27, y: 26)
        fence.zRotation = 0.42
        root.addChild(fence)
        // Wing-root fairing hump over the hull.
        let fairing = SKSpriteNode(color: blue, size: CGSize(width: 34, height: 8))
        fairing.position = CGPoint(x: -2, y: 8)
        root.addChild(fairing)
        // Four engine pods: pylon + pod + glowing fan face + dark nozzle.
        for ex in [-24, -8, 10, 26] as [CGFloat] {
            let pylon = SKSpriteNode(color: blueD, size: CGSize(width: 4, height: 10))
            pylon.position = CGPoint(x: ex, y: -6)
            root.addChild(pylon)
            let pod = SKSpriteNode(color: blueDD, size: CGSize(width: 17, height: 13))
            pod.position = CGPoint(x: ex, y: -14)
            root.addChild(pod)
            let lip = SKSpriteNode(color: sky, size: CGSize(width: 3, height: 11))
            lip.position = CGPoint(x: ex + 8, y: -14)
            root.addChild(lip)
            let fan = SKShapeNode(circleOfRadius: 3.5)
            fan.fillColor = SKColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1)
            fan.strokeColor = .clear
            fan.position = CGPoint(x: ex + 8, y: -14)
            root.addChild(fan)
            fan.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.5, duration: 0.28), .fadeAlpha(to: 1.0, duration: 0.28),
            ])))
            let nozzle = SKSpriteNode(color: SKColor(white: 0, alpha: 0.9),
                                      size: CGSize(width: 4, height: 9))
            nozzle.position = CGPoint(x: ex - 9, y: -14)
            root.addChild(nozzle)
        }
        // Open bomb bay: dark interior, angled doors, one round peeking.
        let bayInner = SKSpriteNode(color: SKColor(white: 0, alpha: 0.9),
                                    size: CGSize(width: 34, height: 6))
        bayInner.position = CGPoint(x: 0, y: -14)
        root.addChild(bayInner)
        for s in [-1, 1] as [CGFloat] {
            let door = SKSpriteNode(color: blueD, size: CGSize(width: 17, height: 3))
            door.position = CGPoint(x: s * 20, y: -16)
            door.zRotation = s * -0.35
            root.addChild(door)
        }
        let loaded = SKSpriteNode(color: SKColor(red: 0.25, green: 0.28, blue: 0.33, alpha: 1),
                                  size: CGSize(width: 8, height: 6))
        loaded.position = CGPoint(x: 0, y: -15)
        root.addChild(loaded)
        // Tall tail fin with sky tip, squadron stripe and hull number.
        let fin = SKSpriteNode(color: blueD, size: CGSize(width: 13, height: 34))
        fin.position = CGPoint(x: -54, y: 20)
        root.addChild(fin)
        let finTip = SKSpriteNode(color: sky, size: CGSize(width: 13, height: 7))
        finTip.position = CGPoint(x: -54, y: 34)
        root.addChild(finTip)
        let stripe = SKSpriteNode(color: .white, size: CGSize(width: 13, height: 3))
        stripe.position = CGPoint(x: -54, y: 25)
        stripe.alpha = 0.9
        root.addChild(stripe)
        let numeral = SKLabelNode(fontNamed: "Menlo-Bold")
        numeral.text = "25"
        numeral.fontSize = 9
        numeral.fontColor = .white
        numeral.position = CGPoint(x: -54, y: 12)
        root.addChild(numeral)
        // Tailplanes with lit tips.
        let tailplane = SKSpriteNode(color: blue, size: CGSize(width: 34, height: 7))
        tailplane.position = CGPoint(x: -56, y: 4)
        root.addChild(tailplane)
        for tx in [-70, -42] as [CGFloat] {
            let tipLight = SKSpriteNode(color: sky, size: CGSize(width: 3, height: 7))
            tipLight.position = CGPoint(x: tx, y: 4)
            root.addChild(tipLight)
        }
        // Beacons: red fin tip, green nose, double-flash white strobe on
        // the wing fence.
        let tailLight = SKShapeNode(circleOfRadius: 3)
        tailLight.fillColor = SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)
        tailLight.strokeColor = .clear
        tailLight.position = CGPoint(x: -54, y: 39)
        root.addChild(tailLight)
        tailLight.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.15, duration: 0.4), .fadeAlpha(to: 1.0, duration: 0.4),
        ])))
        let noseLight = SKShapeNode(circleOfRadius: 3)
        noseLight.fillColor = SKColor(red: 0.3, green: 1, blue: 0.4, alpha: 1)
        noseLight.strokeColor = .clear
        noseLight.position = CGPoint(x: 75, y: 1)
        root.addChild(noseLight)
        noseLight.run(.repeatForever(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.4), .fadeAlpha(to: 0.15, duration: 0.4),
        ])))
        let strobe = SKShapeNode(circleOfRadius: 2.5)
        strobe.fillColor = .white
        strobe.strokeColor = .clear
        strobe.position = CGPoint(x: -27, y: 31)
        root.addChild(strobe)
        strobe.run(.repeatForever(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.08),
            .fadeAlpha(to: 0.1, duration: 0.12),
            .fadeAlpha(to: 1.0, duration: 0.08),
            .fadeAlpha(to: 0.1, duration: 1.1),
        ])))
        return root
    }

    /// One bomb off the rack: straight down off the wing, gravity does the
    /// rest — the normal projectile sim detonates it on the turf with AoE.
    private func dropBomberBomb(from pos: CGPoint) {
        let bomb = ProjectileFactory.makeMortarBomb()
        bomb.position = pos
        bomb.setScale(1.25)
        world.addChild(bomb)
        var shell = Projectile(node: bomb, dir: CGVector(dx: 0, dy: -1),
                               life: 4.0,
                               speed: 150,
                               damage: Balance.bomberBombDamage,
                               team: .player)
        shell.gravity = 1100
        shell.blast = Balance.bomberBombBlast
        shell.trail = .smoke
        projectiles.append(shell)
    }

    /// Bomber sim: recharge tick, west→east run, bomb stick across the
    /// zone, engine smoke, cleanup past the east edge.
    private func stepBomber(dt: TimeInterval) {
        bomberCooldownLeft = max(0, bomberCooldownLeft - dt)
        guard var run = bomberRun else { return }
        run.node.position.x += Balance.bomberSpeed * CGFloat(dt)
        run.trailAcc += dt
        if run.trailAcc >= 0.08 {
            run.trailAcc = 0
            let puff = ProjectileFactory.makeTrailPuff(.smoke)
            puff.position = CGPoint(x: run.node.position.x - 52,
                                    y: run.node.position.y - 6)
            world.addChild(puff)
        }
        if run.bombsLeft > 0,
           run.node.position.x >= run.targetX - Balance.bomberDropLead {
            run.dropAcc += dt
            while run.bombsLeft > 0, run.dropAcc >= Balance.bomberDropGap {
                run.dropAcc -= Balance.bomberDropGap
                dropBomberBomb(from: run.node.position)
                run.bombsLeft -= 1
            }
        }
        bomberRun = run
        if run.node.position.x > Balance.levelWidth + 400 {
            run.node.removeFromParent()
            bomberRun = nil
        }
    }

    private func killHero() {
        let deathSpot = hero.position
        hero.die()
        hero.isHidden = true
        // The droid dies with him (reborn on respawn).
        droid?.isHidden = true
        releaseAimTouch()
        heroLives = max(0, heroLives - 1)
        if heroLives > 0 {
            respawnAt = sceneTime + Balance.respawnDelay
        } else {
            // Last heart gone: no respawn — the run ends in defeat and
            // GameView raises the mission-failed panel (see minimap.lost).
            respawnAt = -1
            lostAt = sceneTime
        }
        SoundEngine.shared.heroDeath()
        // Death poof.
        for i in 0..<2 {
            let puff = ProjectileFactory.makeImpactPuff()
            puff.position = CGPoint(x: deathSpot.x + CGFloat(i * 10 - 5), y: deathSpot.y)
            world.addChild(puff)
        }
    }

    /// Ad/diamond revive: grants one more heart and schedules the standard
    /// respawn drop with grace. Clears the defeat channel so the SwiftUI
    /// card dismisses on the next poll. No-op unless the run is lost.
    func reviveHero() {
        guard lostAt != nil else { return }
        lostAt = nil
        heroLives = 1
        applyHeroUpgrades(fullRestore: true)
        respawnAt = sceneTime + Balance.respawnDelay
    }

    /// False when the player HQ is rubble — reviving the hero then would
    /// still be a defeat, so the UI hides the revive buttons.
    var playerBaseAlive: Bool {
        bases.first(where: { $0.team == .player })?.alive ?? false
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
            // Grenade fuse ticks from the muzzle.
            if let fuse = p.fuse {
                p.fuse = fuse - dt
                if p.fuse! <= 0 {
                    explode(p, at: p.node.position)
                    ProjectileFactory.recycle(p.node)
                    continue
                }
            }
            // Rocket motors accelerate along the flight line.
            if p.thrust > 0 {
                p.speed = min(p.speed + p.thrust * CGFloat(dt), 1600)
            }
            // Gravity bends the velocity vector downward (grenade arcs).
            if p.gravity > 0 {
                var vx = p.dir.dx * p.speed, vy = p.dir.dy * p.speed
                vy -= p.gravity * CGFloat(dt)
                let s = max(1, hypot(vx, vy))
                p.speed = min(s, 1700)
                p.dir = CGVector(dx: vx / s, dy: vy / s)
                p.node.zRotation = atan2(vy, vx)
            }
            let step = p.speed * CGFloat(dt)
            p.node.position.x += p.dir.dx * step
            p.node.position.y += p.dir.dy * step
            // Choir weave: snake perpendicular to the flight line.
            if p.weaveAmp > 0 {
                p.weavePhase += p.weaveFreq * dt
                let lateral = cos(p.weavePhase) * p.weaveAmp * CGFloat(p.weaveFreq)
                let wob = lateral * CGFloat(dt)
                p.node.position.x += -p.dir.dy * wob
                p.node.position.y += p.dir.dx * wob
                if p.weaveSteers {
                    // Nose into the wave: heading follows the real path.
                    let vx = p.dir.dx * p.speed - p.dir.dy * lateral
                    let vy = p.dir.dy * p.speed + p.dir.dx * lateral
                    p.node.zRotation = atan2(vy, vx)
                }
            }
            // Flight trails (smoke/embers shed on a cadence).
            if p.trail != .none {
                p.trailAcc += dt
                if p.trailAcc >= 0.06 {
                    p.trailAcc = 0
                    let mote = ProjectileFactory.makeTrailPuff(p.trail)
                    mote.position = p.node.position
                    world.addChild(mote)
                }
            }
            p.life -= dt
            if p.life <= 0 {
                if p.blast > 0 {
                    explode(p, at: p.node.position)
                }
                ProjectileFactory.recycle(p.node) // expired mid-air: no plain puff
                continue
            }
            if hitsGroundOrPlatform(p.node.position) {
                // Out of the lane sideways: always gone, never bounces.
                if p.node.position.x < 0 || p.node.position.x > Balance.levelWidth {
                    ProjectileFactory.recycle(p.node)
                    continue
                }
                // Grenades skip off turf (damped vertical flip + a hop).
                if p.bounces > 0, p.team == .neutral {
                    p.bounces -= 1
                    p.dir = CGVector(dx: p.dir.dx, dy: abs(p.dir.dy) * 0.45 + 0.05)
                    let s = max(0.01, hypot(p.dir.dx, p.dir.dy))
                    p.dir = CGVector(dx: p.dir.dx / s, dy: p.dir.dy / s)
                    p.speed *= 0.7
                    p.node.zRotation = atan2(p.dir.dy, p.dir.dx)
                    p.node.position.y = max(p.node.position.y,
                                              Balance.groundY(at: p.node.position.x) + 6)
                    impact(at: p.node.position)
                    alive.append(p)
                    continue
                }
                if p.blast > 0 {
                    explode(p, at: p.node.position)
                } else if p.contactBlast > 0 {
                    if p.team == .enemy {
                        splashPlayer(at: p.node.position, radius: p.contactBlast, damage: p.damage,
                                     blastFX: p.blastFX)
                    } else {
                        detonate(at: p.node.position, radius: p.contactBlast)
                    }
                } else {
                    impact(at: p.node.position)
                }
                ProjectileFactory.recycle(p.node)
                continue
            }
            // Blast shells detonate on contact (AoE covers the victim);
            // plain bolts deal their point damage.
            if p.blast > 0 {
                if touchesFoe(p) {
                    explode(p, at: p.node.position)
                    ProjectileFactory.recycle(p.node)
                    continue
                }
            } else if p.team == .enemy, p.contactBlast > 0 {
                // Saucer plasma / vesper shards: splash carries the damage
                // (no double-hit).
                if touchesPlayer(at: p.node.position) {
                    splashPlayer(at: p.node.position, radius: p.contactBlast, damage: p.damage,
                                 blastFX: p.blastFX)
                    ProjectileFactory.recycle(p.node)
                    continue
                }
            } else if hitEnemy(p) {
                if p.contactBlast > 0 {
                    detonate(at: p.node.position, radius: p.contactBlast)
                } else {
                    impact(at: p.node.position)
                }
                ProjectileFactory.recycle(p.node)
                continue
            }
            alive.append(p)
        }
        projectiles = alive
    }

    /// Contact-only foe test for blast shells (no point damage — the
    /// detonation's AoE covers the victim). Mirrors hitEnemy's geometry.
    private func touchesFoe(_ p: Projectile) -> Bool {
        guard p.team == .neutral || p.team == .player else { return false }
        let pt = p.node.position
        for e in enemies where e.alive {
            if abs(pt.x - e.position.x) < e.size.width / 2 + 22,
               abs(pt.y - e.position.y) < e.size.height / 2 + 8 {
                return true
            }
        }
        if towerIndex(at: pt, team: .enemy) != nil { return true }
        if baseIndex(at: pt, team: .enemy) != nil { return true }
        return false
    }

    /// Detonation: shockwave FX + boom scaled to the blast, full damage to
    /// every enemy marcher in the radius, splash to towers/HQ in reach.
    private func explode(_ p: Projectile, at pos: CGPoint) {
        let r = p.blast
        // The Tempest's arc-blast renders its own cyan detonation; smaller
        // shells keep the standard orange boom.
        let boom = r >= 140 ? ProjectileFactory.makeTempestBlast(radius: r)
            : ProjectileFactory.makeExplosion(radius: r)
        boom.position = pos
        world.addChild(boom)
        if r >= 80 {
            SoundEngine.shared.explosionBig(at: pos.x)
        } else {
            SoundEngine.shared.impact(at: pos.x)
        }
        guard p.team == .neutral || p.team == .player else { return }
        let fromHero = p.team == .neutral
        for e in enemies where e.alive {
            if hypot(e.position.x - pos.x, e.position.y - pos.y) <= r + e.size.width / 2 {
                damageMarcher(e, amount: p.damage, fromHero: fromHero)
            }
        }
        for (i, t) in towers.enumerated() where t.team == .enemy && t.alive {
            if hypot(t.node.position.x - pos.x,
                     (Balance.groundTopY + 100) - pos.y) <= r + 62 {
                damageTower(at: i, amount: p.damage)
            }
        }
        if let base = bases.first(where: { $0.team == .enemy }), base.alive,
           let idx = bases.firstIndex(where: { $0.node === base.node }),
           hypot(base.node.position.x - pos.x,
                 (Balance.groundTopY + 100) - pos.y) <= r + 130 {
            damageBase(at: idx, amount: p.damage)
        }
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

    /// Bolt vs summoned marchers. Kills pay the marcher's bounty (raider
    /// +100, brute +175), plus reserve ammo for the active hero gun on
    /// hero-gun kills (capped at 2x start).
    private func hitMarcher(at pt: CGPoint, amount: CGFloat, fromHero: Bool) -> Bool {
        for e in enemies where e.alive {
            if abs(pt.x - e.position.x) < e.size.width / 2 + 22,
               abs(pt.y - e.position.y) < e.size.height / 2 + 8 {
                damageMarcher(e, amount: amount, fromHero: fromHero)
                return true
            }
        }
        return false
    }

    /// Shared marcher damage (bolts, blasts, axes): drains HP, pays bounty
    /// + ammo + drops + death FX on the kill. Removal from the field
    /// happens in updateEnemies' sweep.
    private func damageMarcher(_ e: EnemyNode, amount: CGFloat, fromHero: Bool) {
        guard e.alive else { return }
        e.hp = max(0, e.hp - amount)
        e.refreshHPBar()
        if !e.alive {
            money += e.reward
            if fromHero {
                let i = heroWeapon.rawValue
                reserves[i] = min(reserves[i] + heroWeapon.killAmmo,
                                  heroWeapon.startReserve * 2)
            }
            maybeSpawnDrop(at: e.position)
            if e.kind == .gnasher {
                // Volatile rusher dies bursting: pale blast splashes the
                // hero + nearby allies — kill it at range, not in the line.
                splashPlayer(at: e.position,
                             radius: Balance.gnasherDeathBlast,
                             damage: Balance.gnasherDeathDamage)
            } else if e.kind == .immortal {
                // The phase walker dies big: shield pop + crimson flare.
                let boom = ProjectileFactory.makeImmortalExplosion()
                boom.position = e.position
                world.addChild(boom)
            } else if e.kind.isMech {
                // Mech walkers come apart in a heavy blast.
                let boom = ProjectileFactory.makeMechExplosion()
                boom.position = e.position
                world.addChild(boom)
            } else if e.kind.isFlying {
                // Jetpack droids go out in a mid-air fireball + falling wreck.
                let boom = ProjectileFactory.makeJetExplosion()
                boom.position = e.position
                world.addChild(boom)
            } else {
                let puff = ProjectileFactory.makeImpactPuff()
                puff.position = e.position
                puff.setScale(1.6)
                world.addChild(puff)
            }
            e.removeFromParent()
            SoundEngine.shared.enemyDown(at: e.position.x)
        }
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
        if pt.y <= Balance.groundY(at: pt.x) + 3 { return true }
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

    /// Contact detonation (missiles): the boom is the payoff for the hit —
    /// the damage itself already landed on whatever it touched.
    private func detonate(at pt: CGPoint, radius: CGFloat) {
        SoundEngine.shared.missileDetonate(at: pt.x)
        let boom = ProjectileFactory.makeExplosion(radius: radius)
        boom.position = pt
        world.addChild(boom)
        let puff = ProjectileFactory.makeImpactPuff()
        puff.position = pt
        puff.setScale(1.4)
        world.addChild(puff)
    }

    /// Non-damaging contact test for enemy splash shells (saucer plasma):
    /// true when the orb touches any player-side body, tower or HQ.
    /// The splash itself carries the damage (see splashPlayer), so the
    /// primary victim is never double-hit.
    private func touchesPlayer(at pt: CGPoint) -> Bool {
        for a in allies where a.alive {
            if abs(pt.x - a.position.x) < a.size.width / 2 + 14,
               abs(pt.y - a.position.y) < a.size.height / 2 + 10 {
                return true
            }
        }
        for d in interceptors where d.alive {
            if abs(pt.x - d.position.x) < d.size.width / 2 + 10,
               abs(pt.y - d.position.y) < d.size.height / 2 + 8 {
                return true
            }
        }
        if towerIndex(at: pt, team: .player) != nil { return true }
        if baseIndex(at: pt, team: .player) != nil { return true }
        if !heroProtected,
           abs(pt.x - hero.position.x) < 36,
           abs(pt.y - hero.position.y) < Balance.heroHeight / 2 + 8 {
            return true
        }
        return false
    }

    /// Enemy splash (saucer plasma, vesper shards): blast FX + full damage
    /// to every player-side body in the radius — allies, hero, towers, HQ.
    /// The FX family follows the round (blue for saucer plasma, violet for
    /// vesper shards).
    private func splashPlayer(at pt: CGPoint, radius: CGFloat, damage: CGFloat,
                              blastFX: BlastFX = .saucer) {
        SoundEngine.shared.missileDetonate(at: pt.x)
        let boom = blastFX == .vesper
            ? ProjectileFactory.makeVesperBlast(radius: radius)
            : ProjectileFactory.makeSaucerBlast(radius: radius)
        boom.position = pt
        world.addChild(boom)
        for a in allies where a.alive {
            if hypot(a.position.x - pt.x, a.position.y - pt.y) <= radius + a.size.width / 2 {
                damageAlly(a, amount: damage)
            }
        }
        for d in interceptors where d.alive {
            if hypot(d.position.x - pt.x, d.position.y - pt.y) <= radius + d.size.width / 2 {
                damageInterceptor(d, amount: damage)
            }
        }
        if !heroProtected,
           hypot(hero.position.x - pt.x, hero.position.y - pt.y) <= radius + 34 {
            damageHero(amount: damage)
        }
        for (i, t) in towers.enumerated() where t.team == .player && t.alive {
            if hypot(t.node.position.x - pt.x,
                     (Balance.groundTopY + 100) - pt.y) <= radius + 62 {
                damageTower(at: i, amount: damage)
            }
        }
        if let base = bases.first(where: { $0.team == .player }), base.alive,
           let idx = bases.firstIndex(where: { $0.node === base.node }),
           hypot(base.node.position.x - pt.x,
                 (Balance.groundTopY + 100) - pt.y) <= radius + 130 {
            damageBase(at: idx, amount: damage)
        }
    }

    // MARK: - Debug (temporary HUD readout)
    private var frameCount = 0
    private var fpsSmoothed: Double = 0
    private var perfFrameMs: Double = 0
    private var perfPeakMs: Double = 0
    private var perfPeakWindow: TimeInterval = 0
    private var perfHitchWindow: TimeInterval = 0
    private var perfHitches = 0
    private var perfCPUMs: Double = 0
    private var perfLastCPUms: Double = 0
    private var perfWorstCPUms: Double = 0
    private var perfWorstDraws = 0
    private var perfWorstNodes = 0
    private var perfWorstTextures = 0
    private var perfWorstShapes = 0
    private var perfWorstProjectiles = 0
    private var perfWorstEnemies = 0
    private var perfWorstAllies = 0
    private var perfSampleAccum: TimeInterval = 0
    private var perfNodes = 0
    private var perfDraws = 0
    private var perfOffscreen = 0
    private var perfTextures = 0
    private var perfShapes = 0
    private var perfProjectiles = 0
    private var perfEnemies = 0
    private var perfAllies = 0
    private var perfMemoryMB: Double = 0
    private var perfScreen = DebugDeviceInfo.screen

    var perfSnapshot: DebugMetricsSnapshot {
        DebugMetricsSnapshot(fps: fpsSmoothed,
                             frameMs: perfFrameMs,
                             peakMs: perfPeakMs,
                             cpuMs: perfCPUMs,
                             nodes: perfNodes,
                             draws: perfDraws,
                             offscreen: perfOffscreen,
                             textures: perfTextures,
                             shapes: perfShapes,
                             projectiles: perfProjectiles,
                             enemies: perfEnemies,
                             allies: perfAllies,
                             hitches: perfHitches,
                             worstCPUms: perfWorstCPUms,
                             worstDraws: perfWorstDraws,
                             worstNodes: perfWorstNodes,
                             worstTextures: perfWorstTextures,
                             worstShapes: perfWorstShapes,
                             worstProjectiles: perfWorstProjectiles,
                             worstEnemies: perfWorstEnemies,
                             worstAllies: perfWorstAllies,
                             memoryMB: perfMemoryMB,
                             thermal: DebugDeviceInfo.thermal,
                             lowPower: DebugDeviceInfo.lowPower,
                             device: DebugDeviceInfo.device,
                             os: DebugDeviceInfo.os,
                             screen: perfScreen,
                             gpu: DebugDeviceInfo.gpu,
                             ramGB: DebugDeviceInfo.ramGB,
                             cores: DebugDeviceInfo.cores,
                             maxHz: DebugDeviceInfo.maxHz)
    }

    /// Refresh node/draw/projectile counts a few times per second. Walking
    /// the live scene graph is cheap at 4 Hz and keeps the SwiftUI poll light.
    private func refreshPerfCounts() {
        let viewW = size.width * cam.xScale
        let viewH = size.height * cam.xScale
        let viewRect = CGRect(x: cam.position.x - viewW / 2,
                              y: cam.position.y - viewH / 2,
                              width: viewW, height: viewH).insetBy(dx: -40, dy: -40)
        var nodes = 0
        var draws = 0
        var offscreen = 0
        var shapes = 0
        var textures = Set<ObjectIdentifier>()
        func walk(_ node: SKNode, parentVisible: Bool) {
            nodes += 1
            let visible = parentVisible && !node.isHidden && node.alpha > 0.01
            if visible {
                let sceneFrame = node.parent?.convert(node.frame, to: self) ?? node.frame
                let inView = sceneFrame.intersects(viewRect)
                if inView { draws += 1 } else { offscreen += 1 }
                if let sprite = node as? SKSpriteNode {
                    if inView, let texture = sprite.texture {
                        textures.insert(ObjectIdentifier(texture))
                    }
                } else if node is SKShapeNode, inView {
                    shapes += 1
                }
            }
            for child in node.children { walk(child, parentVisible: visible) }
        }
        walk(self, parentVisible: true)
        perfNodes = nodes
        perfDraws = draws
        perfOffscreen = offscreen
        perfTextures = textures.count
        perfShapes = shapes
        perfProjectiles = projectiles.count
        perfEnemies = enemies.count
        perfAllies = allies.count
        perfMemoryMB = DebugDeviceInfo.footprintMB()
        perfScreen = DebugDeviceInfo.screen
    }

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
            heroMaxHP: heroMaxHP,
            heroLives: heroLives,
            heroMaxLives: Balance.heroLives,
            shieldHP: shieldHP,
            shieldMax: shieldMax,
            packReady: heroPackArmed && hero.alive && heroHP < heroMaxHP,
            packAmount: HeroAddons.boosterHeal(
                tier: HeroAddons.boosterTier(heroId: heroId)),
            bomberLocked: !bomberUnlocked,
            bomberReady: bomberUnlocked && bomberCooldownLeft <= 0 && bomberRun == nil,
            bomberCooldown: bomberCooldownLeft,
            bomberTargeting: bomberTargeting,
            money: money,
            allyXs: allies.filter { $0.alive }.map { $0.position.x },
            enemyXs: enemies.filter { $0.alive }.map { $0.position.x },
            ammoText: ammoDisplayText,
            ammoMag: mags[heroWeapon.rawValue],
            reloading: reloadingWeapon == heroWeapon,
            won: wonAt != nil,
            winTime: wonAt ?? 0,
            lost: lostAt != nil,
            summonCooldowns: summonCooldowns,
            allyCount: allies.count,
            allyCap: Balance.maxAllies,
            playerHQAlive: bases.first(where: { $0.team == .player })?.alive ?? true
        )
    }

    // MARK: - Gun ammo readout (shown as 12/90 on the HUD gun button)
    private var ammoDisplayText: String {
        let i = heroWeapon.rawValue
        let stock = heroWeapon.hasInfiniteAmmo ? "∞" : "\(reserves[i])"
        if reloadingWeapon == heroWeapon { return "REL \(mags[i])/\(stock)" }
        return "\(mags[i])/\(stock)"
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
        if heroHP >= heroMaxHP {
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
            heroHP = min(heroMaxHP, heroHP + Balance.dropHeal)
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

    // MARK: - Droid companion: follow, acquire, fire
    /// The owned battle droid hovers over the hero's back shoulder and
    /// fires its own blaster at the nearest enemy in range. Hidden while
    /// the hero is down; reborn beside him on respawn. Must run before
    /// stepProjectiles so its bolts join this frame's sim.
    private func updateDroid(dt: TimeInterval) {
        guard let droid, hero.alive else {
            droid?.isHidden = true
            return
        }
        droid.isHidden = false
        droid.fireCooldown -= dt
        // Anchor: above + behind the facing shoulder, eased toward every
        // frame so the droid trails flight-smooth instead of teleporting.
        let anchor = CGPoint(x: hero.position.x - hero.facingX * Balance.droidFollowX,
                             y: hero.position.y + Balance.droidHoverHeight)
        let prevX = droid.position.x
        let k = min(1, 5 * CGFloat(dt))
        droid.position.x += (anchor.x - droid.position.x) * k
        droid.position.y += (anchor.y - droid.position.y) * k
        droid.hover(dt: dt, velX: (droid.position.x - prevX) / max(0.001, CGFloat(dt)))

        guard let target = droidTarget(from: droid.position) else {
            droid.face(hero.facingX)
            return
        }
        droid.face(target.x - droid.position.x)
        guard droid.fireCooldown <= 0 else { return }
        droid.fireCooldown = Balance.droidCooldown
        fireDroidBolt(from: droid, to: target)
    }

    /// Nearest thing worth shooting within droid range: marchers first,
    /// then towers, then the HQ — same hunger as the army, smaller teeth.
    private func droidTarget(from pos: CGPoint) -> CGPoint? {
        var best: CGPoint?
        var bestDist = Balance.droidRange
        for e in enemies where e.alive {
            let d = hypot(e.position.x - pos.x, e.position.y - pos.y)
            if d < bestDist { bestDist = d; best = e.position }
        }
        if best != nil { return best }
        for t in towers where t.team == .enemy && t.alive {
            let p = CGPoint(x: t.node.position.x, y: Balance.groundTopY + 100)
            let d = hypot(p.x - pos.x, p.y - pos.y)
            if d < bestDist { bestDist = d; best = p }
        }
        if best != nil { return best }
        if let base = bases.first(where: { $0.team == .enemy }), base.alive {
            let p = CGPoint(x: base.node.position.x, y: Balance.groundTopY + 100)
            if hypot(p.x - pos.x, p.y - pos.y) < bestDist { best = p }
        }
        return best
    }

    private func fireDroidBolt(from droid: DroidNode, to target: CGPoint) {
        let muzzle = droid.muzzle()
        let base = atan2(target.y - muzzle.y, target.x - muzzle.x)
        // Elite droids fan a 3-shot spread of scout-grade pellets;
        // gunships fire one harder bolt; scouts one standard bolt.
        let tier = HeroAddons.droidTier(heroId: heroId)
        let pellets = tier >= 3 ? 3 : 1
        let damage: CGFloat = tier == 2 ? Balance.droidDamageTier2 : Balance.droidDamage
        SoundEngine.shared.allyFire(at: muzzle.x)
        for k in 0..<pellets {
            let offset = (CGFloat(k) - CGFloat(pellets - 1) / 2) * Balance.droidPelletSpread
            let a = base + offset
            let dir = CGVector(dx: cos(a), dy: sin(a))
            let bolt = ProjectileFactory.makeTowerBolt(team: .player)
            bolt.setScale(0.6)
            bolt.position = muzzle
            bolt.zRotation = a
            world.addChild(bolt)
            projectiles.append(Projectile(node: bolt, dir: dir,
                                          life: Double(Balance.droidRange / Balance.droidBoltSpeed),
                                          speed: Balance.droidBoltSpeed,
                                          damage: damage, team: .player))
        }
        let flash = ProjectileFactory.makeMuzzleFlash()
        flash.setScale(0.6)
        flash.position = muzzle
        world.addChild(flash)
    }

    /// Owned heroes field the droid at its bought tier; everyone else
    /// flies solo. Keeps the node across resets (it eases to the fresh
    /// anchor on its own), rebuilding only when the tier changed.
    private func ensureDroid() {
        let tier = HeroAddons.droidTier(heroId: heroId)
        if tier > 0, droid == nil || droid?.tier != tier {
            droid?.removeFromParent()
            let d = DroidNode(tier: tier)
            d.position = CGPoint(x: hero.position.x - hero.facingX * Balance.droidFollowX,
                                 y: hero.position.y + Balance.droidHoverHeight)
            d.zPosition = 9
            world.addChild(d)
            droid = d
        } else if tier == 0, let d = droid {
            d.removeFromParent()
            droid = nil
        }
    }
}

// MARK: - Droid companion node (battle buddy)

/// Little circular hover droid: dome body, cyan eye, nose blaster, halo
/// breathing underneath. Banks into lateral motion; the nose flips with
/// xScale to face targets. Never targeted — equipment that shoots.
final class DroidNode: SKNode {
    private let body: SKSpriteNode
    private var t: TimeInterval = 0
    private var trailAcc: TimeInterval = 0
    var fireCooldown: TimeInterval = 0
    /// Add-on tier driving the body art (1 scout, 2 gunship, 3 elite).
    let tier: Int

    init(tier: Int) {
        self.tier = tier
        body = SKSpriteNode(texture: DroidArt.texture(tier))
        body.size = DroidArt.displaySize
        super.init()
        addChild(body)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Face travel/target direction (nose barrel flips with xScale).
    func face(_ dx: CGFloat) {
        guard dx != 0 else { return }
        xScale = dx < 0 ? -1 : 1
    }

    /// Hover bob + bank into lateral motion + faint ion trail shed below.
    func hover(dt: TimeInterval, velX: CGFloat) {
        t += dt
        body.position.y = sin(t * 3.1) * 4
        body.zRotation = max(-0.2, min(0.2, -velX * 0.0004))
        trailAcc += dt
        if trailAcc >= 0.12 {
            trailAcc = 0
            spawnTrailMote()
        }
    }

    /// Tiny cyan mote falling away beneath the droid — reads as engine
    /// wash without any persistent shadow blob.
    private func spawnTrailMote() {
        guard let parent else { return }
        let side = CGFloat.random(in: 2...3.5)
        let mote = SKSpriteNode(color: SKColor(red: 0.4, green: 0.9, blue: 1,
                                               alpha: 0.7),
                                size: CGSize(width: side, height: side))
        mote.position = CGPoint(x: position.x + CGFloat.random(in: -10...10),
                                y: position.y - 14)
        mote.zPosition = 8
        parent.addChild(mote)
        let dur = TimeInterval.random(in: 0.3...0.45)
        mote.run(.sequence([
            .group([
                .moveBy(x: CGFloat.random(in: -8...8),
                        y: CGFloat.random(in: -50...(-30)), duration: dur),
                .fadeOut(withDuration: dur),
            ]),
            .removeFromParent(),
        ]))
    }

    /// Nose-barrel tip in parent space (muzzle for bolts).
    func muzzle() -> CGPoint {
        guard let parent else { return position }
        return convert(CGPoint(x: 16 * xScale, y: 0), to: parent)
    }
}
