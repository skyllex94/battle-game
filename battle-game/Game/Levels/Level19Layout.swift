import CoreGraphics

/// Level 19 Stormcrown Summit: the same dusk alpine shelf as Riven Pass
/// — identical lane, tower line and redoubt dressing — but the sky sits
/// under a heavy storm grade: darker violet-blue overhead, thicker slate
/// clouds, and lightning flickering low in the peaks (the storm king's
/// home).
///
/// The gate runs hotter: marches out faster, pops pairs more often, and
/// the mech walker cadence tightens to every fifth summon (plus another
/// quartet of bonus walkers) — the summit fields a walker army.
///
/// Structure HP and enemy HP follow the campaign's usual per-level step
/// (enemy HP ×1.9801, +5% over L18).
extension Balance {
    static let layout19 = LevelLayout(
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
        summonInterval: 3.2,
        doubleChance: 0.58,
        maxEnemies: 32,
        bruteEvery: 3,
        reaverEvery: 0,
        /// No claw rushers on the summit: those gate slots now march out
        /// rank-and-file raiders instead.
        skitterEvery: 0,
        jetEvery: 11,
        mechEvery: 5,
        heliEvery: 4,
        mechPairSize: 2,
        mechPairDelay: 1.4,
        towerHP: 560,
        baseHP: 1480,
        enemyHPScale: 1.9801,
        alpinePass: true,
        ridgeRedoubt: true,
        stormSummit: true,
        extraBruteSummons: [5, 11, 17, 23, 29],
        extraMechSummons: [7, 14, 21, 28],
        pineDensity: 0.9,
        towerFanCount: 3,
        truckEvery: 5,
        truckCount: 2,
        /// Level 19 debut: the storm king's own bodyguard marches out —
        /// one Immortal at a time, every ninth summon.
        immortalEvery: 9
    )
}
