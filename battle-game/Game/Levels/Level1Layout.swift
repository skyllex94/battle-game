import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 1: the original 5200pt Twilight lane, 2 towers per side.
    static let layout1 = LevelLayout(
        width: 5200,
        playerBaseX: 220,
        playerTowerXs: [800, 1450],
        enemyTowerXs: [3750, 4400],
        enemyBaseX: 4980,
        heroSpawnX: 420,
        platforms: [],
        theme: .twilight,
        flags: false,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 8.0,
        doubleChance: 0.0,
        maxEnemies: 20,
        bruteEvery: 0,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 200,
        baseHP: 500,
        enemyHPScale: 1.0
    )
}
