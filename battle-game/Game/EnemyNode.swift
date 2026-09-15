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
        let armorDark = SKColor(red: 0.16, green: 0.12, blue: 0.14, alpha: 1)
        let armorRed = SKColor(red: 0.75, green: 0.16, blue: 0.14, alpha: 1)
        let eyeGlow = SKColor(red: 1.0, green: 0.25, blue: 0.15, alpha: 1)

        func part(_ size: CGSize, color: SKColor) -> SKShapeNode {
            let n = SKShapeNode(rectOf: size, cornerRadius: size.width / 2)
            n.fillColor = color
            n.strokeColor = .clear
            return n
        }

        // Red glow disc so the dark sprite never melts into the hell ground.
        let glow = SKShapeNode(circleOfRadius: h * 0.52)
        glow.fillColor = SKColor(red: 1.0, green: 0.15, blue: 0.1, alpha: 0.30)
        glow.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 0.9)
        glow.lineWidth = 2
        glow.zPosition = -1
        addChild(glow)

        // Legs.
        let legH = h * 0.32
        let legL = part(CGSize(width: 12, height: legH), color: armorDark)
        legL.position = CGPoint(x: -7, y: -h / 2 + legH / 2)
        body.addChild(legL)
        let legR = part(CGSize(width: 12, height: legH), color: armorDark)
        legR.position = CGPoint(x: 7, y: -h / 2 + legH / 2)
        body.addChild(legR)

        // Torso + glowing red chest core.
        let torso = part(CGSize(width: 32, height: h * 0.38), color: armorDark)
        torso.position = CGPoint(x: 0, y: 2)
        body.addChild(torso)
        let core = part(CGSize(width: 12, height: 12), color: armorRed)
        core.position = CGPoint(x: 6, y: 4)
        body.addChild(core)

        // Angular alien head + twin glowing eyes.
        let head = SKShapeNode(rectOf: CGSize(width: 26, height: 20), cornerRadius: 6)
        head.fillColor = armorDark
        head.strokeColor = armorRed
        head.lineWidth = 2
        head.position = CGPoint(x: 2, y: h * 0.32)
        body.addChild(head)
        for x in [0, 12] as [CGFloat] {
            let eye = SKShapeNode(circleOfRadius: 4)
            eye.fillColor = eyeGlow
            eye.strokeColor = .clear
            eye.position = CGPoint(x: x, y: h * 0.32 + 2)
            body.addChild(eye)
        }
        // Antennae spikes.
        for x in [-6, 10] as [CGFloat] {
            let spike = SKShapeNode(rectOf: CGSize(width: 3, height: 12))
            spike.fillColor = armorRed
            spike.strokeColor = .clear
            spike.position = CGPoint(x: x, y: h * 0.32 + 14)
            spike.zRotation = x < 0 ? 0.3 : -0.3
            body.addChild(spike)
        }

        // Rifle pointing +x.
        let gun = part(CGSize(width: 32, height: 8), color: SKColor(white: 0.12, alpha: 1))
        gun.position = CGPoint(x: 16, y: 2)
        body.addChild(gun)
        let tip = part(CGSize(width: 8, height: 10), color: armorRed)
        tip.position = CGPoint(x: 30, y: 2)
        body.addChild(tip)

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

    /// March animation: slight bob while advancing. Called by the scene.
    func animateMarch(dt: TimeInterval, advancing: Bool) {
        if advancing { marchPhase += dt * 10 }
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
