import SpriteKit
import UIKit

/// Pixel-art main base (HQ) where units walk out from.
///
/// Same procedural pixel language as TowerNode (low-res textures,
/// `.nearest` filtering, team trim, brick courses, hazard chevrons).
/// - Central keep with dome roof + side wings + riveted foundation.
/// - Arched spawn gate with a flickering energy glow that flashes
///   whenever a unit walks out (see `spawnPulse()`).
/// - Roof cannon pointing toward mid; the enemy base fires its 3-bolt
///   fan from the muzzle tip (see `muzzlePosition()` + `fireFlash()`).
/// - Self-contained pixel HP bar + blinking beacons.
///
/// Origin = ground line under the building (scene positions the node at
/// `(x, Balance.groundTopY)`).
final class BaseNode: SKNode {

    /// Building height, matches the old ~170pt Base sprite.
    static let baseHeight: CGFloat = 170
    /// HP bar floats just above the roof (same spot as the old bars).
    private static let hpBarY: CGFloat = 185

    let team: Team
    /// Which way the gate + cannon face: player looks right (+1),
    /// enemy looks left (-1) — both toward mid.
    var facing: CGFloat { team == .player ? 1 : -1 }

    private let bodySprite: SKSpriteNode
    private let cannonPivot = SKNode() // traverses to track targets
    private let cannonSprite: SKSpriteNode
    private let muzzleSocket = SKNode()
    private let gateGlow: SKShapeNode
    private let gateLightL: SKShapeNode
    private let gateLightR: SKShapeNode
    private let beacon: SKShapeNode
    private let hpBG = SKSpriteNode()
    private let hpFill = SKSpriteNode()
    private let teamGlow = SKShapeNode(circleOfRadius: 70)

    private var phase: TimeInterval = 0
    private var gateFlash: CGFloat = 0   // 0..1, decays after a spawn
    private var muzzleFlash: CGFloat = 0 // 0..1, decays after a fan shot
    private var desiredAngle: CGFloat?   // nil = park toward mid
    private var destroyed = false

    /// Rest direction: both HQs face mid (player right, enemy left).
    private var homeAngle: CGFloat { team == .player ? 0 : .pi }

    // MARK: - Init

