import CoreGraphics
import Foundation

/// Per-hero upgrade tracks. Four lines, three tiers each (0 = stock):
/// HP (+25 max HP/tier), SPD (+8% move speed/tier), SHIELD (energy shield
/// that absorbs damage first and recharges), DMG (+10% hero damage/tier).
enum HeroUpgradeTrack: String, CaseIterable {
    case hp
    case speed
    case shield
    case damage

    static let maxTier = 3

    var label: String {
        switch self {
        case .hp: return "HEALTH"
        case .speed: return "SPEED"
        case .shield: return "SHIELD"
        case .damage: return "DAMAGE"
        }
    }

    /// Short effect line for the current tier (shown under the pips).
    func effect(tier: Int) -> String {
        switch self {
        case .hp: return "+\(25 * tier) MAX HP"
        case .speed: return tier == 0 ? "STOCK SPEED" : "+\(tier) SPEED"
        case .shield:
            return tier == 0 ? "NO SHIELD" : "\(HeroUpgrades.shieldCapacity(tier: tier)) SHIELD"
        case .damage: return "+\(2 * tier) DMG"
        }
    }
}

/// Persisted per-hero upgrade tiers (UserDefaults). The battle reads
/// effective stats through here — the armory writes through buy().
enum HeroUpgrades {
    private static func key(heroId: String, track: HeroUpgradeTrack) -> String {
        "hero.upgrades.\(heroId).\(track.rawValue)"
    }

    static func tier(heroId: String, track: HeroUpgradeTrack) -> Int {
        min(HeroUpgradeTrack.maxTier,
            max(0, UserDefaults.standard.integer(forKey: key(heroId: heroId, track: track))))
    }

    /// Next-tier price, nil when maxed.
    static func nextCost(heroId: String, track: HeroUpgradeTrack) -> Int? {
        let t = tier(heroId: heroId, track: track)
        return t < HeroUpgradeTrack.maxTier ? Economy.heroUpgradeCost(t + 1) : nil
    }

    /// Buys the next tier. Returns false when maxed or broke.
    @discardableResult
    static func buy(heroId: String, track: HeroUpgradeTrack) -> Bool {
        guard let cost = nextCost(heroId: heroId, track: track),
              WalletStore.shared.spend(cost) else { return false }
        UserDefaults.standard.set(tier(heroId: heroId, track: track) + 1,
                                  forKey: key(heroId: heroId, track: track))
        return true
    }

    // MARK: - Effective battle stats (base behavior untouched at tier 0)

    /// Roster stock HP for a hero (100 scout … 580 warlord).
    static func baseHP(heroId: String) -> Int {
        HeroRoster.heroes.first(where: { $0.id == heroId })?.maxHealth ?? 100
    }

    /// Battle max HP: roster stock +25/tier.
    static func maxHP(heroId: String) -> CGFloat {
        CGFloat(baseHP(heroId: heroId) + 25 * tier(heroId: heroId, track: .hp))
    }

    /// Move-speed multiplier. Gentle curve: scout stock (10) runs the
    /// classic 1.0x, and every +1 speed is +5% — so the 20-speed ranger
    /// tops out at 1.5x (what 15 used to be), never double pace.
    static func speedMultiplier(heroId: String) -> CGFloat {
        CGFloat(0.5 + 0.05 * speedValue(heroId: heroId))
    }

    /// Roster stock speed for a hero (10 scout … 20 ranger).
    static func baseSpeed(heroId: String) -> Double {
        HeroRoster.heroes.first(where: { $0.id == heroId })?.speed ?? 10
    }

    /// Effective speed: roster stock +1 per SPEED tier. Battle run speed
    /// is Balance.heroRunSpeed × (0.5 + 0.05 × value), so scout (10) runs
    /// the classic 520, each +1 tier reads on the sheet and adds 5% pace.
    static func speedValue(heroId: String) -> Double {
        baseSpeed(heroId: heroId) + Double(tier(heroId: heroId, track: .speed))
    }

    /// Roster stock damage bonus (0 scout … 14 warlord).
    static func baseDamage(heroId: String) -> Int {
        HeroRoster.heroes.first(where: { $0.id == heroId })?.baseDamage ?? 0
    }

    /// Flat damage added to every shot fired: roster stock +2 per DAMAGE
    /// tier. Scout stock stays +0; a maxed warlord lands +20 per trigger.
    static func damageBonus(heroId: String) -> CGFloat {
        CGFloat(baseDamage(heroId: heroId) + 2 * tier(heroId: heroId, track: .damage))
    }

    /// Shield pool capacity (0 = no shield mechanic at all).
    /// Tiers run 0/100/200/300 — the orb's three charge levels.
    static func shieldCapacity(tier: Int) -> Int {
        [0, 100, 200, 300][min(max(tier, 0), 3)]
    }

    static func shieldMax(heroId: String) -> CGFloat {
        CGFloat(shieldCapacity(tier: tier(heroId: heroId, track: .shield)))
    }

    // MARK: - Shield carryover (leftovers survive a win)

    private static func carryKey(_ heroId: String) -> String {
        "hero.shield.\(heroId).carry"
    }

