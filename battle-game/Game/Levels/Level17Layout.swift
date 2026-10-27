import CoreGraphics

/// Level 17 Highridge Redoubt: the same high granite shelf as Cinderpeak
/// Ascent — same sunrise, same bare rock shelf, same lane width and tower
/// line, and the same thin treeline.
///
/// The enemy works are spilled across the field
/// (broken curtain walls, dug-in gun pits, stake barricades, their
/// banners); the mid-ground range is left bare.
///
/// The gate stays as heavy as Cinderpeak's — single Missile Trucks,
/// Gunships every fourth wave, Brutes every other summon, Mech walkers
/// filling every remaining rank slot one at a time, with no skitters at
/// all (their slots roll out as brutes and walkers instead), with bonus
/// Brutes and Mechs on top of the normal batch. The gate also marches
/// a touch faster.
///
/// Structure HP and enemy HP follow the campaign's usual per-level step
/// (enemy HP ×1.7960, +5% over L16).
extension Balance {
    static let layout17 = LevelLayout(
        width: 13200,
        playerBaseX: 220,
        playerTowerXs: [840, 1640, 2440, 3240],
        enemyTowerXs: [9050, 9850, 10650, 11450],
        enemyBaseX: 12980,
        heroSpawnX: 420,
        platforms: [],
        theme: .sunrise,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 3.4,
        doubleChance: 0.55,
        maxEnemies: 30,
        // The heavy roster, same as the Ascent.
        bruteEvery: 2,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 11,
        // Mechs own every ranked slot the trucks, gunships and brutes
        // don't claim — raider chaff is gone from this level.
        mechEvery: 1,
        heliEvery: 4,
        mechPairSize: 1,
        towerHP: 520,
        baseHP: 1360,
        enemyHPScale: 1.7960,
        alpinePass: true,
        // The difference from Level 16: the field and the mid ground
        // carry the redoubt's works and the ridge fort.
        ridgeRedoubt: true,
        extraBruteSummons: [5, 11, 17, 23, 29],
        extraMechSummons: [8, 15, 22, 29],
        pineDensity: 0.9,
        towerFanCount: 3,
        truckEvery: 5,
        truckCount: 1
    )
}
