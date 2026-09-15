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
        let suitDark = SKColor(red: 0.15, green: 0.30, blue: 0.65, alpha: 1)
        let visor = SKColor(red: 0.55, green: 0.95, blue: 1.0, alpha: 1)

        func part(_ size: CGSize, color: SKColor) -> SKShapeNode {
            let n = SKShapeNode(rectOf: size, cornerRadius: size.width / 2)
            n.fillColor = color
            n.strokeColor = .clear
            return n
        }

        // Team glow so friendlies pop on the dark ground.
        let glow = SKShapeNode(circleOfRadius: h * 0.52)
        glow.fillColor = SKColor(red: 0.25, green: 0.5, blue: 1.0, alpha: 0.28)
        glow.strokeColor = SKColor(red: 0.45, green: 0.7, blue: 1.0, alpha: 0.9)
        glow.lineWidth = 2
        glow.zPosition = -1
        addChild(glow)

        // Legs.
        let legH = h * 0.32
        let legL = part(CGSize(width: heavy ? 15 : 12, height: legH), color: suitDark)
        legL.position = CGPoint(x: -7, y: -h / 2 + legH / 2)
        body.addChild(legL)
        let legR = part(CGSize(width: heavy ? 15 : 12, height: legH), color: suitBlue)
        legR.position = CGPoint(x: 7, y: -h / 2 + legH / 2)
        body.addChild(legR)

        // Torso (heavy gets a wider chest plate).
        let torso = part(CGSize(width: heavy ? 40 : 32, height: h * 0.38), color: suitBlue)
        torso.position = CGPoint(x: 0, y: 2)
        body.addChild(torso)
        if heavy {
            let plate = part(CGSize(width: 30, height: 20), color: suitDark)
            plate.position = CGPoint(x: 0, y: 4)
            body.addChild(plate)
        }

        // Helmet + visor.
        let helmet = SKShapeNode(circleOfRadius: heavy ? 15 : 13)
        helmet.fillColor = SKColor(red: 0.88, green: 0.92, blue: 0.96, alpha: 1)
        helmet.strokeColor = suitDark
        helmet.lineWidth = 2
        helmet.position = CGPoint(x: 2, y: h * 0.32)
        body.addChild(helmet)
        let visorNode = SKShapeNode(rectOf: CGSize(width: 16, height: 9), cornerRadius: 4)
        visorNode.fillColor = visor
        visorNode.strokeColor = .clear
        visorNode.position = CGPoint(x: 8, y: h * 0.32)
        body.addChild(visorNode)

        // Rifle pointing +x.
        let gun = part(CGSize(width: heavy ? 36 : 30, height: heavy ? 10 : 8),
                       color: SKColor(white: 0.18, alpha: 1))
        gun.position = CGPoint(x: 16, y: 4)
        body.addChild(gun)

        addChild(body)
    }

    /// March bob while advancing. Called by the scene.
    func animateMarch(dt: TimeInterval, advancing: Bool) {
        if advancing { marchPhase += dt * 10 }
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
