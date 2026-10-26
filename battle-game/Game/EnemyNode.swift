import SpriteKit

/// Enemy marcher kinds. .raider is the classic fast shooter (Levels 1+);
/// .brute is the bulky siege crusher debuting in Level 3 — slow, tanky,
/// hits like a tower bolt, pays a premium when dropped.
/// .reaver is the axe rusher debuting in Level 4 — fast, closes to arm's
/// length and chops for heavy melee damage (no bolts).
/// .skitter is the claw rusher debuting in Level 6 — zergling-fast swarm
/// melee, thin armor, shreds up close (no bolts).
/// .jet is the jetpack droid debuting in Level 7 — hovers low over the
/// lane on twin thrusters raining bolts, and jukes up/down around every
/// 5th incoming shot.
/// .heli is the Heli Gunship debuting in Level 13 — a futuristic attack
/// helicopter that cruises above the jets and fires 3-round bursts.
/// .immortal is the white-armored tracked walker debuting in Level 19 —
/// bigger than the Brute, a non-regenerating shield drinks damage before
/// its shell, and its cannon fires straight-flying mortar shells.
/// .saucer is the twin-blaster gun-drone debuting in Level 24 — a bigger
/// flying drone cruising above even the Heli Gunship, holding high
/// station to fire 2-round blue-plasma bursts.
/// .gnasher is the pale volatile rusher debuting in Level 27 — a fast
/// abyss-floor crawler that chops hard in melee and detonates when
/// killed, splashing the hero and nearby allies.
/// .phoenix is the red graviton strike-fighter debuting in Level 30 —
/// a fast crimson interceptor cruising above even the saucers, loosing
/// 3-round red-plasma bursts.
/// .vesper is the violet void-herald debuting in Level 34 — a slow
/// crescent-winged glider cruising above everything hostile, loosing a
/// 3-shard fan of weaving void splinters with a small splash.
enum EnemyKind: Int, CaseIterable {
    case raider
    case brute
    case reaver
    case skitter
    case jet
    case mech
    case heli
    case missileTruck
    case immortal
    case saucer
    case gnasher
    case phoenix
    case vesper

    /// True for claw/axe fighters (swing + direct damage); false for shooters.
    var isMelee: Bool { self == .reaver || self == .skitter || self == .gnasher }
    /// True for airborne units (hover cruise; jets also dodge-juke).
    var isFlying: Bool { self == .jet || self == .heli || self == .saucer || self == .phoenix || self == .vesper }
    /// True for the heavy mech walker (huge, slow, burst-firing).
    var isMech: Bool { self == .mech }
    /// True for the high-altitude attack helicopter.
    var isHelicopter: Bool { self == .heli }

    /// Draw tier — light infantry render IN FRONT of the heavy walkers so
    /// a big chassis never hides the small, fast threats on top of it.
    /// Air units float above everything (they are up in the air anyway).
    var zTier: CGFloat {
        switch self {
        case .heli: return 9.8
        case .saucer: return 9.9
        case .phoenix: return 10.0
        case .vesper: return 10.1
        case .raider, .skitter: return 9.6
        case .reaver, .jet, .gnasher: return 9.2
        case .brute, .mech, .missileTruck, .immortal: return 8.0
        }
    }

    /// Cruise altitude above the walkable deck (0 for grounded kinds).
    var flightHeight: CGFloat {
        switch self {
        case .jet: return Balance.jetHoverHeight
        case .heli: return Balance.heliHoverHeight
        case .saucer: return Balance.saucerHoverHeight
        case .phoenix: return Balance.phoenixHoverHeight
        case .vesper: return Balance.vesperHoverHeight
        default: return 0
        }
    }

    /// Display name (briefings + intel cards).
    var displayName: String {
        switch self {
        case .raider: return "Raider"
        case .brute: return "Brute"
        case .reaver: return "Reaver"
        case .skitter: return "Skitter"
        case .jet: return "Jetpack Droid"
        case .mech: return "Mech Walker"
        case .heli: return "Heli Gunship"
        case .saucer: return "Saucer Drone"
        case .phoenix: return "Phoenix"
        case .vesper: return "Vesper"
        case .missileTruck: return "Missile Truck"
        case .immortal: return "Immortal"
        case .gnasher: return "Gnasher"
        }
    }

