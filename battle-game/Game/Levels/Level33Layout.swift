import CoreGraphics

/// Level 33 Dread Hollow: the same Mordor-inspired blood-red theater as
/// Shadowrift (see MordorBG) — burning maroon sky under the bloated ember
/// moon, black peak-wall with the smoking volcano, rolling ash wastes,
/// cracked basalt lane veined with living ember — crossed one small step
/// deeper: the lane drops into a bowl of black rock ringed by jagged peaks,
/// and the enemy's war banners hang from the spires, lit by red fire
/// (see `dreadHollow`: banner-spires, hollow teeth, hanging braziers).
///
/// The 5-tower line holds (fifth emplacements at player 4950 / enemy 8250,
/// same 13200pt lane). Level 33 fields no new enemy — instead the hollow
/// turns the screws over Shadowrift (L32): marches out faster, pops pairs
/// more often, the field cap holds at the 50-unit ceiling, elites stay dense
/// across the board (jets every 5th, mechs every 3rd, gunships every 2nd,
/// trucks every 4th, saucers every 2nd, Immortals every 3rd, Phoenix every
/// 4th), bonus Brutes + Mechs stack up across the 17-wave push, and enemy
/// HP scales another 5% (×3.9206, +5% over L32). Five Gnashers still crawl
/// out as bonus summons across the push; clear them at range or eat the
/// burst.
extension Balance {
    static let layout33 = LevelLayout(
        width: 13200,
        playerBaseX: 220,
        playerTowerXs: [1750, 2550, 3350, 4150, 4950],
        enemyTowerXs: [8250, 9050, 9850, 10650, 11450],
        enemyBaseX: 12980,
        heroSpawnX: 420,
        platforms: [],
        theme: .mordor,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 1.4,
        doubleChance: 0.86,
        maxEnemies: 50,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 5,
        mechEvery: 3,
        heliEvery: 2,
        mechPairSize: 2,
        mechPairDelay: 0.6,
        towerHP: 930,
        baseHP: 2500,
        enemyHPScale: 3.9206,
        snowfall: false,
        extraBruteSummons: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38],
        extraMechSummons: [3, 7, 11, 15, 19, 23, 27, 31, 35, 39],
        extraGnasherSummons: [4, 12, 20, 28, 36],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 4,
        truckCount: 1,
        /// The Immortals press the hollow — one walker at a time,
        /// every third summon (the densest cadence, held from L31).
        immortalEvery: 3,
        /// Saucer gun-drones thick over the hollow — every second
        /// summon, matching the gunships.
        saucerEvery: 2,
        /// Phoenix strike-fighters dive over the hollow — every fourth
        /// summon, checked ahead of the saucer cadence.
        phoenixEvery: 4,
        /// The lane is cracked basalt, not wind-glazed ice.
        iceField: false,
        /// Dread Hollow ash ground: small pixel-art whispers baked
        /// into the field (see LevelDressing.buildDreadHollow).
        dreadHollow: true
    )
}
