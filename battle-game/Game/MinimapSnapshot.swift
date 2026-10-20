import CoreGraphics

/// Lightweight minimap data. The scene publishes this at ~7Hz; MinimapView
/// renders dots — no second SKView, near-zero perf cost.
/// (Alive/dead flags join in the combat stage when towers fall.)
struct MinimapSnapshot: Equatable {
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
    /// Energy shield pool (0 max hides the bar).
    var shieldHP: CGFloat = 0
    var shieldMax: CGFloat = 0
    /// Health-pack button state (booster add-on): armed this run + heal.
    var packReady: Bool = false
    var packAmount: Int = 0
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
    // Deploy cooldowns straight from the scene (seconds left per unit) —
    // the scene is the authority so the card never disagrees with the gate.
    var summonCooldowns: [ArmyKind: Double] = [:]
    // Live army count + the cap (so the UI can say FULL instead of silently
    // refusing a deploy).
    var allyCount: Int = 0
    var allyCap: Int = 20
}
