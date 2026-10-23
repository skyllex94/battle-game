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
    /// Sunforge Redoubt (Level 11): the same night desert with a distant
    /// foundry burning on the horizon. Sirocco Canyon (Level 12): that
    /// night desert squeezed between moonlit canyon walls.
    /// Stonewatch Pass (Level 13): desert sunrise — the sun lifting over a
    /// hazy mountain range, warm morning light on the sand.
    /// Granite Reach (Level 14): the same sunrise over the same peaks, but
    /// the lane itself is bare alpine rock — no sand, no dunes.
    /// Riven Pass (Level 18): the same alpine shelf at evening, just before
    /// sunset — deep evening blue above, amber-gold horizon, low warm sun.
    enum BGTheme { case twilight, overgrown, bastion, dawn, sunscorch, sandhold, dunesea, oasis, duskdesert, nightdesert, sunrise, dusk, frost }

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
        /// Every Nth summon flies in a high-altitude Heli Gunship instead
        /// (0 = never — the gunship debuts in Level 13; earlier elites
        /// win ties against it).
        var heliEvery: Int = 0
        /// How many mechs leave the gate in one mech summon (1 = single).
        /// Level 10 sends a pair, spaced by `mechPairDelay`.
        var mechPairSize: Int = 1
        /// Seconds between each mech in a pair.
        var mechPairDelay: Double = 2.0
        // MARK: - Structure durability (matches the LevelDef dossier)
        var towerHP: CGFloat
        var baseHP: CGFloat
        /// Enemy marcher HP multiplier (1.0 = base stats; Level 5+ = 1.05,
        /// later levels stack further). Applies to raider/brute/reaver.
        var enemyHPScale: CGFloat
        /// Night-desert variation: distant foundry glow, chimney smoke and
        /// ember drift over the usual moonlit sand (Level 11).
        var forgeNight: Bool = false
        /// Night-desert variation: tall canyon buttes, layered rock walls
        /// and tumbled boulders framing the moonlit lane (Level 12).
        var canyonNight: Bool = false
        /// Sunrise-over-mountains variation: keep Level 13's sky and far
        /// peaks, but swap the desert field for bare granite, jagged mid
        /// ridges, alpine pines and rock outcrops (Level 14).
        var alpinePass: Bool = false
    /// Highridge Redoubt variation (Level 17): the same alpine shelf,
    /// but the field carries the redoubt's works (broken ramparts, gun
    /// emplacements, banners) and the mid-ground range carries the
    /// ridge fort itself.
    var ridgeRedoubt: Bool = false
    /// Stormcrown Summit variation (Level 19): the same dusk alpine
    /// shelf, but the sky sits under heavy storm slate — darker grade,
    /// thicker clouds, low-violet lightning flickering in the peaks.
    var stormSummit: Bool = false
    /// Ironhold snowfall (Level 20): the same storm shelf, but the storm
    /// finally drops its load — a SnowFX looping snow overlay drifts over
    /// the field (sprite-sheet loop, virtually free).
    var snowfall: Bool = false
        /// Summon numbers (1-based) that get an EXTRA Brute on top of the
        /// normal gate batch. Empty = no bonus Brutes.
        var extraBruteSummons: [Int] = []
        /// Summon numbers (1-based) that get an EXTRA Mech walker on top of
        /// the normal gate batch. Empty = no bonus Mechs.
        var extraMechSummons: [Int] = []
        /// Pine density for the alpine levels: 1 = the standard stands
        /// (far-range conifers, foreground pines, ground scrub), higher
        /// values thicken the treeline.
        var pineDensity: CGFloat = 1.0
        /// Bolts per tower volley: 1 = single shot, 3 = the fanned volley
        /// the towers switched to in Level 10.
        var towerFanCount: Int = 1
        /// Every Nth summon rolls out the missile truck instead of the
        /// normal unit (0 = the truck never shows up on this level).
        var truckEvery: Int = 0
        /// Missile trucks per truck wave.
        var truckCount: Int = 1
        /// Every Nth summon rolls out the Immortal (0 = never shows). The
        /// walker is a singleton: the next one only marches once the
        /// previous falls.
        var immortalEvery: Int = 0
        /// Every Nth summon floats in a Saucer gun-drone (0 = never
        /// shows). Heavy high-altitude saucer: cruises above the gunships
        /// and holds station to fire twin-blaster bursts (Level 24+).
        var saucerEvery: Int = 0
        /// DEV playground (Level 999): tiny arena, one player tower, no
        /// enemy tower, and the enemy gate releases only the unit under
        /// inspection. The PLAYGROUND button on the briefing screen is
        /// the only entry.
        var playground: Bool = false

        /// The lane is wind-glazed ice (Level 21+): ground sparkle texture,
        /// subtle slide on landing, and breath plumes on units.
        var iceField: Bool = false

        /// Whiteout Redoubt siege ground (Level 22): small pixel-art
        /// whispers frozen into the snow field — half-buried supply
        /// crates, wind-carved drifts, rime shards and wind-sheltered
        /// braziers (see LevelDressing.buildWhiteoutRedoubt).
        var whiteoutRedoubt: Bool = false

        /// Howling Causeway bridge ground (Level 23): small pixel-art
        /// whispers frozen into the snow field — lantern-lit marker
        /// posts, rime shards, wind-carved drifts and broken span stones
        /// (see LevelDressing.buildHowlingCauseway).
        var howlingCauseway: Bool = false

        /// Rimewatch Crag watch ground (Level 24): small pixel-art
        /// whispers frozen into the snow field — leaning blue-ice crag
        /// teeth, sundered watch-cairn rubble with cold-blue crystals,
        /// rime shards and wind-carved drifts
        /// (see LevelDressing.buildRimewatchCrag).
        var rimewatchCrag: Bool = false

        /// Frozen Narrows ice-channel ground (Level 25): small pixel-art
        /// whispers frozen into the snow field — brittle ice sheets,
        /// rime shards and wind-carved drifts
        /// (see LevelDressing.buildFrozenNarrows). The mid ground carries
        /// the matching small alteration (see FrostbiteBG.buildMid): pale
        /// ice floes.
        var frozenNarrows: Bool = false

        /// Rimevault vault ground (Level 26): small pixel-art whispers
        /// frozen into the snow field — sunken vault door-slabs, rime
        /// shards, wind-carved drifts and ember braziers burning against
        /// the evening cold (see LevelDressing.buildRimevault).
        var rimevault: Bool = false

        /// Frost evening grade (Level 26 Rimevault): the same frozen
        /// theater under a low amber sun — deep indigo zenith melting to
        /// ember-gold at the horizon. FrostbiteBG.buildSky reads this.
        var frostEvening: Bool = false

        /// The enemy kinds this level can actually summon, in roster order.
        /// Briefings use this instead of campaign unlock levels, so a level
        /// that disables a unit (e.g. Level 13 has no Reavers) doesn't list it.
        var enemyKinds: [EnemyKind] {
            var kinds: [EnemyKind] = [.raider]
            if bruteEvery > 0 || !extraBruteSummons.isEmpty { kinds.append(.brute) }
            if reaverEvery > 0 { kinds.append(.reaver) }
            if skitterEvery > 0 { kinds.append(.skitter) }
            if jetEvery > 0 { kinds.append(.jet) }
            if mechEvery > 0 { kinds.append(.mech) }
            if heliEvery > 0 { kinds.append(.heli) }
            if truckEvery > 0 { kinds.append(.missileTruck) }
            if immortalEvery > 0 { kinds.append(.immortal) }
            if saucerEvery > 0 { kinds.append(.saucer) }
            return kinds
        }
    }

    /// Active battlefield. GameScene sets this from the level id before
    /// building (init + didMove). Defaults to Level 1 (menu previews etc.).
    static var active = layout1

    /// True while a battle scene owns the active layout. The menu and
    /// briefing dioramas dress themselves with it, but they must never
    /// re-pin it underneath a running battle (the diorama is rebuilt
    /// whenever SwiftUI re-renders, and a stale pin would swap the whole
    /// battlefield mid-fight).
    static var battleOwnsLayout = false

    /// DEV playground level id (see the PLAYGROUND button on the briefing
    /// screen). Special-cased everywhere campaign scaling applies.
    static let playgroundLevelId = 999
    /// The unit the playground gate releases, one per wave. Set by the
    /// briefing's PLAYGROUND button to that level's debut hostile
    /// (Saucer fallback); swap manually to inspect any other unit.
    static var playgroundUnit: EnemyKind = .saucer

    /// Enemy structure durability at Level 1. Every campaign level after
    /// that adds 10%, compounding (L2 ×1.10, L3 ×1.21 …).
    static let startingTowerHP: CGFloat = 200
    static let startingBaseHP: CGFloat = 500
    static let enemyStructureHPPerLevel: CGFloat = 0.10

    static func enemyStructureHPMultiplier(for levelId: Int) -> CGFloat {
        // Playground fields Level-1-grade structures (raw stat checks).
        guard levelId != playgroundLevelId else { return 1 }
        let steps = CGFloat(max(0, levelId - 1))
        return CGFloat(pow(Double(1 + enemyStructureHPPerLevel), Double(steps)))
    }

    /// Enemy tower HP for a level (10% growth per level from the start).
    /// Used by the battle and the briefing/prep dossiers. From the
    /// refit level on, both teams' towers switch to the Mk-II design and
    /// the enemy shells carry a ONE-TIME +400 HP boost (not compounding).
    static func enemyTowerHealth(forLevel levelId: Int) -> CGFloat {
        var hp = startingTowerHP * enemyStructureHPMultiplier(for: levelId)
        if levelId >= upgradedTowerLevel, levelId != playgroundLevelId {
            hp += upgradedTowerHPBonus
        }
        return hp
    }

    /// Enemy main-base HP for a level (same 10% growth as the towers).
    static func enemyBaseHealth(forLevel levelId: Int) -> CGFloat {
        startingBaseHP * enemyStructureHPMultiplier(for: levelId)
    }

    /// Structure HP for a team. Enemy structures scale with the campaign
    /// level; player structures keep the layout's durable values.
    static func towerHealth(for team: Team, levelId: Int) -> CGFloat {
        team == .enemy ? enemyTowerHealth(forLevel: levelId) : layout(for: levelId).towerHP
    }

    static func baseHealth(for team: Team, levelId: Int) -> CGFloat {
        team == .enemy ? enemyBaseHealth(forLevel: levelId) : layout(for: levelId).baseHP
    }

    static func layout(for levelId: Int) -> LevelLayout {
        if levelId == playgroundLevelId { return layoutPlayground }
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
        case 11: return layout11
        case 12: return layout12
        case 13: return layout13
        case 14: return layout14
        case 15: return layout15
        case 16: return layout16
        case 17: return layout17
        case 18: return layout18
        case 19: return layout19
        case 20: return layout20
        case 21: return layout21
        case 22: return layout22
        case 23: return layout23
        case 24: return layout24
        case 25: return layout25
        case 26: return layout26
        default: return layout1
        }
    }

    // MARK: - Level layout (points; follow `active`)
    static var levelWidth: CGFloat { active.width }
    static var forgeNight: Bool { active.forgeNight }
    static var canyonNight: Bool { active.canyonNight }
    static var alpinePass: Bool { active.alpinePass }
    /// Highridge Redoubt field + mid-ground fort (Level 17).
    static var ridgeRedoubt: Bool { active.ridgeRedoubt }
    /// Stormcrown storm sky over the dusk alpine shelf (Level 19).
    static var stormSummit: Bool { active.stormSummit }
    /// Looping snowfall over a snowy battlefield (Level 20).
    static var snowfall: Bool { active.snowfall }
    /// DEV playground: the active layout is the tiny unit-test arena.
    static var playgroundMode: Bool { active.playground }
    /// Wind-glazed ice lane (Level 21+): ground sparkle, slide, breath plumes.
    static var iceField: Bool { active.iceField }
    /// Whiteout Redoubt siege ground (Level 22): frozen field whispers.
    static var whiteoutRedoubt: Bool { active.whiteoutRedoubt }
    /// Howling Causeway bridge ground (Level 23): the abyss span's field.
    static var howlingCauseway: Bool { active.howlingCauseway }
    /// Rimewatch Crag watch ground (Level 24): blue-ice spire teeth +
    /// sundered watch-cairn rubble frozen into the field.
    static var rimewatchCrag: Bool { active.rimewatchCrag }
    /// Frozen Narrows ice-channel ground (Level 25): brittle ice sheets
    /// frozen into the field, with matching mid-ground ice floes.
    static var frozenNarrows: Bool { active.frozenNarrows }
    /// Rimevault vault ground (Level 26): sunken vault slabs + braziers.
    static var rimevault: Bool { active.rimevault }
    /// Frost evening grade (Level 26): amber dusk over the ice.
    static var frostEvening: Bool { active.frostEvening }
    static var groundTopY: CGFloat = 120        // y of the walkable surface
    /// True on desert themes (dune sand + sand dressing; Levels 7-13).
    static var dunes: Bool {
        let t = active.theme
        if alpinePass { return false }
        return t == .dunesea || t == .oasis || t == .duskdesert
            || t == .nightdesert || t == .sunrise || t == .dusk
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
    /// Base war chest (Level 1-2). Every 2 levels it grows by
    /// `startingGoldStep` (L1-2: 300, L3-4: 350, L5-6: 400, …).
    static let startingGold: Int = 300
    /// Starting-gold bump, granted every 2 campaign levels.
    static let startingGoldStep: Int = 50
    /// DEV playground war chest: a fat stack so every army card can be
    /// fielded while inspecting the unit under test.
    static let playgroundStartingGold: Int = 1000
    /// Starting gold for a level id (playground pays the fat stack).
    static func startingGold(for levelId: Int) -> Int {
        guard levelId != playgroundLevelId else { return playgroundStartingGold }
        return startingGold + ((max(1, levelId) - 1) / 2) * startingGoldStep
    }
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
    /// From this roster level on, towers on BOTH teams render the heavy
    /// Mk-II design (armored shell + missile-pod turret) — see TowerNode.
    static let upgradedTowerLevel = 18
    /// One-time enemy refit at the Mk-II tier: enemy tower shells carry
    /// this flat bonus from Level 18 onward (+400 once, never per level).
    static let upgradedTowerHPBonus: CGFloat = 400
    /// Mk-II turret (Level 18+): a 3-missile volley replaces the bolt fan
    /// on BOTH teams. The enemy volley lands at tower-bolt damage; the
    /// player's fires at roughly half (safer to keep the defense fair).
    static let towerMissileCount = 3
    static let towerMissileSpeed: CGFloat = 520
    static let towerMissileLife: Double = 1.7
    static let towerMissileSpread: CGFloat = 0.12
    static let towerMissileWeaveAmp: CGFloat = 34
    static let towerMissileWeaveFreq: Double = 6.0
    static let playerTowerMissileDamage: CGFloat = 6

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
    /// From this roster level on, main HQs on BOTH teams render the heavy
    /// Mk-II design (bigger fortified keep + quad rooftop missile pods) —
    /// see BaseNode.
    static let upgradedBaseLevel = 20
    /// Mk-II HQ rooftop battery (Level 20+): a 4-missile volley replaces
    /// the 3-bolt fan on BOTH teams. Each missile rides a slight angle
    /// fan + weave, like the Level 18 tower refit, and lands at the same
    /// base-bolt payload (four homers at one base = a heavier HQ punch).
    static let baseMissileCount = 4
    static let baseMissileSpeed: CGFloat = 520
    static let baseMissileLife: Double = 2.0
    static let baseMissileSpread: CGFloat = 0.11
    static let baseMissileWeaveAmp: CGFloat = 36
    static let baseMissileWeaveFreq: Double = 6.0

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
    static var heliEvery: Int { active.heliEvery }
    static var mechPairSize: Int { active.mechPairSize }
    static var mechPairDelay: Double { active.mechPairDelay }
    static var extraBruteSummons: [Int] { active.extraBruteSummons }
    static var extraMechSummons: [Int] { active.extraMechSummons }
    /// Multiplier for the alpine treeline (pines + scrub).
    static var pineDensity: CGFloat { active.pineDensity }
    /// Bolts per tower volley (1 early, 3 from Level 10 on).
    static var towerFanCount: Int { active.towerFanCount }
    /// Every Nth summon is a missile-truck wave (0 = never).
    static var truckEvery: Int { active.truckEvery }
    /// Missile trucks per truck wave.
    static var truckCount: Int { active.truckCount }
    /// Every Nth summon is the Immortal walker (0 = never). Singleton.
    static var immortalEvery: Int { active.immortalEvery }
    /// Every Nth summon is a Saucer gun-drone (0 = never).
    static var saucerEvery: Int { active.saucerEvery }
    static let firstSummonDelay: Double = 5.0
    /// Raider (the classic marcher — Levels 1+). Base 40; Level 5+ scales
    /// via the layout's enemyHPScale (L5 = ×1.05, L6 = ×1.1025).
    static var enemyHP: CGFloat { 40 * active.enemyHPScale }
    static let enemySpeed: CGFloat = 120
    static let killReward: Int = 100           // Unity KillEnemy gold
    /// Global cut to enemy-kill bounties. 0.6 keeps 60% of base reward
    /// (i.e. about 40% less money from enemy units). Bounties then round
    /// down to the nearest 10 (42 -> 40, 105 -> 100).
    static let enemyRewardScale: CGFloat = 0.6
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
    /// Heli Gunship (futuristic attack helicopter — Level 13+): cruises
    /// above the jet droid and fires tight 3-round machine-gun bursts.
    /// Base 170, scaled.
    static var heliHP: CGFloat { 170 * active.enemyHPScale }
    static let heliSpeed: CGFloat = 112
    static let heliReward: Int = 275
    static let heliSightRange: CGFloat = 700
    static let heliShootRange: CGFloat = 470
    static let heliFireCooldown: Double = 2.6
    static let heliBoltDamage: CGFloat = 9
    static let heliHoverHeight: CGFloat = 160  // high cruise above the jets
    static let heliBurstCount: Int = 3
    static let heliBurstGap: Double = 0.09
    static let heliBoltSpeed: CGFloat = 700
    static let jetJukeTime: Double = 0.45    // out-and-back dodge duration
    static let jetJukeCooldown: Double = 0.6 // min gap between dodge triggers
    /// Missile Truck (Level 15+): a tracked self-propelled launcher —
    /// armored cab at the back, missile module on the nose, and a big rail
    /// that always points the way it drives. Long range: it shells the
    /// lane from a distance, and its twin missiles weave on the way in.
    /// Heavily armored: tougher than the Mech Walker.
    static var missileTruckHP: CGFloat { 300 * active.enemyHPScale }
    static let missileTruckSpeed: CGFloat = 108
    static let missileTruckReward: Int = 150
    /// Long sight: the launcher spots the hero from well down the lane.
    static let missileTruckSightRange: CGFloat = 700
    /// Long reach too — the rail throws a missile most of the way across
    /// the field, so the truck can start shelling from a safe distance.
    static let missileTruckShootRange: CGFloat = 390
    static let missileTruckFireCooldown: Double = 2.2
    static let missileTruckMissileDamage: CGFloat = 14
    static let missileTruckMissileSpeed: CGFloat = 520
    static let missileTruckMissileLife: Double = 0.9
    /// Missile weave: lateral snake perpendicular to the flight line.
    static let missileTruckWeaveAmp: CGFloat = 42
    static let missileTruckWeaveFreq: Double = 7.0
    /// Immortal (white-armored tracked walker — Level 19+): a fast armored
    /// battle machine bigger than the Brute — long black rail cannon on
    /// the chest, black missile pods over the shoulder, hot pink glow trim,
    /// riding wide tank tracks. Ranged only: it fires one straight-flying
    /// mortar shell (the Bombard's round, no arc) down the lane.
    /// Base 280, scaled.
    static var immortalHP: CGFloat { 280 * active.enemyHPScale }
    static let immortalSpeed: CGFloat = 150
    static let immortalReward: Int = 250
    static let immortalSightRange: CGFloat = 640
    static let immortalShootRange: CGFloat = 420
    static let immortalFireCooldown: Double = 2.8
    static let immortalShellDamage: CGFloat = 20
    /// Straight-shot shells: the Bombard's mortar round fired flat and
    /// fast, detonating with the Bombard's blast on impact.
    static let immortalShellSpeed: CGFloat = 760
    static let immortalShellLife: Double = 0.8
    static let immortalShellBlast: CGFloat = 92
    /// Saucer (twin-blaster gun-drone — Level 24+): a bigger flying drone
    /// built off the saucer reference — wide rust-orange disc hull with a
    /// red eye, twin boxy blaster cannons slung below firing blue plasma.
    /// It cruises higher than the Heli Gunship and holds station to loose
    /// 2-round blaster bursts with a small splash. Slow, tanky,
    /// long-reaching. Base 330, scaled — it pays a premium as the
    /// Level 24 sky terror.
    static var saucerHP: CGFloat { 330 * active.enemyHPScale }
    static let saucerSpeed: CGFloat = 100
    static let saucerReward: Int = 325
    static let saucerSightRange: CGFloat = 740
    static let saucerShootRange: CGFloat = 480
    static let saucerFireCooldown: Double = 2.8
    static let saucerBoltDamage: CGFloat = 11
    static let saucerHoverHeight: CGFloat = 225  // above the gunships (heli 160)
    static let saucerBurstCount: Int = 2
    static let saucerBurstGap: Double = 0.16
    static let saucerBoltSpeed: CGFloat = 680
    /// Blue-plasma splash: small AoE around each saucer impact (px radius).
    static let saucerBlast: CGFloat = 70
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
    // Bombard: Level 11 mortar carrier. Slow, lightly armored chassis with
    // a top-mounted launcher. Outranges every other ally and lobs one bomb
    // per shot; the shell falls in a gravity arc and detonates in a splash.
    static let bombardCost: Int = 450
    static let bombardHP: CGFloat = 210
    static let bombardSpeed: CGFloat = 62
    static let bombardDamage: CGFloat = 64
    static let bombardFireCooldown: Double = 3.4
    static let bombardRange: CGFloat = 780
    static let bombardSightRange: CGFloat = 940
    static let bombardBlast: CGFloat = 92
    static let bombardGravity: CGFloat = 980
    // Tank: Level 17 main-battle tank. Tracked chassis with a top turret
    // that fires one missile in a dead-straight line — no arc, no weave.
    // Costs 600 and rolls out with 30% more life than the Gun-Truck.
    static let tankCost: Int = 600
    static let tankHP: CGFloat = truckHP * 1.3
    static let tankSpeed: CGFloat = 84
    static let tankDamage: CGFloat = 52
    static let tankFireCooldown: Double = 1.9
    static let tankRange: CGFloat = 560
    static let tankSightRange: CGFloat = 780
    static let tankMissileSpeed: CGFloat = 640
    static let tankMissileLife: Double = 1.4
    static let tankMissileBlast: CGFloat = 38
    // Gunship: Level 22 dual-rotor heavy attack helicopter — the player's
    // first flying army unit. Larger tandem-rotor frame that hovers high
    // above the lane and fires a 3-round burst from its chin turret.
    static let gunshipCost: Int = 700
    static let gunshipHP: CGFloat = 340
    static let gunshipSpeed: CGFloat = 155
    static let gunshipDamage: CGFloat = 22
    static let gunshipFireCooldown: Double = 1.5
    static let gunshipRange: CGFloat = 480
    static let gunshipSightRange: CGFloat = 760
    static let gunshipHoverHeight: CGFloat = 165
    static let gunshipBurstCount: Int = 3
    static let gunshipBurstGap: Double = 0.09
    static let gunshipBoltSpeed: CGFloat = 720

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
