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
    enum BGTheme { case twilight, overgrown, bastion }

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
        // MARK: - Structure durability (matches the LevelDef dossier)
        var towerHP: CGFloat
        var baseHP: CGFloat
    }

    /// Level 1: the original 5200pt Twilight lane, 2 towers per side.
    private static let layout1 = LevelLayout(
        width: 5200,
        playerBaseX: 220,
        playerTowerXs: [800, 1450],
        enemyTowerXs: [3750, 4400],
        enemyBaseX: 4980,
        heroSpawnX: 420,
        platforms: [
            CGRect(x: 1960, y: 300, width: 320, height: 36),
            CGRect(x: 2440, y: 420, width: 320, height: 36),
            CGRect(x: 2920, y: 300, width: 320, height: 36),
        ],
        theme: .twilight,
        flags: false,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 8.0,
        doubleChance: 0.0,
        maxEnemies: 6,
        bruteEvery: 0,
        towerHP: 200,
        baseHP: 500
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
        platforms: [
            CGRect(x: 2560, y: 300, width: 320, height: 36),
            CGRect(x: 3040, y: 420, width: 320, height: 36),
            CGRect(x: 3520, y: 300, width: 320, height: 36),
            CGRect(x: 4000, y: 420, width: 320, height: 36),
            CGRect(x: 4480, y: 300, width: 320, height: 36),
        ],
        theme: .overgrown,
        flags: true,
        alienBirds: true,
        lushFlora: true,
        summonInterval: 7.0,
        doubleChance: 0.45,
        maxEnemies: 8,
        bruteEvery: 0,
        towerHP: 220,
        baseHP: 550
    )

    /// Level 3 Thornwood Bastion: longest lane yet (7200pt), 3 towers per
    /// side like Level 2 but shifted inward, and a stepped bastion-approach
    /// platform run with a high perch mid-lane. Timber-ember grade.
    /// Easy-to-medium flow: steady raiders, occasional pairs, and every
    /// 4th summon a Brute (first one ~25s in — easy start, medium punch).
    private static let layout3 = LevelLayout(
        width: 7200,
        playerBaseX: 220,
        playerTowerXs: [750, 1450, 2150],
        enemyTowerXs: [5050, 5750, 6450],
        enemyBaseX: 6980,
        heroSpawnX: 420,
        platforms: [
            CGRect(x: 2500, y: 280, width: 300, height: 36),
            CGRect(x: 2960, y: 400, width: 300, height: 36),
            CGRect(x: 3420, y: 480, width: 280, height: 36),
            CGRect(x: 3860, y: 360, width: 300, height: 36),
            CGRect(x: 4320, y: 280, width: 320, height: 36),
        ],
        theme: .bastion,
        flags: true,
        alienBirds: true,
        lushFlora: true,
        summonInterval: 6.0,
        doubleChance: 0.35,
        maxEnemies: 9,
        bruteEvery: 4,
        towerHP: 250,
        baseHP: 600
    )

    /// Active battlefield. GameScene sets this from the level id before
    /// building (init + didMove). Defaults to Level 1 (menu previews etc.).
    static var active = layout1

    static func layout(for levelId: Int) -> LevelLayout {
        switch levelId {
        case 2: return layout2
        case 3: return layout3
        default: return layout1
        }
    }

    // MARK: - Level layout (points; follow `active`)
    static var levelWidth: CGFloat { active.width }
    static var groundTopY: CGFloat = 120        // y of the walkable surface
    static var groundThickness: CGFloat = 120
    static var viewHeight: CGFloat = 750        // logical scene height

    // MARK: - Structures (x centers; towers guard each base from mid:
    // base -> tower(s) -> mid, mirrored per side)
    static var playerBaseX: CGFloat { active.playerBaseX }
    static var playerTowerXs: [CGFloat] { active.playerTowerXs }
    static var enemyTowerXs: [CGFloat] { active.enemyTowerXs }
    static var enemyBaseX: CGFloat { active.enemyBaseX }

    // MARK: - Platforms (mid-map verticality for the hero; physics lands next stage)
    static var platforms: [CGRect] { active.platforms }

    // MARK: - Hero (visual only this stage; movement stats used next stage)
    static var heroSpawnX: CGFloat { active.heroSpawnX }
    static let heroHeight: CGFloat = 78

    // MARK: - Hero movement feel (smooth, not snappy: eased drive in,
    // long glide out, floaty variable jumps)
    static let heroRunSpeed: CGFloat = 520
    static let heroJumpVelocity: CGFloat = 1000
    static let heroGravity: CGFloat = -1850   // jump apex ≈ 270pt: clears the 216pt rise to platform 1
    static let heroAccelGround: CGFloat = 2600 // driving (stick held): eager but not instant
    static let heroDecelGround: CGFloat = 2000 // stick released: long glide to a stop
    static let heroAccelAir: CGFloat = 1700   // air steering: present but soft
    static let heroAirDrag: CGFloat = 350     // no-input air drift: momentum mostly preserved
    static let heroStopThreshold: CGFloat = 12 // below this grounded drift, just rest
    static let heroJumpCutFraction: CGFloat = 0.5 // early release bleeds half the rise (tap = hop)
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
    static let towerFireCooldown: Double = 1.1 // seconds between tower shots
    static let towerDamage: CGFloat = 12
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
    static let firstSummonDelay: Double = 5.0
    /// Raider (the classic marcher — Levels 1+).
    static let enemyHP: CGFloat = 40
    static let enemySpeed: CGFloat = 120
    static let killReward: Int = 100           // Unity KillEnemy gold
    // Ranged troopers: advance, stop at shooting range, fire bolts.
    static let enemySightRange: CGFloat = 550  // notice the hero this far away
    static let enemyShootRange: CGFloat = 380  // stop + shoot this close to target
    static let enemyFireCooldown: Double = 1.7
    static let enemyBoltDamage: CGFloat = 8
    /// Brute (bulky siege marcher — Level 3+): slow, tanky, hits like a
    /// tower bolt and pays a premium when dropped.
    static let bruteHP: CGFloat = 150
    static let bruteSpeed: CGFloat = 70
    static let bruteReward: Int = 175
    static let bruteSightRange: CGFloat = 500
    static let bruteShootRange: CGFloat = 330
    static let bruteFireCooldown: Double = 2.2
    static let bruteBoltDamage: CGFloat = 16
    static let enemyBoltSpeed: CGFloat = 520
    static let enemyBoltLife: Double = 1.2     // range ≈ 624: outranged by the hero

    // MARK: - Drops (dead enemies randomly leave ammo/health for the hero)
    static let dropChance: Double = 0.4      // roll per enemy kill
    static let dropHeal: CGFloat = 30        // health-pack heal (capped at max)
    static let dropMoney: Int = 50           // gold-coin pickup value
    static let dropLifetime: Double = 15.0   // seconds before a drop expires
    static let dropAmmoMultiplier: Int = 2   // ammo drop = killAmmo x this, per gun

    // MARK: - Player army (summoned from cards, marches toward the enemy base)
    static let maxAllies: Int = 10
    // Trooper: cheap, fast, light. Heavy: pricey, slow, tanky + hard-hitting.
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
