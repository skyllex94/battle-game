import Foundation

/// Rewarded-ad outcome from the player's side: granted = they watched
/// enough to earn the revive, anything else = no reward.
enum AdReward {
    case granted
    case cancelled
    case unavailable
}

/// Rewarded-ads seam. The game only talks to this protocol — today the
/// stub simulates a 3s ad so the revive flow is fully playable with zero
/// accounts; later Google Mobile Ads / Unity Ads conforms here and drops
/// in with no game-code changes.
protocol AdService {
    /// Presents a rewarded ad and returns its outcome. The caller owns
    /// all UI (the stub needs none — GameView shows its own countdown).
    func showRewarded() async -> AdReward
}

/// Simulated rewarded ad: waits ~3s (the GameView countdown covers it),
/// then grants. Stands in until the real SDK lands.
final class StubAdService: AdService {
    static let shared = StubAdService()

    private init() {}

    func showRewarded() async -> AdReward {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        return .granted
    }
}
