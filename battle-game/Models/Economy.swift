import Foundation

/// Diamond economy tuning. One table, no magic numbers in views:
/// free drip stays small, sinks stay meaningful, repeats pay less.
enum Economy {
    /// Repeat clears pay a fraction (anti-farm).
    static let repeatPayout: Double = 0.3

    /// Victory clear reward: base scales with level + star bonus.
    /// L1 ≈ 12+stars … L15 ≈ 68+stars.
    static func clearReward(levelId: Int, stars: Int, isRepeat: Bool) -> Int {
        let base = 8 + 4 * levelId + 2 * stars
        return isRepeat ? Int((Double(base) * repeatPayout).rounded(.down)) : base
    }

    /// Unspent war gold auto-converts on victory (gold resets every run,
    /// so this is the only way leftover money survives the battle).
    static func leftoverReward(gold: Int) -> Int {
        max(0, gold / 150)
    }

    /// Diamond revive cost: one revive per run, pricier deeper in.
    /// L1 = 15 … L4 = 30 … L15 = 85.
    static func reviveDiamondCost(levelId: Int) -> Int {
        10 + 5 * levelId
    }

    /// War-chest rate (phase 2): diamonds buy starting gold. Deliberately
    /// worse than the sell rate (150g → 1💎) so there's no arbitrage loop.
    static let goldPerDiamond: Int = 50

    /// Loadout slot prices (slot 1 is free; slot 2 is bought or granted
    /// free at Level 5; slots 3…6 are diamond sinks).
    static func slotCost(_ slot: Int) -> Int {
        switch slot {
        case 2: return 40
        case 3: return 100
        case 4: return 250
        case 5: return 500
        case 6: return 1000
        default: return 0
        }
    }

    /// Hero upgrade tier prices (per track: HP/SPD/SHIELD/DMG I/II/III).
    static func heroUpgradeCost(_ tier: Int) -> Int {
        switch tier {
        case 1: return 30
        case 2: return 70
        case 3: return 130
        default: return 0
        }
    }

    /// Hero add-on prices: health boosters and battle-droid tiers are
    /// flat test diamonds for now (real curves land with economy pass).
    static func heroBoosterCost(_ tier: Int) -> Int {
        1 // test price
    }

    static func heroDroidCost(_ tier: Int) -> Int {
        1 // test price — real curve lands with the economy pass
    }
}
