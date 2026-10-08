import CoreGraphics
import Foundation

/// Hero guns (14). One HUD button cycles through UNLOCKED guns in roster
/// order. Power climbs down the roster: bigger damage, faster cadence,
/// fatter mags, heavier bolts — each tier outguns the last in its role.
/// New cases must always be APPENDED (raw values persist in UserDefaults).
enum HeroWeapon: Int, CaseIterable {
    case blaster
    case scatter
    case cannon
    case repeater
    case piercer
    case shredder
    case sunder
    case hornet
    case lancer
    case tempest
    case mauler
    case nova
    case requiem
    case oblivion

    /// Roster order for the armory (by campaign unlock, not raw value).
    static var rosterOrder: [HeroWeapon] {
        allCases.sorted { $0.unlockLevel < $1.unlockLevel }
    }

    var name: String {
        switch self {
        case .blaster: return "Blaster"
        case .scatter: return "Scatter"
        case .cannon: return "Cannon"
        case .repeater: return "Repeater"
        case .piercer: return "Piercer"
        case .shredder: return "Shredder"
        case .sunder: return "Sunder"
        case .hornet: return "Hornet"
        case .lancer: return "Lancer"
        case .tempest: return "Tempest"
        case .mauler: return "Mauler"
        case .nova: return "Nova"
        case .requiem: return "Requiem"
        case .oblivion: return "Oblivion"
        }
    }

    /// SF Symbol shown on the switch button.
    var icon: String {
        switch self {
        case .blaster: return "bolt.fill"
        case .scatter: return "burst.fill"
        case .cannon: return "target"
        case .repeater: return "repeat"
        case .piercer: return "scope"
        case .shredder: return "flame.fill"
        case .sunder: return "sparkles"
        case .hornet: return "wind"
        case .lancer: return "arrow.up.right"
        case .tempest: return "tornado"
        case .mauler: return "hammer.fill"
        case .nova: return "sun.max.fill"
        case .requiem: return "star.fill"
        case .oblivion: return "crown.fill"
        }
    }

    var damage: CGFloat {
        switch self {
        case .blaster: return Balance.heroDamage // 10
        case .scatter: return 7
        case .cannon: return 30
        case .repeater: return 8
        case .piercer: return 18
        case .shredder: return 7
        case .sunder: return 22
        case .hornet: return 5
        case .lancer: return 36
        case .tempest: return 9
        case .mauler: return 18
        case .nova: return 55
        case .requiem: return 12
        case .oblivion: return 60
        }
    }

    var cooldown: Double {
        switch self {
        case .blaster: return Balance.fireCooldown // 0.26
        case .scatter: return 0.5
        case .cannon: return 0.8
        case .repeater: return 0.2
        case .piercer: return 0.45
        case .shredder: return 0.16
        case .sunder: return 0.6
        case .hornet: return 0.22
        case .lancer: return 0.85
        case .tempest: return 0.18
        case .mauler: return 0.4
        case .nova: return 0.9
        case .requiem: return 0.24
        case .oblivion: return 1.1
        }
    }

    /// Shots per second (the armory's fire-rate meter). Roster max is the
    /// Shredder at 6.25/s — every meter is relative to the full 14-gun
    /// roster so bars stay progressive from Blaster to Oblivion.
    var fireRate: Double { 1.0 / cooldown }
    static let maxFireRate: Double = 6.25
    /// Roster-wide meter ceilings (damage × pellets is burst, not this).
    static let maxDamage: Double = 60
    static let maxRangeValue: Double = 750

    var bulletSpeed: CGFloat {
        switch self {
        case .blaster: return Balance.bulletSpeed // 950
        case .scatter: return 850
        case .cannon: return 1100
        case .repeater: return 1000
        case .piercer: return 1250
        case .shredder: return 900
        case .sunder: return 1000
        case .hornet: return 880
        case .lancer: return 1300
        case .tempest: return 950
        case .mauler: return 920
        case .nova: return 1200
        case .requiem: return 980
        case .oblivion: return 1350
        }
    }

    /// Seconds a bolt stays alive. Max range = speed × life, tuned per gun
    /// so nothing meaningfully outranges enemy towers (750): the hero must
    /// close in to deal damage — no safe cross-map sniping.
    var bulletLife: Double {
        switch self {
        case .blaster: return 0.67
        case .scatter: return 0.59
        case .cannon: return 0.64
        case .repeater: return 0.62
        case .piercer: return 0.56
        case .shredder: return 0.62
        case .sunder: return 0.62
        case .hornet: return 0.57
        case .lancer: return 0.54
        case .tempest: return 0.60
        case .mauler: return 0.60
        case .nova: return 0.58
        case .requiem: return 0.60
        case .oblivion: return 0.52
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
        case .repeater: return 1
        case .piercer: return 1
        case .shredder: return 1
        case .sunder: return 2
        case .hornet: return 4
        case .lancer: return 1
        case .tempest: return 3
        case .mauler: return 4
        case .nova: return 1
        case .requiem: return 5
        case .oblivion: return 2
        }
    }

