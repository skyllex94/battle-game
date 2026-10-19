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
        grant(gun)
        return true
    }

    /// Free milestone grant (Level 5 modals, quest rewards): records
    /// ownership with no diamond charge. No-op when already owned.
    static func grant(_ gun: HeroWeapon) {
        var set = purchasedRawValues
        set.insert(gun.rawValue)
        UserDefaults.standard.set(Array(set), forKey: purchasedKey)
    }
}

/// Heroes claimed by milestone (persisted ids). HeroRoster consults it
/// so a battle-time unlock survives replays — the gun-unlock seam, but
/// for heroes.
enum HeroRosterClaims {
    private static let claimedKey = "heroroster.claimed"

    static var claimedIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: claimedKey) ?? [])
    }

    static func owns(_ hero: HeroDef) -> Bool {
        claimedIds.contains(hero.id)
    }

    /// Records a claimed hero and selects it for future battles.
    static func claim(_ hero: HeroDef) {
        record(hero)
        HeroRoster.selectedHeroId = hero.id
    }

    /// Records ownership only (the player kept their current hero) — the
    /// milestone unlocks in the armory without re-offering the modal.
    static func record(_ hero: HeroDef) {
        var set = claimedIds
        set.insert(hero.id)
        UserDefaults.standard.set(Array(set), forKey: claimedKey)
    }
}
