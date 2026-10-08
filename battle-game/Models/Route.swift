import Foundation

/// Path-based campaign navigation (owned by MainMenuView's NavigationStack).
/// Game → Continue pops the finished battle and pushes the next briefing,
/// so BACK from a briefing always lands on the map and finished battles
/// are released instead of stacking in memory.
enum Route: Hashable {
    case map
    case detail(levelId: Int)
    case game(levelId: Int, heroId: String)
}
