import CoreGraphics

/// Level 18 Riven Pass: the same field as Highridge Redoubt — identical
/// lane width, tower line, ridge-fort dressing and summon cadence — but
/// fought at evening, in the last hour before the sun sets. The deep
/// evening-blue sky glows amber-gold at the horizon; the pines and the
/// redoubt's ramparts sit silhouetted against it.
///
/// Structure HP and enemy HP follow the campaign's usual per-level step
/// (enemy HP ×1.8858, +5% over L17); the gate ticks a touch faster for
/// the 12-wave dossier. Riven Pass fields three extra mech walkers on
/// top of Highridge's bonus list — spread between the existing bonus
/// summon numbers so no stretch of the lane goes walker-free.
extension Balance {
    static let layout18 = LevelLayout(
        width: 13200,
        playerBaseX: 220,
        playerTowerXs: [840, 1640, 2440, 3240],
        enemyTowerXs: [9050, 9850, 10650, 11450],
        enemyBaseX: 12980,
        heroSpawnX: 420,
        platforms: [],
        theme: .dusk,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 3.3,
        doubleChance: 0.55,
        maxEnemies: 32,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 11,
        mechEvery: 7,
        heliEvery: 4,
        mechPairSize: 2,
        mechPairDelay: 1.6,
        towerHP: 540,
        baseHP: 1420,
        enemyHPScale: 1.8858,
        alpinePass: true,
        ridgeRedoubt: true,
        extraBruteSummons: [5, 11, 17, 23, 29],
        extraMechSummons: [8, 12, 15, 19, 22, 26, 29],
        pineDensity: 0.9,
        towerFanCount: 3,
        truckEvery: 5,
        truckCount: 1
    )
}
