import SpriteKit

/// Player-summonable army kinds. Four cards:
/// .trooper = cheap + fast, .heavy = expensive tank that hits hard,
/// .ranger = long-rifle skirmisher that outranges raiders but folds fast,
/// .truck = fast gun-truck debuting in Level 6 — wheels, turret + gunner.
/// .bombard = slow mortar carrier debuting in Level 11 — long-range lobbed
/// bombs with splash damage.
/// .tank = main-battle tank debuting in Level 17 — tracked, top-turret
/// missile fired in a straight line.
/// The Ranger is introduced in Level 2, the Heavy in Level 3,
/// the Truck in Level 6, the Bombard in Level 11, the Tank in Level 17.
enum ArmyKind: Int, CaseIterable, Identifiable {
    case trooper
    case heavy
    case ranger
    case truck
    case bombard
    case tank

    var id: Int { rawValue }

    /// Campaign level that fields this unit (trooper from the start,
    /// ranger from Level 2's Rootwall Thicket briefing onward,
    /// heavy from Level 3's Thornwood Bastion briefing onward,
    /// truck from Level 6's Sandhold Citadel briefing onward,
    /// bombard from Level 11's Sunforge Redoubt briefing onward).
    var unlockLevel: Int {
        switch self {
        case .trooper: return 1
        case .heavy: return 3
        case .ranger: return 2
        case .truck: return 6
        case .bombard: return 11
        case .tank: return 17
        }
    }

    /// Level-gated (no persistence needed): a unit is fieldable once its
    /// introduction level is reached.
    static func isUnlocked(_ kind: ArmyKind, levelId: Int) -> Bool {
        levelId >= kind.unlockLevel
    }

    var name: String {
        switch self {
        case .trooper: return "Trooper"
        case .heavy: return "Heavy"
        case .ranger: return "Ranger"
        case .truck: return "Truck"
        case .bombard: return "Bombard"
        case .tank: return "Tank"
        }
    }

    var cost: Int {
        switch self {
        case .trooper: return Balance.trooperCost
        case .heavy: return Balance.heavyCost
        case .ranger: return Balance.rangerCost
        case .truck: return Balance.truckCost
        case .bombard: return Balance.bombardCost
        case .tank: return Balance.tankCost
        }
    }

    /// Deploy cooldown in seconds (pricier units wait longer).
    var cooldown: Double {
        switch self {
        case .trooper: return 3
        case .ranger: return 5
        case .heavy: return 8
        case .truck: return 10
        case .bombard: return 13
        case .tank: return 14
        }
    }

    var hp: CGFloat {
        switch self {
        case .trooper: return Balance.trooperHP
        case .heavy: return Balance.heavyHP
        case .ranger: return Balance.rangerHP
        case .truck: return Balance.truckHP
        case .bombard: return Balance.bombardHP
        case .tank: return Balance.tankHP
        }
    }

    var speed: CGFloat {
        switch self {
        case .trooper: return Balance.trooperSpeed
        case .heavy: return Balance.heavySpeed
        case .ranger: return Balance.rangerSpeed
        case .truck: return Balance.truckSpeed
        case .bombard: return Balance.bombardSpeed
        case .tank: return Balance.tankSpeed
        }
    }

    var damage: CGFloat {
        switch self {
        case .trooper: return Balance.trooperDamage
        case .heavy: return Balance.heavyDamage
        case .ranger: return Balance.rangerDamage
        case .truck: return Balance.truckDamage
        case .bombard: return Balance.bombardDamage
        case .tank: return Balance.tankDamage
        }
    }

    var fireCooldown: TimeInterval {
        switch self {
        case .trooper: return Balance.trooperFireCooldown
        case .heavy: return Balance.heavyFireCooldown
        case .ranger: return Balance.rangerFireCooldown
        case .truck: return Balance.truckFireCooldown
        case .bombard: return Balance.bombardFireCooldown
        case .tank: return Balance.tankFireCooldown
        }
    }

    var shootRange: CGFloat {
        switch self {
        case .trooper: return Balance.trooperRange
        case .heavy: return Balance.heavyRange
        case .ranger: return Balance.rangerRange
        case .truck: return Balance.truckRange
        case .bombard: return Balance.bombardRange
        case .tank: return Balance.tankRange
        }
    }

    var sightRange: CGFloat {
        switch self {
        case .trooper: return Balance.trooperSightRange
        case .heavy: return Balance.heavySightRange
        case .ranger: return Balance.rangerSightRange
        case .truck: return Balance.truckSightRange
        case .bombard: return Balance.bombardSightRange
        case .tank: return Balance.tankSightRange
        }
    }

    /// Short battlefield role for the army library.
    var roleLabel: String {
        switch self {
        case .trooper: return "RIFLE"
        case .heavy: return "TANK"
        case .ranger: return "MARKSMAN"
        case .truck: return "SIEGE"
        case .bombard: return "ARTILLERY"
        case .tank: return "ARMOR"
        }
    }

    /// Draw tier — the light skirmishers render IN FRONT of the heavy
    /// vehicles, so a tank never hides the riflemen fighting beside it.
    var zTier: CGFloat {
        switch self {
        case .trooper, .ranger: return 9.6
        case .heavy, .truck, .bombard, .tank: return 8.2
        }
    }

