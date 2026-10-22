import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 10 Moonveil Dunes: 10000pt desert under a cold moon, 3 towers
    /// per side. Same straight sand field as the other dune lanes; the
    /// night lives in the sky, ridge silhouettes and moonlit warm ground.
    /// Flow holds Level 9's pressure, Mech walkers still every 4th
    /// summon — but they now arrive as a pair, one beat apart, instead of
    /// one at a time. Enemy HP ×1.3401 (+5% over Level 9, compounding).
    /// Structure HP matches the dossier.
    static let layout10 = LevelLayout(
        width: 10000,
        playerBaseX: 220,
        playerTowerXs: [820, 1620, 2420],
        enemyTowerXs: [7350, 8150, 8950],
        enemyBaseX: 9780,
        heroSpawnX: 420,
        platforms: [],
        theme: .nightdesert,
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
        mechPairSize: 2,
        towerHP: 460,
        baseHP: 1150,
        enemyHPScale: 1.3401,
        // Level 10 is where the towers switched to the fanned volley.
        towerFanCount: 3
    )
}
