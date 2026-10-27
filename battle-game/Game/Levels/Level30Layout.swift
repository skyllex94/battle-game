import CoreGraphics

/// Level 30 Blackroot Vale: the same Mordor-inspired blood-red theater as
/// Ashen March (see MordorBG) — burning maroon sky under the bloated ember
/// moon, black peak-wall with the smoking volcano, rolling ash wastes,
/// cracked basalt lane veined with living ember — crossed one step deeper:
/// blackened root wreaths break through the basalt where nothing green has
/// grown in years, ember sap glowing in the splits, and pale root-bound
/// cairns mark the dead vale (see `blackrootVale`: root wreaths, ember sap,
/// root-cairns, taller braziers).
///
/// The 5-tower line holds (fifth emplacements at player 4950 / enemy 8250,
/// same 13200pt lane). Level 30 debut: the Phoenix — a fast crimson
/// graviton strike-fighter cruising above even the saucers, loosing
/// 3-round red-plasma bursts. It dives in on every 4th summon (checked
/// ahead of the saucer cadence so the debut is never swallowed by it).
/// The gate turns the screws over Ashen March (L29): marches out faster,
/// pops pairs more often, the field cap rises to the 48-unit ceiling,
/// elites come denser across the board (jets every 5th, mechs every 3rd,
/// gunships every 2nd, trucks every 4th, saucers every 2nd, Immortals
/// every 3rd), bonus Brutes + Mechs stack up across the 16-wave push, and
/// enemy HP scales another 5% (×3.3868, +5% over L29). Five Gnashers still
/// crawl out as bonus summons across the push; clear them at range or eat
/// the burst.
extension Balance {
    static let layout30 = LevelLayout(
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
        summonInterval: 1.7,
        doubleChance: 0.80,
        maxEnemies: 48,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 5,
        mechEvery: 3,
        heliEvery: 2,
        mechPairSize: 2,
        mechPairDelay: 0.6,
        towerHP: 840,
        baseHP: 2260,
        enemyHPScale: 3.3868,
        snowfall: false,
        extraBruteSummons: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38],
        extraMechSummons: [3, 7, 11, 15, 19, 23, 27, 31, 35, 39],
        extraGnasherSummons: [4, 12, 20, 28, 36],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 4,
        truckCount: 1,
        /// The Immortals press the vale — one walker at a time,
        /// every third summon (the densest cadence yet).
        immortalEvery: 3,
        /// Saucer gun-drones thick over the roots — every second
        /// summon, matching the gunships.
        saucerEvery: 2,
        /// Phoenix strike-fighters dive over the vale — every fourth
        /// summon, checked ahead of the saucer cadence.
        phoenixEvery: 4,
        /// The lane is cracked basalt, not wind-glazed ice.
        iceField: false,
        /// Blackroot Vale ash ground: small pixel-art whispers baked
        /// into the field (see LevelDressing.buildBlackrootVale).
        blackrootVale: true
    )
}
