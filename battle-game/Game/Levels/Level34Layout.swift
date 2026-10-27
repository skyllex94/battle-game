import CoreGraphics

/// Level 34 Obsidian Gate: the same Mordor-inspired blood-red theater as
/// Dread Hollow (see MordorBG) — burning maroon sky under the bloated ember
/// moon, black peak-wall with the smoking volcano, rolling ash wastes,
/// cracked basalt lane veined with living ember — crossed one final step
/// before the Core: the lane climbs to a wall of black glass where obsidian
/// monoliths rise like blades, violet void veins bleed between the slabs,
/// and pale shackle-rings hang from the stone, lit by violet void-fire
/// (see `obsidianGate`: monoliths, void veins, shackle-rings,
/// void-braziers).
///
/// The 5-tower line holds (fifth emplacements at player 4950 / enemy 8250,
/// same 13200pt lane). Level 34 debut: the Vesper — a slow violet
/// void-herald gliding above everything hostile, loosing a 3-shard fan of
/// weaving void splinters with a small splash. It drifts in on every 5th
/// summon (checked ahead of the phoenix cadence so the debut is never
/// swallowed by it). The gate turns the screws over Dread Hollow (L33):
/// marches out faster, pops pairs more often, the field cap holds at the
/// 50-unit ceiling, elites stay dense across the board (jets every 5th,
/// mechs every 3rd, gunships every 2nd, trucks every 4th, saucers every 2nd,
/// Immortals every 3rd, Phoenix every 4th), bonus Brutes + Mechs stack up
/// across the 17-wave push, and enemy HP scales another 5% (×4.1166, +5%
/// over L33). Five Gnashers still crawl out as bonus summons across the
/// push; clear them at range or eat the burst.
extension Balance {
    static let layout34 = LevelLayout(
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
        summonInterval: 1.3,
        doubleChance: 0.88,
        maxEnemies: 50,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 5,
        mechEvery: 3,
        heliEvery: 2,
        mechPairSize: 2,
        mechPairDelay: 0.6,
        towerHP: 970,
        baseHP: 2600,
        enemyHPScale: 4.1166,
        snowfall: false,
        extraBruteSummons: [2, 6, 10, 14, 18, 22, 26, 30, 34, 38],
        extraMechSummons: [3, 7, 11, 15, 19, 23, 27, 31, 35, 39],
        extraGnasherSummons: [4, 12, 20, 28, 36],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 4,
        truckCount: 1,
        /// The Immortals press the gate — one walker at a time,
        /// every third summon (the densest cadence, held from L31).
        immortalEvery: 3,
        /// Saucer gun-drones thick over the gate — every second
        /// summon, matching the gunships.
        saucerEvery: 2,
        /// Phoenix strike-fighters dive over the gate — every fourth
        /// summon, checked behind the vesper cadence.
        phoenixEvery: 4,
        /// Vesper heralds drift over the gate — every fifth summon,
        /// checked ahead of the phoenix cadence.
        vesperEvery: 5,
        /// The lane is cracked basalt, not wind-glazed ice.
        iceField: false,
        /// Obsidian Gate ash ground: small pixel-art whispers baked
        /// into the field (see LevelDressing.buildObsidianGate).
        obsidianGate: true
    )
}
