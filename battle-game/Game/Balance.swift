import CoreGraphics

/// Single tuning file for Level 1. Ported from your Unity balance:
/// tower HP 200, base HP 500, starting gold 500 — plus layout numbers.
/// No magic numbers in GameScene; everything reads from here.
///
/// Per-level battlefields: layout values (width, structures, platforms)
/// read from `active`, which the scene sets from `layout(for:)` before
/// building. They stay `Balance.*` at call sites, so all readers follow
/// the current level with zero signature churn. Builds are synchronous on
/// the main thread, so the mutable active layout is race-free.
enum Balance {
    // MARK: - Battlefield themes (same Twilight concept, per-level grade)
    /// Twilight Ruins (Level 1): indigo dusk. Overgrown Expanse (Level 2):
    /// alien jungle — teal-green grade, denser canopy, heavier glow flora.
    /// Thornwood Bastion (Level 3): ember-amber timber grade, russet canopy.
    /// Dune Atoll (Level 4): early dawn — a touch brighter, pale-gold
    /// horizon, dry open treeline, sandy lane wash.
    /// Sunscorch Expanse (Level 5): high noon — brightest so far, bleached
    /// sky, open rolling fields, no platforms.
    /// Sandhold Citadel (Level 6): burnt-orange desert-keep dusk, fortress
    /// silhouette, shadow flyers circling the far range.
    /// Sirocco Dunes (Level 7): golden desert day — rolling dune sea,
    /// wavy walkable fields, hazy ridge lines, drifting sand.
    /// Oasis Waste (Level 8): greener desert — palm oases + ruin arches
    /// + bone fields in the distance, crawling sand creatures.
    /// Duskfall Flats (Level 9): the sun going down over the desert —
    /// darker, deep indigo sky, stars out, ember-lit mesas.
    /// Moonveil Dunes (Level 10): the desert after dark — deep navy sky,
    /// a huge cold moon, moonlit warm sand and glass-shard glitter.
    enum BGTheme { case twilight, overgrown, bastion, dawn, sunscorch, sandhold, dunesea, oasis, duskdesert, nightdesert }

    // MARK: - Per-level battlefield layout
    struct LevelLayout {
        var width: CGFloat
        var playerBaseX: CGFloat
        var playerTowerXs: [CGFloat]
        var enemyTowerXs: [CGFloat]
        var enemyBaseX: CGFloat
        var heroSpawnX: CGFloat
        var platforms: [CGRect]
        var theme: BGTheme
        /// War-banner poles along the lane.
        var flags: Bool
        /// Extraterrestrial sky-flocks (manta-rayeds with glow eyes).
        var alienBirds: Bool
        /// Extra glow-fern / shroom clusters on the ground.
        var lushFlora: Bool
        // MARK: - Enemy summon tuning (enemy base marchers)
        /// Seconds between summon ticks.
        var summonInterval: Double
        /// Chance a tick pops a PAIR out of the gate instead of one.
        var doubleChance: Double
        /// Marcher cap on the field.
        var maxEnemies: Int
        /// Every Nth summon marches out a Brute instead of a Raider
        /// (0 = never — Levels 1-2 field raiders only).
        var bruteEvery: Int
        /// Every Nth summon rushes out a Reaver axe-fighter instead
        /// (0 = never — Levels 1-3 never see axes; Brutes win ties).
        var reaverEvery: Int
        /// Every Nth summon scuttles out a Skitter zergling instead
        /// (0 = never — Levels 1-5 never see claws; Brutes then
        /// Reavers win ties).
        var skitterEvery: Int
        /// Every Nth summon flies in a Jet gun-robot instead
        /// (0 = never — Levels 1-6 never see jets; Brutes, Reavers,
        /// then Skitters win ties).
        var jetEvery: Int
        /// Every Nth summon rolls out a heavy Mech walker instead
        /// (0 = never — the mech debuts late; Brutes and Reavers win
        /// ties against it).
        var mechEvery: Int
        /// How many mechs leave the gate in one mech summon (1 = single).
        /// Level 10 sends a pair, spaced by `mechPairDelay`.
        var mechPairSize: Int = 1
        /// Seconds between each mech in a pair.
        var mechPairDelay: Double = 1.0
        // MARK: - Structure durability (matches the LevelDef dossier)
        var towerHP: CGFloat
        var baseHP: CGFloat
        /// Enemy marcher HP multiplier (1.0 = base stats; Level 5+ = 1.05,
        /// later levels stack further). Applies to raider/brute/reaver.
        var enemyHPScale: CGFloat
    }

