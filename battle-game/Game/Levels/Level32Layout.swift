import CoreGraphics

/// Level 32 Shadowrift: the same Mordor-inspired blood-red theater as
/// Cinder Gate (see MordorBG) — burning maroon sky under the bloated ember
/// moon, black peak-wall with the smoking volcano, rolling ash wastes,
/// cracked basalt lane veined with living ember — crossed one small step
/// deeper: the ground splits into a burning rift, and the only crossing is
/// a black bridge under enemy guns (see `shadowRift`: rift scar, bridge
/// span, rift-edge teeth, hanging braziers).
///
/// The 5-tower line holds (fifth emplacements at player 4950 / enemy 8250,
/// same 13200pt lane). Level 32 fields no new enemy — instead it unlocks
/// the Revrent, a bluish StarCraft-style carrier command ship ringed by
/// 5 interceptor droids that each loose their own bolt. The gate turns the
/// screws over Cinder Gate (L31): marches out faster, pops pairs more
/// often, the field cap rises to the 50-unit ceiling, elites stay dense
/// across the board (jets every 5th, mechs every 3rd, gunships every 2nd,
/// trucks every 4th, saucers every 2nd, Immortals every 3rd, Phoenix every
/// 4th), bonus Brutes + Mechs stack up across the 16-wave push, and enemy
/// HP scales another 5% (×3.7339, +5% over L31). Five Gnashers still crawl
/// out as bonus summons across the push; clear them at range or eat the
/// burst.
extension Balance {
    static let layout32 = LevelLayout(
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
        summonInterval: 1.5,
        doubleChance: 0.84,
        maxEnemies: 50,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 5,
        mechEvery: 3,
        heliEvery: 2,
        mechPairSize: 2,
        mechPairDelay: 0.6,
        towerHP: 900,
        baseHP: 2420,
        enemyHPScale: 3.7339,
        snowfall: false,
        extraBruteSummons: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38],
        extraMechSummons: [3, 7, 11, 15, 19, 23, 27, 31, 35, 39],
        extraGnasherSummons: [4, 12, 20, 28, 36],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 4,
        truckCount: 1,
        /// The Immortals press the rift — one walker at a time,
        /// every third summon (the densest cadence, held from L31).
        immortalEvery: 3,
        /// Saucer gun-drones thick over the rift — every second
        /// summon, matching the gunships.
        saucerEvery: 2,
        /// Phoenix strike-fighters dive over the rift — every fourth
        /// summon, checked ahead of the saucer cadence.
        phoenixEvery: 4,
        /// The lane is cracked basalt, not wind-glazed ice.
        iceField: false,
        /// Shadowrift ash ground: small pixel-art whispers baked
        /// into the field (see LevelDressing.buildShadowRift).
        shadowRift: true
    )
}
