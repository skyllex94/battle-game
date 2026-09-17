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
    var playerTowerX: CGFloat
    var enemyTowerX: CGFloat
    var enemyBaseX: CGFloat
    // HUD economy/combat state (same polling channel, ~7Hz).
    var heroHP: CGFloat
    var heroMaxHP: CGFloat
    var money: Int
    // Unit dots: player army (blue) + enemy marchers (red).
    var allyXs: [CGFloat] = []
    var enemyXs: [CGFloat] = []
    // Active hero-gun ammo readout (mag/reserve, e.g. 12/90).
    var ammoText: String = "–/–"
    var ammoMag: Int = 0
    var reloading: Bool = false
}
