import CoreGraphics

/// Level 29 Ashen March: the same Mordor-inspired blood-red theater as
/// Umbral Outskirts (see MordorBG) — burning maroon sky under the bloated
/// ember moon, black peak-wall with the smoking volcano, rolling ash
/// wastes, cracked basalt lane veined with living ember — marched one step
/// deeper: the sky hangs heavier with ash storm (see the `ashenMarch`
/// grade in MordorBG.buildSky), the volcano burns a second crater glow,
/// the wastes stack an extra ash-drift sheet (see MordorBG.buildMid), and
/// the lane carries the march's whispers (see `ashenMarch`: scorched war
/// debris, shattered helms, broken banners, denser obsidian, taller
/// braziers).
///
/// The 5-tower line holds (fifth emplacements at player 4950 / enemy 8250,
/// same 13200pt lane). The gate turns the screws over Umbral Outskirts
/// (L28): marches out faster, pops pairs more often, the field cap rises
/// to the 46-unit ceiling, elites come denser across the board (jets every
/// 5th, mechs every 3rd, gunships every 2nd, trucks every 4th, saucers
/// every 2nd, Immortals every 3rd), bonus Brutes + Mechs stack up across
/// the 15-wave push, and enemy HP scales another 5% (×3.2255, +5% over L28).
/// Level 29 fields no new enemy — instead it unlocks the Tempest, a
/// flying allied artillery drone that spins up each shot before answering
/// with the widest blast in the army. The gate turns the screws over
/// Umbral Outskirts (L28): marches out faster, pops pairs more often, the
/// field cap rises to the 46-unit ceiling, elites come denser across the
/// board (jets every 5th, mechs every 3rd, gunships every 2nd, trucks
/// every 2nd, saucers every 2nd, Immortals every 3rd), bonus Brutes +
/// Mechs stack up across the 15-wave push, and enemy HP scales another 5%
/// (×3.2255, +5% over L28). Five Gnashers still crawl out as bonus summons
/// across the push; clear them at range or eat the burst.
extension Balance {
    static let layout29 = LevelLayout(
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
        summonInterval: 1.8,
        doubleChance: 0.78,
        maxEnemies: 46,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 5,
        mechEvery: 3,
        heliEvery: 2,
        mechPairSize: 2,
        mechPairDelay: 0.6,
        towerHP: 810,
        baseHP: 2180,
        enemyHPScale: 3.2255,
        snowfall: false,
        extraBruteSummons: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38],
        extraMechSummons: [3, 7, 11, 15, 19, 23, 27, 31, 35, 39],
        extraGnasherSummons: [4, 12, 20, 28, 36],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 4,
        truckCount: 1,
        /// The Immortals press the march — one walker at a time,
        /// every third summon (the densest cadence yet).
        immortalEvery: 3,
        /// Saucer gun-drones thick over the ash — every second
        /// summon, matching the gunships.
        saucerEvery: 2,
        /// The lane is cracked basalt, not wind-glazed ice.
        iceField: false,
        /// Ashen March ash ground: small pixel-art whispers baked
        /// into the field (see LevelDressing.buildAshenMarch).
        ashenMarch: true
    )
}
