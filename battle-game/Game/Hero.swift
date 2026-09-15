import SpriteKit

/// Hero player node. Procedural astronaut trooper (InvaderPush theme) built from
/// shape nodes — crisp at any zoom and fully animatable. Real sprite frames can
/// swap in later by replacing `buildVisuals()` without touching movement/input.
///
/// Movement is a manual character controller (explicit velocity integration +
/// AABB ground/platform collision, no physics bodies): fully deterministic, no
/// hidden engine impulses. Same tuning numbers live in Balance.
///
/// Controls: `inputX` (-1...1 run), `jumpHeld` (stick up = auto-jump on landing).
/// Animation: leg run-cycle, forward lean, tucked jump pose, idle bob — all driven
/// in `step()` from velocity so visuals never desync.
final class HeroNode: SKSpriteNode {

    // MARK: - Input (written by GameView each frame)
    var inputX: CGFloat = 0
    var jumpHeld: Bool = false

    // MARK: - State (manual character controller)
    var velocity = CGVector.zero
    private var grounded = false
    /// When false the hero is dead: step() skips, scene hides the node.
    var alive = true
    private var lastGroundedTime: TimeInterval = -10
    private var lastJumpPressedTime: TimeInterval = -10
    private var prevJumpHeld = false
    private var legPhase: TimeInterval = 0
    var isGrounded: Bool { grounded }

    var runSpeed: CGFloat { Balance.heroRunSpeed }
    var jumpVelocity: CGFloat { Balance.heroJumpVelocity }
    /// Collision height (visual is Balance.heroHeight tall, centered on node).
    private var bodyHeight: CGFloat { Balance.heroHeight }

    // MARK: - Visual parts
    private let visual = SKNode()
    private var legL = SKShapeNode()
    private var legR = SKShapeNode()
    private var armBack = SKShapeNode()
    private var armFront = SKShapeNode()
    private var visor = SKShapeNode()
    private var gun = SKShapeNode()

    // MARK: - Aim state (written by GameScene while the shoot-touch is down)
    /// X of the current aim direction. 0 = not aiming (face travel direction).
    var aimFacingX: CGFloat = 0

    // MARK: - Init (no physics body: movement is integrated manually)
    init() {
        super.init(texture: nil, color: .clear, size: CGSize(width: 44, height: Balance.heroHeight))
        name = "hero"
        zPosition = 10
        buildVisuals()
        addChild(visual)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - Visual construction (local coords: origin at node center, +x facing)
    private func buildVisuals() {
        let H = Balance.heroHeight // 96
        let suitWhite = SKColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1)
        let suitShade = SKColor(red: 0.55, green: 0.62, blue: 0.72, alpha: 1)
        let trimBlue  = SKColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1)
        let visorCyan = SKColor(red: 0.30, green: 0.90, blue: 1.0, alpha: 1)

        func limb(_ size: CGSize, color: SKColor) -> SKShapeNode {
            let n = SKShapeNode(rectOf: size, cornerRadius: size.width / 2)
            n.fillColor = color
            n.strokeColor = .clear
            return n
        }

        // Backpack (behind torso).
        let pack = limb(CGSize(width: 16, height: 34), color: suitShade)
        pack.position = CGPoint(x: -16, y: 8)
        visual.addChild(pack)
        let tankStripe = limb(CGSize(width: 6, height: 24), color: visorCyan)
        tankStripe.position = CGPoint(x: -16, y: 8)
        visual.addChild(tankStripe)

        // Legs pivot at the hip (anchor top-center via offset child trick:
        // shape centered, so position the node at hip and offset the shape down).
        legL = limb(CGSize(width: 13, height: 34), color: suitShade)
        legL.position = CGPoint(x: -6, y: -H / 2 + 17)
        visual.addChild(legL)
        legR = limb(CGSize(width: 13, height: 34), color: suitWhite)
        legR.position = CGPoint(x: 7, y: -H / 2 + 17)
        visual.addChild(legR)
        // Boots.
        for (x, c) in [(-6, suitShade), (7, SKColor.darkGray)] as [(CGFloat, SKColor)] {
            let boot = limb(CGSize(width: 16, height: 9), color: c)
            boot.position = CGPoint(x: x + 2, y: -H / 2 + 4)
            boot.name = "boot"
            visual.addChild(boot)
        }

