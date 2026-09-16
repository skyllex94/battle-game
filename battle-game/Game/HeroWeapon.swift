import CoreGraphics

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
}