    /// Campaign level this enemy first marches out (drives the "new enemy
    /// units" briefing callout; 1 = the baseline raider).
    var unlockLevel: Int {
        switch self {
        case .raider: return 1
        case .brute: return 3
        case .reaver: return 4
        case .skitter: return 6
        case .jet: return 7
        case .mech: return 9
        case .heli: return 13
        case .saucer: return 24
        case .missileTruck: return 15
        case .immortal: return 19
        case .gnasher: return 27
        case .phoenix: return 30
        case .vesper: return 34
        }
    }

    /// One-line threat read for the briefing callout.
    var threatBlurb: String {
        switch self {
        case .raider: return "Standard trooper. Shoots from mid range."
        case .brute: return "Siege bruiser. Slow, armored, heavy bolts."
        case .reaver: return "Axe rusher. Closes and chops."
        case .skitter: return "Claw zergling. Fast, fragile, swarms."
        case .jet: return "Flying droid. Hovers and jukes around your fire."
        case .mech: return "Walking gun platform. Heavy armor, burst fire."
        case .heli: return "Attack helicopter. High hover, 3-round gun bursts."
        case .saucer: return "Heavy gun-drone. High hover, twin-blaster bursts."
        case .phoenix: return "Red strike-fighter. Highest hover, 3-round plasma bursts."
        case .vesper: return "Void-herald. Highest hover, weaving shard fan."
        case .missileTruck: return "Missile launcher truck. Short range, weaving missiles."
        case .immortal: return "White-armored tracked platform. Straight mortar shells."
        case .gnasher: return "Pale rusher. Chops hard, detonates when killed."
        }
    }

    /// Extra intro-modal line for debuts with a story (nil = threat blurb
    /// alone). The Gnasher is evolved Skitter stock, remade by the abyss.
    var debutNote: String? {
        switch self {
        case .gnasher: return "Evolved Skitter stock, remade by the abyss — bigger, faster, and volatile. The old stock is extinct from here on."
        default: return nil
        }
    }

    var hp: CGFloat {
        switch self {
        case .raider: return Balance.enemyHP
        case .brute: return Balance.bruteHP
        case .reaver: return Balance.reaverHP
        case .skitter: return Balance.skitterHP
        case .jet: return Balance.jetHP
        case .mech: return Balance.mechHP
        case .heli: return Balance.heliHP
        case .saucer: return Balance.saucerHP
        case .phoenix: return Balance.phoenixHP
        case .vesper: return Balance.vesperHP
        case .missileTruck: return Balance.missileTruckHP
        case .immortal: return Balance.immortalHP
        case .gnasher: return Balance.gnasherHP
        }
    }

    var moveSpeed: CGFloat {
        switch self {
        case .raider: return Balance.enemySpeed
        case .brute: return Balance.bruteSpeed
        case .reaver: return Balance.reaverSpeed
        case .skitter: return Balance.skitterSpeed
        case .jet: return Balance.jetSpeed
        case .mech: return Balance.mechSpeed
        case .heli: return Balance.heliSpeed
        case .saucer: return Balance.saucerSpeed
        case .phoenix: return Balance.phoenixSpeed
        case .vesper: return Balance.vesperSpeed
        case .missileTruck: return Balance.missileTruckSpeed
        case .immortal: return Balance.immortalSpeed
        case .gnasher: return Balance.gnasherSpeed
        }
    }

    var sightRange: CGFloat {
        switch self {
        case .raider: return Balance.enemySightRange
        case .brute: return Balance.bruteSightRange
        case .reaver: return Balance.reaverSightRange
        case .skitter: return Balance.skitterSightRange
        case .jet: return Balance.jetSightRange
        case .mech: return Balance.mechSightRange
        case .heli: return Balance.heliSightRange
        case .saucer: return Balance.saucerSightRange
        case .phoenix: return Balance.phoenixSightRange
        case .vesper: return Balance.vesperSightRange
        case .missileTruck: return Balance.missileTruckSightRange
        case .immortal: return Balance.immortalSightRange
        case .gnasher: return Balance.gnasherSightRange
        }
    }

    /// Shooters stop and fire here; melee kinds close to claw/axe length here.
    var shootRange: CGFloat {
        switch self {
        case .raider: return Balance.enemyShootRange
        case .brute: return Balance.bruteShootRange
        case .reaver: return Balance.reaverMeleeRange
        case .skitter: return Balance.skitterMeleeRange
        case .jet: return Balance.jetShootRange
        case .mech: return Balance.mechShootRange
        case .heli: return Balance.heliShootRange
        case .saucer: return Balance.saucerShootRange
        case .phoenix: return Balance.phoenixShootRange
        case .vesper: return Balance.vesperShootRange
        case .missileTruck: return Balance.missileTruckShootRange
        case .immortal: return Balance.immortalShootRange
        case .gnasher: return Balance.gnasherMeleeRange
        }
    }

