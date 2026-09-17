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
    /// Set on takeoff; spent when the stick is released mid-rise (hop).
    private var jumpCutArmed = false
    var isGrounded: Bool { grounded }

    var runSpeed: CGFloat { Balance.heroRunSpeed }
    var jumpVelocity: CGFloat { Balance.heroJumpVelocity }
    /// Collision height (visual is Balance.heroHeight tall, centered on node).
    private var bodyHeight: CGFloat { Balance.heroHeight }

    // MARK: - Pixel-art visual (PixelHeroArt frames + aiming rifle)
    private let visual = SKNode()
    private var body: SKSpriteNode!
    private var rifle: SKSpriteNode!
    /// Grip -> muzzle tip for the active gun (world pt). Drives muzzlePosition.
    private var rifleLength: CGFloat = 42
    /// Frame player: run index + timers. Pose cache avoids texture churn.
    private var animT: TimeInterval = 0
    private var runFrame = 0
    /// 0 idle, 1-4 run, 5 jump, 6 fall. -1 forces the first set.
    private var shownPose = -1

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

    // MARK: - Visual construction (pixel body + rifle, facing +x)
    private func buildVisuals() {
        body = SKSpriteNode(texture: PixelHeroArt.idleTex)
        body.size = PixelHeroArt.bodySize()
        body.zPosition = 0
        visual.addChild(body)
        rifle = SKSpriteNode(texture: PixelHeroArt.gunTexture(.blaster))
        rifle.size = PixelHeroArt.gunSize(.blaster)
        rifle.anchorPoint = PixelHeroArt.gunAnchor // grip = rotation pivot
        rifle.position = CGPoint(x: 10, y: 4) // chest, arms meet the body
        // Gun + arms always draw in front of the body (same-z siblings have
        // no guaranteed order under ignoresSiblingOrder).
        rifle.zPosition = 5
        visual.addChild(rifle)
        rifleLength = PixelHeroArt.gunLength(.blaster)
    }

    /// Swaps the visible rifle for the active weapon (HUD gun button).
    /// Rotation is preserved; length re-aims the muzzle automatically.
    func setWeapon(_ weapon: HeroWeapon) {
        rifle.texture = PixelHeroArt.gunTexture(weapon)
        rifle.size = PixelHeroArt.gunSize(weapon)
        rifleLength = PixelHeroArt.gunLength(weapon)
    }

    // MARK: - Aiming (called by GameScene while the shoot-touch is down)
    /// Faces the aim direction and rotates the rifle to the world-space angle.
    /// Handles the flipped visual (xScale = -1) so the barrel truly points at the tap.
    func aimToward(_ dir: CGVector) {
        aimFacingX = dir.dx
        let facingRight = dir.dx >= 0
        visual.xScale = facingRight ? 1 : -1
        let worldAngle = atan2(dir.dy, dir.dx)
        rifle.zRotation = facingRight ? worldAngle : .pi - worldAngle
    }

    func clearAim() { aimFacingX = 0 }

    /// Muzzle tip in parent (world) space: rifle grip at the chest + rifle
    /// length along the aim direction.
    func muzzlePosition(for dir: CGVector) -> CGPoint {
        guard let parent else { return position }
        let hx: CGFloat = dir.dx >= 0 ? 10 : -10
        return convert(CGPoint(x: hx + dir.dx * rifleLength,
                               y: 4 + dir.dy * rifleLength), to: parent)
    }

    // MARK: - Per-frame movement + animation (manual character controller)
    func step(dt: TimeInterval, now: TimeInterval) {
        guard alive else { return }
        let dt = min(max(dt, 0), 1.0 / 30)
        let dtCG = CGFloat(dt)

        if grounded { lastGroundedTime = now }

        // Horizontal: separate drive/glide lanes so starts feel eager,
        // releases glide out smoothly, and air keeps its flow instead of
        // braking mid-flight.
        let targetVX = inputX * runSpeed
        let driving = abs(targetVX) > 1
        let accel: CGFloat
        if grounded {
            accel = driving ? Balance.heroAccelGround : Balance.heroDecelGround
        } else {
            accel = driving ? Balance.heroAccelAir : Balance.heroAirDrag
        }
        let maxDelta = accel * dtCG
        let dvx = targetVX - velocity.dx
        velocity.dx += max(-maxDelta, min(maxDelta, dvx))
        // Rest once the glide decays (grounded, stick centered).
        if grounded, !driving, abs(velocity.dx) < Balance.heroStopThreshold {
            velocity.dx = 0
        }

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
            jumpCutArmed = true // early release will bleed the rise once
            lastGroundedTime = -10 // consume coyote so we don't double-jump
            lastJumpPressedTime = -10 // consume buffer
        }
        // Variable jump height: releasing mid-rise bleeds lift once, so a tap
        // hops and a hold flies full height (hold still auto-bounces).
        if jumpCutArmed, !jumpHeld, velocity.dy > 0 {
            velocity.dy *= Balance.heroJumpCutFraction
            jumpCutArmed = false
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
        jumpCutArmed = false
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
        jumpCutArmed = false
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

    // MARK: - Pixel-frame animation (driven by velocity, never desyncs)
    /// Pose ids: 0 idle, 1-4 run cycle, 5 jump (rising), 6 fall.
    private func setPose(_ pose: Int, texture: SKTexture) {
        guard pose != shownPose else { return }
        shownPose = pose
        body.texture = texture
    }

    private func animate(velocity: CGVector, dt: TimeInterval, now: TimeInterval) {
        let speed = abs(velocity.dx)
        let moving = speed > 30

        // Face travel direction — unless aiming, which owns the facing.
        // (Flip visuals only; the node itself never rotates.)
        if aimFacingX == 0, moving { visual.xScale = velocity.dx < 0 ? -1 : 1 }

        if !isGrounded {
            // Airborne: tucked jump frame rising, stretched fall frame.
            setPose(velocity.dy > 60 ? 5 : 6,
                    texture: velocity.dy > 60 ? PixelHeroArt.jumpTex : PixelHeroArt.fallTex)
            visual.zRotation = velocity.dy > 0 ? -0.06 : 0.08
            visual.position.y = 0
        } else if moving {
            // Run cycle: frame rate scales with speed, lean + bounce on top.
            animT += dt * (0.5 + speed / runSpeed)
            if animT >= 0.12 {
                animT = 0
                runFrame = (runFrame + 1) % PixelHeroArt.runTex.count
            }
            setPose(1 + runFrame, texture: PixelHeroArt.runTex[runFrame])
            visual.zRotation = -min(0.1, speed / runSpeed * 0.1)
            visual.position.y = (runFrame % 2 == 0) ? 0 : -2
        } else {
            // Idle: single frame + gentle breathing bob.
            runFrame = 0
            animT = 0
            setPose(0, texture: PixelHeroArt.idleTex)
            visual.zRotation = 0
            visual.position.y = sin(now * 3) * 2
        }
    }
}
