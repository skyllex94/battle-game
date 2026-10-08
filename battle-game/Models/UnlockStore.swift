import Foundation

/// Diamond buyouts for guns. Owns the purchased set (persisted raw values);
/// GunLocker consults it alongside campaign milestones. Atomic buy:
/// spends from the wallet and records ownership in one call.
enum UnlockStore {
    private static let purchasedKey = "unlockstore.guns.purchased"

    /// Raw values of guns bought with diamonds.
    static var purchasedRawValues: Set<Int> {
        Set(UserDefaults.standard.array(forKey: purchasedKey) as? [Int] ?? [])
    }

    static func owns(_ gun: HeroWeapon) -> Bool {
        purchasedRawValues.contains(gun.rawValue)
    }

    /// Buys a gun for its diamond price. Returns false (no charge, no
    /// record) when already owned/unlocked or when the wallet is short.
    @discardableResult
    static func buy(_ gun: HeroWeapon) -> Bool {
        guard gun.diamondCost > 0,
              !owns(gun),
              !GunLocker.isUnlocked(gun),
              WalletStore.shared.spend(gun.diamondCost) else { return false }
        var set = purchasedRawValues
        set.insert(gun.rawValue)
        UserDefaults.standard.set(Array(set), forKey: purchasedKey)
        return true
    }
}
