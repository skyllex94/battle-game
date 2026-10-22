import CoreGraphics

/// Level 20 Ironhold Bastion: the same dusk alpine shelf as Stormcrown
/// Summit — identical lane, tower line and redoubt dressing — but the
/// storm finally drops its load: a looping snowfall drifts over the field
/// (see SnowFX) while the sky keeps the Level 19 storm grade.
///
/// The gate stays hot one step hotter: marches out faster, pops pairs a
/// touch more often, the field cap ticks up, and the Immortal cadence
/// tightens to every eighth summon.
///
/// Structure HP and enemy HP follow the campaign's usual per-level step
/// (enemy HP ×2.0791, +5% over L19).
extension Balance {
    static let layout20 = LevelLayout(
        width: 13200,
        playerBaseX: 220,
        playerTowerXs: [840, 1640, 2440, 3240],
        enemyTowerXs: [9050, 9850, 10650, 11450],
        enemyBaseX: 12980,
        heroSpawnX: 420,
        platforms: [],
        theme: .dusk,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 3.0,
        doubleChance: 0.60,
        maxEnemies: 33,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 11,
        mechEvery: 5,
        heliEvery: 4,
        mechPairSize: 2,
        mechPairDelay: 1.4,
        towerHP: 590,
        baseHP: 1560,
        enemyHPScale: 2.0791,
        alpinePass: true,
        ridgeRedoubt: true,
        stormSummit: true,
        snowfall: true,
        extraBruteSummons: [5, 11, 17, 23, 29],
        extraMechSummons: [7, 14, 21, 28],
        pineDensity: 0.9,
        towerFanCount: 3,
        truckEvery: 5,
        truckCount: 2,
        /// The storm king is gone, but his Immortals garrison Ironhold —
        /// one walker at a time, every eighth summon.
        immortalEvery: 8
    )
}
