import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 12 Sirocco Canyon: 12200pt night desert — the widest lane so
    /// far — with the same 4-tower line per side. The open dunes narrow
    /// into a moonlit canyon: tall buttes and layered rock walls replace
    /// the low ridgelines, and tumbled boulders litter the sand. Summons
    /// are a touch hotter than Level 11 (cap 24); Mech pairs continue.
    /// Enemy HP ×1.4775 (+5% over Level 11, compounding).
    /// Structure HP matches the dossier.
    static let layout12 = LevelLayout(
        width: 12200,
        playerBaseX: 220,
        playerTowerXs: [820, 1620, 2420, 3220],
        enemyTowerXs: [8750, 9550, 10350, 11150],
        enemyBaseX: 11980,
        heroSpawnX: 420,
        platforms: [],
        theme: .nightdesert,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 4.1,
        doubleChance: 0.48,
        maxEnemies: 24,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 5,
        mechEvery: 4,
        mechPairSize: 2,
        towerHP: 420,
        baseHP: 1060,
        enemyHPScale: 1.4775,
        canyonNight: true,
        extraBruteSummons: [7, 13],
        towerFanCount: 3
    )
}
