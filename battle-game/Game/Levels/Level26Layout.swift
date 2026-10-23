import CoreGraphics

/// Level 26 Rimevault: the same frozen theater as Frostbite Approach —
/// identical polar glacier shelf and wind-glazed snow lane (see
/// FrostbiteBG, SnowFX, the `iceField` flag) — but fought at evening: a
/// low amber sun melts the zenith indigo into ember-gold at the horizon
/// (see the `frostEvening` grade in FrostbiteBG.buildSky), and the lane
/// carries the vault's whispers (see `rimevault`: sunken vault
/// door-slabs, rime shards, wind-carved drifts and ember braziers
/// burning against the evening cold).
///
/// The gate turns the screws over Frozen Narrows (L25): marches out
/// faster, pops pairs more often, the field cap holds at the 40-unit
/// ceiling, elites come denser across the board (jets every 8th, mechs
/// every 3rd, trucks every 3rd, saucers every 4th, Immortals every 6th),
/// bonus Brutes + Mechs stack up across the 14-wave push, and enemy HP
/// scales another 5% (×2.7863, +5% over L25). The 5-tower line holds
/// (fifth emplacements at player 4950 / enemy 8250, same 13200pt lane).
extension Balance {
    static let layout26 = LevelLayout(
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
        summonInterval: 2.2,
        doubleChance: 0.72,
        maxEnemies: 40,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 8,
        mechEvery: 3,
        heliEvery: 3,
        mechPairSize: 2,
        mechPairDelay: 0.8,
        towerHP: 720,
        baseHP: 1940,
        enemyHPScale: 2.7863,
        snowfall: true,
        extraBruteSummons: [3, 7, 12, 17, 22, 27, 32, 37],
        extraMechSummons: [4, 9, 14, 19, 24, 29, 34, 39],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 3,
        truckCount: 2,
        /// The Immortals hold the vault — one walker at a time,
        /// every sixth summon (tighter than the Narrows' seventh).
        immortalEvery: 6,
        /// Saucer gun-drones thicken over the vault — every fourth
        /// summon, above even the gunships.
        saucerEvery: 4,
        /// The lane stays wind-glazed ice like the Approach and Narrows.
        iceField: true,
        /// Rimevault vault ground: small pixel-art whispers frozen into
        /// the field (see LevelDressing.buildRimevault).
        rimevault: true,
        /// Evening grade over the ice: amber dusk sun instead of the
        /// pale polar noon (see FrostbiteBG.buildSky).
        frostEvening: true
    )
}
