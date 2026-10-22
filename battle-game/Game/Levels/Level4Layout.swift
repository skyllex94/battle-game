import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 4 Dune Atoll: open 7400pt white-sand crossing, 3 towers per
    /// side pushed wider apart. Open fields, no platforms.
    /// Dawn grade (see .dawn). Hotter flow: raiders every 5.5s with frequent
    /// pairs, a Reaver axe-rush every 3rd summon, and a Brute every 6th
    /// (Brutes win the 6th-summon tie) — plus the Scatter unlock in hand.
    static let layout4 = LevelLayout(
        width: 7400,
        playerBaseX: 220,
        playerTowerXs: [700, 1400, 2100],
        enemyTowerXs: [5200, 5900, 6600],
        enemyBaseX: 7180,
        heroSpawnX: 420,
        platforms: [],
        theme: .dawn,
        flags: true,
        alienBirds: true,
        lushFlora: false,
        summonInterval: 5.5,
        doubleChance: 0.40,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 260,
        baseHP: 650,
        enemyHPScale: 1.0
    )
}
