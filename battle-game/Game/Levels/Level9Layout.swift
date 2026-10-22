import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 9 Duskfall Flats: 9600pt desert at sundown, 3 towers per
    /// side. The sun is going down — indigo sky, stars out, ember-lit
    /// mesas, colder sand. Straight field. The heavy Mech walker
    /// debuts here (every 4th summon: Brutes/Reavers win ties, then
    /// the Mech, then Skitters/Jets). Enemy HP ×1.2763 (+5% over
    /// Level 8, compounding). Structure HP matches the dossier.
    static let layout9 = LevelLayout(
        width: 9600,
        playerBaseX: 220,
        playerTowerXs: [780, 1550, 2320],
        enemyTowerXs: [7000, 7750, 8500],
        enemyBaseX: 9380,
        heroSpawnX: 420,
        platforms: [],
        theme: .duskdesert,
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
        mechEvery: 4,
        towerHP: 440,
        baseHP: 1100,
        enemyHPScale: 1.2763
    )
}
