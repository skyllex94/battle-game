import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 13 Stonewatch Pass: 12600pt desert sunrise lane, 4 towers per
    /// side. The dunes run east into a distant mountain wall; the sun is
    /// just lifting over the range, washing the sand in warm morning light.
    /// Unit roster leans on Brutes and Heli Gunships: no Reavers, a hot
    /// Brute cadence, and Gunship flights every 5th summon.
    static let layout13 = LevelLayout(
        width: 12600,
        playerBaseX: 220,
        playerTowerXs: [840, 1640, 2440, 3240],
        enemyTowerXs: [8950, 9750, 10550, 11350],
        enemyBaseX: 12380,
        heroSpawnX: 420,
        platforms: [],
        theme: .sunrise,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 4.1,
        doubleChance: 0.48,
        maxEnemies: 24,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 7,
        mechEvery: 8,
        heliEvery: 5,
        mechPairSize: 2,
        towerHP: 440,
        baseHP: 1080,
        enemyHPScale: 1.4775,
        towerFanCount: 3
    )
}
