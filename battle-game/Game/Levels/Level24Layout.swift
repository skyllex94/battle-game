import CoreGraphics

/// Level 24 Rimewatch Crag: the same frozen theater as Frostbite
/// Approach — identical polar sky, glacier shelf and wind-glazed snow
/// lane (see FrostbiteBG, SnowFX, the `iceField` flag) — but the lane
/// now climbs past the old watch: the field carries the crag's small
/// whispers (see `rimewatchCrag`: leaning blue-ice spire teeth, sundered
/// watch-cairn rubble with cold-blue crystals, rime shards and
/// wind-carved drifts).
///
/// Level 24 debut: the Saucer gun-drone — a bigger flying drone off the
/// saucer reference, cruising higher than the Heli Gunship and holding
/// high station to fire twin-blaster bursts. The 5-tower line holds from
/// Level 23 (fifth emplacements at player 4950 / enemy 8250, same
/// 13200pt lane). The gate keeps the heat climbing: marches out faster,
/// pops pairs a touch more often, the field cap ticks up, and enemy HP
/// scales another 5% (×2.5272, +5% over L23). The Immortal garrison
/// cadence holds at every eighth summon — the watch never blinks.
extension Balance {
    static let layout24 = LevelLayout(
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
        summonInterval: 2.5,
        doubleChance: 0.68,
        maxEnemies: 37,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 10,
        mechEvery: 5,
        heliEvery: 4,
        mechPairSize: 2,
        mechPairDelay: 1.0,
        towerHP: 680,
        baseHP: 1820,
        enemyHPScale: 2.5272,
        snowfall: true,
        extraBruteSummons: [4, 10, 16, 22, 28, 35],
        extraMechSummons: [6, 13, 20, 27, 34],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 5,
        truckCount: 1,
        /// The Immortals hold the watch — one walker at a time,
        /// every eighth summon.
        immortalEvery: 8,
        /// Level 24 debut: Saucer gun-drones float in every sixth summon,
        /// above even the gunships — twin blasters, high hover.
        saucerEvery: 6,
        /// The lane stays wind-glazed ice like the Approach and Causeway.
        iceField: true,
        /// Rimewatch Crag watch ground: small pixel-art whispers
        /// frozen into the field (see LevelDressing.buildRimewatchCrag).
        rimewatchCrag: true
    )
}
