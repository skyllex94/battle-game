import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 7 Sirocco Dunes: 8800pt desert siege lane, 3 towers
    /// per side. Straight sand field like the other lanes; the dunes
    /// live in the background art. Golden desert-day grade
    /// with pixel ridge lines + drifting sand. Hotter flow: pairs often,
    /// Reavers every 3rd, Skitters every 2nd, Brute every 6th (Brutes then
    /// Reavers win ties). Enemy HP ×1.1576 (+5% over Level 6,
    /// compounding). Structure HP matches the dossier.
    static let layout7 = LevelLayout(
        width: 8800,
        playerBaseX: 220,
        playerTowerXs: [750, 1500, 2250],
        enemyTowerXs: [6350, 7100, 7850],
        enemyBaseX: 8580,
        heroSpawnX: 420,
        platforms: [],
        theme: .dunesea,
        flags: false,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 5.0,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 5,
        mechEvery: 0,
        towerHP: 350,
        baseHP: 900,
        enemyHPScale: 1.1576
    )
}