    var fireInterval: TimeInterval {
        switch self {
        case .raider: return Balance.enemyFireCooldown
        case .brute: return Balance.bruteFireCooldown
        case .reaver: return Balance.reaverSwingCooldown
        case .skitter: return Balance.skitterSwingCooldown
        case .jet: return Balance.jetFireCooldown
        case .mech: return Balance.mechFireCooldown
        case .heli: return Balance.heliFireCooldown
        case .saucer: return Balance.saucerFireCooldown
        case .phoenix: return Balance.phoenixFireCooldown
        case .vesper: return Balance.vesperFireCooldown
        case .missileTruck: return Balance.missileTruckFireCooldown
        case .immortal: return Balance.immortalFireCooldown
        case .gnasher: return Balance.gnasherSwingCooldown
        }
    }

    var boltDamage: CGFloat {
        switch self {
        case .raider: return Balance.enemyBoltDamage
        case .brute: return Balance.bruteBoltDamage
        case .reaver: return 0
        case .skitter: return 0
        case .jet: return Balance.jetBoltDamage
        case .mech: return Balance.mechBoltDamage
        case .heli: return Balance.heliBoltDamage
        case .saucer: return Balance.saucerBoltDamage
        case .phoenix: return Balance.phoenixBoltDamage
        case .vesper: return Balance.vesperBoltDamage
        case .missileTruck: return Balance.missileTruckMissileDamage
        case .immortal: return Balance.immortalShellDamage
        case .gnasher: return 0
        }
    }

    /// Claw/axe chop damage (melee kinds only).
    var meleeDamage: CGFloat {
        switch self {
        case .reaver: return Balance.reaverMeleeDamage
        case .skitter: return Balance.skitterMeleeDamage
        case .gnasher: return Balance.gnasherMeleeDamage
        case .raider, .brute, .jet, .mech, .heli, .missileTruck, .immortal, .saucer, .phoenix, .vesper: return 0
        }
    }

    /// Bounty paid when this unit dies, after the global reward cut.
    var reward: Int {
        let base: Int
        switch self {
        case .raider: base = Balance.killReward
        case .brute: base = Balance.bruteReward
        case .reaver: base = Balance.reaverReward
        case .skitter: base = Balance.skitterReward
        case .jet: base = Balance.jetReward
        case .mech: base = Balance.mechReward
        case .heli: base = Balance.heliReward
        case .saucer: base = Balance.saucerReward
        case .phoenix: base = Balance.phoenixReward
        case .vesper: base = Balance.vesperReward
        case .missileTruck: base = Balance.missileTruckReward
        case .immortal: base = Balance.immortalReward
        case .gnasher: base = Balance.gnasherReward
        }
        let scaled = Int((CGFloat(base) * Balance.enemyRewardScale).rounded(.down))
        return (scaled / 10) * 10
    }

    /// Pixel-art kind used for library + briefing portraits.
    var pixelKind: UnitPixelArt.Kind {
        switch self {
        case .raider: return .enemy
        case .brute: return .brute
        case .reaver: return .reaver
        case .skitter: return .skitter
            case .jet: return .jet
            case .mech: return .mech
            case .heli: return .heli
            case .missileTruck: return .missileTruck
            case .immortal: return .immortal
            case .saucer: return .saucer
            case .phoenix: return .phoenix
            case .vesper: return .vesper
            case .gnasher: return .gnasher
        }
    }

    /// Short battlefield role for the enemy library.
    var roleLabel: String {
        switch self {
        case .raider: return "SHOOTER"
        case .brute: return "SIEGE"
        case .reaver: return "MELEE"
        case .skitter: return "SWARM"
        case .jet: return "FLYER"
        case .mech: return "HEAVY"
        case .heli: return "GUNSHIP"
        case .saucer: return "SAUCER"
        case .phoenix: return "STRIKER"
        case .vesper: return "HERALD"
        case .missileTruck: return "LAUNCHER"
        case .immortal: return "PHASE"
        case .gnasher: return "VOLATILE"
        }
    }

