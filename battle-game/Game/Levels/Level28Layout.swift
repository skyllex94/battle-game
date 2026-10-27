import CoreGraphics

/// Level 28 Umbral Outskirts: the first step into the dark core — a new
/// Mordor-inspired blood-red theater (see MordorBG): burning maroon sky
/// under a bloated ember moon, a black peak-wall with a smoking volcano
/// at its heart, rolling ash wastes in the mid ground, and a cracked
/// basalt lane veined with living ember (see `umbralOutskirts`: ember
/// fissures, obsidian shards, dead snags and ember braziers).
///
/// The ice is behind us: no snowfall, no wind-glazed lane. The 5-tower
/// line holds (fifth emplacements at player 4950 / enemy 8250, same
/// 13200pt lane). The gate turns the screws over Pale Abyss (L27):
/// marches out faster, pops pairs more often, the field cap rises to the
/// 44-unit ceiling, elites come denser across the board (jets every 6th,
/// mechs every 3rd, gunships every 2nd, trucks every 4th, saucers every
/// 2nd, Immortals every 4th), bonus Brutes + Mechs stack up across the
/// 15-wave push, and enemy HP scales another 5% (×3.0719, +5% over L27).
/// The Gnashers stalk out of the ash on the same cadence as the abyss.
extension Balance {
    static let layout28 = LevelLayout(
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
        summonInterval: 1.9,
        doubleChance: 0.76,
        maxEnemies: 44,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 6,
        mechEvery: 3,
        heliEvery: 2,
        mechPairSize: 2,
        mechPairDelay: 0.6,
        towerHP: 780,
        baseHP: 2100,
        enemyHPScale: 3.0719,
        snowfall: false,
        extraBruteSummons: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38],
        extraMechSummons: [3, 7, 11, 15, 19, 23, 27, 31, 35, 39],
        extraGnasherSummons: [4, 12, 20, 28, 36],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 4,
        truckCount: 1,
        /// The Immortals hold the outer dark — one walker at a time,
        /// every fourth summon (the densest cadence yet).
        immortalEvery: 4,
        /// Saucer gun-drones thick over the ash — every second
        /// summon, matching the gunships.
        saucerEvery: 2,
        /// The lane is cracked basalt, not wind-glazed ice.
        iceField: false,
        /// Umbral Outskirts ash ground: small pixel-art whispers baked
        /// into the field (see LevelDressing.buildUmbralOutskirts).
        umbralOutskirts: true
    )
}
