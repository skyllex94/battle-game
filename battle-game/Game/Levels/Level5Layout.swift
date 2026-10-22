import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 5 Sunscorch Expanse: longest lane yet (8000pt), 3 towers per
    /// side spread wide, ZERO jumping platforms — open rolling fields with
    /// very small dips and a gentle ascent mid-lane (visual swells only,
    /// gameplay stays flat). High-noon grade: brightest sky so far.
    /// Flow untouched for now (same summon line as Level 4); units + game
    /// tuning lands next. Structure HP matches the LevelDef dossier.
    static let layout5 = LevelLayout(
        width: 8000,
        playerBaseX: 220,
        playerTowerXs: [700, 1450, 2200],
        enemyTowerXs: [5600, 6350, 7100],
        enemyBaseX: 7780,
        heroSpawnX: 420,
        platforms: [],
        theme: .sunscorch,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 5.5,
        doubleChance: 0.40,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 300,
        baseHP: 700,
        enemyHPScale: 1.05
    )
}