    /// Level 1: the original 5200pt Twilight lane, 2 towers per side.
    private static let layout1 = LevelLayout(
        width: 5200,
        playerBaseX: 220,
        playerTowerXs: [800, 1450],
        enemyTowerXs: [3750, 4400],
        enemyBaseX: 4980,
        heroSpawnX: 420,
        platforms: [],
        theme: .twilight,
        flags: false,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 8.0,
        doubleChance: 0.0,
        maxEnemies: 20,
        bruteEvery: 0,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 200,
        baseHP: 500,
        enemyHPScale: 1.0
    )

    /// Level 2 Rootwall Thicket: bigger 6800pt overgrown map, 3 towers per
    /// side guarding each base, extra mid platforms, full dressing pack.
    private static let layout2 = LevelLayout(
        width: 6800,
        playerBaseX: 220,
        playerTowerXs: [800, 1500, 2200],
        enemyTowerXs: [4600, 5300, 6000],
        enemyBaseX: 6580,
        heroSpawnX: 420,
        platforms: [],
        theme: .overgrown,
        flags: true,
        alienBirds: true,
        lushFlora: true,
        summonInterval: 7.0,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 0,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 220,
        baseHP: 550,
        enemyHPScale: 1.0
    )

    /// Level 3 Thornwood Bastion: longest lane yet (7200pt), 3 towers per
    /// side like Level 2 but shifted inward. Open fields, no platforms.
    /// Timber-ember grade.
    /// Easy-to-medium flow: steady raiders, occasional pairs, and every
    /// 4th summon a Brute (first one ~25s in — easy start, medium punch).
    private static let layout3 = LevelLayout(
        width: 7200,
        playerBaseX: 220,
        playerTowerXs: [750, 1450, 2150],
        enemyTowerXs: [5050, 5750, 6450],
        enemyBaseX: 6980,
        heroSpawnX: 420,
        platforms: [],
        theme: .bastion,
        flags: true,
        alienBirds: true,
        lushFlora: true,
        summonInterval: 6.0,
        doubleChance: 0.35,
        maxEnemies: 20,
        bruteEvery: 4,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 250,
        baseHP: 600,
        enemyHPScale: 1.0
    )

    /// Level 4 Dune Atoll: open 7400pt white-sand crossing, 3 towers per
    /// side pushed wider apart. Open fields, no platforms.
    /// Dawn grade (see .dawn). Hotter flow: raiders every 5.5s with frequent
    /// pairs, a Reaver axe-rush every 3rd summon, and a Brute every 6th
    /// (Brutes win the 6th-summon tie) — plus the Scatter unlock in hand.
    private static let layout4 = LevelLayout(
        width: 7400,
        playerBaseX: 220,
        playerTowerXs: [700, 1400, 2100],
        enemyTowerXs: [5200, 5900, 6600],
        enemyBaseX: 7180,
        heroSpawnX: 420,
        platforms: [],
        theme: .dawn,
        flags: true,
        alienBirds: true,
        lushFlora: false,
        summonInterval: 5.5,
        doubleChance: 0.40,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 260,
        baseHP: 650,
        enemyHPScale: 1.0
    )

    /// Level 5 Sunscorch Expanse: longest lane yet (8000pt), 3 towers per
    /// side spread wide, ZERO jumping platforms — open rolling fields with
    /// very small dips and a gentle ascent mid-lane (visual swells only,
    /// gameplay stays flat). High-noon grade: brightest sky so far.
    /// Flow untouched for now (same summon line as Level 4); units + game
    /// tuning lands next. Structure HP matches the LevelDef dossier.
    private static let layout5 = LevelLayout(
        width: 8000,
        playerBaseX: 220,
        playerTowerXs: [700, 1450, 2200],
        enemyTowerXs: [5600, 6350, 7100],
        enemyBaseX: 7780,
        heroSpawnX: 420,
        platforms: [],
        theme: .sunscorch,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 5.5,
        doubleChance: 0.40,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 300,
        baseHP: 700,
        enemyHPScale: 1.05
    )

