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
enum EnemyKind: Int, CaseIterable {
    case raider
    case brute
    case reaver
    case skitter
    case jet
    case mech

    /// True for claw/axe fighters (swing + direct damage); false for shooters.
    var isMelee: Bool { self == .reaver || self == .skitter }
    /// True for the flying gun-robot (hover cruise + dodge jukes).
    var isFlying: Bool { self == .jet }
    /// True for the heavy mech walker (huge, slow, burst-firing).
    var isMech: Bool { self == .mech }

    /// Display name (briefings + intel cards).
    var displayName: String {
        switch self {
        case .raider: return "Raider"
        case .brute: return "Brute"
        case .reaver: return "Reaver"
        case .skitter: return "Skitter"
        case .jet: return "Jetpack Droid"
        case .mech: return "Mech Walker"
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
        }
    }

    /// Claw/axe chop damage (melee kinds only).
    var meleeDamage: CGFloat {
        switch self {
        case .reaver: return Balance.reaverMeleeDamage
        case .skitter: return Balance.skitterMeleeDamage
        case .raider, .brute, .jet, .mech: return 0
        }
    }

    var reward: Int {
        switch self {
        case .raider: return Balance.killReward
        case .brute: return Balance.bruteReward
        case .reaver: return Balance.reaverReward
        case .skitter: return Balance.skitterReward
        case .jet: return Balance.jetReward
        case .mech: return Balance.mechReward
        }
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
    /// Thruster-exhaust timer (jets puff exhaust while flying).
    var jetExhaustTimer: TimeInterval = 0
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
        }
        super.init(texture: nil, color: .clear, size: size)
        name = "enemy"
        zPosition = 9
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
        let armTex = UnitPixelArt.armTexture(for: {
            switch kind {
            case .raider: return UnitPixelArt.Kind.enemy
            case .brute: return .brute
            case .reaver: return .reaver
            case .skitter: return .skitter
            case .jet: return .jet
            case .mech: return .mech
            }
        }())
        armTex.filteringMode = .nearest
        let s = bodyScale
        spikeSprite = SKSpriteNode(texture: armTex)
        spikeSprite.setScale(s)
        spikeSprite.anchorPoint = CGPoint(x: CGFloat(UnitPixelArt.armGripX) / CGFloat(UnitPixelArt.armW),
                                           y: 0.5)
        armPivot.position = {
            switch kind {
            case .brute: return CGPoint(x: 8, y: 10)
            case .reaver: return CGPoint(x: 7, y: 9)
            case .skitter: return CGPoint(x: 5, y: 6)
            case .raider: return CGPoint(x: 6, y: 8)
            case .jet: return CGPoint(x: 13, y: 0)
            case .mech: return CGPoint(x: 41, y: 19)
            }
        }()
        armPivot.addChild(spikeSprite)
        gunTip.position = CGPoint(x: CGFloat(UnitPixelArt.armTipX - UnitPixelArt.armGripX) * s,
                                  y: 0)
        armPivot.addChild(gunTip)
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
        mechLegBack.zPosition = -1
        body.addChild(mechLegBack)

        let legTexFront = UnitPixelArt.mechLegTexture(front: true, phase: 0)
        legTexFront.filteringMode = .nearest
        mechLegFront = SKSpriteNode(texture: legTexFront)
        mechLegFront.setScale(s)
        mechLegFront.anchorPoint = CGPoint(x: 0.5, y: 1)
        mechLegFront.position = CGPoint(x: 8, y: hipY + 2)
        mechLegFront.zPosition = 1
        body.addChild(mechLegFront)

        // Gatling arm on the gun-side shoulder.
        let armTex = UnitPixelArt.armTexture(for: .mech)
        armTex.filteringMode = .nearest
        spikeSprite = SKSpriteNode(texture: armTex)
        spikeSprite.setScale(s)
        spikeSprite.anchorPoint = CGPoint(x: CGFloat(UnitPixelArt.armGripX) / CGFloat(UnitPixelArt.armW),
                                           y: 0.5)
        armPivot.position = CGPoint(x: 32, y: 0)
        armPivot.zPosition = 2
        armPivot.addChild(spikeSprite)
        gunTip.position = CGPoint(x: CGFloat(UnitPixelArt.armTipX - UnitPixelArt.armGripX) * s,
                                  y: 0)
        armPivot.addChild(gunTip)
        body.addChild(armPivot)

        addChild(body)
    }

    private func buildHPBar() {
        // Pro chunky pixel bar, same language as TowerNode/BaseNode:
        // dark padded BG + thin light border + left-anchored fill that
        // drains from the right side only. Brutes wear a wider bar.
        let barW: CGFloat = kind == .brute ? 56 : (kind.isMech ? 64 : 44)
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
        if kind == .mech {
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
