import CoreGraphics

/// DEV playground (reached only via the PLAYGROUND button on the briefing
/// screen): a tiny dusk arena — one tower guarding the player HQ, NO enemy
/// tower — whose gate releases exactly ONE spawn of `Balance.playgroundUnit`
/// every summon tick (see GameScene.updateBases) so a unit can be inspected
/// up close. Structures and enemy HP stay Level-1 grade for raw stat checks.
extension Balance {
    static let layoutPlayground = LevelLayout(
        width: 2600,
        playerBaseX: 220,
        playerTowerXs: [760],
        enemyTowerXs: [],
        enemyBaseX: 2380,
        heroSpawnX: 420,
        platforms: [],
        theme: .dusk,
        flags: true,
        alienBirds: false,
        lushFlora: false,
        summonInterval: 4.0,
        doubleChance: 0,
        maxEnemies: 6,
        bruteEvery: 0,
        reaverEvery: 0,
        skitterEvery: 0,
        jetEvery: 0,
        mechEvery: 0,
        heliEvery: 0,
        mechPairSize: 1,
        mechPairDelay: 2.0,
        towerHP: 200,
        baseHP: 500,
        enemyHPScale: 1.0,
        towerFanCount: 1,
        playground: true
    )
}
