import CoreGraphics

/// Level 21 Frostbite Approach: the ice region begins — a whole frozen
/// theater with no mountains anywhere (see FrostbiteBG): polar sky with
/// aurora ribbons, glacier shelf + ice spires far, wind-swept snow drifts
/// mid, a white snow lane over deep blue ice below, and falling snow on
/// top (SnowFX). The field is wind-glazed ice (see `iceField` flag).
///
/// The gate steps up noticeably over Ironhold Bastion (L20): marches out
/// faster (2.8s vs 3.0s), pops pairs more often (63% vs 60%), raises the
/// active field cap to 35, and scales enemy HP another 5% (×2.1831).
/// The Immortal cadence tightens from every 8th summon to every 7th —
/// which also frees the 8th/16th/24th/32nd waves for Heli Gunships —
/// backed up by Mech walker pairs on shared 7th-wave slots and six bonus
/// Brutes + six bonus Mech walkers across the 13-wave push.
extension Balance {
    static let layout21 = LevelLayout(
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
        summonInterval: 2.8,
        doubleChance: 0.63,
        maxEnemies: 35,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 11,
        mechEvery: 7,
        heliEvery: 4,
        mechPairSize: 2,
        mechPairDelay: 1.25,
        towerHP: 620,
        baseHP: 1640,
        enemyHPScale: 2.1831,
        snowfall: true,
        extraBruteSummons: [4, 10, 16, 22, 28, 33],
        extraMechSummons: [6, 12, 18, 24, 30, 34],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 5,
        truckCount: 2,
        /// Tightened from L20's every-8th to every-7th summon — and if an
        /// Immortal is still standing on wave 14, `mechEvery: 7` rolls out
        /// a Mech walker pair in its place.
        immortalEvery: 7,
        /// Frostbite debut: the lane is glazed wind-ice — ground sparkle
        /// texture, subtle slide on landing, and breath plumes on units.
        iceField: true
    )
}