    /// Radians between fan pellets (single-pellet guns ignore it).
    var spread: CGFloat {
        switch self {
        case .scatter: return 0.14
        case .sunder: return 0.10
        case .hornet: return 0.16
        case .tempest: return 0.12
        case .mauler: return 0.14
        case .requiem: return 0.12
        case .oblivion: return 0.08
        case .blaster, .cannon, .repeater, .piercer, .shredder,
             .lancer, .nova:
            return 0
        }
    }

    /// Visual scale of the bolts.
    var boltScale: CGFloat {
        switch self {
        case .cannon: return 1.5
        case .lancer: return 1.4
        case .nova: return 1.8
        case .oblivion: return 2.0
        case .sunder, .mauler: return 1.2
        case .blaster, .scatter, .repeater, .piercer, .shredder,
             .hornet, .tempest, .requiem:
            return 1.0
        }
    }

    // MARK: - Ammo (mag + reserve, shown as 12/90 on the gun button)
    /// Rounds per magazine. One trigger pull spends one round (multi-pellet
    /// fans cost a single round per pull).
    var magSize: Int {
        switch self {
        case .blaster: return 30
        case .scatter: return 6
        case .cannon: return 4
        case .repeater: return 40
        case .piercer: return 12
        case .shredder: return 50
        case .sunder: return 8
        case .hornet: return 16
        case .lancer: return 5
        case .tempest: return 30
        case .mauler: return 10
        case .nova: return 3
        case .requiem: return 24
        case .oblivion: return 4
        }
    }

    /// Reserve rounds at level start.
    var startReserve: Int {
        switch self {
        case .blaster: return 90
        case .scatter: return 24
        case .cannon: return 16
        case .repeater: return 120
        case .piercer: return 48
        case .shredder: return 150
        case .sunder: return 32
        case .hornet: return 64
        case .lancer: return 20
        case .tempest: return 90
        case .mauler: return 40
        case .nova: return 12
        case .requiem: return 72
        case .oblivion: return 16
        }
    }

    /// Seconds a full reload takes once the mag runs dry.
    var reloadTime: Double {
        switch self {
        case .blaster: return 1.1
        case .scatter: return 1.6
        case .cannon: return 2.0
        case .repeater: return 1.2
        case .piercer: return 1.5
        case .shredder: return 1.4
        case .sunder: return 1.8
        case .hornet: return 1.7
        case .lancer: return 2.0
        case .tempest: return 1.8
        case .mauler: return 2.0
        case .nova: return 2.4
        case .requiem: return 2.0
        case .oblivion: return 2.6
        }
    }

    /// Reserve rounds earned per hero-gun kill with this gun (capped).
    var killAmmo: Int {
        switch self {
        case .blaster: return 6
        case .scatter: return 3
        case .cannon: return 2
        case .repeater: return 6
        case .piercer: return 4
        case .shredder: return 7
        case .sunder: return 3
        case .hornet: return 4
        case .lancer: return 2
        case .tempest: return 5
        case .mauler: return 3
        case .nova: return 2
        case .requiem: return 4
        case .oblivion: return 2
        }
    }

    // MARK: - Unlock gating (milestone grants + diamond buyouts)

    /// Campaign level that grants this gun free (0 = available from the
    /// start). Spread across the 35-level campaign; guns past the built
    /// levels are diamond-only until their levels land.
    var unlockLevel: Int {
        switch self {
        case .blaster: return 0
        case .scatter: return 4
        case .repeater: return 6
        case .cannon: return 7
        case .piercer: return 10
        case .shredder: return 13
        case .sunder: return 16
        case .hornet: return 19
        case .lancer: return 22
        case .tempest: return 25
        case .mauler: return 28
        case .nova: return 30
        case .requiem: return 32
        case .oblivion: return 35
        }
    }

    /// Diamond buyout price (0 = never for sale — the Blaster is free).
    /// Any gun can be bought early instead of waiting for its milestone.
    var diamondCost: Int {
        switch self {
        case .blaster: return 0
        case .scatter: return 60
        case .repeater: return 90
        case .cannon: return 140
        case .piercer: return 180
        case .shredder: return 240
        case .sunder: return 320
        case .hornet: return 400
        case .lancer: return 500
        case .tempest: return 620
        case .mauler: return 750
        case .nova: return 900
        case .requiem: return 1100
        case .oblivion: return 1500
        }
    }

