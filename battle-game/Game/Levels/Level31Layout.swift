import CoreGraphics

/// Level 31 Cinder Gate: the same Mordor-inspired blood-red theater as
/// Blackroot Vale (see MordorBG) — burning maroon sky under the bloated
/// ember moon, black peak-wall with the smoking volcano, rolling ash
/// wastes, cracked basalt lane veined with living ember — crossed one step
/// deeper: scorched iron gate shards jut from the basalt where the Cinder
/// Gate itself was torn down, ember channels bleed light between the
/// slabs, and piled cinder slag + tall gate-braziers line the army's road
/// (see `cinderGate`: gate shards, ember channels, slag heaps,
/// gate-braziers).
///
/// The 5-tower line holds (fifth emplacements at player 4950 / enemy 8250,
/// same 13200pt lane). Level 31 debut: the Mk-III siege tower — a taller,
/// bulkier refit fielded by BOTH teams, trading the 3-missile Mk-II salvo
/// for a 4-missile volley (see Balance.megaUpgradedTowerLevel). The gate
/// turns the screws over Blackroot Vale (L30): marches out faster, pops
/// pairs more often, the field cap holds at the 48-unit ceiling, elites
/// come denser across the board (jets every 5th, mechs every 3rd,
/// gunships every 2nd, trucks every 4th, saucers every 2nd, Immortals
/// every 3rd, Phoenix every 4th), bonus Brutes + Mechs stack up across the
/// 16-wave push, and enemy HP scales another 5% (×3.5561, +5% over L30).
/// Five Gnashers still crawl out as bonus summons across the push; clear
/// them at range or eat the burst.
extension Balance {
    static let layout31 = LevelLayout(
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
        summonInterval: 1.6,
        doubleChance: 0.82,
        maxEnemies: 48,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 5,
        mechEvery: 3,
        heliEvery: 2,
        mechPairSize: 2,
        mechPairDelay: 0.6,
        towerHP: 870,
        baseHP: 2340,
        enemyHPScale: 3.5561,
        snowfall: false,
        extraBruteSummons: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38],
        extraMechSummons: [3, 7, 11, 15, 19, 23, 27, 31, 35, 39],
        extraGnasherSummons: [4, 12, 20, 28, 36],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 4,
        truckCount: 1,
        /// The Immortals press the gate — one walker at a time,
        /// every third summon (the densest cadence yet).
        immortalEvery: 3,
        /// Saucer gun-drones thick over the cinders — every second
        /// summon, matching the gunships.
        saucerEvery: 2,
        /// Phoenix strike-fighters dive over the gate — every fourth
        /// summon, checked ahead of the saucer cadence.
        phoenixEvery: 4,
        /// The lane is cracked basalt, not wind-glazed ice.
        iceField: false,
        /// Cinder Gate ash ground: small pixel-art whispers baked
        /// into the field (see LevelDressing.buildCinderGate).
        cinderGate: true
    )
}
