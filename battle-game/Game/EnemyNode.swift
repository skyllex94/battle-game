import SpriteKit

/// Enemy raider trooper: red alien invader built procedurally (no texture
/// dependency, so the design always shows), mirroring AllyNode's structure.
/// Ground-bound ranged fighter: the scene advances it toward its target,
/// stops at shooting range, and fires enemy bolts.
/// No physics bodies — same manual style as the hero.
final class EnemyNode: SKSpriteNode {

    var hp: CGFloat = Balance.enemyHP
    var maxHP: CGFloat = Balance.enemyHP
    var fireCooldown: TimeInterval = 0
    var alive: Bool { hp > 0 }

    private var hpBarBG = SKSpriteNode()
    private var hpBarFill = SKSpriteNode()
    private var marchPhase: TimeInterval = 0
    private var body = SKNode()
    /// Pixel sprite (2 walk frames) + cached frames for the march cycle.
    private var bodySprite = SKSpriteNode()
    private var frames: [SKTexture] = UnitPixelArt.frames(for: .enemy)

    init() {
        super.init(texture: nil, color: .clear, size: CGSize(width: 40, height: 64))
        name = "enemy"
        zPosition = 9
        xScale = -abs(xScale) // marchers head left
        buildVisuals()
        buildHPBar()
        buildNameTag()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// +1 faces right (toward a hero behind the line), -1 faces left (advance).
    func face(_ direction: CGFloat) {
        guard direction != 0 else { return }
        xScale = (direction > 0 ? 1 : -1) * abs(xScale)
    }

    var facing: CGFloat { xScale >= 0 ? 1 : -1 }

    /// Muzzle at the rifle tip, on the facing side.
    func muzzle() -> CGPoint {
        CGPoint(x: position.x + facing * size.width * 0.55, y: position.y + 6)
    }

    private func buildVisuals() {
        let h = size.height

        // Red glow disc so the dark sprite never melts into the hell ground.
        let glow = SKShapeNode(circleOfRadius: h * 0.52)
        glow.fillColor = SKColor(red: 1.0, green: 0.15, blue: 0.1, alpha: 0.30)
        glow.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 0.9)
        glow.lineWidth = 2
        glow.zPosition = -1
        addChild(glow)

        // Pixel sprite body: red alien invader with spike rifle.
        if let first = frames.first {
            bodySprite = SKSpriteNode(texture: first)
            first.filteringMode = .nearest
            bodySprite.setScale(size.height / first.size().height)
        }
        body.addChild(bodySprite)
        addChild(body)
    }

    /// Tiny name tag floating above the HP bar.
    private func buildNameTag() {
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.text = "RAIDER"
        label.fontSize = 9
        label.fontColor = SKColor(red: 1.0, green: 0.45, blue: 0.4, alpha: 1)
        label.position = CGPoint(x: 0, y: size.height / 2 + 20)
        label.zPosition = 3
        addChild(label)
    }

    private func buildHPBar() {
        let barW: CGFloat = 44
        hpBarBG = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6),
                               size: CGSize(width: barW, height: 6))
        hpBarBG.position = CGPoint(x: 0, y: size.height / 2 + 10)
        hpBarBG.zPosition = 1
        addChild(hpBarBG)
        hpBarFill = SKSpriteNode(color: .red, size: CGSize(width: barW, height: 6))
        hpBarFill.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        hpBarFill.position = hpBarBG.position
        hpBarFill.zPosition = 2
        addChild(hpBarFill)
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
        // Bob around the resting height the scene sets (offset only).
        yBob = advancing ? sin(marchPhase) * 2.5 : 0
        body.zRotation = advancing ? sin(marchPhase) * 0.03 : 0
    }

    /// Small vertical offset applied by the scene on top of ground rest height.
    var yBob: CGFloat = 0

    func refreshHPBar() {
        let frac = max(0, min(1, hp / maxHP))
        hpBarFill.xScale = frac
        hpBarFill.color = frac > 0.5 ? .red : .orange
    }
}
