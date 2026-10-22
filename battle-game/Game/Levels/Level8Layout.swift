import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 8 Oasis Waste: 9200pt desert-oasis siege lane, 3 towers
    /// per side. Desert again but greener + ornamented: palm oases,
    /// ruin arches and bone fields in the distance, crawling sand
    /// creatures stalking the ridges. Straight sand field. Hotter flow:
    /// pairs often, Reavers every 3rd, Jets every 5th, Skitters every
    /// 2nd, Brute every 6th. Enemy HP ×1.2155 (+5% over Level 7,
    /// compounding). Structure HP matches the dossier.
    static let layout8 = LevelLayout(
        width: 9200,
        playerBaseX: 220,
        playerTowerXs: [750, 1500, 2250],
        enemyTowerXs: [6650, 7400, 8150],
        enemyBaseX: 8980,
        heroSpawnX: 420,
        platforms: [],
        theme: .oasis,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 4.5,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 5,
        mechEvery: 0,
        towerHP: 400,
        baseHP: 1000,
        enemyHPScale: 1.2155
    )
}
