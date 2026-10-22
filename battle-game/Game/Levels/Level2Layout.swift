import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 2 Rootwall Thicket: bigger 6800pt overgrown map, 3 towers per
    /// side guarding each base, extra mid platforms, full dressing pack.
    static let layout2 = LevelLayout(
        width: 6800,
        playerBaseX: 220,
        playerTowerXs: [800, 1500, 2200],
        enemyTowerXs: [4600, 5300, 6000],
        enemyBaseX: 6580,
        heroSpawnX: 420,
        platforms: [],
        theme: .overgrown,
        flags: true,
        alienBirds: true,
        lushFlora: true,
        summonInterval: 7.0,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 0,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 220,
        baseHP: 550,
        enemyHPScale: 1.0
    )
}
