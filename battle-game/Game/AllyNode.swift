import SpriteKit

/// Player-summonable army kinds. Exactly 2 cards for now:
/// .trooper = cheap + fast, .heavy = expensive tank that hits hard.
enum ArmyKind: Int, CaseIterable, Identifiable {
    case trooper
    case heavy

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .trooper: return "Trooper"
        case .heavy: return "Heavy"
        }
    }

    var cost: Int {
        switch self {
        case .trooper: return Balance.trooperCost
        case .heavy: return Balance.heavyCost
        }
    }

    var hp: CGFloat {
        switch self {
        case .trooper: return Balance.trooperHP
        case .heavy: return Balance.heavyHP
        }
    }

    var speed: CGFloat {
        switch self {
        case .trooper: return Balance.trooperSpeed
        case .heavy: return Balance.heavySpeed
        }
    }

    var damage: CGFloat {
        switch self {
        case .trooper: return Balance.trooperDamage
        case .heavy: return Balance.heavyDamage
        }
    }

    var fireCooldown: TimeInterval {
        switch self {
        case .trooper: return Balance.trooperFireCooldown
        case .heavy: return Balance.heavyFireCooldown
        }
    }

    var shootRange: CGFloat {
        switch self {
        case .trooper: return Balance.trooperRange
        case .heavy: return Balance.heavyRange
        }
    }

    var sightRange: CGFloat {
        switch self {
        case .trooper: return Balance.trooperSightRange
        case .heavy: return Balance.heavySightRange
        }
    }

    /// SF Symbol used on the summon card.
    var icon: String {
        switch self {
        case .trooper: return "person.fill"
        case .heavy: return "shield.fill"
        }
    }

    /// Pixel-art kind for the summon-card portrait (the real sprite).
    var pixelKind: UnitPixelArt.Kind {
        switch self {
        case .trooper: return .trooper
        case .heavy: return .heavy
        }
    }
}

/// Friendly trooper that marches right toward the enemy base.
/// Mirrors EnemyNode (manual movement, no physics): the scene advances it,
/// stops it at shooting range, and fires player-team bolts.
/// Procedural blue astronaut visual (no texture dependency) so it always reads.
final class AllyNode: SKSpriteNode {

    let kind: ArmyKind
    var hp: CGFloat
    var maxHP: CGFloat
    var fireCooldown: TimeInterval = 0
    var alive: Bool { hp > 0 }

    private var marchPhase: TimeInterval = 0
    private var hpBarRoot = SKNode()
    private var hpBarBG = SKSpriteNode()
    private var hpBarFill = SKSpriteNode()
    private var body = SKNode()
    /// Pixel sprite (4 walk frames) + cached frames for the march cycle.
    private var bodySprite = SKSpriteNode()
    private var frames: [SKTexture] = []
    /// Aimable gun-arm: shoulder pivot + barrel-tip socket (see aimAt).
    private let armPivot = SKNode()
    private var armSprite = SKSpriteNode()
    private let gunTip = SKNode()
    private var aimAngle: CGFloat = 0
    private var desiredAim: CGFloat?

    /// Small vertical offset applied by the scene on top of ground rest height.
    var yBob: CGFloat = 0
    var facing: CGFloat { xScale >= 0 ? 1 : -1 }

    init(kind: ArmyKind) {
        self.kind = kind
        self.hp = kind.hp
        self.maxHP = kind.hp
        let size: CGSize
        switch kind {
        case .trooper: size = CGSize(width: 40, height: 62)
        case .heavy: size = CGSize(width: 52, height: 76)
        }
        super.init(texture: nil, color: .clear, size: size)
        name = "ally"
        zPosition = 9
        frames = UnitPixelArt.frames(for: kind == .heavy ? .heavy : .trooper)
        buildVisuals()
        buildHPBar()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func face(_ direction: CGFloat) {
        guard direction != 0 else { return }
        xScale = (direction > 0 ? 1 : -1) * abs(xScale)
        // Counter-flip the HP bar so it always drains from the same
        // world side (parent flip would otherwise mirror the anchor).
        hpBarRoot.xScale = facing
    }

    /// Muzzle at the aimed barrel tip, in parent (world) coordinates.
    /// Shots truly leave the gun that is pointing at the target.
    func muzzle() -> CGPoint {
        if let parent = parent { return gunTip.convert(CGPoint.zero, to: parent) }
        return CGPoint(x: position.x + facing * size.width * 0.55, y: position.y + 8)
    }

    /// Steer the gun-arm toward a world-space direction (nil = level it).
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
        let heavy = kind == .heavy
        let suitBlue = SKColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)

