import CoreGraphics

/// Lightweight minimap data. The scene publishes this at ~7Hz; MinimapView
/// renders dots — no second SKView, near-zero perf cost.
/// (Alive/dead flags join in the combat stage when towers fall.)
struct MinimapSnapshot {
    var levelWidth: CGFloat
    var heroX: CGFloat
    var cameraX: CGFloat
    var viewWidth: CGFloat
    var playerBaseX: CGFloat
    var playerTowerXs: [CGFloat]
    var enemyTowerXs: [CGFloat]
    var enemyBaseX: CGFloat
    // HUD economy/combat state (same polling channel, ~7Hz).
    var heroHP: CGFloat
    var heroMaxHP: CGFloat
    var heroLives: Int = 3
    var heroMaxLives: Int = 3
    var money: Int
    // Unit dots: player army (blue) + enemy marchers (red).
    var allyXs: [CGFloat] = []
    var enemyXs: [CGFloat] = []
    // Active hero-gun ammo readout (mag/reserve, e.g. 12/90).
    var ammoText: String = "–/–"
    var ammoMag: Int = 0
    var reloading: Bool = false
    // Victory channel: enemy HQ down + the winning time (seconds).
    var won: Bool = false
    var winTime: Double = 0
    // Defeat channel: last hero heart lost (no respawn coming).
    var lost: Bool = false
}
