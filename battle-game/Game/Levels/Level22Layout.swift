import CoreGraphics

/// Level 22 Whiteout Redoubt: the same frozen theater as Frostbite
/// Approach — identical polar sky, glacier shelf and wind-glazed snow
/// lane (see FrostbiteBG, SnowFX, the `iceField` flag) — but the lane
/// now runs through the redoubt's siege ground: the field carries the
/// fortress's whispers (see `whiteoutRedoubt`: half-buried supply
/// crates, snow drifts, rime shards and wind-sheltered braziers).
///
/// The gate keeps the heat climbing: marches out faster, pops pairs a
/// touch more often, the field cap ticks up, and enemy HP scales
/// another 5% (×2.2923, +5% over L21). The Immortal garrison cadence
/// holds at every eighth summon — this time they belong to the fort.
extension Balance {
    static let layout22 = LevelLayout(
        width: 13200,
        playerBaseX: 220,
        playerTowerXs: [840, 1640, 2440, 3240],
        enemyTowerXs: [9050, 9850, 10650, 11450],
        enemyBaseX: 12980,
        heroSpawnX: 420,
        platforms: [],
        theme: .frost,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 2.7,
        doubleChance: 0.64,
        maxEnemies: 35,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 10,
        mechEvery: 5,
        heliEvery: 4,
        mechPairSize: 2,
        mechPairDelay: 1.2,
        towerHP: 640,
        baseHP: 1700,
        enemyHPScale: 2.2923,
        snowfall: true,
        extraBruteSummons: [4, 10, 16, 22, 28, 34],
        extraMechSummons: [6, 13, 20, 27, 33],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 5,
        truckCount: 1,
        /// The Immortals garrison the Redoubt itself — one walker at
        /// a time, every eighth summon.
        immortalEvery: 8,
        /// The lane stays wind-glazed ice like the Approach.
        iceField: true,
        /// Whiteout Redoubt siege ground: small pixel-art whispers
        /// frozen into the field (see LevelDressing.buildWhiteoutRedoubt).
        whiteoutRedoubt: true
    )
}