        // Pixel sprite body (heavy fills a bigger frame than the trooper).
        if let first = frames.first {
            bodySprite = SKSpriteNode(texture: first)
            first.filteringMode = .nearest
            bodySprite.setScale(size.height / first.size().height)
        }
        body.addChild(bodySprite)
        addChild(body)

        // Aimable gun-arm on the shoulder; the scene steers it via aimAt(_).
        // Pixels match the body (same 32px-tall canvas scale).
        let armTex = UnitPixelArt.armTexture(for: kind == .heavy ? .heavy : .trooper)
        armTex.filteringMode = .nearest
        let s = size.height / 32
        armSprite = SKSpriteNode(texture: armTex)
        armSprite.setScale(s)
        armSprite.anchorPoint = CGPoint(x: CGFloat(UnitPixelArt.armGripX) / CGFloat(UnitPixelArt.armW),
                                        y: 0.5)
        armPivot.position = heavy ? CGPoint(x: 9, y: 7) : CGPoint(x: 6, y: 8)
        armPivot.addChild(armSprite)
        gunTip.position = CGPoint(x: CGFloat(UnitPixelArt.armTipX - UnitPixelArt.armGripX) * s,
                                  y: 0)
        armPivot.addChild(gunTip)
        body.addChild(armPivot)

        // Heavy pip so the two cards read apart at a glance.
        if heavy {
            let pip = SKShapeNode(rectOf: CGSize(width: 10, height: 10), cornerRadius: 2)
            pip.fillColor = suitBlue
            pip.strokeColor = .clear
            pip.position = CGPoint(x: -size.width / 2 - 4, y: size.height / 2 - 6)
            addChild(pip)
        }
    }

    /// March cycle: swaps the 4 pixel stride frames + bob while advancing,
    /// and eases the gun-arm toward its target (levels out when idle).
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
        yBob = advancing ? sin(marchPhase) * 2.5 : 0
        body.zRotation = advancing ? sin(marchPhase) * 0.03 : 0
        let target = desiredAim ?? 0
        aimAngle += (target - aimAngle) * min(1, 12 * dt)
        armPivot.zRotation = aimAngle
    }

    func refreshHPBar() {
        let frac = max(0, min(1, hp / maxHP))
        hpBarFill.xScale = frac
        if frac > 0.5 {
            hpBarFill.color = .cyan
        } else if frac > 0.25 {
            hpBarFill.color = .orange
        } else {
            hpBarFill.color = .red
        }
    }

    private func buildHPBar() {
        // Pro chunky pixel bar, same language as TowerNode/BaseNode:
        // dark padded BG + thin light border + left-anchored fill that
        // drains from the right side only.
        let barW: CGFloat = kind == .heavy ? 52 : 44
        let barH: CGFloat = 7
        // Soft + sunk: more transparent than the structure bars, and pinned
        // deep behind so the hero always covers it when passing by units.
        hpBarRoot.position = CGPoint(x: 0, y: size.height / 2 + 10)
        hpBarRoot.zPosition = -5
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
        hpBarFill = SKSpriteNode(color: .cyan, size: CGSize(width: barW, height: barH))
        hpBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBarFill.position = CGPoint(x: -barW / 2, y: 0)
        hpBarFill.zPosition = 1
        hpBarFill.alpha = 0.9
        hpBarRoot.addChild(hpBarFill)
    }
}
