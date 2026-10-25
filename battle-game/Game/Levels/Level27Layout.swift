import CoreGraphics

/// Level 27 Pale Abyss: the same frozen theater as Frostbite Approach —
/// identical polar glacier shelf and wind-glazed snow lane (see
/// FrostbiteBG, SnowFX, the `iceField` flag) — but fought at night at the
/// edge of the world: a pale moonlit dark hangs over the shelf (see the
/// `frostNight` grade in FrostbiteBG.buildSky), the mid ground splits open
/// on the abyss rift (see FrostbiteBG.buildMid), and the lane carries the
/// abyss's whispers (see `paleAbyss`: glowing crevasse fissures, pale
/// sentinel monoliths, rime shards, wind-carved drifts and pale-flame
/// braziers burning against the white dark).
///
/// The ice-region capstone (and a castle stop on the campaign map): the
/// 5-tower line holds (fifth emplacements at player 4950 / enemy 8250,
/// same 13200pt lane). The gate turns the screws over Rimevault (L26):
/// marches out faster, pops pairs more often, the field cap rises to the
/// 42-unit ceiling, elites come denser across the board (jets every 7th,
/// mechs every 3rd, gunships every 2nd, trucks every 2nd, saucers every
/// 3rd, Immortals every 5th), bonus Brutes + Mechs stack up across the
/// 15-wave push, and enemy HP scales another 5% (×2.9256, +5% over L26).
/// Level 27 debut: the Gnasher — evolved Skitter stock remade by the
/// abyss: bigger, faster, and volatile, detonating when killed. Five
/// crawl out as bonus summons across the push; clear them at range or
/// eat the burst. The old Skitter stock is gone from here on — outcompeted
/// by its own evolution (skitterEvery stays 0 on 27+).
extension Balance {
    static let layout27 = LevelLayout(
        width: 13200,
        playerBaseX: 220,
        playerTowerXs: [1750, 2550, 3350, 4150, 4950],
        enemyTowerXs: [8250, 9050, 9850, 10650, 11450],
        enemyBaseX: 12980,
        heroSpawnX: 420,
        platforms: [],
        theme: .frost,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 2.0,
        doubleChance: 0.74,
        maxEnemies: 42,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 7,
        mechEvery: 3,
        heliEvery: 2,
        mechPairSize: 2,
        mechPairDelay: 0.7,
        towerHP: 750,
        baseHP: 2020,
        enemyHPScale: 2.9256,
        snowfall: true,
        extraBruteSummons: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38],
        extraMechSummons: [3, 7, 11, 15, 19, 23, 27, 31, 35, 39],
        extraGnasherSummons: [5, 13, 21, 29, 37],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 2,
        truckCount: 2,
        /// The Immortals hold the abyss edge — one walker at a time,
        /// every fifth summon (the densest cadence of the ice region).
        immortalEvery: 5,
        /// Saucer gun-drones thick over the crevasse — every third
        /// summon, matching the gunships.
        saucerEvery: 3,
        /// The lane stays wind-glazed ice like the whole ice region.
        iceField: true,
        /// Night grade over the ice: pale moonlit night instead of the
        /// polar noon or the vault's amber evening (see FrostbiteBG.buildSky).
        frostNight: true,
        /// Pale Abyss ground: small pixel-art whispers frozen into
        /// the field (see LevelDressing.buildPaleAbyss).
        paleAbyss: true
    )
}
