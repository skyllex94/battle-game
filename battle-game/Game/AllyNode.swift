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
    private var hpBarBG = SKSpriteNode()
    private var hpBarFill = SKSpriteNode()
    private var body = SKNode()
    /// Pixel sprite (2 walk frames) + cached frames for the march cycle.
    private var bodySprite = SKSpriteNode()
    private var frames: [SKTexture] = []

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
    }

    /// Muzzle at the gun tip, on the facing side.
    func muzzle() -> CGPoint {
        CGPoint(x: position.x + facing * size.width * 0.55, y: position.y + 8)
    }

    private func buildVisuals() {
        let heavy = kind == .heavy
        let h = size.height
        let suitBlue = SKColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)

        // Team glow so friendlies pop on the dark ground.
        let glow = SKShapeNode(circleOfRadius: h * 0.52)
        glow.fillColor = SKColor(red: 0.25, green: 0.5, blue: 1.0, alpha: 0.28)
        glow.strokeColor = SKColor(red: 0.45, green: 0.7, blue: 1.0, alpha: 0.9)
        glow.lineWidth = 2
        glow.zPosition = -1
        addChild(glow)

        // Pixel sprite body (heavy fills a bigger frame than the trooper).
        if let first = frames.first {
            bodySprite = SKSpriteNode(texture: first)
            first.filteringMode = .nearest
            bodySprite.setScale(size.height / first.size().height)
        }
        body.addChild(bodySprite)
        addChild(body)

        // Heavy pip so the two cards read apart at a glance.
        if heavy {
            let pip = SKShapeNode(rectOf: CGSize(width: 10, height: 10), cornerRadius: 2)
            pip.fillColor = suitBlue
            pip.strokeColor = .clear
            pip.position = CGPoint(x: -size.width / 2 - 4, y: size.height / 2 - 6)
            addChild(pip)
        }
    }

    /// March cycle: swaps the 2 pixel walk frames + bob while advancing.
    /// Called by the scene.
    func animateMarch(dt: TimeInterval, advancing: Bool) {
        if advancing {
            marchPhase += dt * 10
            if frames.count == 2 {
                bodySprite.texture = frames[Int(marchPhase) % 2]
            }
        } else if frames.count == 2 {
            bodySprite.texture = frames[0]
        }
        yBob = advancing ? sin(marchPhase) * 2.5 : 0
        body.zRotation = advancing ? sin(marchPhase) * 0.03 : 0
    }

    func refreshHPBar() {
        let frac = max(0, min(1, hp / maxHP))
        hpBarFill.xScale = frac
        hpBarFill.color = frac > 0.5 ? .cyan : .orange
    }

    private func buildHPBar() {
        let barW: CGFloat = kind == .heavy ? 52 : 44
        hpBarBG = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6),
                               size: CGSize(width: barW, height: 6))
        hpBarBG.position = CGPoint(x: 0, y: size.height / 2 + 10)
        hpBarBG.zPosition = 1
        addChild(hpBarBG)
        hpBarFill = SKSpriteNode(color: .cyan, size: CGSize(width: barW, height: 6))
        hpBarFill.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        hpBarFill.position = hpBarBG.position
        hpBarFill.zPosition = 2
        addChild(hpBarFill)
    }
}
