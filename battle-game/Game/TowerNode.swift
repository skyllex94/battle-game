import SpriteKit
import UIKit

/// Pixel-art tower with a smoothly turning turret head.
///
/// Replaces the old single-sprite tinted tripod (`Tower.png`).
/// - Static pixel bunker base (procedural low-res texture, `.nearest`
///   filtering so pixels stay crisp) in team colours.
/// - Rotating turret head: housing + barrel pivot that eases toward its
///   target each frame, idle-scans when nothing is in range, kicks back
///   on fire, and slumps when destroyed.
/// - Self-contained pixel HP bar + team beacon light.
///
/// Origin = ground line under the tower (scene positions the node at
/// `(x, Balance.groundTopY)`). All child offsets are relative to that.
final class TowerNode: SKNode {

    // MARK: - Layout (points; textures are low-res, upscaled with .nearest)

    /// Height of the whole tower, matches the old 190pt sprite.
    static let towerHeight: CGFloat = 190
    /// Turret mount height above ground. Matches Balance.towerMuzzleHeight.
    static let mountHeight: CGFloat = 150
    /// HP bar floats just above the tower (same spot as the old bars).
    private static let hpBarY: CGFloat = 205

    let team: Team

    private let baseSprite: SKSpriteNode
    private let headPivot = SKNode()      // rotates to track targets
    private let headSprite: SKSpriteNode
    private let muzzleSocket = SKNode()   // barrel tip, in head space
    private let beacon = SKShapeNode(circleOfRadius: 5) // blinking team light
    private let hpBG = SKSpriteNode()
    private let hpFill = SKSpriteNode()
    private let teamGlow = SKShapeNode(circleOfRadius: 46)

    private var desiredAngle: CGFloat?    // nil = idle scan
    private var scanPhase: TimeInterval = 0
    private var beaconPhase: TimeInterval = 0
    private var recoilOffset: CGFloat = 0
    private var destroyed = false

    /// Forward direction when idle (player faces right, enemy faces left).
    private var homeAngle: CGFloat { team == .player ? 0 : .pi }

    // MARK: - Init