    /// Level 6 Sandhold Citadel: 8400pt desert-keep siege lane, 3 towers
    /// per side. Open fields, no platforms. Burnt-orange
    /// keep-dusk grade with shadow flyers circling far. Hotter flow:
    /// pairs often, Reavers every 3rd, Skitter zerg-rush every 2nd, Brute
    /// every 6th (Brutes then Reavers win ties). Enemy HP ×1.1025 (+5%
    /// over Level 5, compounding). Structure HP matches the dossier.
    private static let layout6 = LevelLayout(
        width: 8400,
        playerBaseX: 220,
        playerTowerXs: [700, 1450, 2200],
        enemyTowerXs: [6000, 6750, 7500],
        enemyBaseX: 8180,
        heroSpawnX: 420,
        platforms: [],
        theme: .sandhold,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 5.0,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 320,
        baseHP: 800,
        enemyHPScale: 1.1025
    )

    /// Level 7 Sirocco Dunes: 8800pt desert siege lane, 3 towers
    /// per side. Straight sand field like the other lanes; the dunes
    /// live in the background art. Golden desert-day grade
    /// with pixel ridge lines + drifting sand. Hotter flow: pairs often,
    /// Reavers every 3rd, Skitters every 2nd, Brute every 6th (Brutes then
    /// Reavers win ties). Enemy HP ×1.1576 (+5% over Level 6,
    /// compounding). Structure HP matches the dossier.
    private static let layout7 = LevelLayout(
        width: 8800,
        playerBaseX: 220,
        playerTowerXs: [750, 1500, 2250],
        enemyTowerXs: [6350, 7100, 7850],
        enemyBaseX: 8580,
        heroSpawnX: 420,
        platforms: [],
        theme: .dunesea,
        flags: false,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 5.0,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 5,
        mechEvery: 0,
        towerHP: 350,
        baseHP: 900,
        enemyHPScale: 1.1576
    )

    /// Level 8 Oasis Waste: 9200pt desert-oasis siege lane, 3 towers
    /// per side. Desert again but greener + ornamented: palm oases,
    /// ruin arches and bone fields in the distance, crawling sand
    /// creatures stalking the ridges. Straight sand field. Hotter flow:
    /// pairs often, Reavers every 3rd, Jets every 5th, Skitters every
    /// 2nd, Brute every 6th. Enemy HP ×1.2155 (+5% over Level 7,
    /// compounding). Structure HP matches the dossier.
    private static let layout8 = LevelLayout(
        width: 9200,
        playerBaseX: 220,
        playerTowerXs: [750, 1500, 2250],
        enemyTowerXs: [6650, 7400, 8150],
        enemyBaseX: 8980,
        heroSpawnX: 420,
        platforms: [],
        theme: .oasis,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 4.5,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 5,
        mechEvery: 0,
        towerHP: 400,
        baseHP: 1000,
        enemyHPScale: 1.2155
    )

    /// Level 9 Duskfall Flats: 9600pt desert at sundown, 3 towers per
    /// side. The sun is going down — indigo sky, stars out, ember-lit
    /// mesas, colder sand. Straight field. The heavy Mech walker
    /// debuts here (every 4th summon: Brutes/Reavers win ties, then
    /// the Mech, then Skitters/Jets). Enemy HP ×1.2763 (+5% over
    /// Level 8, compounding). Structure HP matches the dossier.
    private static let layout9 = LevelLayout(
        width: 9600,
        playerBaseX: 220,
        playerTowerXs: [780, 1550, 2320],
        enemyTowerXs: [7000, 7750, 8500],
        enemyBaseX: 9380,
        heroSpawnX: 420,
        platforms: [],
        theme: .duskdesert,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 4.5,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 5,
        mechEvery: 4,
        towerHP: 440,
        baseHP: 1100,
        enemyHPScale: 1.2763
    )

