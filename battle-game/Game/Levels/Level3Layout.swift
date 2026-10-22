import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 3 Thornwood Bastion: longest lane yet (7200pt), 3 towers per
    /// side like Level 2 but shifted inward. Open fields, no platforms.
    /// Timber-ember grade.
    /// Easy-to-medium flow: steady raiders, occasional pairs, and every
    /// 4th summon a Brute (first one ~25s in — easy start, medium punch).
    static let layout3 = LevelLayout(
        width: 7200,
        playerBaseX: 220,
        playerTowerXs: [750, 1450, 2150],
        enemyTowerXs: [5050, 5750, 6450],
        enemyBaseX: 6980,
        heroSpawnX: 420,
        platforms: [],
        theme: .bastion,
        flags: true,
        alienBirds: true,
        lushFlora: true,
        summonInterval: 6.0,
        doubleChance: 0.35,
        maxEnemies: 20,
        bruteEvery: 4,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 250,
        baseHP: 600,
        enemyHPScale: 1.0
    )
}
