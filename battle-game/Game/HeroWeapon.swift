import CoreGraphics
import Foundation

/// Hero guns. One HUD button cycles through them (blaster -> scatter -> cannon).
/// Blaster is the current default feel; scatter trades damage for a 3-pellet
/// fan; cannon hits like a truck but fires slowly.
enum HeroWeapon: Int, CaseIterable {
    case blaster
    case scatter
    case cannon

    var name: String {
        switch self {
        case .blaster: return "Blaster"
        case .scatter: return "Scatter"
        case .cannon: return "Cannon"
        }
    }

    /// SF Symbol shown on the switch button.
    var icon: String {
        switch self {
        case .blaster: return "bolt.fill"
        case .scatter: return "burst.fill"
        case .cannon: return "target"
        }
    }

    var damage: CGFloat {
        switch self {
        case .blaster: return Balance.heroDamage // 10
        case .scatter: return 7
        case .cannon: return 30
        }
    }

    var cooldown: Double {
        switch self {
        case .blaster: return Balance.fireCooldown // 0.26
        case .scatter: return 0.5
        case .cannon: return 0.8
        }
    }

    var bulletSpeed: CGFloat {
        switch self {
        case .blaster: return Balance.bulletSpeed // 950
        case .scatter: return 850
        case .cannon: return 1100
        }
    }

    /// Seconds a bolt stays alive. Max range = speed × life, tuned per gun
    /// so nothing outranges enemy towers (750): the hero must close in to
    /// deal damage — no safe cross-map sniping.
    /// Blaster ≈ 640, scatter ≈ 500 (shotgun-falloff feel), cannon ≈ 700.
    var bulletLife: Double {
        switch self {
        case .blaster: return 0.67
        case .scatter: return 0.59
        case .cannon: return 0.64
        }
    }

    /// Max reach in points (speed × life). Shown in the gun shop.
    var maxRange: CGFloat {
        bulletSpeed * CGFloat(bulletLife)
    }

    var pelletCount: Int {
        switch self {
        case .blaster: return 1
        case .scatter: return 3
        case .cannon: return 1
        }
    }

    /// Radians between fan pellets (single-pellet guns ignore it).
    var spread: CGFloat {
        switch self {
        case .scatter: return 0.14
        case .blaster, .cannon: return 0
        }
    }

    /// Visual scale of the bolts.
    var boltScale: CGFloat {
        switch self {
        case .cannon: return 1.5
        case .blaster, .scatter: return 1.0
        }
    }

    // MARK: - Ammo (mag + reserve, shown as 12/90 on the gun button)
    /// Rounds per magazine. One trigger pull spends one round (scatter's
    /// 3 pellets cost a single round).
    var magSize: Int {
        switch self {
        case .blaster: return 30
        case .scatter: return 6
        case .cannon: return 4
        }
    }

    /// Reserve rounds at level start.
    var startReserve: Int {
        switch self {
        case .blaster: return 90
        case .scatter: return 24
        case .cannon: return 16
        }
    }

    /// Seconds a full reload takes once the mag runs dry.
    var reloadTime: Double {
        switch self {
        case .blaster: return 1.1
        case .scatter: return 1.6
        case .cannon: return 2.0
        }
    }

    /// Reserve rounds earned per hero-gun kill with this gun (capped).
    var killAmmo: Int {
        switch self {
        case .blaster: return 6
        case .scatter: return 3
        case .cannon: return 2
        }
    }

    // MARK: - Unlock gating (milestone grants; diamonds buyout plugs in later)

    /// Campaign level that unlocks this gun (0 = available from the start).
    /// Only the Blaster starts unlocked; Scatter/Cannon are novelty grants.
    var unlockLevel: Int {
        switch self {
        case .blaster: return 0
        case .scatter: return 1
        case .cannon: return 7
        }
    }

    /// One-line sales pitch for the gun shop cards.
    var blurb: String {
        switch self {
        case .blaster: return "Reliable + endless ammo."
        case .scatter: return "3-pellet fan. Eats shells."
        case .cannon: return "Slow siege hammer."
        }
    }

    /// The Blaster fires from an endless reserve: the mag still drains and
    /// reloads exactly like other guns, but the reserve never depletes
    /// (reloads always fill to full, no drought, no REL-lockout).
    var hasInfiniteAmmo: Bool {
        self == .blaster
    }
}

/// GunLocker — mirrors HeroRoster gating for guns: selection persistence
/// with migration, lock checks, and the unlock schedule seam the future
/// UnlockStore (milestone grants + diamonds buyout) will claim through.
enum GunLocker {
    private static let selectedKey = "campaign.selectedGun"

    /// A gun is selectable when its milestone is claimed. Until the
    /// UnlockStore lands, only unlockLevel 0 (Blaster) is available.
    static func isUnlocked(_ gun: HeroWeapon) -> Bool {
        gun.unlockLevel <= 0
    }

    static var unlockedGuns: [HeroWeapon] { HeroWeapon.allCases.filter(isUnlocked) }

    static var selectedGun: HeroWeapon {
        get {
            let stored = UserDefaults.standard.integer(forKey: selectedKey)
            if let match = HeroWeapon(rawValue: stored), isUnlocked(match) {
                return match
            }
            // Migrate old installs (default 0 = blaster) and guard locked
            // picks: always fall back to the Blaster, never a locked gun.
            return .blaster
        }
        set {
            // Never persist a locked gun.
            if isUnlocked(newValue) {
                UserDefaults.standard.set(newValue.rawValue, forKey: selectedKey)
            }
        }
    }
}