    private static func carryMaxKey(_ heroId: String) -> String {
        "hero.shield.\(heroId).carryMax"
    }

    /// Banks the leftover shield on victory (amount + the max it was
    /// banked under, so later upgrades stack additively on top).
    static func saveShieldCarry(heroId: String, amount: CGFloat, cap: CGFloat) {
        UserDefaults.standard.set(Double(max(0, amount)), forKey: carryKey(heroId))
        UserDefaults.standard.set(Double(max(0, cap)), forKey: carryMaxKey(heroId))
    }

    /// Starting shield for a fresh level entry: banked leftover plus any
    /// capacity bought since the win, capped at the current max.
    /// Nil = nothing banked → start full. Single-use: it clears on read.
    static func consumeShieldCarry(heroId: String, cap: CGFloat) -> CGFloat? {
        guard UserDefaults.standard.object(forKey: carryKey(heroId)) != nil else {
            return nil
        }
        let carry = CGFloat(UserDefaults.standard.double(forKey: carryKey(heroId)))
        let carryMax = CGFloat(UserDefaults.standard.double(forKey: carryMaxKey(heroId)))
        UserDefaults.standard.removeObject(forKey: carryKey(heroId))
        UserDefaults.standard.removeObject(forKey: carryMaxKey(heroId))
        return min(cap, carry + max(0, cap - carryMax))
    }
}

/// Per-hero ADD-ONS (the armory's second panel, under UPGRADES).
/// Shield lives here in the UI but keeps its upgrade-track storage +
/// battle behavior untouched. New perks get their own storage:
/// - HEALTH BOOSTER: tiered 0-3 heal packs (75/150/300 HP). Each attempt
///   carries one pack, fired from the HUD button next to the vitals.
///   One use per run.
/// - BATTLE DROID: tiered 0-3 hover buddy (scout, gunship, elite spread).
///   Dies and is reborn with the hero; never targeted.
enum HeroAddons {
    static let boosterMax = 3

    private static func boosterKey(_ heroId: String) -> String {
        "hero.addons.\(heroId).booster"
    }

    private static func droidKey(_ heroId: String) -> String {
        "hero.addons.\(heroId).droid"
    }

    // MARK: - Health booster (HUD heal pack, one use per run)

    static func boosterTier(heroId: String) -> Int {
        min(boosterMax, max(0, UserDefaults.standard.integer(forKey: boosterKey(heroId))))
    }

    /// HP restored by the pack at each tier.
    static func boosterHeal(tier: Int) -> Int {
        [0, 75, 150, 300][min(max(tier, 0), 3)]
    }

    static func boosterEffect(tier: Int) -> String {
        tier == 0 ? "NO PACK" : "+\(boosterHeal(tier: tier)) HP PACK"
    }

    /// Next-tier price, nil when maxed.
    static func boosterCost(heroId: String) -> Int? {
        let t = boosterTier(heroId: heroId)
        return t < boosterMax ? Economy.heroBoosterCost(t + 1) : nil
    }

    /// Buys the next booster tier. Returns false when maxed or broke.
    @discardableResult
    static func buyBooster(heroId: String) -> Bool {
        guard let cost = boosterCost(heroId: heroId),
              WalletStore.shared.spend(cost) else { return false }
        UserDefaults.standard.set(boosterTier(heroId: heroId) + 1, forKey: boosterKey(heroId))
        return true
    }

    // MARK: - Battle droid (hover buddy, 3 tiers)

    static let droidMax = 3

    private static func droidTierKey(_ heroId: String) -> String {
        "hero.addons.\(heroId).droidTier"
    }

    static func droidTier(heroId: String) -> Int {
        let t = UserDefaults.standard.integer(forKey: droidTierKey(heroId))
        if t > 0 { return min(droidMax, t) }
        // Migrate the old single-buyout flag (true = tier 1).
        if UserDefaults.standard.bool(forKey: droidKey(heroId)) {
            UserDefaults.standard.set(1, forKey: droidTierKey(heroId))
            return 1
        }
        return 0
    }

    static func hasDroid(heroId: String) -> Bool {
        droidTier(heroId: heroId) > 0
    }

    static func droidEffect(tier: Int) -> String {
        switch tier {
        case 1: return "SHOTS ×6 DMG"
        case 2: return "SHOTS ×10 DMG"
        case 3: return "3-SHOT ×6 SPREAD"
        default: return "NO DROID"
        }
    }

    /// Next-tier price, nil when maxed. Flat 1 diamond while tuning.
    static func droidCost(heroId: String) -> Int? {
        let t = droidTier(heroId: heroId)
        return t < droidMax ? Economy.heroDroidCost(t + 1) : nil
    }

    /// Buys the next droid tier. Returns false when maxed or broke.
    @discardableResult
    static func buyDroid(heroId: String) -> Bool {
        guard let cost = droidCost(heroId: heroId),
              WalletStore.shared.spend(cost) else { return false }
        UserDefaults.standard.set(droidTier(heroId: heroId) + 1, forKey: droidTierKey(heroId))
        return true
    }
}