    /// Baseline HP (before per-level scaling) for the library readout.
    var baseHP: CGFloat {
        let scale = Balance.active.enemyHPScale
        return scale > 0 ? hp / scale : hp
    }

    /// Bolt or melee damage, whichever this kind uses.
    var attackDamage: CGFloat {
        boltDamage > 0 ? boltDamage : meleeDamage
    }
}

/// Enemy raider trooper: red alien invader built procedurally (no texture
/// dependency, so the design always shows), mirroring AllyNode's structure.
/// Ground-bound ranged fighter: the scene advances it toward its target,
/// stops at shooting range, and fires enemy bolts.
/// No physics bodies — same manual style as the hero.
final class EnemyNode: SKSpriteNode {

    let kind: EnemyKind
    var hp: CGFloat
    var maxHP: CGFloat
    var fireCooldown: TimeInterval = 0
    var alive: Bool { hp > 0 }
    /// Per-kind combat stats (the scene reads these, never globals).
    var moveSpeed: CGFloat
    var sightRange: CGFloat
    var shootRange: CGFloat
    var fireInterval: TimeInterval
    var boltDamage: CGFloat
    var meleeDamage: CGFloat
    var reward: Int
    /// Closing-burst state (reavers): fires once per life inside burst
    /// range, then dashes at burst speed while the timer runs down.
    var burstUsed: Bool = false
    var burstTimer: TimeInterval = 0
    /// Dodge-juke state (jets): counts incoming shots; every 5th triggers
    /// a vertical juke (see jukeOffset). The scene drives these.
    var incomingShots: Int = 0
    var jukeCooldown: TimeInterval = 0
    var jukeOffset: CGFloat = 0   // current dodge displacement (eases to 0)
    var jukeTarget: CGFloat = 0   // dodge peak the offset chases, then clears
    /// Hover-sway offset for high flyers (saucers ride it like the jet's
    /// juke offset; the scene drives it). Kept for future strafe moves.
    var diveOffset: CGFloat = 0
    var diving: Bool = false
    var diveCooldown: TimeInterval = 0
    /// Thruster-exhaust timer (jets puff exhaust while flying).
    var jetExhaustTimer: TimeInterval = 0
    /// Rotor-wash sound timer (heli): retriggers the looping blade slap.
    var rotorSoundTimer: TimeInterval = 0
    /// Machine-gun burst ramp (mech): volley size cycles 1 -> 2 -> 3.
    var mechBurstStep: Int = 0
    /// Footfall dust timer (mech): heavy steps kick up sand.
    var footDustTimer: TimeInterval = 0
    /// Overhead-chop offset added to the arm angle (see swing()).
    private var swingOffset: CGFloat = 0

    private var hpBarRoot = SKNode()
    private var hpBarBG = SKSpriteNode()
    private var hpBarFill = SKSpriteNode()
    private var marchPhase: TimeInterval = 0
    private var body = SKNode()
    /// Pixel sprite (4 walk frames) + cached frames for the march cycle.
    private var bodySprite = SKSpriteNode()
    private var frames: [SKTexture]
    /// Mech only: the two legs animate independently so the gait reads.
    private var mechLegFront = SKSpriteNode()
    private var mechLegBack = SKSpriteNode()
    private var mechLegPhase: Int = 0
    /// Aimable spike-arm: shoulder pivot + barrel-tip socket (see aimAt).
    private let armPivot = SKNode()
    private var spikeSprite = SKSpriteNode()
    private let gunTip = SKNode()
    private var aimAngle: CGFloat = 0
    private var desiredAim: CGFloat?

