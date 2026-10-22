import CoreGraphics

/// Level layouts live one file per level from here on (Game/Levels/).
/// Each file owns its own `Balance.layoutNN` and tunes the battlefield:
/// lane width, structures, theme, summon cadence and dressing density.
///
/// The layout type itself stays in Balance.swift — this file only fills
/// in the numbers for its level.
extension Balance {
    /// Level 6 Sandhold Citadel: 8400pt desert-keep siege lane, 3 towers
    /// per side. Open fields, no platforms. Burnt-orange
    /// keep-dusk grade with shadow flyers circling far. Hotter flow:
    /// pairs often, Reavers every 3rd, Skitter zerg-rush every 2nd, Brute
    /// every 6th (Brutes then Reavers win ties). Enemy HP ×1.1025 (+5%
    /// over Level 5, compounding). Structure HP matches the dossier.
    static let layout6 = LevelLayout(
        width: 8400,
        playerBaseX: 220,
        playerTowerXs: [700, 1450, 2200],
        enemyTowerXs: [6000, 6750, 7500],
        enemyBaseX: 8180,
        heroSpawnX: 420,
        platforms: [],
        theme: .sandhold,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 5.0,
        doubleChance: 0.45,
        maxEnemies: 20,
        bruteEvery: 6,
        reaverEvery: 3,
        skitterEvery: 2,
        jetEvery: 0,
        mechEvery: 0,
        towerHP: 320,
        baseHP: 800,
        enemyHPScale: 1.1025
    )
}
