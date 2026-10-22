import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 11 Sunforge Redoubt: 11600pt — the widest lane yet — and the
    /// first with a 4th tower per side. Still the moonlit desert, but a
    /// distant foundry burns on the horizon: warm chimney smoke, ember
    /// drift and iron-slag dressing over the same sand. Flow steps up from
    /// Level 10 (slightly faster summons, cap 22); Mech pairs continue.
    /// Enemy HP ×1.4071 (+5% over Level 10, compounding).
    /// Structure HP matches the dossier.
    static let layout11 = LevelLayout(
        width: 11600,
        playerBaseX: 220,
        playerTowerXs: [820, 1620, 2420, 3220],
        enemyTowerXs: [8150, 8950, 9750, 10550],
        enemyBaseX: 11380,
        heroSpawnX: 420,
        platforms: [],
        theme: .nightdesert,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 4.3,
        doubleChance: 0.46,
        maxEnemies: 22,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 5,
        mechEvery: 4,
        mechPairSize: 2,
        towerHP: 400,
        baseHP: 1000,
        enemyHPScale: 1.4071,
        forgeNight: true,
        towerFanCount: 3
    )
}