    init(kind: EnemyKind = .raider) {
        self.kind = kind
        self.hp = kind.hp
        self.maxHP = kind.hp
        self.moveSpeed = kind.moveSpeed
        self.sightRange = kind.sightRange
        self.shootRange = kind.shootRange
        self.fireInterval = kind.fireInterval
        self.boltDamage = kind.boltDamage
        self.meleeDamage = kind.meleeDamage
        self.reward = kind.reward
        self.frames = UnitPixelArt.frames(for: {
            switch kind {
            case .raider: return UnitPixelArt.Kind.enemy
            case .brute: return .brute
            case .reaver: return .reaver
            case .skitter: return .skitter
            case .jet: return .jet
            case .mech: return .mech
            case .heli: return .heli
            case .missileTruck: return .missileTruck
            case .immortal: return .immortal
            case .saucer: return .saucer
            case .phoenix: return .phoenix
            case .vesper: return .vesper
            case .gnasher: return .gnasher
            }
        }())
        let size: CGSize
        switch kind {
        case .raider: size = CGSize(width: 40, height: 64)
        case .brute: size = CGSize(width: 58, height: 88)
        case .reaver: size = CGSize(width: 44, height: 68)
        case .skitter: size = CGSize(width: 36, height: 48)
        case .jet: size = CGSize(width: 84, height: 60)
        case .mech: size = CGSize(width: 112, height: 104)
        case .heli: size = CGSize(width: 120, height: 64)
        case .saucer: size = CGSize(width: 144, height: 84)
        case .phoenix: size = CGSize(width: 150, height: 88)
        case .vesper: size = CGSize(width: 156, height: 92)
        case .missileTruck: size = CGSize(width: 128, height: 80)
        case .immortal: size = CGSize(width: 128, height: 114)
        case .gnasher: size = CGSize(width: 52, height: 72)
        }
        super.init(texture: nil, color: .clear, size: size)
        name = "enemy"
        // Tier + a tiny stable per-unit offset: two overlapping units of
        // the same kind (e.g. missile trucks walking side by side) get a
        // fixed draw order — one stays fully in front, no z-tie flicker.
        zPosition = kind.zTier + CGFloat.random(in: 0 ..< 0.14)
        xScale = -abs(xScale) // marchers head left
        buildVisuals()
        buildHPBar()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// +1 faces right (toward a hero behind the line), -1 faces left (advance).
    func face(_ direction: CGFloat) {
        guard direction != 0 else { return }
        xScale = (direction > 0 ? 1 : -1) * abs(xScale)
        // Counter-flip the HP bar so it always drains from the same
        // world side (parent flip would otherwise mirror the anchor).
        hpBarRoot.xScale = facing
    }

    var facing: CGFloat { xScale >= 0 ? 1 : -1 }

    /// Muzzle at the aimed barrel tip, in parent (world) coordinates.
    func muzzle() -> CGPoint {
        if let parent = parent { return gunTip.convert(CGPoint.zero, to: parent) }
        return CGPoint(x: position.x + facing * size.width * 0.55, y: position.y + 6)
    }

    /// Steer the spike-arm toward a world-space direction (nil = level it).
    /// Called every frame by the scene alongside animateMarch.
    func aimAt(_ dir: CGVector?) {
        guard let dir = dir, dir.dx != 0 || dir.dy != 0 else {
            desiredAim = nil
            return
        }
        var local = atan2(dir.dy, dir.dx)
        if facing < 0 { local = .pi - local } // unmirror under xScale = -1
        while local > .pi { local -= 2 * .pi }
        while local < -.pi { local += 2 * .pi }
        desiredAim = min(1.1, max(-1.1, local)) // never aim through the body
    }

    private func buildVisuals() {
        // The mech is built from a torso + two articulated legs so it can
        // actually walk instead of sliding.
        if kind == .mech {
            buildMechVisuals()
            return
        }
        // Pixel sprite body: red alien invader with spike rifle.
        // Body scale comes from the texture's own height so the gun arm
        // matches it (the mech's canvas is taller than the usual 32px).
        var bodyScale: CGFloat = size.height / 32
        if let first = frames.first {
            bodySprite = SKSpriteNode(texture: first)
            first.filteringMode = .nearest
            bodyScale = size.height / first.size().height
            bodySprite.setScale(bodyScale)
        }
        body.addChild(bodySprite)
        addChild(body)

        // Aimable spike-arm on the shoulder; the scene steers it via aimAt(_).
        // Reavers mount a great-axe on the same pivot (swung via swing()).
        let armKind: UnitPixelArt.Kind = {
            switch kind {
            case .raider: return UnitPixelArt.Kind.enemy
            case .brute: return .brute
            case .reaver: return .reaver
            case .skitter: return .skitter
            case .jet: return .jet
            case .mech: return .mech
            case .heli: return .heli
            case .missileTruck: return .missileTruck
            case .immortal: return .immortal
            case .saucer: return .saucer
            case .phoenix: return .phoenix
            case .vesper: return .vesper
            case .gnasher: return .gnasher
            }
        }()
        let armTex = UnitPixelArt.armTexture(for: armKind)
        armTex.filteringMode = .nearest
        let s = bodyScale
        let arm = UnitPixelArt.armMetrics(for: armKind)
        spikeSprite = SKSpriteNode(texture: armTex)
        spikeSprite.setScale(s)
        spikeSprite.anchorPoint = CGPoint(x: CGFloat(arm.gripX) / CGFloat(arm.w),
                                           y: 0.5)
        armPivot.position = {
            switch kind {
            case .brute: return CGPoint(x: 8, y: 10)
            case .reaver: return CGPoint(x: 7, y: 9)
            case .gnasher: return CGPoint(x: 8, y: 9)
            case .skitter: return CGPoint(x: 5, y: 6)
            case .raider: return CGPoint(x: 6, y: 8)
            case .jet: return CGPoint(x: 13, y: 0)
            case .saucer: return CGPoint(x: 30, y: -22)
            case .phoenix: return CGPoint(x: 32, y: -22)
            case .vesper: return CGPoint(x: 34, y: -24)
            case .mech: return CGPoint(x: 41, y: 19)
            case .heli: return CGPoint(x: 21, y: -20)
            // Launcher cradle in the mantlet at the very nose: the rail
            // (and every missile it fires) clears the hull in front.
            case .missileTruck: return CGPoint(x: 54, y: 19)
            // Cannon grip sits at the front chest joint, under the helmet,
            // where the long rail is cradled across the walker's torso.
            case .immortal: return CGPoint(x: 10, y: 12.5)
            }
        }()
        armPivot.addChild(spikeSprite)
        gunTip.position = CGPoint(x: CGFloat(arm.tipX - arm.gripX) * s,
                                  y: 0)
        armPivot.addChild(gunTip)
        // Small z so the arm/layers over the own body but never climbs
        // above the next unit tier (child z is cumulative with the node's).
        armPivot.zPosition = 0.3
        body.addChild(armPivot)
    }

    /// Mech build: torso sprite + two separately animated legs hung off
    /// the hip line, so the walker has a real gait (strike, plant,
    /// push-off, swing) instead of sliding on a static body.
    private func buildMechVisuals() {
        let bodyTex = UnitPixelArt.mechBodyTexture()
        bodyTex.filteringMode = .nearest
        // 26px torso + 20px legs = 46px of canvas in 104pt of height.
        let s = size.height / 46
        bodySprite = SKSpriteNode(texture: bodyTex)
        bodySprite.setScale(s)
        bodySprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        // Hips sit where the torso's bottom row lands.
        let hipY = size.height / 2 - 26 * s
        bodySprite.position = CGPoint(x: 0, y: hipY)
        body.addChild(bodySprite)

        // Legs: back leg behind the body, front leg in front.
        let legTexBack = UnitPixelArt.mechLegTexture(front: false, phase: 0)
        legTexBack.filteringMode = .nearest
        mechLegBack = SKSpriteNode(texture: legTexBack)
        mechLegBack.setScale(s)
        mechLegBack.anchorPoint = CGPoint(x: 0.5, y: 1)
        mechLegBack.position = CGPoint(x: -8, y: hipY + 2)
        mechLegBack.zPosition = -0.2
        body.addChild(mechLegBack)

        let legTexFront = UnitPixelArt.mechLegTexture(front: true, phase: 0)
        legTexFront.filteringMode = .nearest
        mechLegFront = SKSpriteNode(texture: legTexFront)
        mechLegFront.setScale(s)
        mechLegFront.anchorPoint = CGPoint(x: 0.5, y: 1)
        mechLegFront.position = CGPoint(x: 8, y: hipY + 2)
        mechLegFront.zPosition = 0.2
        body.addChild(mechLegFront)

        // Gatling arm on the gun-side shoulder.
        let armKind: UnitPixelArt.Kind = .mech
        let armTex = UnitPixelArt.armTexture(for: armKind)
        armTex.filteringMode = .nearest
        let arm = UnitPixelArt.armMetrics(for: armKind)
        spikeSprite = SKSpriteNode(texture: armTex)
        spikeSprite.setScale(s)
        spikeSprite.anchorPoint = CGPoint(x: CGFloat(arm.gripX) / CGFloat(arm.w),
                                           y: 0.5)
        armPivot.position = CGPoint(x: 32, y: 0)
        armPivot.zPosition = 0.4
        armPivot.addChild(spikeSprite)
        gunTip.position = CGPoint(x: CGFloat(arm.tipX - arm.gripX) * s,
                                  y: 0)
        armPivot.addChild(gunTip)
        body.addChild(armPivot)

        addChild(body)
    }

    private func buildHPBar() {
        // Pro chunky pixel bar, same language as TowerNode/BaseNode:
        // dark padded BG + thin light border + left-anchored fill that
        // drains from the right side only. Brutes wear a wider bar.
        let barW: CGFloat = kind == .brute ? 56
            : (kind.isMech || kind == .missileTruck || kind == .immortal || kind == .saucer || kind == .phoenix || kind == .vesper ? 64 : 44)
        let barH: CGFloat = 7
        // Soft + sunk: more transparent than the structure bars, and pinned
        // deep behind so the hero always covers it when passing by units.
        hpBarRoot.position = CGPoint(x: 0, y: size.height / 2 + 10)
        hpBarRoot.zPosition = -5
        // Cancel the initial xScale = -1 so the bar opens unmirrored.
        hpBarRoot.xScale = facing
        addChild(hpBarRoot)
        hpBarBG = SKSpriteNode(color: SKColor(white: 0, alpha: 0.35),
                               size: CGSize(width: barW + 4, height: barH + 4))
        hpBarBG.zPosition = 0
        hpBarRoot.addChild(hpBarBG)
        let border = SKShapeNode(rectOf: CGSize(width: barW + 4, height: barH + 4))
        border.strokeColor = SKColor(white: 1, alpha: 0.12)
        border.lineWidth = 1
        border.fillColor = .clear
        border.zPosition = 1
        hpBarRoot.addChild(border)
        hpBarFill = SKSpriteNode(color: .red, size: CGSize(width: barW, height: barH))
        hpBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBarFill.position = CGPoint(x: -barW / 2, y: 0)
        hpBarFill.zPosition = 1
        hpBarFill.alpha = 0.9
        hpBarRoot.addChild(hpBarFill)
    }

    /// March cycle: swaps the 4 pixel stride frames + bob while advancing,
    /// and eases the spike-arm toward its target (levels out when idle).
    /// Called by the scene.
    func animateMarch(dt: TimeInterval, advancing: Bool) {
        if kind == .heli {
            animateHeli(dt: dt, advancing: advancing)
        } else if kind == .saucer {
            animateSaucer(dt: dt, advancing: advancing)
        } else if kind == .phoenix {
            animatePhoenix(dt: dt, advancing: advancing)
        } else if kind == .vesper {
            animateVesper(dt: dt, advancing: advancing)
        } else if kind == .mech {
            animateMech(dt: dt, advancing: advancing)
        } else {
            if advancing {
                marchPhase += dt * 10
                if frames.count == 4 {
                    bodySprite.texture = frames[Int(marchPhase) % 4]
                }
            } else if frames.count == 4 {
                bodySprite.texture = frames[0]
            }
            // Bob around the resting height the scene sets (offset only).
            yBob = advancing ? sin(marchPhase) * 2.5 : 0
            body.zRotation = advancing ? sin(marchPhase) * 0.03 : 0
        }
        let target = desiredAim ?? 0
        aimAngle += (target - aimAngle) * min(1, 12 * dt)
        armPivot.zRotation = aimAngle + swingOffset
    }

    /// Helicopter hover: the rotor keeps turning whether the gunship is
    /// advancing or holding station, so the 4 blade-blur frames cycle at
    /// all times. Forward flight noses down; stopping to shoot levels the
    /// fuselage like a real gunship.
    private func animateHeli(dt: TimeInterval, advancing: Bool) {
        marchPhase += dt * 20
        if frames.count == 4 {
            bodySprite.texture = frames[Int(marchPhase) % 4]
        }
        yBob = 0
        let targetTilt: CGFloat = advancing ? -0.09 : 0
        body.zRotation += (targetTilt - body.zRotation) * min(1, 8 * CGFloat(dt))
    }

    /// Saucer hover: the heavy disc lumbers forward — the 4 glow-flicker
    /// frames cycle at all times, the hull noses down slightly in flight
    /// and levels to aim while holding station.
    private func animateSaucer(dt: TimeInterval, advancing: Bool) {
        marchPhase += dt * 12
        if frames.count == 4 {
            bodySprite.texture = frames[Int(marchPhase) % 4]
        }
        yBob = 0
        let targetTilt: CGFloat = advancing ? -0.05 : 0
        body.zRotation += (targetTilt - body.zRotation) * min(1, 6 * CGFloat(dt))
    }

    /// Phoenix hover: the red interceptor banks through the air — the 4
    /// wing-sail flicker frames cycle at all times, the frame noses down
    /// slightly in flight and levels to aim while holding station. Faster
    /// tilt response than the lumbering saucer, for a darting read.
    private func animatePhoenix(dt: TimeInterval, advancing: Bool) {
        marchPhase += dt * 16
        if frames.count == 4 {
            bodySprite.texture = frames[Int(marchPhase) % 4]
        }
        yBob = 0
        let targetTilt: CGFloat = advancing ? -0.08 : 0
        body.zRotation += (targetTilt - body.zRotation) * min(1, 8 * CGFloat(dt))
    }

    /// Vesper hover: the void-herald drifts rather than darts — the 4
    /// wing-veil shimmer frames cycle at all times, the frame banks a touch
    /// deeper than the phoenix in flight and levels to aim while holding
    /// station. Slowest tilt response of the sky pack, for a looming read.
    private func animateVesper(dt: TimeInterval, advancing: Bool) {
        marchPhase += dt * 10
        if frames.count == 4 {
            bodySprite.texture = frames[Int(marchPhase) % 4]
        }
        yBob = 0
        let targetTilt: CGFloat = advancing ? -0.06 : 0
        body.zRotation += (targetTilt - body.zRotation) * min(1, 5 * CGFloat(dt))
    }

    /// Mech gait: the two legs run a 4-phase cycle half a cycle apart
    /// (front: strike/plant/push/swing, back: the opposite), and the
    /// torso dips as each foot plants. Idle: legs settle to a neutral
    /// stance with the body level.
    private func animateMech(dt: TimeInterval, advancing: Bool) {
        let s = size.height / 46
        let hipY = size.height / 2 - 26 * s
        // The torso carries the bob; the node itself stays planted.
        yBob = 0
        body.zRotation = 0
        if advancing {
            // Heavy machine: a slow, deliberate lumber (half the cadence
            // of the infantry march).
            marchPhase += dt * 3.0
            let phase = Int(marchPhase) % 4
            if phase != mechLegPhase {
                mechLegPhase = phase
                mechLegFront.texture = UnitPixelArt.mechLegTexture(front: true, phase: phase)
                mechLegBack.texture = UnitPixelArt.mechLegTexture(front: false,
                                                                   phase: (phase + 2) % 4)
            }
            // Torso rides the gait: lowest as a foot plants, highest at
            // the strike/swing moments.
            let bob = 2.2 * cos(marchPhase * .pi)
            bodySprite.position = CGPoint(x: 0, y: hipY + bob)
            // Slight forward lean while striding.
            bodySprite.zRotation = 0.05
        } else {
            if mechLegPhase != 1 {
                mechLegPhase = 1
                mechLegFront.texture = UnitPixelArt.mechLegTexture(front: true, phase: 1)
                mechLegBack.texture = UnitPixelArt.mechLegTexture(front: false, phase: 1)
            }
            bodySprite.position = CGPoint(x: 0, y: hipY)
            bodySprite.zRotation = 0
        }
    }

    /// Overhead axe chop for reavers: fast wind-up then slam. The offset
    /// rides on top of the aim angle (see animateMarch) so the swing reads
    /// without fighting the arm steering. Guarded so chops don't stack.
    func swing() {
        guard action(forKey: "swing") == nil else { return }
        run(.sequence([
            .customAction(withDuration: 0.12) { [weak self] _, t in
                self?.swingOffset = -0.9 * CGFloat(t)
            },
            .customAction(withDuration: 0.10) { [weak self] _, t in
                self?.swingOffset = -0.9 + 1.5 * CGFloat(t)
            },
            .customAction(withDuration: 0.25) { [weak self] _, t in
                self?.swingOffset = 0.6 * (1 - CGFloat(t))
            },
        ]), withKey: "swing")
    }

    /// Small vertical offset applied by the scene on top of ground rest height.
    var yBob: CGFloat = 0
    /// Set when the unit marches off-view after the player HQ falls.
    var marchedOff = false

    func refreshHPBar() {
        let frac = max(0, min(1, hp / maxHP))
        hpBarFill.xScale = frac
        if frac > 0.5 {
            hpBarFill.color = .red
        } else if frac > 0.25 {
            hpBarFill.color = .orange
        } else {
            hpBarFill.color = .red
        }
    }
}
