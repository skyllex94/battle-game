import Foundation

/// Gun loadout: the hero carries slotted guns into battle (starter = slot
/// 1, the HUD switch cycles the rest). Starts at 2 slots, purchasable to
/// 6 with diamonds. Order matters; empties allowed past slot 1.
enum LoadoutStore {
    private static let loadoutKey = "loadout.guns.v1"
    private static let slotsKey = "loadout.slots.v1"

    static let baseSlots = 2
    static let maxSlotsCap = 6

    /// Purchased extra slots (persisted count).
    private static var extraSlots: Int {
        get { UserDefaults.standard.integer(forKey: slotsKey) }
        set { UserDefaults.standard.set(newValue, forKey: slotsKey) }
    }

    /// Total usable slots right now.
    static var slotCount: Int {
        min(baseSlots + extraSlots, maxSlotsCap)
    }

    /// Next slot price, nil when maxed.
    static var nextSlotCost: Int? {
        let next = slotCount + 1
        return next <= maxSlotsCap ? Economy.slotCost(next) : nil
    }

    /// Buys the next slot. Returns false when maxed or broke.
    @discardableResult
    static func buySlot() -> Bool {
        guard let cost = nextSlotCost,
              WalletStore.shared.spend(cost) else { return false }
        extraSlots += 1
        return true
    }

    /// Filled slots in order (never empty — falls back to Blaster).
    static var loadout: [HeroWeapon] {
        get {
            let raw = UserDefaults.standard.array(forKey: loadoutKey) as? [Int] ?? []
            let guns = raw.compactMap { HeroWeapon(rawValue: $0) }
                .filter { GunLocker.isUnlocked($0) }
            return guns.isEmpty ? [.blaster] : Array(guns.prefix(slotCount))
        }
        set {
            let guns = Array(newValue.prefix(slotCount))
            UserDefaults.standard.set(guns.map { $0.rawValue }, forKey: loadoutKey)
        }
    }

    /// Slot 1 — the gun the battle starts with.
    static var starter: HeroWeapon {
        loadout.first ?? .blaster
    }

    /// Assigns a gun to a slot (replace) or appends when tapping an empty
    /// slot. Locked guns are refused; duplicates are refused (the gun is
    /// already slotted — caller reselects instead).
    /// Returns the resulting slot index, or nil when refused.
    @discardableResult
    static func assign(_ gun: HeroWeapon, to slot: Int) -> Int? {
        guard GunLocker.isUnlocked(gun),
              slot >= 0, slot < slotCount else { return nil }
        var guns = loadout
        if let existing = guns.firstIndex(of: gun) { return existing }
        if slot < guns.count {
            guns[slot] = gun
            loadout = guns
            return slot
        } else if guns.count < slotCount {
            guns.append(gun)
            loadout = guns
            return guns.count - 1
        }
        return nil
    }

    /// Index of the gun's slot, if slotted.
    static func slot(of gun: HeroWeapon) -> Int? {
        loadout.firstIndex(of: gun)
    }
}
