import CoreGraphics

/// Level 16 Cinderpeak Ascent: the same high granite shelf as Titan's
/// Gate — same sunrise, same bare rock shelf, same lane width and tower
/// line. The only change to the land is the treeline: the pines thin
/// out, leaving more bare scree and open rock on the shelf.
///
/// The gate is the hard part. The enemy field is stacked with heavy
/// units — single Missile Trucks roll out, Heli Gunships fly almost
/// every fourth wave, Brutes every third, Mech walkers every seventh
/// (in twos), and five waves get an extra Brute and four get an extra
/// Mech on top of the normal batch. The gate also pops pairs more
/// often and marches faster.
///
/// The structure HP and enemy HP follow the campaign's usual per-level
/// step (enemy HP ×1.7105, +5% over L15).
extension Balance {
    static let layout16 = LevelLayout(
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
        // Hotter gate than Titan's Gate: marches out faster and pops a
        // pair more often.
        summonInterval: 3.5,
        doubleChance: 0.55,
        maxEnemies: 30,
        // The heavy roster: Brutes every 3rd wave, Gunships every 4th,
        // Missile Trucks every 5th (singly), Mech walkers every 7th
        // (in twos). Skitters keep the gaps between them busy.
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 11,
        mechEvery: 7,
        heliEvery: 4,
        // Walkers roll out in pairs now, tighter together than on L15.
        mechPairSize: 2,
        mechPairDelay: 1.6,
        towerHP: 500,
        baseHP: 1300,
        enemyHPScale: 1.7105,
        alpinePass: true,
        // Bonus heavies on top of the normal batch.
        extraBruteSummons: [5, 11, 17, 23, 29],
        extraMechSummons: [8, 15, 22, 29],
        // The difference from Level 15: the treeline thins right out —
        // more bare rock, far fewer pines.
        pineDensity: 0.9,
        towerFanCount: 3,
        // Missile-truck waves: a single launcher every 5th wave.
        truckEvery: 5,
        truckCount: 1
    )
}