    init(team: Team) {
        self.team = team

        let palette = BaseNode.palette(for: team)
        let bodyTex = BaseNode.makeBodyTexture(palette: palette)
        bodyTex.filteringMode = .nearest
        bodySprite = SKSpriteNode(texture: bodyTex)
        let bodyScale = BaseNode.baseHeight / bodyTex.size().height
        bodySprite.setScale(bodyScale)
        bodySprite.anchorPoint = CGPoint(x: 0.5, y: 0)

        let cannonTex = BaseNode.makeCannonTexture(palette: palette)
        cannonTex.filteringMode = .nearest
        cannonSprite = SKSpriteNode(texture: cannonTex)
        // Pivot at the breech (left of the 22px texture); barrel points +x.
        cannonSprite.anchorPoint = CGPoint(x: 4.0 / cannonTex.size().width, y: 0.5)

        // Gate glow sits inside the arch; sized in points after scaling.
        gateGlow = SKShapeNode(ellipseOf: CGSize(width: 30, height: 52))
        gateLightL = SKShapeNode(circleOfRadius: 4)
        gateLightR = SKShapeNode(circleOfRadius: 4)
        beacon = SKShapeNode(circleOfRadius: 5)

        super.init()

        name = team == .player ? "playerBase" : "enemyBase"
        zPosition = 5

        // Team ground wash so home turf reads at a glance.
        teamGlow.fillColor = palette.glow
        teamGlow.strokeColor = .clear
        teamGlow.alpha = 0.20
        teamGlow.position = CGPoint(x: 0, y: 12)
        teamGlow.zPosition = -2
        addChild(teamGlow)

        // Wide drop shadow for 2.5D grounding (child so it leaves with the HQ).
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 220, height: 20))
        shadow.fillColor = SKColor(white: 0, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 6)
        shadow.zPosition = -3
        addChild(shadow)

        bodySprite.position = .zero
        bodySprite.zPosition = 0
        addChild(bodySprite)

        // Energy glow inside the gate arch (flickers; flashes on spawn).
        // Gate opening rows 20-29 -> ~33-76pt; centre the glow on it.
        let gateLocal = CGPoint(x: 0, y: 54)
        gateGlow.fillColor = palette.gate
        gateGlow.strokeColor = .clear
        gateGlow.alpha = 0.55
        gateGlow.position = gateLocal
        gateGlow.zPosition = 1
        addChild(gateGlow)

        // Gate side lamps.
        gateLightL.fillColor = palette.beacon
        gateLightL.strokeColor = .clear
        gateLightL.position = gateLocal + CGVector(dx: -24, dy: 6)
        gateLightL.zPosition = 2
        addChild(gateLightL)
        gateLightR.fillColor = palette.beacon
        gateLightR.strokeColor = .clear
        gateLightR.position = gateLocal + CGVector(dx: 24, dy: 6)
        gateLightR.zPosition = 2
        addChild(gateLightR)

        // Roof cannon on a traversing pivot (turret-style, like TowerNode).
        // Barrel points +x in texture space; the pivot steers it at targets.
        let cannonScale: CGFloat = 3.6
        cannonSprite.setScale(cannonScale)
        cannonSprite.position = .zero
        cannonPivot.position = CGPoint(x: facing * 18, y: 140)
        cannonPivot.zRotation = homeAngle
        cannonPivot.zPosition = 2
        cannonPivot.addChild(cannonSprite)
        addChild(cannonPivot)

        // Muzzle at the barrel tip (18px right of the breech in texture space).
        muzzleSocket.position = CGPoint(x: 18 * cannonScale, y: 0)
        cannonPivot.addChild(muzzleSocket)

        // Antenna beacon on the dome.
        beacon.fillColor = palette.beacon
        beacon.strokeColor = .clear
        beacon.position = CGPoint(x: -2, y: 180)
        beacon.zPosition = 2
        addChild(beacon)

        buildHPBar(palette: palette)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - Per-frame

    /// Beacon blink + gate flicker + flash decay + turret traverse.
    /// Called every frame.
    func update(dt: TimeInterval) {
        guard !destroyed else { return }
        phase += dt
        beacon.alpha = 0.6 + 0.4 * sin(phase * 5)
        teamGlow.alpha = 0.17 + 0.05 * sin(phase * 5)
        gateFlash = max(0, gateFlash - dt * 2.2)
        muzzleFlash = max(0, muzzleFlash - dt * 6)
        // Traverse toward the target, or sway gently around mid when idle.
        let want = desiredAngle ?? (homeAngle + CGFloat(sin(phase * 0.7)) * 0.12)
        cannonPivot.zRotation = BaseNode.lerpAngle(cannonPivot.zRotation, want,
                                                   t: min(1, 8 * dt))
        // Idle gate shimmer + bright surge right after a unit walks out.
        let shimmer = 0.45 + 0.12 * sin(phase * 7) + 0.08 * sin(phase * 13)
        gateGlow.alpha = min(1, shimmer + gateFlash * 0.6)
        let s = 1 + gateFlash * 0.35 + muzzleFlash * 0.15
        gateGlow.setScale(s)
        gateLightL.alpha = 0.6 + 0.4 * sin(phase * 5)
        gateLightR.alpha = 0.6 + 0.4 * sin(phase * 5 + .pi)
    }

    /// Gate surge when a unit walks out. Called by the scene on summon.
    func spawnPulse() {
        guard !destroyed else { return }
        gateFlash = 1
    }

    /// Muzzle blink when the fan fires. Called by the scene on volley.
    func fireFlash() {
        guard !destroyed else { return }
        muzzleFlash = 1
    }

    /// Steer the roof cannon at a world-space point (nil = park toward
    /// mid). Called every frame by the scene alongside update(dt:).
    func aimAt(_ worldPoint: CGPoint?) {
        guard !destroyed else { return }
        guard let p = worldPoint, let parent = parent else {
            desiredAngle = nil
            return
        }
        let pivot = cannonPivot.convert(CGPoint.zero, to: parent)
        desiredAngle = atan2(p.y - pivot.y, p.x - pivot.x)
    }

    /// Shortest-path angle interpolation (handles the ±π wrap).
    private static func lerpAngle(_ from: CGFloat, _ to: CGFloat, t: CGFloat) -> CGFloat {
        var delta = to - from
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return from + delta * t
    }

    /// Fan shots originate here (roof cannon tip, parent/world coords).
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

    /// Explosion + burning rubble, then the HQ leaves the field.
    /// Dead bases are already untargetable; this only plays visuals.
    func setDestroyed() {
        destroyed = true
        desiredAngle = nil
        bodySprite.color = SKColor(white: 0.3, alpha: 1)
        bodySprite.colorBlendFactor = 0.7
        bodySprite.alpha = 0.8
        cannonSprite.color = SKColor(white: 0.3, alpha: 1)
        cannonSprite.colorBlendFactor = 0.7
        cannonSprite.alpha = 0.8
        cannonPivot.zRotation = homeAngle - 0.45 * facing
        gateGlow.isHidden = true
        gateLightL.isHidden = true
        gateLightR.isHidden = true
        beacon.isHidden = true
        teamGlow.alpha = 0.05
        hpFill.isHidden = true
        hpBG.alpha = 0.25
        if let parent = parent {
            StructureFX.explode(at: position, in: parent, team: team,
                                size: BaseNode.baseHeight)
        }
        // Burn briefly, sink + fade, then remove (shadow is a child: goes too).
        run(.sequence([
            .wait(forDuration: 1.1),
            .group([.moveBy(x: 0, y: -14, duration: 0.4),
                    .fadeOut(withDuration: 0.4)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - HP bar (chunky pixel style, matches TowerNode)

    /// Pinned above units (z=9) but below the hero (z=10): readable
    /// through marching armies, covered only by the hero passing by.
    private func buildHPBar(palette: Palette) {
        let w: CGFloat = 140, h: CGFloat = 12
        hpBG.color = SKColor(white: 0, alpha: 0.65)
        hpBG.size = CGSize(width: w + 4, height: h + 4)
        hpBG.position = CGPoint(x: 0, y: BaseNode.hpBarY)
        hpBG.zPosition = 9.2
        addChild(hpBG)
        let border = SKShapeNode(rectOf: CGSize(width: w + 4, height: h + 4))
        border.strokeColor = SKColor(white: 1, alpha: 0.25)
        border.lineWidth = 1
        border.fillColor = .clear
        border.position = hpBG.position
        border.zPosition = 9.5
        addChild(border)

        hpFill.color = palette.bar
        hpFill.size = CGSize(width: w, height: h)
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill.position = CGPoint(x: -w / 2, y: BaseNode.hpBarY)
        hpFill.zPosition = 9.5
        addChild(hpFill)
    }

    // MARK: - Pixel art

    private struct Palette {
        var trim: UIColor
        var trimDark: UIColor
        var gate: SKColor
        var beacon: SKColor
        var bar: SKColor
        var glow: SKColor
    }

    private static func palette(for team: Team) -> Palette {
        switch team {
        case .player:
            return Palette(trim: UIColor(red: 0.25, green: 0.65, blue: 1.0, alpha: 1),
                           trimDark: UIColor(red: 0.12, green: 0.32, blue: 0.7, alpha: 1),
                           gate: SKColor(red: 0.4, green: 0.85, blue: 1.0, alpha: 1),
                           beacon: SKColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1),
                           bar: .cyan,
                           glow: SKColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1))
        case .enemy:
            return Palette(trim: UIColor(red: 1.0, green: 0.3, blue: 0.22, alpha: 1),
                           trimDark: UIColor(red: 0.6, green: 0.12, blue: 0.1, alpha: 1),
                           gate: SKColor(red: 1.0, green: 0.45, blue: 0.25, alpha: 1),
                           beacon: SKColor(red: 1.0, green: 0.35, blue: 0.2, alpha: 1),
                           bar: .red,
                           glow: SKColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1))
        case .neutral:
            return Palette(trim: UIColor(white: 0.7, alpha: 1),
                           trimDark: UIColor(white: 0.4, alpha: 1),
                           gate: .white,
                           beacon: .white,
                           bar: .white,
                           glow: SKColor(white: 0.7, alpha: 1))
        }
    }

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
            // flip: SKTexture(image:) displays upright, and a flip here is
            // what previously rendered the base upside-down.)
            draw(cg)
        }
        return SKTexture(image: img)
    }

    private static func fill(_ cg: CGContext, x: Int, y: Int, w: Int, h: Int,
                             color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    /// 48×36 HQ fortress: radar mast + dome + crenellated parapet,
    /// bannered keep, side bastions with pennants, arched spawn gate,
    /// riveted foundation. Row 0 = top.
    /// Gate arch centre x=24, opening rows 20-29.
    private static func makeBodyTexture(palette: Palette) -> SKTexture {
        let W = 48, H = 36
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
            let stoneD = UIColor(red: 0.23, green: 0.25, blue: 0.31, alpha: 1)
            let stoneM = UIColor(red: 0.42, green: 0.45, blue: 0.52, alpha: 1)
            let stoneL = UIColor(red: 0.67, green: 0.70, blue: 0.77, alpha: 1)
            let mortar = UIColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1)
            let dark = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1)
            let warn = UIColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 1)
            let gateDark = UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1)

            // Silhouette spans per row (x-ranges of solid building).
            func spans(at row: Int) -> [(Int, Int)] {
                switch row {
                case 0: return [(23, 24)]            // mast tip
                case 1: return [(20, 27)]            // radar bar
                case 2: return [(22, 25)]            // mast
                case 3: return [(19, 28)]            // dome crown
                case 4: return [(17, 30)]            // dome
                case 5: return [(16, 31)]            // dome foot
                case 6: return [(15, 32)]            // dome ring
                case 7: return [(14, 33)]            // parapet base
                case 8: return [(14, 33)]            // merlons
                case 9: return [(14, 33)]            // keep top
                case 10: return [(2, 12), (14, 33), (35, 45)]  // bastion caps + keep
                case 11: return [(2, 12), (14, 33), (35, 45)]
                case 12..<31: return [(3, 11), (14, 33), (36, 44)] // bastions + keep
                case 31..<35: return [(1, 46)]       // foundation
                case 35: return [(0, 47)]            // ground skirt
                default: return []
                }
            }
            for row in 0..<H {
                for (x0, x1) in spans(at: row) {
                    // Outline shell.
                    fill(cg, x: x0, y: row, w: x1 - x0 + 1, h: 1, color: outline)
                    // Stone gradient: light left edge, mid body, dark right.
                    let innerW = x1 - x0 - 1
                    if innerW > 0 {
                        fill(cg, x: x0 + 1, y: row, w: min(2, innerW), h: 1, color: stoneL)
                        fill(cg, x: x0 + 3, y: row, w: max(0, innerW - 4), h: 1, color: stoneM)
                        fill(cg, x: x1 - 1, y: row, w: 2, h: 1, color: stoneD)
                    }
                }
            }
            // Radar mast: dark pole + team tip + sweeping bar.
            fill(cg, x: 23, y: 0, w: 2, h: 3, color: dark)
            fill(cg, x: 23, y: 0, w: 2, h: 1, color: palette.trim)
            fill(cg, x: 20, y: 1, w: 8, h: 1, color: stoneM)
            fill(cg, x: 20, y: 1, w: 2, h: 1, color: palette.trim)
            fill(cg, x: 26, y: 1, w: 2, h: 1, color: palette.trim)
            // Dome shading: bright crown + team ring at its foot.
            fill(cg, x: 21, y: 3, w: 6, h: 1, color: stoneL)
            fill(cg, x: 19, y: 3, w: 2, h: 1, color: .white.withAlphaComponent(0.6))
            fill(cg, x: 15, y: 6, w: 18, h: 1, color: palette.trimDark)
            fill(cg, x: 16, y: 5, w: 16, h: 1, color: palette.trim)

            // Crenellated parapet: lit top edge (row 7) + merlon blocks (row 8).
            fill(cg, x: 14, y: 7, w: 20, h: 1, color: stoneL)
            var mx = 14
            while mx < 34 {
                fill(cg, x: mx + 2, y: 8, w: 2, h: 1, color: dark) // crenel gaps
                mx += 4
            }

            // Team banner band across the keep (rows 10-12) + chevron emblem.
            fill(cg, x: 14, y: 10, w: 20, h: 1, color: palette.trimDark)
            fill(cg, x: 14, y: 11, w: 20, h: 2, color: palette.trim)
            fill(cg, x: 14, y: 13, w: 20, h: 1, color: palette.trimDark)
            fill(cg, x: 14, y: 11, w: 2, h: 2, color: .white.withAlphaComponent(0.35))
            fill(cg, x: 23, y: 11, w: 3, h: 1, color: .white)
            fill(cg, x: 24, y: 11, w: 1, h: 2, color: .white)

            // Brick mortar courses on the keep.
            for row in [16, 27] {
                fill(cg, x: 15, y: row, w: 18, h: 1, color: mortar)
            }
            // Keep arrow slits (lit, team-tinted) flanking the banner/gate.
            for (sx, sy) in [(16, 15), (30, 15)] {
                fill(cg, x: sx, y: sy, w: 2, h: 4, color: outline)
                fill(cg, x: sx, y: sy + 1, w: 2, h: 2, color: palette.trimDark)
                fill(cg, x: sx, y: sy + 1, w: 2, h: 1, color: .white.withAlphaComponent(0.7))
            }

            // Bastion caps: lit tops + team band + crenels.
            for (bx, _) in [(2, 0), (35, 0)] {
                fill(cg, x: bx, y: 10, w: 11, h: 1, color: stoneL)
                fill(cg, x: bx, y: 11, w: 11, h: 1, color: palette.trim)
                fill(cg, x: bx + 1, y: 10, w: 1, h: 1, color: dark)
                fill(cg, x: bx + 5, y: 10, w: 1, h: 1, color: dark)
                fill(cg, x: bx + 9, y: 10, w: 1, h: 1, color: dark)
            }
            // Bastion pennants: poles + team flags flying outward.
            fill(cg, x: 7, y: 6, w: 1, h: 4, color: dark)
            fill(cg, x: 3, y: 6, w: 4, h: 1, color: palette.trim)
            fill(cg, x: 4, y: 7, w: 3, h: 1, color: palette.trimDark)
            fill(cg, x: 40, y: 6, w: 1, h: 4, color: dark)
            fill(cg, x: 41, y: 6, w: 4, h: 1, color: palette.trim)
            fill(cg, x: 41, y: 7, w: 3, h: 1, color: palette.trimDark)
            // Bastion windows: lit slits.
            for wx in [5, 38] {
                fill(cg, x: wx, y: 20, w: 4, h: 4, color: outline)
                fill(cg, x: wx + 1, y: 21, w: 2, h: 2, color: palette.trimDark)
                fill(cg, x: wx + 1, y: 21, w: 2, h: 1, color: .white.withAlphaComponent(0.7))
                fill(cg, x: wx, y: 26, w: 4, h: 3, color: outline)
                fill(cg, x: wx + 1, y: 26, w: 2, h: 2, color: stoneD)
            }

            // Spawn gate arch: opening x20-27, rows 20-29.
            fill(cg, x: 19, y: 19, w: 10, h: 12, color: outline)
            fill(cg, x: 20, y: 20, w: 8, h: 11, color: gateDark)
            // Inner energy field (the glow node animates over this).
            fill(cg, x: 21, y: 21, w: 6, h: 9, color: palette.trimDark)
            fill(cg, x: 22, y: 22, w: 4, h: 7, color: palette.trim)
            fill(cg, x: 23, y: 23, w: 2, h: 5, color: .white.withAlphaComponent(0.8))
            // Door shutter teeth top + bottom (half-open).
            for sx in 20..<28 {
                fill(cg, x: sx, y: 20, w: 1, h: 2, color: dark)
                fill(cg, x: sx, y: 29, w: 1, h: 2, color: dark)
            }
            // Arch pillars: lit left, shaded right.
            fill(cg, x: 18, y: 19, w: 1, h: 12, color: stoneL)
            fill(cg, x: 29, y: 19, w: 1, h: 12, color: stoneD)
            // Hazard chevrons + keystone ABOVE the gate.
            var hx = 19
            var flip = false
            while hx < 27 {
                fill(cg, x: hx, y: 17, w: 2, h: 2, color: flip ? warn : dark)
                hx += 2
                flip.toggle()
            }
            fill(cg, x: 23, y: 16, w: 2, h: 1, color: warn)

            // Foundation block (rows 31-35): lit top edge, dark body, rivets.
            fill(cg, x: 1, y: 31, w: 46, h: 1, color: stoneL)
            fill(cg, x: 1, y: 32, w: 46, h: 2, color: stoneD)
            fill(cg, x: 0, y: 35, w: 48, h: 1, color: outline)
            for rx in [3, 10, 17, 30, 37, 44] {
                fill(cg, x: rx, y: 32, w: 1, h: 1, color: stoneL)
            }
            _ = W
        }
    }

    /// 22×8 roof cannon, barrel pointing +x (scene flips it via xScale).
    private static func makeCannonTexture(palette: Palette) -> SKTexture {
        let W = 22, H = 8
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
            let metalD = UIColor(red: 0.20, green: 0.21, blue: 0.27, alpha: 1)
            let metalM = UIColor(red: 0.45, green: 0.48, blue: 0.56, alpha: 1)
            let metalL = UIColor(red: 0.75, green: 0.78, blue: 0.85, alpha: 1)
            let barrelD = UIColor(red: 0.13, green: 0.13, blue: 0.17, alpha: 1)

            // Breech housing x1-7, y1-6.
            fill(cg, x: 1, y: 1, w: 7, h: 6, color: outline)
            fill(cg, x: 2, y: 2, w: 5, h: 4, color: metalM)
            fill(cg, x: 2, y: 2, w: 5, h: 1, color: metalL)
            fill(cg, x: 2, y: 5, w: 5, h: 1, color: metalD)
            fill(cg, x: 3, y: 3, w: 2, h: 2, color: palette.trim)
            // Barrel x7-20, y3-4 + highlight.
            fill(cg, x: 7, y: 2, w: 14, h: 4, color: outline)
            fill(cg, x: 8, y: 3, w: 12, h: 2, color: barrelD)
            fill(cg, x: 8, y: 3, w: 12, h: 1, color: metalM)
            // Muzzle brake rings (team colour).
            fill(cg, x: 16, y: 3, w: 1, h: 2, color: palette.trimDark)
            fill(cg, x: 18, y: 3, w: 2, h: 2, color: palette.trim)
            fill(cg, x: 20, y: 3, w: 1, h: 2, color: outline)
            fill(cg, x: 20, y: 3, w: 1, h: 2, color: .black)
            // Mount foot.
            fill(cg, x: 2, y: 6, w: 5, h: 2, color: outline)
            fill(cg, x: 3, y: 7, w: 3, h: 1, color: metalD)
            _ = W
        }
    }
}

// MARK: - CGPoint helpers (file-local)

private func +(lhs: CGPoint, rhs: CGVector) -> CGPoint {
    CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
}
