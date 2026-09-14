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
}