    /// Level 10 Moonveil Dunes: 10000pt desert under a cold moon, 3 towers
    /// per side. Same straight sand field as the other dune lanes; the
    /// night lives in the sky, ridge silhouettes and moonlit warm ground.
    /// Flow holds Level 9's pressure, Mech walkers still every 4th
    /// summon — but they now arrive as a pair, one beat apart, instead of
    /// one at a time. Enemy HP ×1.3401 (+5% over Level 9, compounding).
    /// Structure HP matches the dossier.
    private static let layout10 = LevelLayout(
        width: 10000,
        playerBaseX: 220,
        playerTowerXs: [820, 1620, 2420],
        enemyTowerXs: [7350, 8150, 8950],
        enemyBaseX: 9780,
        heroSpawnX: 420,
        platforms: [],
        theme: .nightdesert,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 4.5,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 5,
        mechEvery: 4,
        mechPairSize: 2,
        towerHP: 460,
        baseHP: 1150,
        enemyHPScale: 1.3401
    )

    /// Active battlefield. GameScene sets this from the level id before
    /// building (init + didMove). Defaults to Level 1 (menu previews etc.).
    static var active = layout1

    /// True while a battle scene owns the active layout. The menu and
    /// briefing dioramas dress themselves with it, but they must never
    /// re-pin it underneath a running battle (the diorama is rebuilt
    /// whenever SwiftUI re-renders, and a stale pin would swap the whole
    /// battlefield mid-fight).
    static var battleOwnsLayout = false

    static func layout(for levelId: Int) -> LevelLayout {
        switch levelId {
        case 2: return layout2
        case 3: return layout3
        case 4: return layout4
        case 5: return layout5
        case 6: return layout6
        case 7: return layout7
        case 8: return layout8
        case 9: return layout9
        case 10: return layout10
        default: return layout1
        }
    }

    // MARK: - Level layout (points; follow `active`)
    static var levelWidth: CGFloat { active.width }
    static var groundTopY: CGFloat = 120        // y of the walkable surface
    /// True on desert themes (dune sand + sand dressing; Level 7-10).
    static var dunes: Bool {
        let t = active.theme
        return t == .dunesea || t == .oasis || t == .duskdesert || t == .nightdesert
    }
    /// Walkable surface height at world x. Flat on every level, dunes
    /// included — straight fields everywhere.
    static func groundY(at x: CGFloat) -> CGFloat {
        _ = x
        return groundTopY
    }
    static var groundThickness: CGFloat = 120
    static var viewHeight: CGFloat = 750        // logical scene height

    // MARK: - Structures (x centers; towers guard each base from mid:
    // base -> tower(s) -> mid, mirrored per side)
    static var playerBaseX: CGFloat { active.playerBaseX }
    static var playerTowerXs: [CGFloat] { active.playerTowerXs }
    static var enemyTowerXs: [CGFloat] { active.enemyTowerXs }
    static var enemyBaseX: CGFloat { active.enemyBaseX }

    // MARK: - Platforms (empty on all levels: open fields only)
    static var platforms: [CGRect] { active.platforms }

    // MARK: - Hero (visual only this stage; movement stats used next stage)
    static var heroSpawnX: CGFloat { active.heroSpawnX }
    static let heroHeight: CGFloat = 78