        // Torso.
        let torso = limb(CGSize(width: 36, height: 42), color: suitWhite)
        torso.position = CGPoint(x: 0, y: 6)
        visual.addChild(torso)
        // Chest light + belt.
        let chest = limb(CGSize(width: 12, height: 12), color: trimBlue)
        chest.position = CGPoint(x: 8, y: 14)
        visual.addChild(chest)
        let belt = limb(CGSize(width: 37, height: 7), color: suitShade)
        belt.position = CGPoint(x: 0, y: -13)
        visual.addChild(belt)
        // Shoulder pad (team blue).
        let pad = SKShapeNode(circleOfRadius: 9)
        pad.fillColor = trimBlue
        pad.strokeColor = .clear
        pad.position = CGPoint(x: 4, y: 24)
        visual.addChild(pad)

        // Arms (swing opposite to legs; front arm will hold the gun later).
        armBack = limb(CGSize(width: 11, height: 30), color: suitShade)
        armBack.position = CGPoint(x: -8, y: 8)
        visual.addChild(armBack)
        armFront = limb(CGSize(width: 11, height: 30), color: suitWhite)
        armFront.position = CGPoint(x: 9, y: 8)
        visual.addChild(armFront)

        // Helmet + visor.
        let helmet = SKShapeNode(circleOfRadius: 17)
        helmet.fillColor = suitWhite
        helmet.strokeColor = suitShade
        helmet.lineWidth = 2
        helmet.position = CGPoint(x: 2, y: 40)
        visual.addChild(helmet)
        visor = SKShapeNode(rectOf: CGSize(width: 20, height: 11), cornerRadius: 5)
        visor.fillColor = visorCyan
        visor.strokeColor = SKColor(red: 0.1, green: 0.3, blue: 0.45, alpha: 1)
        visor.lineWidth = 2
        visor.position = CGPoint(x: 9, y: 41)
        visual.addChild(visor)
        // Helmet crest light.
        let crest = limb(CGSize(width: 6, height: 6), color: trimBlue)
        crest.position = CGPoint(x: 2, y: 55)
        visual.addChild(crest)

