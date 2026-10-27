import CoreGraphics

/// Level 35 Embral Core (FINALE): the same Mordor-inspired blood-red theater
/// as the Obsidian Gate (see MordorBG) — burning maroon sky under the bloated
/// ember moon, black peak-wall with the smoking volcano, rolling ash wastes,
/// cracked basalt lane veined with living ember — pushed to the heart of it:
/// the lane ends at the fused floor of the Embral Core itself, where
/// obsidian and ember have melted together into core shards, burning
/// core veins split the slabs, chained core rings lie half-buried, and tall
/// twin-flame core-braziers mark the army's last road
/// (see `embralCore`: core shards, core veins, chained rings,
/// core-braziers).
///
/// The 5-tower line holds (fifth emplacements at player 4950 / enemy 8250,
/// same 13200pt lane). The finale fields no new marcher — instead the Core
/// turns the screws over the Obsidian Gate (L34): marches out fastest yet,
/// pops pairs most often, the field cap holds at the 50-unit ceiling,
/// elites stay at their densest cadence across the board (jets every 5th,
/// mechs every 3rd, gunships every 2nd, trucks every 4th, saucers every 2nd,
/// Immortals every 3rd, Phoenix every 4th, Vespers every 5th), bonus Brutes
/// + Mechs stack up across the 18-wave push, and enemy HP scales another 5%
/// (×4.3224, +5% over L34). Six Gnashers still crawl out as bonus summons
/// across the push; clear them at range or eat the burst.
///
/// Structures: the allied HQ is the same Mk-II citadel + 4-missile battery
/// as every level since 20. The enemy HQ is the finale main-main building —
/// a huge Mordor-style core-fortress (see BaseNode finale) answering every
/// push with a 5-missile salvo (see Balance.baseMissileCountFinale).
extension Balance {
    static let layout35 = LevelLayout(
        width: 13200,
        playerBaseX: 220,
        playerTowerXs: [1750, 2550, 3350, 4150, 4950],
        enemyTowerXs: [8250, 9050, 9850, 10650, 11450],
        enemyBaseX: 12980,
        heroSpawnX: 420,
        platforms: [],
        theme: .mordor,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 1.2,
        doubleChance: 0.90,
        maxEnemies: 50,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 5,
        mechEvery: 3,
        heliEvery: 2,
        mechPairSize: 2,
        mechPairDelay: 0.6,
        towerHP: 1020,
        baseHP: 2750,
        enemyHPScale: 4.3224,
        snowfall: false,
        extraBruteSummons: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42],
        extraMechSummons: [3, 7, 11, 15, 19, 23, 27, 31, 35, 39, 43],
        extraGnasherSummons: [4, 12, 20, 28, 36, 44],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 4,
        truckCount: 1,
        /// The Immortals hold the Core — one walker at a time,
        /// every third summon (the densest cadence, held from L31).
        immortalEvery: 3,
        /// Saucer gun-drones thick over the Core — every second
        /// summon, matching the gunships.
        saucerEvery: 2,
        /// Phoenix strike-fighters dive over the Core — every fourth
        /// summon, checked behind the vesper cadence.
        phoenixEvery: 4,
        /// Vesper heralds drift over the Core — every fifth summon,
        /// checked ahead of the phoenix cadence.
        vesperEvery: 5,
        /// The lane is cracked basalt, not wind-glazed ice.
        iceField: false,
        /// Embral Core ash ground: small pixel-art whispers baked
        /// into the field (see LevelDressing.buildEmbralCore).
        embralCore: true
    )
}