    // MARK: - Hero movement feel (snappy, not floaty: fast drive in,
    // fast stop, turn boost for reversals, fall-faster-than-rise jumps
    // with an apex hang so landings are easy to line up — Celeste/GMTK
    // rules: ~6 frames to full speed, ~3-5 to stop, no ice)
    static let heroRunSpeed: CGFloat = 520
    static let heroJumpVelocity: CGFloat = 1000
    static let heroGravity: CGFloat = -2100   // rise: crisp, apex ≈ 238pt
    static let heroFallMultiplier: CGFloat = 1.5 // fall faster than rise: snappy, precise landings
    static let heroApexWindow: CGFloat = 140  // |vy| below this = apex hang zone
    static let heroApexScale: CGFloat = 0.55  // gravity inside the hang zone (floaty top, easy to steer)
    static let heroCutGravityScale: CGFloat = 2.0 // extra gravity while rising with jump released (variable height)
    static let heroJumpSpeedBonus: CGFloat = 0.12 // full-run takeoff jumps 12% higher (Mario-tiered feel)
    static let heroAccelGround: CGFloat = 4200 // driving (stick held): full speed in ~7 frames
    static let heroDecelGround: CGFloat = 4800 // stick released: stopped in ~6 frames, no ice
    static let heroTurnAccel: CGFloat = 6400 // reversing at speed: instant flip, tiny skid instead of slide
    static let heroAccelAir: CGFloat = 3000   // air steering: strong but not teleporty
    static let heroAirDrag: CGFloat = 1400    // no-input air drift: bleeds fast so drops land where aimed (Celeste air friction)
    static let heroStopThreshold: CGFloat = 12 // below this grounded drift, just rest
    static let heroJumpCutFraction: CGFloat = 0.55 // early release bleeds the rise once (tap = hop)
    static let heroCoyoteTime: Double = 0.12
    static let heroJumpBuffer: Double = 0.15  // taps just before landing still jump

    // MARK: - Shooting (tap right side to aim + fire)
    static let bulletSpeed: CGFloat = 950
    static let fireCooldown: Double = 0.26 // hold touch = auto-fire at this cadence
    // NOTE: hero bolt lifetime moved to HeroWeapon.bulletLife (per-gun range
    // tuning lives with the guns, not here).
    static let heroDamage: CGFloat = 10
    static let heroHP: CGFloat = 100
    /// Full deaths the hero survives per attempt. Each death costs one
    /// heart (HUD); the run ends in defeat when the last heart is lost.
    static let heroLives: Int = 3
    static let startingGold: Int = 500 // Unity PlayerMoney.startingMoney
    // MARK: - Hero respawn (dropped from above, in front of the player base)
    static let respawnDelay: Double = 2.0      // seconds dead before the drop
    static let respawnOffsetX: CGFloat = 150   // in front of the player base, toward mid
    static let respawnDropHeight: CGFloat = 520 // spawn this high above ground, then fall
    static let respawnGrace: Double = 1.0      // invulnerable seconds after landing

    // MARK: - Tower combat (towers fire at enemies in proximity)
    /// Per-level via the layout table (matches each LevelDef dossier).
    static var towerHP: CGFloat { active.towerHP }
    static let towerRange: CGFloat = 750       // acquire targets within this distance
    static let towerFireCooldown: Double = 1.1 // seconds between tower volleys
    static let towerDamage: CGFloat = 12       // per bolt (3-bolt fan, like the HQ)
    static let towerBulletSpeed: CGFloat = 620
    static let towerBulletLife: Double = 2.2   // range ≈ speed × life, comfortably covers towerRange
    static let towerMuzzleHeight: CGFloat = 150 // muzzle above ground (near tower top)

    // MARK: - Main base (enemy base fans 3 bolts + summons marchers)
    /// Per-level via the layout table (matches each LevelDef dossier).
    static var baseHP: CGFloat { active.baseHP }
    static let baseRange: CGFloat = 900        // fan fires when the hero closes in
    static let baseFireCooldown: Double = 2.4
    static let baseFanCount: Int = 3           // 3 blasts, same muzzle, spread out
    static let baseFanSpread: CGFloat = 0.16   // radians between fan bolts (~9°)
    static let baseBoltDamage: CGFloat = 10
    static let baseMuzzleHeight: CGFloat = 140
    static let baseMuzzleForward: CGFloat = 60 // muzzle sits toward the enemy side

