import CoreGraphics

/// Level 15 Titan's Gate: the Granite Reach plateau again, but the gate
/// side of the range — same sunrise, same bare granite shelf, and this
/// time the treeline closes in: pine stands thicken across the far
/// range, the foreground and the ground scrub.
///
/// Everything else mirrors Level 14 (lane width, tower line, sunrise
/// theme, summon cadence). The structure HP and enemy HP follow the
/// campaign's usual per-level step.
extension Balance {
    static let layout15 = LevelLayout(
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
        summonInterval: 4.0,
        doubleChance: 0.49,
        maxEnemies: 24,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 6,
        mechEvery: 8,
        heliEvery: 5,
        // One walker per wave, same as Granite Reach.
        mechPairSize: 1,
        towerHP: 480,
        baseHP: 1240,
        enemyHPScale: 1.6290,
        alpinePass: true,
        extraMechSummons: [6, 13, 20],
        // The difference from Level 14: a much heavier treeline.
        pineDensity: 2.2,
        towerFanCount: 3
    )
}
