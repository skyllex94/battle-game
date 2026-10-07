import Combine
import Foundation

/// Diamond wallet. Singleton observable (HUD, armories, popups all read
/// live) persisted in UserDefaults. earn() / spend() are the only
/// mutations — the economy flows through here.
final class WalletStore: ObservableObject {
    static let shared = WalletStore()

    private static let balanceKey = "wallet.diamonds"
    private static let lifetimeKey = "wallet.lifetimeEarned"

    @Published private(set) var diamonds: Int
    @Published private(set) var lifetimeEarned: Int

    private init() {
        diamonds = max(0, UserDefaults.standard.integer(forKey: Self.balanceKey))
        lifetimeEarned = max(0, UserDefaults.standard.integer(forKey: Self.lifetimeKey))
    }

    /// Adds diamonds (victory payouts, IAP packs later). Always succeeds.
    func earn(_ amount: Int) {
        guard amount > 0 else { return }
        diamonds += amount
        lifetimeEarned += amount
        persist()
    }

    /// Spends diamonds (revives, buyouts, upgrades). Returns false when
    /// broke — the balance is untouched in that case.
    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard amount > 0, diamonds >= amount else { return false }
        diamonds -= amount
        persist()
        return true
    }

    func canAfford(_ amount: Int) -> Bool {
        diamonds >= amount
    }

    private func persist() {
        UserDefaults.standard.set(diamonds, forKey: Self.balanceKey)
        UserDefaults.standard.set(lifetimeEarned, forKey: Self.lifetimeKey)
    }
}