    // MARK: - Summoned enemies (march on the enemy base's side toward your base)
    // Per-level via the layout table (L1: single every 8s, cap 6 — untouched).
    static var summonInterval: Double { active.summonInterval }
    static var summonDoubleChance: Double { active.doubleChance }
    static var maxEnemies: Int { active.maxEnemies }
    static var bruteEvery: Int { active.bruteEvery }
    static var reaverEvery: Int { active.reaverEvery }
    static var skitterEvery: Int { active.skitterEvery }
    static var jetEvery: Int { active.jetEvery }
    static var mechEvery: Int { active.mechEvery }
    static var mechPairSize: Int { active.mechPairSize }
    static var mechPairDelay: Double { active.mechPairDelay }
    static let firstSummonDelay: Double = 5.0
    /// Raider (the classic marcher — Levels 1+). Base 40; Level 5+ scales
    /// via the layout's enemyHPScale (L5 = ×1.05, L6 = ×1.1025).
    static var enemyHP: CGFloat { 40 * active.enemyHPScale }
    static let enemySpeed: CGFloat = 120
    static let killReward: Int = 100           // Unity KillEnemy gold
    // Ranged troopers: advance, stop at shooting range, fire bolts.
    static let enemySightRange: CGFloat = 550  // notice the hero this far away
    static let enemyShootRange: CGFloat = 380  // stop + shoot this close to target
    static let enemyFireCooldown: Double = 1.7
    static let enemyBoltDamage: CGFloat = 8
    /// Brute (bulky siege marcher — Level 3+): slow, tanky, hits like a
    /// tower bolt and pays a premium when dropped. Base 150, scaled.
    static var bruteHP: CGFloat { 150 * active.enemyHPScale }
    static let bruteSpeed: CGFloat = 70
    static let bruteReward: Int = 175
    static let bruteSightRange: CGFloat = 500
    static let bruteShootRange: CGFloat = 330
    static let bruteFireCooldown: Double = 2.2
    static let bruteBoltDamage: CGFloat = 16
    /// Reaver (axe melee rusher — Level 4+): fast, closes to arm's length
    /// and chops for heavy damage. No bolts — the axe is the weapon.
    /// Base 90, scaled.
    static var reaverHP: CGFloat { 90 * active.enemyHPScale }
    static let reaverSpeed: CGFloat = 135
    static let reaverReward: Int = 150
    static let reaverSightRange: CGFloat = 560
    static let reaverMeleeRange: CGFloat = 70
    static let reaverSwingCooldown: Double = 1.9
    static let reaverMeleeDamage: CGFloat = 25
    /// Closing burst: triggers once per reaver inside this radius of its
    /// victim — a short 1.8x dash so the last stretch explodes inward.
    static let reaverBurstRange: CGFloat = 280
    static let reaverBurstTime: Double = 0.6
    static let reaverBurstSpeed: CGFloat = 1.8
    /// Skitter (claw melee rusher — Level 6+): zergling-fast, paper-thin,
    /// shreds in swarms. No bolts — the claws are the weapon. Base 50, scaled.
    static var skitterHP: CGFloat { 50 * active.enemyHPScale }
    static let skitterSpeed: CGFloat = 205
    static let skitterReward: Int = 70
    static let skitterSightRange: CGFloat = 620
    static let skitterMeleeRange: CGFloat = 62
    static let skitterSwingCooldown: Double = 1.2
    static let skitterMeleeDamage: CGFloat = 12
    /// Jetpack droid (flying gun-robot — Level 7+): hovers low over the
    /// lane on twin thrusters and shoots down at the line. Counts
    /// incoming shots and jukes up/down around every 5th bullet.
    /// Base 120, scaled.
    static var jetHP: CGFloat { 120 * active.enemyHPScale }
    static let jetSpeed: CGFloat = 165
    static let jetReward: Int = 200
    static let jetSightRange: CGFloat = 640
    static let jetShootRange: CGFloat = 400
    static let jetFireCooldown: Double = 1.6
    static let jetBoltDamage: CGFloat = 11
    static let jetHoverHeight: CGFloat = 90  // low cruise over the deck
    static let jetJukeHeight: CGFloat = 40   // dodge dip/rise amplitude
    /// How many jetpack droids fly out together (one after another).
    static let jetPairSize: Int = 2
    /// Mech walker (heavy robot — Level 9+): a slow, huge gun-platform
    /// that lobs machine-gun bursts (1, then 2, then 3 rounds a volley).
    /// Base 260, scaled.
    static var mechHP: CGFloat { 260 * active.enemyHPScale }
    static let mechSpeed: CGFloat = 48
    static let mechReward: Int = 350
    static let mechSightRange: CGFloat = 700
    static let mechShootRange: CGFloat = 520
    static let mechFireCooldown: Double = 2.4
    static let mechBoltDamage: CGFloat = 14
    /// Machine-gun burst: rounds per volley, ramping 1 -> 2 -> 3.
    static let mechBurstMax: Int = 3
    static let mechBurstGap: Double = 0.12   // seconds between rounds
    static let mechBoltSpeed: CGFloat = 640
    static let jetJukeTime: Double = 0.45    // out-and-back dodge duration
    static let jetJukeCooldown: Double = 0.6 // min gap between dodge triggers
    static let enemyBoltSpeed: CGFloat = 520
    static let enemyBoltLife: Double = 1.2     // range ≈ 624: outranged by the hero

