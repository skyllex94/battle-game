import CoreGraphics

/// Level 23 Howling Causeway: the same frozen theater as Frostbite
/// Approach — identical polar sky, glacier shelf and wind-glazed snow
/// lane (see FrostbiteBG, SnowFX, the `iceField` flag) — but the lane
/// now runs along the abyss bridge: the field carries the causeway's
/// small whispers (see `howlingCauseway`: frozen marker posts with
/// lantern-blue crystals, rime shards, wind-carved drifts and broken
/// span stones half-buried in the snow).
///
/// First 5-tower line: a fifth gun emplacement anchors each base, pushed
/// into the wide middle gap (player 4950 / enemy 8250) with no field
/// growth — same 13200pt lane. The gate keeps the heat climbing:
/// marches out faster, pops pairs a touch more often, the field cap
/// ticks up, and enemy HP scales another 5% (×2.4069, +5% over L22).
/// The Immortal garrison cadence holds at every eighth summon — the
/// Wardens' watch never blinks.
extension Balance {
    static let layout23 = LevelLayout(
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
        summonInterval: 2.6,
        doubleChance: 0.66,
        maxEnemies: 36,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 10,
        mechEvery: 5,
        heliEvery: 4,
        mechPairSize: 2,
        mechPairDelay: 1.1,
        towerHP: 660,
        baseHP: 1760,
        enemyHPScale: 2.4069,
        snowfall: true,
        extraBruteSummons: [4, 10, 16, 22, 28, 35],
        extraMechSummons: [6, 13, 20, 27, 34],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 5,
        truckCount: 2,
        /// The Immortals garrison the Causeway — one walker at a time,
        /// every eighth summon.
        immortalEvery: 8,
        /// The lane stays wind-glazed ice like the Approach and Redoubt.
        iceField: true,
        /// Howling Causeway bridge ground: small pixel-art whispers
        /// frozen into the field (see LevelDressing.buildHowlingCauseway).
        howlingCauseway: true
    )
}
