import CoreGraphics

/// Level 25 Frozen Narrows: the same frozen theater as Frostbite
/// Approach — identical polar sky, glacier shelf and wind-glazed snow
/// lane (see FrostbiteBG, SnowFX, the `iceField` flag) — but the glacier
/// pinches into a narrow channel: the field carries the narrows' small
/// whispers (see `frozenNarrows`: brittle ice sheets, rime shards and
/// wind-carved drifts) and the mid ground carries the matching small
/// alteration (see FrostbiteBG.buildMid): pale ice floes.
///
/// The gate turns the screws over Rimewatch Crag (L24): marches out
/// faster, pops pairs more often, the field cap jumps to 40, elites come
/// denser across the board (jets every 9th, mechs every 4th, helis every
/// 3rd, trucks every 4th, saucers every 5th, Immortals every 7th), bonus
/// Brutes + Mechs stack up across the 14-wave push, and enemy HP scales
/// another 5% (×2.6536, +5% over L24). The 5-tower line holds (fifth
/// emplacements at player 4950 / enemy 8250, same 13200pt lane).
extension Balance {
    static let layout25 = LevelLayout(
        width: 13200,
        playerBaseX: 220,
        playerTowerXs: [1750, 2550, 3350, 4150, 4950],
        enemyTowerXs: [8250, 9050, 9850, 10650, 11450],
        enemyBaseX: 12980,
        heroSpawnX: 420,
        platforms: [],
        theme: .frost,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 2.4,
        doubleChance: 0.70,
        maxEnemies: 40,
        bruteEvery: 3,
        reaverEvery: 0,
        skitterEvery: 2,
        jetEvery: 9,
        mechEvery: 4,
        heliEvery: 3,
        mechPairSize: 2,
        mechPairDelay: 0.9,
        towerHP: 700,
        baseHP: 1880,
        enemyHPScale: 2.6536,
        snowfall: true,
        extraBruteSummons: [4, 9, 15, 21, 27, 33, 39],
        extraMechSummons: [5, 11, 17, 23, 29, 35],
        pineDensity: 0,
        towerFanCount: 3,
        truckEvery: 4,
        truckCount: 2,
        /// The Immortals hold the narrows — one walker at a time,
        /// every seventh summon (tighter than the Crag's eighth).
        immortalEvery: 7,
        /// Saucer gun-drones thicken over the channel — every fifth
        /// summon, above even the gunships.
        saucerEvery: 5,
        /// The lane stays wind-glazed ice like the Approach and Crag.
        iceField: true,
        /// Frozen Narrows ice-channel ground: small pixel-art whispers
        /// frozen into the field (see LevelDressing.buildFrozenNarrows).
        frozenNarrows: true
    )
}
