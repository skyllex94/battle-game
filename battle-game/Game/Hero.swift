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

    /// Upgrade multiplier (SPD tiers). Applied to run speed only —
    /// jump physics stay fixed so platforms always clear the same.
    var speedMultiplier: CGFloat = 1

    /// Landing impulse 0...1 for the camera dip. Set on touchdown from
    /// fall speed, decayed every frame; GameScene reads it for a dip.
    var landDip: CGFloat = 0

    /// Gun recoil 0...1. Kicked by fireBullet via kick(), decays fast;
    /// the rifle + visual absorb it so shots feel punchy.
    private var recoil: CGFloat = 0
    /// Squash & stretch offsets (1 = neutral). Takeoff stretches tall,
    /// landing squashes wide, then both spring back — the Celeste rule.
    private var squashX: CGFloat = 1
    private var squashY: CGFloat = 1
    /// Deepest fall speed this airtime (negative). Scales landing dust,
    /// squash and the camera dip so soft hops whisper, long drops thump.
    private var fallPeak: CGFloat = 0
    /// Was grounded last frame (edge detector for land events).
    private var wasGrounded = true
    /// Run-stride dust + footstep cadence.
    private var strideAcc: TimeInterval = 0
    /// Rising-trail cadence while climbing fast.
    private var trailAcc: TimeInterval = 0
    /// Idle blink timer (visor life).
    private var blinkT: TimeInterval = 2.5
    private var blinking: TimeInterval = 0

    var runSpeed: CGFloat { Balance.heroRunSpeed * speedMultiplier }
    var jumpVelocity: CGFloat { Balance.heroJumpVelocity }
    /// Collision height (visual is Balance.heroHeight tall, centered on node).
    private var bodyHeight: CGFloat { Balance.heroHeight }

    // MARK: - Pixel-art visual (per-hero body + aiming rifle)
    private let visual = SKNode()
    private var body: SKSpriteNode!
    private var rifle: SKSpriteNode!
    /// Grip -> muzzle tip for the active gun (world pt). Drives muzzlePosition.
    private var rifleLength: CGFloat = 42
    /// Roster identity + its 4 walk frames (contact → support → toe-off
    /// → swing, astronaut-style). Run cycles all four; jump holds the
    /// toe-off frame, idle/fall park on contact.
    private var heroKind: HeroPixelArt.Kind = .vanguard
    private var heroFrames: [SKTexture] = []
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
        body = SKSpriteNode(texture: nil)
        body.size = HeroPixelArt.displaySize(for: .vanguard)
        body.zPosition = 0
        visual.addChild(body)
        setHero(.vanguard)
        rifle = SKSpriteNode(texture: PixelHeroArt.gunTexture(.blaster))
        rifle.size = PixelHeroArt.gunSize(.blaster)
        rifle.anchorPoint = PixelHeroArt.gunAnchor // grip = rotation pivot
        rifle.position = CGPoint(x: 11, y: 5) // chest, arms meet the body
        // Gun + arms always draw in front of the body (same-z siblings have
        // no guaranteed order under ignoresSiblingOrder).
        rifle.zPosition = 5
        visual.addChild(rifle)
        rifleLength = PixelHeroArt.gunLength(.blaster)
    }

    /// Dresses the hero as a roster fighter (battle twin of the armory art).
    func setHero(_ kind: HeroPixelArt.Kind) {
        heroKind = kind
        heroFrames = HeroPixelArt.frames(for: kind)
        heroFrames.forEach { $0.filteringMode = .nearest }
        body.texture = heroFrames[0]
        // Big frames truly loom (collision box stays put — presence only).
        body.size = HeroPixelArt.displaySize(for: kind)
        shownPose = -1
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

    /// Gun recoil kick from firing (called by GameScene.fireBullet).
    /// Strength scales with the gun's punch (blast guns kick harder).
    func kick(_ strength: CGFloat = 0.5) {
        recoil = min(1, recoil + strength)
    }

    // MARK: - Per-frame movement + animation (manual character controller)
    func step(dt: TimeInterval, now: TimeInterval) {
        guard alive else { return }
        let dt = min(max(dt, 0), 1.0 / 30)
        let dtCG = CGFloat(dt)

        if grounded { lastGroundedTime = now }

        // Horizontal: snappy drive in, snappy stop, boosted reversals.
        // Celeste rule: ~6 frames to full, ~3-6 to stop, flips with a
        // skid pop instead of an icy slide.
        let targetVX = inputX * runSpeed
        let driving = abs(targetVX) > 1
        let reversing = driving && velocity.dx != 0 &&
            (targetVX > 0) != (velocity.dx > 0) && abs(velocity.dx) > 120
        let accel: CGFloat
        if grounded {
            if reversing {
                accel = Balance.heroTurnAccel
                if abs(velocity.dx) > 260 { spawnSkid() }
            } else {
                accel = driving ? Balance.heroAccelGround : Balance.heroDecelGround
            }
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

        // Gravity: fall faster than rise (snappy drops), hang at the apex
        // (floaty top for steering), extra gravity when the jump is
        // released early (variable height without the abrupt velocity cut
        // doing all the work alone).
        var g = Balance.heroGravity
        if velocity.dy < 0 {
            g *= Balance.heroFallMultiplier
        } else if abs(velocity.dy) < Balance.heroApexWindow {
            g *= Balance.heroApexScale
        }
        if !jumpHeld, velocity.dy > 0 {
            g *= Balance.heroCutGravityScale
        }
        velocity.dy += g * dtCG

        // Jump: holding jump auto-jumps on landing; fresh presses are buffered so
        // taps just before landing still fire. Coyote time covers edge walks.
        // Takeoff scales a touch with run speed (Mario-tiered): sprinting
        // leaps clear further, standing hops stay controlled.
        if jumpHeld && !prevJumpHeld { lastJumpPressedTime = now }
        prevJumpHeld = jumpHeld
        let coyote = now - lastGroundedTime < Balance.heroCoyoteTime
        let buffered = now - lastJumpPressedTime < Balance.heroJumpBuffer
        if (jumpHeld || buffered) && (grounded || coyote) {
            let runFrac = min(1, abs(velocity.dx) / max(1, runSpeed))
            velocity.dy = jumpVelocity * (1 + Balance.heroJumpSpeedBonus * runFrac)
            grounded = false
            jumpCutArmed = true // early release will bleed the rise once
            lastGroundedTime = -10 // consume coyote so we don't double-jump
            lastJumpPressedTime = -10 // consume buffer
            fallPeak = 0
            // Takeoff pop: stretch tall + burst + whoosh.
            squashX = 0.82
            squashY = 1.18
            spawnJumpBurst()
            SoundEngine.shared.heroJump()
        }
        // Variable jump height: releasing mid-rise bleeds lift once, so a tap
        // hops and a hold flies full height (hold still auto-bounces).
        if jumpCutArmed, !jumpHeld, velocity.dy > 0 {
            velocity.dy *= Balance.heroJumpCutFraction
            jumpCutArmed = false
        }

        // Track the fall for landing weight.
        if !grounded { fallPeak = min(fallPeak, velocity.dy) }

        // Rising trail: faint motes shed while climbing fast, so big
        // jumps read as powerful instead of floaty.
        if !grounded, velocity.dy > 500 {
            trailAcc += dt
            if trailAcc >= 0.09 {
                trailAcc = 0
                spawnRiseMote()
            }
        } else {
            trailAcc = 0
        }

        // Integrate.
        let prevPos = position
        position.x += velocity.dx * dtCG
        position.y += velocity.dy * dtCG

        // Collide: ground strip + platform tops + platform head-bumps.
        let fellGrounded = grounded
        resolveCollisions(prevPos: prevPos, now: now)

        // Touchdown: weight scales with fall speed. Soft hops whisper;
        // long drops squash deep, puff wide, dip the camera, thump.
        if grounded, !fellGrounded {
            let impact = min(1, max(0, -fallPeak / 1400))
            squashX = 1 + 0.22 * max(0.25, impact)
            squashY = 1 - 0.20 * max(0.25, impact)
            landDip = max(landDip, max(0.25, impact))
            spawnDust(count: 4 + Int(impact * 8), spread: 30 + impact * 30,
                      up: 50 + impact * 90, color: groundDustColor())
            // Hard drops slam a shockwave ring out across the ground.
            if impact > 0.45 { spawnLandRing(scale: 1 + impact) }
            SoundEngine.shared.heroLand(impact)
            fallPeak = 0
            strideAcc = 0
        }
        wasGrounded = grounded

        // Decay one-shot impulses.
        landDip = max(0, landDip - CGFloat(dt) * 5)
        recoil = max(0, recoil - CGFloat(dt) * 7)
        // Squash springs back to neutral (~12/s: punchy but never wobbly).
        let spring = min(1, CGFloat(dt) * 12)
        squashX += (1 - squashX) * spring
        squashY += (1 - squashY) * spring

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
        fallPeak = 0
        landDip = 0
        recoil = 0
        squashX = 1
        squashY = 1
        wasGrounded = false
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
    /// Squash & stretch rides on top of every pose: the visual node
    /// scales (squashX/squashY) while the textures cycle underneath,
    /// so weight reads even on a 4-frame pixel stride.
    private func setPose(_ pose: Int, texture: SKTexture) {
        guard pose != shownPose else { return }
        shownPose = pose
        body.texture = texture
    }

    private func animate(velocity: CGVector, dt: TimeInterval, now: TimeInterval) {
        let speed = abs(velocity.dx)
        let speedFrac = min(1, speed / max(1, runSpeed))
        let moving = speed > 30
        // Walk frames (contact/support/toe-off/swing); idle parks on frame 0.
        let frameCount = max(1, heroFrames.count)
        func walk(_ i: Int) -> SKTexture? {
            heroFrames.isEmpty ? nil : heroFrames[i % frameCount]
        }

        // Face travel direction — unless aiming, which owns the facing.
        // (Flip visuals only; the node itself never rotates.)
        if aimFacingX == 0, moving {
            let want: CGFloat = velocity.dx < 0 ? -1 : 1
            if visual.xScale != want {
                visual.xScale = want
                // Snap-turn pop: brief wide squash sells the reversal.
                squashX = max(squashX, 1.12)
                squashY = min(squashY, 0.92)
            }
        }

        // Recoil absorb: rifle kicks back into the chest, visual shoves
        // a hair with it, then both spring home in step().
        let kickBack = recoil * 9
        rifle.position = CGPoint(x: 11 - kickBack, y: 5 - recoil * 1.5)
        let baseScaleX: CGFloat = visual.xScale >= 0 ? 1 : -1

        if !isGrounded {
            // Airborne: stretch along the flight line — tall on the rise,
            // long on the dive — plus a forward tilt that grows with speed.
            // Toe-off frame rising, contact frame falling.
            let rising = velocity.dy > 60
            if let tex = walk(rising ? 2 : 0) {
                setPose(rising ? 5 : 6, texture: tex)
            }
            let airStretch = min(0.12, abs(velocity.dy) / 9000)
            let sx = (squashX - airStretch * (rising ? 1 : -0.5)) * baseScaleX
            visual.xScale = sx == 0 ? baseScaleX : sx
            visual.yScale = squashY + airStretch
            let tilt: CGFloat = rising ? -0.07 : 0.09
            visual.zRotation = tilt + min(0.08, speedFrac * 0.08) * (velocity.dx < 0 ? -1 : 1) * baseScaleX
            visual.position.y = rising ? 2 : -1
            visual.position.x = -recoil * 3 * baseScaleX
        } else if moving {
            // Run cycle: stride rate scales with speed (quick shuffle at
            // full tilt), lean + bounce on top, dust kicked per stride.
            let interval = 0.14 - 0.07 * Double(speedFrac)
            animT += dt * (0.5 + Double(speedFrac))
            var stepped = false
            if animT >= interval {
                animT = 0
                runFrame = (runFrame + 1) % frameCount
                stepped = true
            }
            if let tex = walk(runFrame) {
                setPose(1 + runFrame, texture: tex)
            }
            // Stride dust + soft footfalls at pace (only when hoofing it).
            if stepped, speedFrac > 0.35 {
                spawnDust(count: 1, spread: 12, up: 30, color: groundDustColor())
                if speedFrac > 0.6 { SoundEngine.shared.heroStep() }
            }
            strideAcc += dt
            visual.xScale = squashX * baseScaleX
            visual.yScale = squashY
            visual.zRotation = -min(0.13, speedFrac * 0.13)
            visual.position.y = (runFrame % 2 == 0) ? 0 : -2 - speedFrac * 1.5
            // Recoil leans the whole body back a touch.
            visual.position.x = -recoil * 3 * baseScaleX
        } else {
            // Idle: contact frame + breathing bob + visor blink + rifle
            // sway. Alive at rest so the hero never looks frozen mid-fight.
            runFrame = 0
            animT = 0
            if let tex = walk(0) {
                setPose(0, texture: tex)
            }
            blinkT -= dt
            if blinkT <= 0 { blinkT = Double.random(in: 2...4.5); blinking = 0.12 }
            if blinking > 0 {
                blinking -= dt
                visual.yScale = squashY * 0.94
            } else {
                visual.yScale = squashY
            }
            visual.xScale = squashX * baseScaleX
            visual.zRotation = recoil * -0.05 * baseScaleX
            visual.position.y = sin(now * 3) * 2
            visual.position.x = -recoil * 2 * baseScaleX
            // Rifle settles home when not aiming, breathing with the body
            // (absolute set, never accumulated, so it can't drift).
            if aimFacingX == 0 {
                rifle.zRotation += (sin(now * 2.2) * 0.04 - rifle.zRotation) * 0.1
            }
        }
    }

    // MARK: - Movement dust (pixel puffs that sell weight)

    /// Twilight-lane dust: pale moss tint, darkens on platforms.
    private func groundDustColor() -> SKColor {
        SKColor(red: 0.75, green: 0.78, blue: 0.85, alpha: 1)
    }

    /// Skid puff when slamming into a reversal at speed.
    private func spawnSkid() {
        squashX = max(squashX, 1.15)
        spawnDust(count: 4, spread: 18, up: 40, color: groundDustColor())
        SoundEngine.shared.heroStep()
    }

    /// Tiny square-pixel dust kicked at the feet. Lives in the world so
    /// it stays behind while the hero runs on; self-removes.
    private func spawnDust(count: Int, spread: CGFloat, up: CGFloat, color: SKColor) {
        guard let parent, count > 0 else { return }
        let feetY = -bodyHeight / 2 + 4
        let origin = visual.convert(CGPoint(x: 0, y: feetY), to: parent)
        for _ in 0..<min(count, 10) {
            let side = CGFloat.random(in: 3...6)
            let mote = SKSpriteNode(color: color.withAlphaComponent(0.85),
                                    size: CGSize(width: side, height: side))
            mote.position = origin + CGVector(
                dx: CGFloat.random(in: -spread...spread),
                dy: CGFloat.random(in: 0...8))
            mote.zPosition = 9
            mote.zRotation = CGFloat.random(in: 0...(CGFloat.pi * 2))
            parent.addChild(mote)
            let dx = CGFloat.random(in: -70...70) - velocity.dx * 0.15
            let dur = TimeInterval.random(in: 0.3...0.55)
            mote.run(.sequence([
                .group([
                    .move(by: CGVector(dx: dx * CGFloat(dur),
                                       dy: CGFloat.random(in: up * 0.5...up)),
                          duration: dur),
                    .rotate(byAngle: CGFloat.random(in: -2...2), duration: dur),
                    .sequence([.wait(forDuration: dur * 0.4),
                                .fadeOut(withDuration: dur * 0.6)]),
                    .scale(to: 0.3, duration: dur),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    /// Takeoff burst: ground dust + an expanding shockwave ring + white
    /// streaks shooting skyward. The jump reads as an explosion upward,
    /// not a float away.
    private func spawnJumpBurst() {
        spawnDust(count: 6, spread: 26, up: 60, color: groundDustColor())
        guard let parent else { return }
        let feetY = -bodyHeight / 2 + 4
        let origin = visual.convert(CGPoint(x: 0, y: feetY), to: parent)
        // Shockwave ring hugging the ground.
        let ring = SKShapeNode(circleOfRadius: 14)
        ring.strokeColor = SKColor(white: 1, alpha: 0.7)
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.position = origin
        ring.zPosition = 9
        parent.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 2.6, duration: 0.35),
                    .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
        // Rising light streaks.
        for _ in 0..<5 {
            let streak = SKSpriteNode(
                color: SKColor(white: 1, alpha: 0.8),
                size: CGSize(width: CGFloat.random(in: 2...3.5),
                             height: CGFloat.random(in: 10...20)))
            streak.position = origin + CGVector(
                dx: CGFloat.random(in: -24...24),
                dy: CGFloat.random(in: 0...6))
            streak.zPosition = 9
            parent.addChild(streak)
            let dur = TimeInterval.random(in: 0.25...0.4)
            streak.run(.sequence([
                .group([
                    .moveBy(x: CGFloat.random(in: -10...10),
                            y: CGFloat.random(in: 50...90), duration: dur),
                    .fadeOut(withDuration: dur),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    /// Landing shockwave for hard drops: a wide ring racing outward.
    private func spawnLandRing(scale: CGFloat) {
        guard let parent else { return }
        let feetY = -bodyHeight / 2 + 4
        let origin = visual.convert(CGPoint(x: 0, y: feetY), to: parent)
        let ring = SKShapeNode(circleOfRadius: 16 * scale)
        ring.strokeColor = SKColor(white: 1, alpha: 0.65)
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.position = origin
        ring.zPosition = 9
        parent.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 2.2, duration: 0.4),
                    .fadeOut(withDuration: 0.4)]),
            .removeFromParent(),
        ]))
    }

    /// Faint mote shed while climbing fast: drifts down past the body so
    /// the rise feels speedy against the world.
    private func spawnRiseMote() {
        guard let parent else { return }
        let origin = visual.convert(
            CGPoint(x: CGFloat.random(in: -10...10),
                    y: CGFloat.random(in: -20...20)), to: parent)
        let side = CGFloat.random(in: 2.5...4.5)
        let mote = SKSpriteNode(color: SKColor(white: 1, alpha: 0.55),
                                size: CGSize(width: side, height: side))
        mote.position = origin
        mote.zPosition = 9
        parent.addChild(mote)
        let dur = TimeInterval.random(in: 0.25...0.4)
        mote.run(.sequence([
            .group([
                .moveBy(x: -velocity.dx * 0.1 * CGFloat(dur),
                        y: CGFloat.random(in: -60...(-30)), duration: dur),
                .fadeOut(withDuration: dur),
            ]),
            .removeFromParent(),
        ]))
    }
}

// MARK: - CGPoint helpers (file-local)

private func +(lhs: CGPoint, rhs: CGVector) -> CGPoint {
    CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
}