    /// One-line dossier for intel cards and showcases.
    var blurb: String {
        switch self {
        case .trooper: return "Fast skirmisher. Cheap, quick, everywhere."
        case .heavy: return "Walking bunker. Slow, pricey, unstoppable."
        case .ranger: return "Long rifle. Outranges raiders, folds fast."
        case .truck: return "Olive gun-truck. Big wheels, long cannon."
        case .bombard: return "Mortar carrier. Slow, long lob, splash blast."
        case .tank: return "Battle tank. Tracked, straight-flying missile."
        }
    }

    /// SF Symbol used on the summon card.
    var icon: String {
        switch self {
        case .trooper: return "person.fill"
        case .heavy: return "shield.fill"
        case .ranger: return "scope"
        case .truck: return "truck.box.fill"
        case .bombard: return "scope"
        case .tank: return "engine.combustion.fill"
        }
    }

    /// Pixel-art kind for the summon-card portrait (the real sprite).
    var pixelKind: UnitPixelArt.Kind {
        switch self {
        case .trooper: return .trooper
        case .heavy: return .heavy
        case .ranger: return .ranger
        case .truck: return .truck
        case .bombard: return .bombard
        case .tank: return .tank
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
    /// Driving-dust timer (trucks kick up dust while rolling).
    var dustTimer: TimeInterval = 0
    var facing: CGFloat { xScale >= 0 ? 1 : -1 }
    /// Set when the unit marches off-view after the enemy HQ falls.
    var marchedOff = false

    init(kind: ArmyKind) {
        self.kind = kind
        self.hp = kind.hp
        self.maxHP = kind.hp
        let size: CGSize
        switch kind {
        case .trooper: size = CGSize(width: 40, height: 62)
        case .heavy: size = CGSize(width: 52, height: 76)
        case .ranger: size = CGSize(width: 38, height: 60)
        case .truck: size = CGSize(width: 132, height: 88)
        case .bombard: size = CGSize(width: 132, height: 88)
        case .tank: size = CGSize(width: 132, height: 88)
        }
        super.init(texture: nil, color: .clear, size: size)
        name = "ally"
        // Tier + a tiny stable per-unit offset: two overlapping units of
        // the same kind get a fixed draw order (one is always in front)
        // instead of flickering on an exact z tie.
        zPosition = kind.zTier + CGFloat.random(in: 0 ..< 0.14)
        frames = UnitPixelArt.frames(for: kind.pixelKind)
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
        // The Bombard's tube is fixed in a high lob angle; the shell's
        // ballistic solution does the aiming, not the barrel.
        if kind == .bombard {
            desiredAim = 0.95
            return
        }
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
        bodySprite.zPosition = 0
        body.addChild(bodySprite)
        addChild(body)

        // Aimable gun-arm on the shoulder; the scene steers it via aimAt(_).
        // Pixels match the body (same 32px-tall canvas scale).
        let armTex = UnitPixelArt.armTexture(for: kind.pixelKind)
        armTex.filteringMode = .nearest
        let s = size.height / 32
        let arm = UnitPixelArt.armMetrics(for: kind.pixelKind)
        armSprite = SKSpriteNode(texture: armTex)
        armSprite.setScale(s)
        armSprite.anchorPoint = CGPoint(x: CGFloat(arm.gripX) / CGFloat(arm.w),
                                        y: 0.5)
        armPivot.position = kind == .heavy ? CGPoint(x: 9, y: 7)
            : kind == .bombard ? CGPoint(x: 0, y: 30)
            : kind == .truck ? CGPoint(x: 0, y: 29)
            : kind == .tank ? CGPoint(x: 3, y: 24)
            : CGPoint(x: 6, y: 8)
        armPivot.addChild(armSprite)
        gunTip.position = CGPoint(x: CGFloat(arm.tipX - arm.gripX) * s,
                                  y: 0)
        armPivot.addChild(gunTip)
        // Small z so the gun layers over the own body but never climbs
        // above the next unit tier (child z is cumulative with the node's).
        armPivot.zPosition = 0.3
        body.addChild(armPivot)

        // Heavy pip so the two cards read apart at a glance.
        if heavy {
            let pip = SKShapeNode(rectOf: CGSize(width: 10, height: 10), cornerRadius: 2)
            pip.fillColor = suitBlue
            pip.strokeColor = .clear
            pip.zPosition = 0.5
            pip.position = CGPoint(x: -size.width / 2 - 4, y: size.height / 2 - 6)
            addChild(pip)
        }
    }

    /// March cycle: swaps the 4 pixel stride frames + bob while advancing,
    /// and eases the gun-arm toward its target (levels out when idle).
    /// Trucks barely rock (wheels sell the roll); walkers bob normally.
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
        let wheeled = kind == .truck || kind == .bombard || kind == .tank
        yBob = advancing ? sin(marchPhase) * (wheeled ? 0.8 : 2.5) : 0
        body.zRotation = advancing ? sin(marchPhase) * (wheeled ? 0.008 : 0.03) : 0
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
        // drains from the right side only. Wide rides get a wider bar.
        let barW: CGFloat = kind == .heavy ? 52
            : (kind == .truck || kind == .bombard || kind == .tank) ? 64 : 44
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