        // Gun (hidden until the first shot; aims at the touch point).
        gun = limb(CGSize(width: 32, height: 9), color: SKColor(white: 0.2, alpha: 1))
        gun.position = CGPoint(x: 16, y: 8)
        gun.isHidden = true
        visual.addChild(gun)
        let grip = limb(CGSize(width: 7, height: 12), color: trimBlue)
        grip.position = CGPoint(x: 8, y: 3)
        gun.addChild(grip)
    }

    // MARK: - Aiming (called by GameScene while the shoot-touch is down)
    /// Faces the aim direction and rotates the gun to the world-space angle.
    /// Handles the flipped visual (xScale = -1) so the barrel truly points at the tap.
    func aimToward(_ dir: CGVector) {
        aimFacingX = dir.dx
        let facingRight = dir.dx >= 0
        visual.xScale = facingRight ? 1 : -1
        gun.isHidden = false
        let worldAngle = atan2(dir.dy, dir.dx)
        gun.zRotation = facingRight ? worldAngle : .pi - worldAngle
    }

    func clearAim() { aimFacingX = 0 }

    // MARK: - Per-frame movement + animation (manual character controller)
    func step(dt: TimeInterval, now: TimeInterval) {
        guard alive else { return }
        let dt = min(max(dt, 0), 1.0 / 30)
        let dtCG = CGFloat(dt)

        if grounded { lastGroundedTime = now }

        // Horizontal: accelerate toward target velocity (snappy on ground,
        // strong steering in air).
        let targetVX = inputX * runSpeed
        let accel: CGFloat = grounded ? Balance.heroAccelGround : Balance.heroAccelAir
        let maxDelta = accel * dtCG
        let dvx = targetVX - velocity.dx
        velocity.dx += max(-maxDelta, min(maxDelta, dvx))

        // Gravity.
        velocity.dy += Balance.heroGravity * dtCG

        // Jump: holding jump auto-jumps on landing; fresh presses are buffered so
        // taps just before landing still fire. Coyote time covers edge walks.
        if jumpHeld && !prevJumpHeld { lastJumpPressedTime = now }
        prevJumpHeld = jumpHeld
        let coyote = now - lastGroundedTime < Balance.heroCoyoteTime
        let buffered = now - lastJumpPressedTime < Balance.heroJumpBuffer
        if (jumpHeld || buffered) && (grounded || coyote) {
            velocity.dy = jumpVelocity
            grounded = false
            lastGroundedTime = -10 // consume coyote so we don't double-jump
            lastJumpPressedTime = -10 // consume buffer
        }

        // Integrate.
        let prevPos = position
        position.x += velocity.dx * dtCG
        position.y += velocity.dy * dtCG

        // Collide: ground strip + platform tops + platform head-bumps.
        resolveCollisions(prevPos: prevPos, now: now)

        animate(velocity: velocity, dt: dt, now: now)

        // Safety: never leave the lane.
        if position.x < 40 {
            position.x = 40
            velocity.dx = max(0, velocity.dx)
        } else if position.x > Balance.levelWidth - 40 {
            position.x = Balance.levelWidth - 40
            velocity.dx = min(0, velocity.dx)
        }
    }

    /// Death: stop simulating; the scene hides the node and respawns later.
    func die() {
        alive = false
        velocity = .zero
        clearAim()
    }

    /// Respawn drop: placed above the base front, falls with gravity, lands.
    func respawn(at pos: CGPoint) {
        position = pos
        velocity = .zero
        grounded = false
        alive = true
        isHidden = false
        alpha = 1
        lastGroundedTime = -10
        lastJumpPressedTime = -10
    }

    private func resolveCollisions(prevPos: CGPoint, now: TimeInterval) {
        let halfH = bodyHeight / 2
        let prevFeet = prevPos.y - halfH
        let prevHead = prevPos.y + halfH
        var feet = position.y - halfH
        let head = position.y + halfH
        grounded = false

        // Ground strip (walkable surface at Balance.groundTopY).
        if velocity.dy <= 0 && feet <= Balance.groundTopY {
            position.y = Balance.groundTopY + halfH
            feet = Balance.groundTopY
            velocity.dy = 0
            grounded = true
        }

        // Floating platforms: land on top when falling onto them,
        // bonk head when rising into them from below.
        let inset: CGFloat = 10 // forgive near-misses at the edges
        for rect in Balance.platforms {
            let withinX = position.x > rect.minX - inset && position.x < rect.maxX + inset
            guard withinX else { continue }
            if velocity.dy <= 0 && prevFeet >= rect.maxY - 1 && feet <= rect.maxY {
                position.y = rect.maxY + halfH
                feet = rect.maxY
                velocity.dy = 0
                grounded = true
            } else if velocity.dy > 0 && prevHead <= rect.minY + 1 && head >= rect.minY {
                position.y = rect.minY - halfH - 1
                velocity.dy = 0
            }
        }

        if grounded { lastGroundedTime = now }
    }

    // MARK: - Procedural animation
    private func animate(velocity: CGVector, dt: TimeInterval, now: TimeInterval) {
        let speed = abs(velocity.dx)
        let moving = speed > 30

        // Face travel direction — unless aiming, which owns the facing.
        // (Flip visuals only; the node itself never rotates.)
        if aimFacingX == 0, moving { visual.xScale = velocity.dx < 0 ? -1 : 1 }

        if !isGrounded {
            // Jump pose: legs tucked, front arm raised, slight back lean.
            legL.position = CGPoint(x: -8, y: -Balance.heroHeight / 2 + 22)
            legR.position = CGPoint(x: 8, y: -Balance.heroHeight / 2 + 16)
            legL.zRotation = -0.5
            legR.zRotation = 0.35
            armFront.position = CGPoint(x: 10, y: 16)
            armBack.position = CGPoint(x: -9, y: 4)
            visual.zRotation = velocity.dy > 0 ? -0.08 : 0.10
            visual.position.y = 0
        } else if moving {
            // Run cycle: legs + arms swing opposite, phase advances with speed.
            legPhase += speed * dt * 0.055
            let swing = sin(legPhase) * min(0.65, speed / runSpeed * 0.65)
            legL.zRotation = swing
            legR.zRotation = -swing
            // Keep feet near the hip while swinging (cheap pendulum feel).
            legL.position = CGPoint(x: -6 + swing * 14, y: -Balance.heroHeight / 2 + 17 - abs(swing) * 6)
            legR.position = CGPoint(x: 7 - swing * 14, y: -Balance.heroHeight / 2 + 17 - abs(swing) * 6)
            armFront.zRotation = -swing * 0.7
            armBack.zRotation = swing * 0.7
            // Lean into the run.
            visual.zRotation = -min(0.14, speed / runSpeed * 0.14)
            visual.position.y = abs(sin(legPhase)) * -2 // tiny ground-pound bounce
        } else {
            // Idle: gentle breathing bob, limbs settle.
            legPhase = 0
            legL.zRotation = 0; legR.zRotation = 0
            legL.position = CGPoint(x: -6, y: -Balance.heroHeight / 2 + 17)
            legR.position = CGPoint(x: 7, y: -Balance.heroHeight / 2 + 17)
            armFront.zRotation = 0; armBack.zRotation = 0
            armFront.position = CGPoint(x: 9, y: 8)
            armBack.position = CGPoint(x: -8, y: 8)
            visual.zRotation = 0
            visual.position.y = sin(now * 3) * 2.5
        }
    }
}