    init(team: Team) {
        self.team = team

        let palette = TowerNode.palette(for: team)
        let baseTex = TowerNode.makeBaseTexture(palette: palette)
        baseTex.filteringMode = .nearest
        baseSprite = SKSpriteNode(texture: baseTex)
        let baseScale = TowerNode.towerHeight / baseTex.size().height
        baseSprite.setScale(baseScale)
        baseSprite.anchorPoint = CGPoint(x: 0.5, y: 0)

        let headTex = TowerNode.makeHeadTexture(palette: palette)
        headTex.filteringMode = .nearest
        headSprite = SKSpriteNode(texture: headTex)
        // Housing centre sits ~7px from the left of the 26px head texture.
        headSprite.anchorPoint = CGPoint(x: 7.0 / headTex.size().width, y: 0.5)

        super.init()

        name = team == .player ? "playerTower" : "enemyTower"
        zPosition = 5

        // Team ground glow so sides read at a glance on the dark ground.
        teamGlow.fillColor = palette.glow
        teamGlow.strokeColor = .clear
        teamGlow.alpha = 0.22
        teamGlow.position = CGPoint(x: 0, y: 14)
        teamGlow.zPosition = -2
        addChild(teamGlow)

        // Drop shadow ellipse for 2.5D grounding (child so it leaves with the tower).
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 110, height: 18))
        shadow.fillColor = SKColor(white: 0, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 6)
        shadow.zPosition = -3
        addChild(shadow)

        baseSprite.position = .zero
        baseSprite.zPosition = 0
        addChild(baseSprite)

        // Turret mount.
        headPivot.position = CGPoint(x: 0, y: TowerNode.mountHeight)
        headPivot.zPosition = 2
        // Start parked toward home so the enemy tower doesn't open facing away.
        headPivot.zRotation = homeAngle
        addChild(headPivot)

        // Head visual scale: ~90pt barrel assembly.
        let headScale: CGFloat = 3.4
        headSprite.setScale(headScale)
        headSprite.position = .zero
        headPivot.addChild(headSprite)

        // Muzzle socket at the barrel tip (19px right of the pivot in texture space).
        muzzleSocket.position = CGPoint(x: 19 * headScale, y: 0)
        headPivot.addChild(muzzleSocket)

        // Beacon light on the housing, pulses in update(dt:).
        beacon.fillColor = palette.beacon
        beacon.strokeColor = .clear
        beacon.position = CGPoint(x: -2 * headScale, y: 2)
        beacon.zPosition = 3
        headPivot.addChild(beacon)

        buildHPBar(palette: palette)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Hitbox size for projectile tests (matches the old ~124x195 box).
    var hitSize: CGSize { CGSize(width: 124, height: 195) }

    // MARK: - Per-frame

    /// Ease the turret toward its target (or idle-scan), pulse the beacon,
    /// and recover recoil. Called every frame by the scene.
    func update(dt: TimeInterval) {
        guard !destroyed else { return }
        scanPhase += dt
        beaconPhase += dt
        beacon.alpha = 0.65 + 0.35 * sin(beaconPhase * 5)
        teamGlow.alpha = 0.18 + 0.06 * sin(beaconPhase * 5)

        let target: CGFloat
        if let desired = desiredAngle {
            target = desired
        } else {
            // Idle scan: slow sweep around home direction.
            target = homeAngle + sin(scanPhase * 0.7) * 0.35
        }
        headPivot.zRotation = TowerNode.lerpAngle(headPivot.zRotation, target,
                                                  t: min(1, 8 * dt))
        // Recoil recovery.
        if recoilOffset != 0 {
            recoilOffset = max(0, recoilOffset - dt * 60)
            headSprite.position.x = -recoilOffset
        }
    }

    /// Aim the turret at a world-space point. Pass nil when no target is
    /// in range (falls back to idle scanning). Call before firing.
    func aimAt(_ worldPoint: CGPoint?) {
        guard !destroyed else { return }
        guard let p = worldPoint, let parent = parent else {
            desiredAngle = nil
            return
        }
        // Pivot in parent (world) space.
        let pivot = headPivot.convert(CGPoint.zero, to: parent)
        desiredAngle = atan2(p.y - pivot.y, p.x - pivot.x)
    }

    /// Kick the barrel back; called by the scene right after firing.
    func recoil() {
        guard !destroyed else { return }
        recoilOffset = 7
        headSprite.position.x = -recoilOffset
    }

    /// Muzzle tip in parent (world) coordinates — shots originate here.
    func muzzlePosition() -> CGPoint {
        guard let parent = parent else { return position }
        return muzzleSocket.convert(CGPoint.zero, to: parent)
    }

    // MARK: - Damage

    func setHPFraction(_ frac: CGFloat) {
        let f = min(1, max(0, frac))
        hpFill.xScale = f
        if f > 0.5 {
            hpFill.color = team == .player ? .cyan : .red
        } else if f > 0.25 {
            hpFill.color = .orange
        } else {
            hpFill.color = .red
        }
    }

    /// Explosion + burning rubble, then the tower leaves the field.
    /// Dead towers are already untargetable; this only plays visuals.
    func setDestroyed() {
        destroyed = true
        desiredAngle = nil
        baseSprite.color = SKColor(white: 0.3, alpha: 1)
        baseSprite.colorBlendFactor = 0.7
        baseSprite.alpha = 0.8
        headSprite.color = SKColor(white: 0.3, alpha: 1)
        headSprite.colorBlendFactor = 0.7
        headSprite.alpha = 0.8
        headPivot.zRotation = homeAngle + (team == .player ? 0.55 : -0.55)
        beacon.isHidden = true
        teamGlow.alpha = 0.05
        hpFill.isHidden = true
        hpBG.alpha = 0.25
        if let parent = parent {
            StructureFX.explode(at: position, in: parent, team: team,
                                size: TowerNode.towerHeight)
        }
        // Burn briefly, sink + fade, then remove (shadow is a child: goes too).
        run(.sequence([
            .wait(forDuration: 1.1),
            .group([.moveBy(x: 0, y: -14, duration: 0.4),
                    .fadeOut(withDuration: 0.4)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - HP bar (chunky pixel style)

    private func buildHPBar(palette: Palette) {
        let w: CGFloat = 96, h: CGFloat = 12
        hpBG.color = SKColor(white: 0, alpha: 0.65)
        hpBG.size = CGSize(width: w + 4, height: h + 4)
        hpBG.position = CGPoint(x: 0, y: TowerNode.hpBarY)
        hpBG.zPosition = 6
        addChild(hpBG)
        // Pixel border ticks.
        let border = SKShapeNode(rectOf: CGSize(width: w + 4, height: h + 4))
        border.strokeColor = SKColor(white: 1, alpha: 0.25)
        border.lineWidth = 1
        border.fillColor = .clear
        border.position = hpBG.position
        border.zPosition = 7
        addChild(border)

        hpFill.color = palette.bar
        hpFill.size = CGSize(width: w, height: h)
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill.position = CGPoint(x: -w / 2, y: TowerNode.hpBarY)
        hpFill.zPosition = 7
        addChild(hpFill)
    }

    // MARK: - Angle helper

    /// Shortest-path angle interpolation (handles the ±π wrap).
    private static func lerpAngle(_ from: CGFloat, _ to: CGFloat, t: CGFloat) -> CGFloat {
        var delta = to - from
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return from + delta * t
    }

    // MARK: - Pixel art

    private struct Palette {
        var trim: UIColor      // team banner / barrel ring
        var trimDark: UIColor
        var beacon: SKColor    // blinking light
        var bar: SKColor       // HP fill
        var glow: SKColor      // ground wash
    }

    private static func palette(for team: Team) -> Palette {
        switch team {
        case .player:
            return Palette(trim: UIColor(red: 0.25, green: 0.65, blue: 1.0, alpha: 1),
                           trimDark: UIColor(red: 0.12, green: 0.32, blue: 0.7, alpha: 1),
                           beacon: SKColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1),
                           bar: .cyan,
                           glow: SKColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1))
        case .enemy:
            return Palette(trim: UIColor(red: 1.0, green: 0.3, blue: 0.22, alpha: 1),
                           trimDark: UIColor(red: 0.6, green: 0.12, blue: 0.1, alpha: 1),
                           beacon: SKColor(red: 1.0, green: 0.35, blue: 0.2, alpha: 1),
                           bar: .red,
                           glow: SKColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1))
        case .neutral:
            return Palette(trim: UIColor(white: 0.7, alpha: 1),
                           trimDark: UIColor(white: 0.4, alpha: 1),
                           beacon: .white,
                           bar: .white,
                           glow: SKColor(white: 0.7, alpha: 1))
        }
    }

    /// Renders a W×H pixel canvas (1 unit = 1 pixel) into a texture.
    private static func pixelTexture(w: Int, h: Int,
                                     draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h),
                                               format: format)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            // UIKit coords: row 0 = top, matching the art below. (Do NOT
            // flip: SKTexture(image:) displays upright.)
            draw(cg)
        }
        return SKTexture(image: img)
    }

    private static func fill(_ cg: CGContext, x: Int, y: Int, w: Int, h: Int,
                             color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    /// 28×40 bunker: tapered stone body, brick courses, team banner,
    /// glowing core slit, riveted foundation cap and turret deck.
    private static func makeBaseTexture(palette: Palette) -> SKTexture {
        let W = 28, H = 40
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
            let stoneD = UIColor(red: 0.23, green: 0.25, blue: 0.31, alpha: 1)
            let stoneM = UIColor(red: 0.42, green: 0.45, blue: 0.52, alpha: 1)
            let stoneL = UIColor(red: 0.67, green: 0.70, blue: 0.77, alpha: 1)
            let mortar = UIColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1)
            let dark = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1)
            let warn = UIColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 1)

            // Body silhouette: tapered (wide base 24px -> top deck 18px).
            // widthAt(row): row 0 = top.
            func halfWidth(at row: Int) -> Int {
                if row < 3 { return 9 }            // turret deck
                if row < 30 { return 9 + (row - 3) * 3 / 27 * 2 } // taper out
                return 12                          // foundation
            }
            let cx = W / 2
            for row in 0..<H {
                let hw = halfWidth(at: row)
                // Outline.
                fill(cg, x: cx - hw - 1, y: row, w: hw * 2 + 2, h: 1, color: outline)
                // Stone gradient: light left, mid centre, dark right.
                fill(cg, x: cx - hw, y: row, w: 2, h: 1, color: stoneL)
                fill(cg, x: cx - hw + 2, y: row, w: hw * 2 - 4, h: 1, color: stoneM)
                fill(cg, x: cx + hw - 2, y: row, w: 2, h: 1, color: stoneD)
            }
            // Brick mortar courses every 5 rows + staggered vertical joints.
            for row in stride(from: 7, to: 33, by: 5) {
                let hw = halfWidth(at: row)
                fill(cg, x: cx - hw, y: row, w: hw * 2, h: 1, color: mortar)
                let off = (row % 10 == 2) ? 3 : -3
                for jx in [cx + off - 4, cx + off, cx + off + 4] {
                    fill(cg, x: jx, y: row + 1, w: 1, h: 3, color: mortar)
                }
            }
            // Turret deck plate (rows 1-3): dark metal + rivets + team edge.
            fill(cg, x: cx - 9, y: 1, w: 18, h: 3, color: dark)
            fill(cg, x: cx - 9, y: 1, w: 18, h: 1, color: stoneL)
            fill(cg, x: cx - 9, y: 3, w: 18, h: 1, color: palette.trim)
            for rx in [cx - 8, cx - 4, cx + 3, cx + 7] {
                fill(cg, x: rx, y: 2, w: 1, h: 1, color: stoneL)
            }
            // Team banner band (rows 6-9) with dark border + centre emblem.
            let hwB = halfWidth(at: 6)
            fill(cg, x: cx - hwB, y: 5, w: hwB * 2, h: 1, color: palette.trimDark)
            fill(cg, x: cx - hwB, y: 6, w: hwB * 2, h: 3, color: palette.trim)
            fill(cg, x: cx - hwB, y: 9, w: hwB * 2, h: 1, color: palette.trimDark)
            fill(cg, x: cx - hwB, y: 6, w: 2, h: 3, color: .white.withAlphaComponent(0.35))
            // Emblem pixel (chevron).
            fill(cg, x: cx - 1, y: 7, w: 3, h: 1, color: .white)
            fill(cg, x: cx, y: 6, w: 1, h: 3, color: .white)
            // Glowing core slit (rows 14-16): team energy cell.
            let hwC = halfWidth(at: 14)
            fill(cg, x: cx - 5, y: 13, w: 10, h: 5, color: outline)
            fill(cg, x: cx - 4, y: 14, w: 8, h: 3, color: palette.trimDark)
            fill(cg, x: cx - 3, y: 14, w: 4, h: 3, color: palette.trim)
            fill(cg, x: cx - 3, y: 14, w: 4, h: 1, color: .white)
            // Hazard chevrons above foundation (row 30).
            let hwH = halfWidth(at: 30)
            var hx = cx - hwH + 1
            var flip = false
            while hx < cx + hwH - 2 {
                fill(cg, x: hx, y: 30, w: 2, h: 2, color: flip ? warn : dark)
                hx += 2
                flip.toggle()
            }
            // Foundation block (rows 34-39): dark + top highlight + rivets.
            fill(cg, x: cx - 12, y: 34, w: 24, h: 1, color: stoneL)
            fill(cg, x: cx - 12, y: 35, w: 24, h: 4, color: stoneD)
            fill(cg, x: cx - 12, y: 39, w: 24, h: 1, color: outline)
            for rx in [cx - 10, cx - 5, cx, cx + 4, cx + 9] {
                fill(cg, x: rx, y: 36, w: 1, h: 1, color: stoneL)
            }
            // Right-side drop shadow strip for depth.
            fill(cg, x: cx + 10, y: 4, w: 2, h: 30, color: UIColor(white: 0, alpha: 0.25))
        }
    }

    /// 26×12 turret head, barrel pointing +x. Housing is vertically
    /// symmetric so full 360° rotation still reads correctly.
    private static func makeHeadTexture(palette: Palette) -> SKTexture {
        let W = 26, H = 12
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
            let metalD = UIColor(red: 0.20, green: 0.21, blue: 0.27, alpha: 1)
            let metalM = UIColor(red: 0.45, green: 0.48, blue: 0.56, alpha: 1)
            let metalL = UIColor(red: 0.75, green: 0.78, blue: 0.85, alpha: 1)
            let barrelD = UIColor(red: 0.13, green: 0.13, blue: 0.17, alpha: 1)

            // Barrel: x 11..24, y 5..6 (+1px highlight on top, shadow below).
            fill(cg, x: 11, y: 4, w: 13, h: 4, color: outline)
            fill(cg, x: 12, y: 5, w: 12, h: 2, color: barrelD)
            fill(cg, x: 12, y: 5, w: 12, h: 1, color: metalM)
            // Muzzle brake rings (team colour) near the tip.
            fill(cg, x: 20, y: 5, w: 1, h: 2, color: palette.trimDark)
            fill(cg, x: 22, y: 5, w: 2, h: 2, color: palette.trim)
            fill(cg, x: 24, y: 5, w: 1, h: 2, color: outline)
            // Muzzle mouth.
            fill(cg, x: 24, y: 5, w: 1, h: 2, color: .black)

            // Housing: rounded box x 1..13, y 2..9.
            fill(cg, x: 2, y: 2, w: 11, h: 8, color: outline)
            fill(cg, x: 3, y: 3, w: 9, h: 6, color: metalM)
            fill(cg, x: 3, y: 3, w: 9, h: 1, color: metalL)   // top highlight
            fill(cg, x: 3, y: 8, w: 9, h: 1, color: metalD)   // bottom shade
            fill(cg, x: 3, y: 4, w: 1, h: 4, color: metalL)   // left light edge
            fill(cg, x: 11, y: 4, w: 1, h: 4, color: metalD)  // right shade
            // Team stripe across the housing + white sight dot.
            fill(cg, x: 5, y: 4, w: 2, h: 4, color: palette.trim)
            fill(cg, x: 5, y: 4, w: 2, h: 1, color: .white.withAlphaComponent(0.6))
            fill(cg, x: 9, y: 5, w: 2, h: 2, color: metalD)
            fill(cg, x: 9, y: 5, w: 2, h: 1, color: .white)
            // Pivot bolt.
            fill(cg, x: 6, y: 5, w: 3, h: 2, color: outline)
            fill(cg, x: 7, y: 5, w: 1, h: 2, color: metalL)
            // Rear vent fins.
            fill(cg, x: 0, y: 4, w: 3, h: 1, color: metalD)
            fill(cg, x: 0, y: 7, w: 3, h: 1, color: metalD)
            _ = W
        }
    }
}