    // MARK: - Drops (dead enemies randomly leave ammo/health for the hero)
    static let dropChance: Double = 0.4      // roll per enemy kill
    static let dropHeal: CGFloat = 30        // health-pack heal (capped at max)
    static let dropMoney: Int = 50           // gold-coin pickup value
    static let dropLifetime: Double = 15.0   // seconds before a drop expires
    static let dropAmmoMultiplier: Int = 2   // ammo drop = killAmmo x this, per gun

    // MARK: - Droid companion (owned battle buddy: hovers the back
    // shoulder, fires its own blaster at nearby enemies, dies/reborn
    // with the hero — never targeted, just equipment that shoots)
    static let droidDamage: CGFloat = 6
    static let droidDamageTier2: CGFloat = 10 // gunship droid hits harder
    static let droidPelletSpread: CGFloat = 0.14 // elite 3-shot fan (~8°)
    static let droidRange: CGFloat = 560
    static let droidCooldown: Double = 0.9
    static let droidBoltSpeed: CGFloat = 800
    static let droidFollowX: CGFloat = 55 // behind the facing shoulder
    static let droidHoverHeight: CGFloat = 95 // above the hero's head

    // MARK: - Player army (summoned from cards, marches toward the enemy base)
    // Army cap: the player can field this many units at once. The card
    // says FULL and the deploy toast explains it — never a silent no-op.
    static let maxAllies: Int = 20
    static let trooperCost: Int = 100
    static let trooperHP: CGFloat = 60
    static let trooperSpeed: CGFloat = 150
    static let trooperDamage: CGFloat = 10
    static let trooperFireCooldown: Double = 1.4
    static let trooperRange: CGFloat = 380
    static let trooperSightRange: CGFloat = 600
    static let heavyCost: Int = 250
    static let heavyHP: CGFloat = 170
    static let heavySpeed: CGFloat = 95
    static let heavyDamage: CGFloat = 22
    static let heavyFireCooldown: Double = 1.9
    static let heavyRange: CGFloat = 340
    static let heavySightRange: CGFloat = 550
    // Ranger: Level 2 long-rifle skirmisher. Outranges raiders (520 vs
    // their 380) so it shoots first, but folds fast when caught.
    static let rangerCost: Int = 175
    static let rangerHP: CGFloat = 50
    static let rangerSpeed: CGFloat = 165
    static let rangerDamage: CGFloat = 14
    static let rangerFireCooldown: Double = 1.1
    static let rangerRange: CGFloat = 520
    static let rangerSightRange: CGFloat = 650
    // Truck: Level 6 fast gun-truck. Fastest ally on wheels, turret gunner
    // on top — pricey, sturdy, hits hard on the move.
    static let truckCost: Int = 300
    static let truckHP: CGFloat = 240
    static let truckSpeed: CGFloat = 210
    static let truckDamage: CGFloat = 16
    static let truckFireCooldown: Double = 1.2
    static let truckRange: CGFloat = 420
    static let truckSightRange: CGFloat = 620

    // MARK: - Parallax scroll factors (ported from your Unity Parallaxing.cs idea:
    // background moves slower than the camera; factor 1.0 = locked to world)
    static let parallaxSky: CGFloat = 0.0
    static let parallaxFar: CGFloat = 0.15
    static let parallaxMid: CGFloat = 0.35
    static let parallaxForeground: CGFloat = 1.28

    // MARK: - Camera
    static let cameraZoom: CGFloat = 0.85  // zoomed out: hero reads smaller, more lane visible
    static let cameraYOffset: CGFloat = 120     // look slightly above ground
}