    /// One-line sales pitch for the gun shop cards.
    var blurb: String {
        switch self {
        case .blaster: return "Reliable + endless ammo."
        case .scatter: return "3-pellet fan. Eats shells."
        case .cannon: return "Slow siege hammer."
        case .repeater: return "Bullet hose. Hold the trigger."
        case .piercer: return "Long rail. Reaches out."
        case .shredder: return "Minigun manners. Brrt."
        case .sunder: return "Twin heavy slugs."
        case .hornet: return "Swarm fan. Covers the lane."
        case .lancer: return "Siege spear. Deletes towers."
        case .tempest: return "Storm of lead. Nothing dodges."
        case .mauler: return "Quad maul. Heavy everything."
        case .nova: return "Sun in a barrel. Slow dawn."
        case .requiem: return "Five-voice choir. Final word."
        case .oblivion: return "End of the argument."
        }
    }

    /// The Blaster fires from an endless reserve: the mag still drains and
    /// reloads exactly like other guns, but the reserve never depletes
    /// (reloads always fill to full, no drought, no REL-lockout).
    var hasInfiniteAmmo: Bool {
        self == .blaster
    }

    // MARK: - Projectile structure (rockets, grenades, orbs, weaves)

    /// Blast radius on death (0 = plain bolt, no explosion).
    var blastRadius: CGFloat {
        switch self {
        case .cannon: return 90
        case .sunder: return 85
        case .nova: return 70
        case .oblivion: return 130
        case .mauler: return 45
        case .tempest: return 30
        case .blaster, .scatter, .repeater, .piercer, .shredder,
             .hornet, .lancer, .requiem:
            return 0
        }
    }

    /// Rockets launch slow, accelerate in flight, smoke-trail, and explode
    /// on any contact.
    var isRocket: Bool { self == .cannon || self == .oblivion }
    /// Grenades arc under gravity, skip off turf, and blow on fuse/contact.
    var isGrenade: Bool { self == .sunder }
    /// Sun orbs fly heavy with an ember trail and blow on contact.
    var isOrb: Bool { self == .nova }

    /// Muzzle velocity (rockets start lazy, then the motor catches up).
    var launchSpeed: CGFloat { bulletSpeed * (isRocket ? 0.55 : 1) }
    /// Motor acceleration along the flight line (rockets only).
    var thrustAccel: CGFloat { isRocket ? 1000 : 0 }
    /// Downward pull in pts/s² (grenades only).
    var gravityPull: CGFloat { isGrenade ? 950 : 0 }
    /// Grenade fuse in seconds (nil = no fuse).
    var fuseTime: TimeInterval? { isGrenade ? 1.7 : nil }
    /// Turf skips before a grenade stays down (grenades only).
    var bounceCount: Int { isGrenade ? 2 : 0 }
    /// Choir weave: lateral snake amplitude in pts (requiem only).
    var weaveAmp: CGFloat { self == .requiem ? 16 : 0 }
    /// Choir weave frequency.
    var weaveFreq: Double { 9 }

    /// Flight trail artifact.
    var trail: TrailKind {
        switch self {
        case .cannon, .oblivion, .mauler: return .smoke
        case .nova, .tempest: return .ember
        case .blaster, .scatter, .repeater, .piercer, .shredder,
             .sunder, .hornet, .lancer, .requiem:
            return .none
        }
    }
}

/// GunLocker — mirrors HeroRoster gating for guns: selection persistence
/// with migration, lock checks, and the unlock schedule seam the
/// UnlockStore (milestone grants + diamond buyouts) claims through.
enum GunLocker {
    private static let selectedKey = "campaign.selectedGun"

    /// DEBUG — explore mode: every gun unlocked while we tune the arsenal.
    /// Flip to false for release (milestones + buyouts take over again).
    static let debugUnlockAll = true

    /// A gun is selectable once its campaign milestone is reached — or
    /// once its diamond buyout is claimed early via UnlockStore.
    static func isUnlocked(_ gun: HeroWeapon) -> Bool {
        debugUnlockAll
            || gun.unlockLevel <= 0
            || CampaignData.unlockedLevel >= gun.unlockLevel
            || UnlockStore.owns(gun)
    }

    static var unlockedGuns: [HeroWeapon] { HeroWeapon.allCases.filter(isUnlocked) }

    static var selectedGun: HeroWeapon {
        get {
            // Source of truth is the loadout's starter (slot 1).
            LoadoutStore.starter
        }
        set {
            // Never persist a locked gun; starter swaps slot 1.
            guard isUnlocked(newValue) else { return }
            var guns = LoadoutStore.loadout
            if guns.isEmpty {
                guns = [newValue]
            } else {
                guns[0] = newValue
            }
            LoadoutStore.loadout = guns
            UserDefaults.standard.set(newValue.rawValue, forKey: selectedKey)
        }
    }
}
