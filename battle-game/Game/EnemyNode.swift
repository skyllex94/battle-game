import SpriteKit

/// Enemy marcher kinds. .raider is the classic fast shooter (Levels 1+);
/// .brute is the bulky siege crusher debuting in Level 3 — slow, tanky,
/// hits like a tower bolt, pays a premium when dropped.
enum EnemyKind: Int, CaseIterable {
    case raider
    case brute

    var hp: CGFloat {
        switch self {
        case .raider: return Balance.enemyHP
        case .brute: return Balance.bruteHP
        }
    }

    var moveSpeed: CGFloat {
        switch self {
        case .raider: return Balance.enemySpeed
        case .brute: return Balance.bruteSpeed
        }
    }

    var sightRange: CGFloat {
        switch self {
        case .raider: return Balance.enemySightRange
        case .brute: return Balance.bruteSightRange
        }
    }

    var shootRange: CGFloat {
        switch self {
        case .raider: return Balance.enemyShootRange
        case .brute: return Balance.bruteShootRange
        }
    }

    var fireInterval: TimeInterval {
        switch self {
        case .raider: return Balance.enemyFireCooldown
        case .brute: return Balance.bruteFireCooldown
        }
    }

    var boltDamage: CGFloat {
        switch self {
        case .raider: return Balance.enemyBoltDamage
        case .brute: return Balance.bruteBoltDamage
        }
    }

    var reward: Int {
        switch self {
        case .raider: return Balance.killReward
        case .brute: return Balance.bruteReward
        }
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
    var reward: Int

    private var hpBarRoot = SKNode()
    private var hpBarBG = SKSpriteNode()
    private var hpBarFill = SKSpriteNode()
    private var marchPhase: TimeInterval = 0
    private var body = SKNode()
    /// Pixel sprite (4 walk frames) + cached frames for the march cycle.
    private var bodySprite = SKSpriteNode()
    private var frames: [SKTexture]
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
        self.reward = kind.reward
        self.frames = UnitPixelArt.frames(for: kind == .brute ? .brute : .enemy)
        let size: CGSize
        switch kind {
        case .raider: size = CGSize(width: 40, height: 64)
        case .brute: size = CGSize(width: 58, height: 88)
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
        // Pixel sprite body: red alien invader with spike rifle.
        if let first = frames.first {
            bodySprite = SKSpriteNode(texture: first)
            first.filteringMode = .nearest
            bodySprite.setScale(size.height / first.size().height)
        }
        body.addChild(bodySprite)
        addChild(body)

        // Aimable spike-arm on the shoulder; the scene steers it via aimAt(_).
        let armTex = UnitPixelArt.armTexture(for: kind == .brute ? .brute : .enemy)
        armTex.filteringMode = .nearest
        let s = size.height / 32
        spikeSprite = SKSpriteNode(texture: armTex)
        spikeSprite.setScale(s)
        spikeSprite.anchorPoint = CGPoint(x: CGFloat(UnitPixelArt.armGripX) / CGFloat(UnitPixelArt.armW),
                                          y: 0.5)
        armPivot.position = kind == .brute ? CGPoint(x: 8, y: 10) : CGPoint(x: 6, y: 8)
        armPivot.addChild(spikeSprite)
        gunTip.position = CGPoint(x: CGFloat(UnitPixelArt.armTipX - UnitPixelArt.armGripX) * s,
                                  y: 0)
        armPivot.addChild(gunTip)
        body.addChild(armPivot)
    }

    private func buildHPBar() {
        // Pro chunky pixel bar, same language as TowerNode/BaseNode:
        // dark padded BG + thin light border + left-anchored fill that
        // drains from the right side only. Brutes wear a wider bar.
        let barW: CGFloat = kind == .brute ? 56 : 44
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
        let target = desiredAim ?? 0
        aimAngle += (target - aimAngle) * min(1, 12 * dt)
        armPivot.zRotation = aimAngle
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
