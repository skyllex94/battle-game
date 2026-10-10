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
    static func shieldCapacity(tier: Int) -> Int {
        [0, 25, 50, 80][min(max(tier, 0), 3)]
    }

    static func shieldMax(heroId: String) -> CGFloat {
        CGFloat(shieldCapacity(tier: tier(heroId: heroId, track: .shield)))
    }
}

/// Per-hero ADD-ONS (the armory's second panel, under UPGRADES).
/// Shield lives here in the UI but keeps its upgrade-track storage +
/// battle behavior untouched. New perks get their own storage:
/// - HEALTH BOOSTER: tiered 0-3 medkits per run. Each pack cheats death:
///   lethal damage burns one pack and puts the hero back at 50% HP.
/// - SECOND HEART: one-time buyout, +1 life every run (3 -> 4 hearts).
enum HeroAddons {
    static let boosterMax = 3

    private static func boosterKey(_ heroId: String) -> String {
        "hero.addons.\(heroId).booster"
    }

    private static func heartKey(_ heroId: String) -> String {
        "hero.addons.\(heroId).heart"
    }

    // MARK: - Health booster (cheat-death packs per run)

    static func boosterTier(heroId: String) -> Int {
        min(boosterMax, max(0, UserDefaults.standard.integer(forKey: boosterKey(heroId))))
    }

    /// Medkit packs carried into every run (one pack = one cheated death).
    static func boosterPacks(heroId: String) -> Int {
        boosterTier(heroId: heroId)
    }

    static func boosterEffect(tier: Int) -> String {
        tier == 0 ? "NO BOOSTER" : "CHEAT DEATH ×\(tier)/RUN"
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

    // MARK: - Second heart (+1 life per run)

    static func hasHeart(heroId: String) -> Bool {
        UserDefaults.standard.bool(forKey: heartKey(heroId))
    }

    /// One-time price, nil once owned.
    static func heartCost(heroId: String) -> Int? {
        hasHeart(heroId: heroId) ? nil : Economy.heroHeartCost
    }

    /// Buys the second heart. Returns false when owned or broke.
    @discardableResult
    static func buyHeart(heroId: String) -> Bool {
        guard !hasHeart(heroId: heroId),
              WalletStore.shared.spend(Economy.heroHeartCost) else { return false }
        UserDefaults.standard.set(true, forKey: heartKey(heroId))
        return true
    }

    /// Lives per attempt: 3 stock, 4 with the second heart.
    static func maxLives(heroId: String) -> Int {
        Balance.heroLives + (hasHeart(heroId: heroId) ? 1 : 0)
    }
}
