import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 14 Granite Reach: 13200pt high-plateau lane, 4 towers per side.
    /// Same warm sunrise and same distant range as Stonewatch, but the field
    /// is bare rock: granite shelves, scree, alpine scrub and pine stands.
    /// Brutes/Heli Gunships keep the pressure; Mech walkers roll out one at
    /// a time (never a pair in the same wave) and the summon cadence is a
    /// touch hotter. Three waves also roll out a bonus Mech walker on top of
    /// the normal batch. Enemy HP ×1.5514 (+5% over L13).
    static let layout14 = LevelLayout(
        width: 13200,
        playerBaseX: 220,
        playerTowerXs: [840, 1640, 2440, 3240],
        enemyTowerXs: [9050, 9850, 10650, 11450],
        enemyBaseX: 12980,
        heroSpawnX: 420,
        platforms: [],
        theme: .sunrise,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 4.0,
        doubleChance: 0.49,
        maxEnemies: 24,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 6,
        mechEvery: 8,
        heliEvery: 5,
        // One walker per wave: the Granite Reach waves never double up.
        mechPairSize: 1,
        towerHP: 460,
        baseHP: 1180,
        enemyHPScale: 1.5514,
        alpinePass: true,
        extraMechSummons: [6, 13, 20],
        towerFanCount: 3
    )
}
