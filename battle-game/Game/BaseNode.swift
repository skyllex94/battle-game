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

    /// Building height, matches the big HQ fortress sprite.
    static let baseHeight: CGFloat = 210
    /// Level 20+ Mk-II HQ fortress height (~25% taller + wider footprint).
    static let upgradedBaseHeight: CGFloat = 258
    /// Finale enemy core-fortress height (Level 35 Embral Core only): a
    /// huge Mordor-style main-main building, ~47% taller than the Mk-II
    /// citadel the allied HQ keeps on the same level.
    static let finaleBaseHeight: CGFloat = 380
    /// HP bar floats just above the roof (same spot as the old bars).
    private static let hpBarY: CGFloat = 232
    private static let upgradedHPBarY: CGFloat = 280
    private static let finaleHPBarY: CGFloat = 404

    let team: Team
    /// Level 20+ Mk-II refit: bigger armored citadel keep + quad-missile
    /// rooftop launcher battery.
    let upgraded: Bool
    /// Finale refit (enemy HQ on Level 35 only): the huge Mordor
    /// core-fortress with a 5-missile rooftop battery. The allied HQ on
    /// the same level stays Mk-II (`upgraded`, 4 missiles).
    let finale: Bool
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
    private let teamGlow: SKShapeNode

    private var phase: TimeInterval = 0
    private var gateFlash: CGFloat = 0   // 0..1, decays after a spawn
    private var muzzleFlash: CGFloat = 0 // 0..1, decays after a fan shot
    private var desiredAngle: CGFloat?   // nil = park toward mid
    private var destroyed = false
    /// Burning Eye + crown flame flicker on the finale core-fortress.
    private var eyeGlow: SKShapeNode?
    private var crownFlame: SKSpriteNode?

    /// Rest direction: both HQs face mid (player right, enemy left).
    private var homeAngle: CGFloat { team == .player ? 0 : .pi }

    // MARK: - Init

    init(team: Team, upgraded: Bool = false, finale: Bool = false) {
        self.team = team
        self.upgraded = upgraded
        // The finale core-fortress is enemy-only: a player-side finale
        // request still renders the Mk-II citadel (allied HQ keeps it).
        self.finale = finale && team == .enemy

        let palette = BaseNode.palette(for: team)
        let bodyTex = BaseNode.makeBodyTexture(palette: palette, upgraded: upgraded,
                                               finale: self.finale)
        bodyTex.filteringMode = .nearest
        bodySprite = SKSpriteNode(texture: bodyTex)
        let targetHeight = self.finale ? BaseNode.finaleBaseHeight
            : upgraded ? BaseNode.upgradedBaseHeight : BaseNode.baseHeight
        let bodyScale = targetHeight / bodyTex.size().height
        bodySprite.setScale(bodyScale)
        bodySprite.anchorPoint = CGPoint(x: 0.5, y: 0)

        let cannonTex = BaseNode.makeCannonTexture(palette: palette, upgraded: upgraded,
                                                   finale: self.finale)
        cannonTex.filteringMode = .nearest
        cannonSprite = SKSpriteNode(texture: cannonTex)
        // Pivot at the breech (left of the texture); barrel points +x.
        let breechX: CGFloat = self.finale ? 6.0 : upgraded ? 6.0 : 4.0
        cannonSprite.anchorPoint = CGPoint(x: breechX / cannonTex.size().width, y: 0.5)

        // Gate glow sits inside the arch; sized in points after scaling.
        gateGlow = SKShapeNode(ellipseOf: CGSize(width: self.finale ? 60 : upgraded ? 44 : 36,
                                                 height: self.finale ? 100 : upgraded ? 72 : 62))
        gateLightL = SKShapeNode(circleOfRadius: self.finale ? 7 : 5)
        gateLightR = SKShapeNode(circleOfRadius: self.finale ? 7 : 5)
        beacon = SKShapeNode(circleOfRadius: self.finale ? 8 : upgraded ? 6 : 5)
        teamGlow = SKShapeNode(circleOfRadius: self.finale ? 155 : upgraded ? 120 : 95)

        super.init()

        name = team == .player ? "playerBase" : "enemyBase"
        zPosition = 5

        // Team ground wash so home turf reads at a glance.
        teamGlow.fillColor = palette.glow
        teamGlow.strokeColor = .clear
        teamGlow.alpha = 0.20
        teamGlow.position = CGPoint(x: 0, y: 16)
        teamGlow.zPosition = -2
        addChild(teamGlow)

        // Wide drop shadow for 2.5D grounding (child so it leaves with the HQ).
        let shadow = SKShapeNode(ellipseOf: CGSize(width: finale ? 470 : upgraded ? 348 : 290,
                                                   height: finale ? 36 : upgraded ? 28 : 24))
        shadow.fillColor = SKColor(white: 0, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 6)
        shadow.zPosition = -3
        addChild(shadow)

        bodySprite.position = .zero
        bodySprite.zPosition = 0
        addChild(bodySprite)

        // Energy glow inside the gate arch (flickers; flashes on spawn).
        // Gate opening rows 27-38 (classic), 33-46 (Mk-II) or 44-58 (finale).
        let gateLocal = CGPoint(x: 0, y: finale ? 100 : upgraded ? 64 : 55)
        gateGlow.fillColor = palette.gate
        gateGlow.strokeColor = .clear
        gateGlow.alpha = 0.55
        gateGlow.position = gateLocal
        gateGlow.zPosition = 1
        addChild(gateGlow)

        // Gate side lamps.
        let lampDX: CGFloat = finale ? 46 : upgraded ? 34 : 28
        gateLightL.fillColor = palette.beacon
        gateLightL.strokeColor = .clear
        gateLightL.position = gateLocal + CGVector(dx: -lampDX, dy: 6)
        gateLightL.zPosition = 2
        addChild(gateLightL)
        gateLightR.fillColor = palette.beacon
        gateLightR.strokeColor = .clear
        gateLightR.position = gateLocal + CGVector(dx: lampDX, dy: 6)
        gateLightR.zPosition = 2
        addChild(gateLightR)

        // Roof cannon / quad-missile pod on a traversing pivot (turret-style,
        // like TowerNode). Barrel points +x in texture space; the pivot steers
        // it at targets.
        let cannonScale: CGFloat = finale ? 4.2 : 3.6
        cannonSprite.setScale(cannonScale)
        cannonSprite.position = .zero
        cannonPivot.position = CGPoint(x: facing * (finale ? 32 : upgraded ? 24 : 20),
                                       y: finale ? 318 : upgraded ? 208 : 170)
        cannonPivot.zRotation = homeAngle
        cannonPivot.zPosition = 2
        cannonPivot.addChild(cannonSprite)
        addChild(cannonPivot)

        // Muzzle at the barrel/pod tip in texture space.
        let muzzleTipX: CGFloat = finale ? 32 : upgraded ? 22 : 18
        muzzleSocket.position = CGPoint(x: muzzleTipX * cannonScale, y: 0)
        cannonPivot.addChild(muzzleSocket)

        // Antenna beacon on the mast (the finale Eye replaces the mast
        // lamp: the beacon still rides the crown as a hot ember).
        beacon.fillColor = palette.beacon
        beacon.strokeColor = .clear
        beacon.position = CGPoint(x: finale ? 0 : upgraded ? 0 : -2,
                                  y: finale ? 372 : upgraded ? 264 : 220)
        beacon.zPosition = 2
        addChild(beacon)

        // Finale Burning Eye: a hot ember slit that breathes over the
        // crown (child so it leaves with the HQ).
        if finale {
            let eye = SKShapeNode(ellipseOf: CGSize(width: 46, height: 20))
            eye.fillColor = SKColor(red: 1.0, green: 0.30, blue: 0.08, alpha: 1)
            eye.strokeColor = SKColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1)
            eye.lineWidth = 2
            eye.position = CGPoint(x: 0, y: 336)
            eye.zPosition = 3
            addChild(eye)
            eyeGlow = eye
            let pupil = SKShapeNode(ellipseOf: CGSize(width: 12, height: 14))
            pupil.fillColor = SKColor(red: 0.35, green: 0.02, blue: 0.02, alpha: 1)
            pupil.strokeColor = .clear
            eye.addChild(pupil)
            let flameTex = BaseNode.eyeFlameTexture()
            flameTex.filteringMode = .nearest
            let flame = SKSpriteNode(texture: flameTex)
            flame.setScale(4.0)
            flame.position = CGPoint(x: 0, y: 352)
            flame.zPosition = 3
            addChild(flame)
            crownFlame = flame
        }

        buildHPBar(palette: palette)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Static pixel-art portrait of the in-battle HQ (procedural citadel +
    /// rooftop turret). Cached for SwiftUI intel cards.
    static func previewImage(for team: Team, upgraded: Bool = false,
                             finale: Bool = false) -> UIImage {
        let fin = finale && team == .enemy
        switch (team, upgraded, fin) {
        case (.player, false, _): return playerPreviewImage
        case (.enemy, false, false): return enemyPreviewImage
        case (.enemy, _, true): return enemyFinalePreviewImage
        case (.player, true, _): return playerUpgradedPreviewImage
        default: return enemyUpgradedPreviewImage
        }
    }

    private static let playerPreviewImage = makePreviewImage(for: .player, upgraded: false)
    private static let enemyPreviewImage = makePreviewImage(for: .enemy, upgraded: false)
    private static let playerUpgradedPreviewImage = makePreviewImage(for: .player, upgraded: true)
    private static let enemyUpgradedPreviewImage = makePreviewImage(for: .enemy, upgraded: true)
    private static let enemyFinalePreviewImage = makePreviewImage(for: .enemy, upgraded: true,
                                                                  finale: true)

    private static func makePreviewImage(for team: Team, upgraded: Bool,
                                         finale: Bool = false) -> UIImage {
        let fin = finale && team == .enemy
        let palette = palette(for: team)
        let bodyImg = UIImage(cgImage: makeBodyTexture(palette: palette, upgraded: upgraded,
                                                       finale: fin).cgImage())
        let cannonImg = UIImage(cgImage: makeCannonTexture(palette: palette, upgraded: upgraded,
                                                           finale: fin).cgImage())

        let baseH: CGFloat = fin ? finaleBaseHeight : upgraded ? upgradedBaseHeight : baseHeight
        let baseW = baseH * bodyImg.size.width / bodyImg.size.height
        let cannonScale: CGFloat = fin ? 4.2 : 3.6
        let cannonW = cannonImg.size.width * cannonScale
        let cannonH = cannonImg.size.height * cannonScale
        let breechX: CGFloat = (fin ? 6.0 : upgraded ? 6.0 : 4.0) / cannonImg.size.width * cannonW
        let mountY: CGFloat = fin ? 318 : upgraded ? 208 : 170
        let mountDX: CGFloat = (team == .player ? 1 : -1) * (fin ? 32 : upgraded ? 24 : 20)
        let groundInset: CGFloat = 8
        let width = baseW + 24
        let height = baseH + groundInset + 16
        let groundY = height - groundInset
        let centerX = width / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height),
                                       format: format).image { ctx in
            let cg = ctx.cgContext
            cg.interpolationQuality = .none
            bodyImg.draw(in: CGRect(x: (width - baseW) / 2,
                                    y: groundY - baseH,
                                    width: baseW, height: baseH))
            cg.saveGState()
            cg.translateBy(x: centerX + mountDX, y: groundY - mountY)
            if team == .enemy { cg.rotate(by: .pi) }
            cannonImg.draw(in: CGRect(x: -breechX, y: -cannonH / 2,
                                      width: cannonW, height: cannonH))
            cg.restoreGState()
        }
    }

    // MARK: - Per-frame

    /// Beacon blink + gate flicker + flash decay + turret traverse.
    /// Called every frame.
    func update(dt: TimeInterval) {
        guard !destroyed else { return }
        phase += dt
        beacon.alpha = 0.6 + 0.4 * sin(phase * 5)
        if let eye = eyeGlow {
            eye.alpha = 0.75 + 0.25 * sin(phase * 3.1)
            eye.setScale(1 + 0.06 * sin(phase * 3.1))
        }
        if let flame = crownFlame {
            flame.alpha = 0.7 + 0.3 * sin(phase * 9.0)
        }
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
        eyeGlow?.isHidden = true
        crownFlame?.isHidden = true
        teamGlow.alpha = 0.05
        hpFill.isHidden = true
        hpBG.alpha = 0.25
        if let parent = parent {
            StructureFX.explode(at: position, in: parent, team: team,
                                size: finale ? BaseNode.finaleBaseHeight
                                    : upgraded ? BaseNode.upgradedBaseHeight : BaseNode.baseHeight)
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
        let w: CGFloat = finale ? 250 : upgraded ? 190 : 160, h: CGFloat = finale ? 14 : 12
        let barY = finale ? BaseNode.finaleHPBarY
            : upgraded ? BaseNode.upgradedHPBarY : BaseNode.hpBarY
        hpBG.color = SKColor(white: 0, alpha: 0.65)
        hpBG.size = CGSize(width: w + 4, height: h + 4)
        hpBG.position = CGPoint(x: 0, y: barY)
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
        hpFill.position = CGPoint(x: -w / 2, y: barY)
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

    /// 56×44 grand HQ fortress: radar mast + dome + crenellated parapet,
    /// bannered keep, twin stepped side towers with pennants, arched
    /// spawn gate, riveted foundation. Row 0 = top.
    /// Gate arch centre x=28, opening rows 27-38.
    private static func makeBodyTexture(palette: Palette, upgraded: Bool,
                                        finale: Bool = false) -> SKTexture {
        if finale { return makeFinaleBodyTexture(palette: palette) }
        if upgraded { return makeUpgradedBodyTexture(palette: palette) }
        let W = 56, H = 44
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
            let stoneD = UIColor(red: 0.23, green: 0.25, blue: 0.31, alpha: 1)
            let stoneM = UIColor(red: 0.42, green: 0.45, blue: 0.52, alpha: 1)
            let stoneL = UIColor(red: 0.67, green: 0.70, blue: 0.77, alpha: 1)
            let mortar = UIColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1)
            let dark = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1)
            let warn = UIColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 1)
            let gateDark = UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1)
            let gold = UIColor(red: 0.85, green: 0.72, blue: 0.35, alpha: 1)

            // Silhouette spans per row (x-ranges of solid building).
            func spans(at row: Int) -> [(Int, Int)] {
                switch row {
                case 0: return [(27, 28)]                 // mast tip
                case 1: return [(24, 31)]                 // radar bar
                case 2: return [(27, 28)]                 // mast
                case 3: return [(24, 31)]                 // dome crown
                case 4: return [(22, 33)]                 // dome
                case 5: return [(21, 34)]                 // dome
                case 6: return [(20, 35)]                 // dome foot
                case 7: return [(20, 35)]                 // dome ring
                case 8: return [(19, 36)]                 // parapet base
                case 9: return [(19, 36)]                 // merlons
                case 10: return [(19, 36)]                // keep top
                case 11: return [(19, 36), (6, 11), (44, 49)]   // banner + tower tips
                case 12: return [(19, 36), (5, 12), (43, 50)]
                case 13: return [(19, 36), (4, 13), (42, 51)]
                case 14: return [(19, 36), (3, 14), (41, 52)]   // roofs widen
                case 15: return [(19, 36), (2, 15), (40, 53)]   // tower caps
                case 16: return [(19, 36), (2, 15), (40, 53)]   // tower merlons
                case 17..<38: return [(2, 15), (19, 36), (40, 53)] // towers + keep
                case 38..<43: return [(1, 54)]            // foundation
                case 43: return [(0, 55)]                 // ground skirt
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
            fill(cg, x: 27, y: 0, w: 2, h: 3, color: dark)
            fill(cg, x: 27, y: 0, w: 2, h: 1, color: palette.trim)
            fill(cg, x: 24, y: 1, w: 8, h: 1, color: stoneM)
            fill(cg, x: 24, y: 1, w: 2, h: 1, color: palette.trim)
            fill(cg, x: 30, y: 1, w: 2, h: 1, color: palette.trim)
            // Dome shading: bright crown + team ring at its foot.
            fill(cg, x: 25, y: 3, w: 6, h: 1, color: stoneL)
            fill(cg, x: 23, y: 3, w: 2, h: 1, color: .white.withAlphaComponent(0.6))
            fill(cg, x: 20, y: 6, w: 16, h: 1, color: palette.trimDark)
            fill(cg, x: 21, y: 5, w: 14, h: 1, color: palette.trim)

            // Crenellated parapet: lit top edge (row 8) + merlon blocks (row 9).
            fill(cg, x: 19, y: 8, w: 18, h: 1, color: stoneL)
            var mx = 19
            while mx < 37 {
                fill(cg, x: mx + 2, y: 9, w: 2, h: 1, color: dark) // crenel gaps
                mx += 4
            }

            // Team banner band across the keep (rows 11-13) + chevron emblem.
            fill(cg, x: 19, y: 11, w: 18, h: 1, color: palette.trimDark)
            fill(cg, x: 19, y: 12, w: 18, h: 2, color: palette.trim)
            fill(cg, x: 19, y: 14, w: 18, h: 1, color: palette.trimDark)
            fill(cg, x: 19, y: 12, w: 2, h: 2, color: .white.withAlphaComponent(0.35))
            fill(cg, x: 27, y: 12, w: 3, h: 1, color: .white)
            fill(cg, x: 28, y: 12, w: 1, h: 2, color: .white)

            // Brick mortar courses on the keep.
            for row in [17, 24, 32] {
                fill(cg, x: 20, y: row, w: 16, h: 1, color: mortar)
            }
            // Keep arrow slits (lit, team-tinted) flanking the banner/gate.
            for (sx, sy) in [(21, 16), (33, 16), (21, 26), (33, 26)] {
                fill(cg, x: sx, y: sy, w: 2, h: 4, color: outline)
                fill(cg, x: sx, y: sy + 1, w: 2, h: 2, color: palette.trimDark)
                fill(cg, x: sx, y: sy + 1, w: 2, h: 1, color: .white.withAlphaComponent(0.7))
            }

            // Twin stepped tower roofs: team-coloured tiers, gold finials.
            for (tx0, tx1) in [(6, 11), (44, 49)] {          // row 11 tips
                fill(cg, x: tx0, y: 11, w: tx1 - tx0 + 1, h: 1, color: gold)
            }
            for (tx0, tx1) in [(5, 12), (43, 50)] {
                fill(cg, x: tx0, y: 12, w: tx1 - tx0 + 1, h: 1, color: palette.trim)
            }
            for (tx0, tx1) in [(4, 13), (42, 51)] {
                fill(cg, x: tx0, y: 13, w: tx1 - tx0 + 1, h: 1, color: palette.trimDark)
            }
            for (tx0, tx1) in [(3, 14), (41, 52)] {
                fill(cg, x: tx0, y: 14, w: tx1 - tx0 + 1, h: 1, color: palette.trim)
            }
            // Tower caps: lit top + team band + crenels.
            for (bx, _) in [(2, 0), (40, 0)] {
                fill(cg, x: bx, y: 15, w: 14, h: 1, color: stoneL)
                fill(cg, x: bx, y: 16, w: 14, h: 1, color: palette.trim)
                fill(cg, x: bx + 1, y: 15, w: 1, h: 1, color: dark)
                fill(cg, x: bx + 6, y: 15, w: 1, h: 1, color: dark)
                fill(cg, x: bx + 12, y: 15, w: 1, h: 1, color: dark)
            }
            // Tower pennants: poles + team flags flying outward.
            fill(cg, x: 9, y: 7, w: 1, h: 4, color: dark)
            fill(cg, x: 4, y: 7, w: 5, h: 1, color: palette.trim)
            fill(cg, x: 5, y: 8, w: 4, h: 1, color: palette.trimDark)
            fill(cg, x: 46, y: 7, w: 1, h: 4, color: dark)
            fill(cg, x: 47, y: 7, w: 5, h: 1, color: palette.trim)
            fill(cg, x: 47, y: 8, w: 4, h: 1, color: palette.trimDark)
            // Tower windows: lit slits.
            for wx in [7, 45] {
                fill(cg, x: wx, y: 21, w: 4, h: 4, color: outline)
                fill(cg, x: wx + 1, y: 22, w: 2, h: 2, color: palette.trimDark)
                fill(cg, x: wx + 1, y: 22, w: 2, h: 1, color: .white.withAlphaComponent(0.7))
                fill(cg, x: wx, y: 28, w: 4, h: 3, color: outline)
                fill(cg, x: wx + 1, y: 28, w: 2, h: 2, color: stoneD)
            }

            // Spawn gate arch: opening x25-30, rows 27-38.
            fill(cg, x: 24, y: 26, w: 10, h: 13, color: outline)
            fill(cg, x: 25, y: 27, w: 8, h: 12, color: gateDark)
            // Inner energy field (the glow node animates over this).
            fill(cg, x: 26, y: 28, w: 6, h: 10, color: palette.trimDark)
            fill(cg, x: 27, y: 29, w: 4, h: 8, color: palette.trim)
            fill(cg, x: 28, y: 30, w: 2, h: 6, color: .white.withAlphaComponent(0.8))
            // Door shutter teeth top + bottom (half-open).
            for sx in 25..<31 {
                fill(cg, x: sx, y: 27, w: 1, h: 2, color: dark)
                fill(cg, x: sx, y: 37, w: 1, h: 2, color: dark)
            }
            // Arch pillars: lit left, shaded right.
            fill(cg, x: 23, y: 26, w: 1, h: 13, color: stoneL)
            fill(cg, x: 32, y: 26, w: 1, h: 13, color: stoneD)
            // Hazard chevrons + keystone ABOVE the gate.
            var hx = 23
            var flip = false
            while hx < 31 {
                fill(cg, x: hx, y: 24, w: 2, h: 2, color: flip ? warn : dark)
                hx += 2
                flip.toggle()
            }
            fill(cg, x: 28, y: 23, w: 2, h: 1, color: warn)

            // Foundation block (rows 38-43): lit top edge, dark body, rivets.
            fill(cg, x: 1, y: 38, w: 54, h: 1, color: stoneL)
            fill(cg, x: 1, y: 39, w: 54, h: 3, color: stoneD)
            fill(cg, x: 0, y: 43, w: 56, h: 1, color: outline)
            for rx in [4, 12, 20, 34, 42, 50] {
                fill(cg, x: rx, y: 39, w: 1, h: 1, color: stoneL)
            }
            _ = W
        }
    }

    /// 68×54 Mk-II grand armored citadel HQ (Level 20+):
    /// - Twin command spires + central radar mast & armored citadel dome.
    /// - Towering armored steel keep with team war-frieze, glowing energy
    ///   core matrix, and heavy bolted plate seams.
    /// - Inner tall bastion towers with gold finials, team pennants, and
    ///   glowing slits, plus outer heavy casemate sponsons with hazard trim.
    /// - Grand reinforced spawn portal (centre x=34, rows 33-46) and a
    ///   wide double-plated foundation slab.
    private static func makeUpgradedBodyTexture(palette: Palette) -> SKTexture {
        let W = 68, H = 54
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.07, green: 0.05, blue: 0.08, alpha: 1)
            let plateD = UIColor(red: 0.16, green: 0.17, blue: 0.23, alpha: 1)
            let plateM = UIColor(red: 0.33, green: 0.35, blue: 0.43, alpha: 1)
            let plateL = UIColor(red: 0.60, green: 0.64, blue: 0.74, alpha: 1)
            let steel = UIColor(red: 0.22, green: 0.24, blue: 0.31, alpha: 1)
            let dark = UIColor(red: 0.09, green: 0.09, blue: 0.13, alpha: 1)
            let warn = UIColor(red: 0.95, green: 0.72, blue: 0.18, alpha: 1)
            let gateDark = UIColor(red: 0.04, green: 0.06, blue: 0.09, alpha: 1)
            let gold = UIColor(red: 0.92, green: 0.78, blue: 0.36, alpha: 1)

            // Silhouette spans per row: central keep (21..46), inner bastion
            // towers (8..19, 48..59), outer armored sponsons (2..7, 60..65).
            func spans(at row: Int) -> [(Int, Int)] {
                switch row {
                case 0: return [(33, 34)]                               // central mast tip
                case 1: return [(29, 38)]                               // upper radar crossbar
                case 2: return [(25, 26), (33, 34), (41, 42)]           // twin spires + mast
                case 3: return [(25, 42)]                               // command crown
                case 4: return [(23, 44)]                               // armored dome upper
                case 5: return [(22, 45)]                               // armored dome mid
                case 6: return [(21, 46)]                               // armored dome base
                case 7: return [(21, 46)]                               // dome energy collar
                case 8: return [(20, 47)]                               // upper parapet deck
                case 9: return [(20, 47), (12, 15), (52, 55)]           // parapet + tower finials
                case 10: return [(20, 47), (11, 16), (51, 56)]
                case 11: return [(20, 47), (10, 17), (50, 57)]
                case 12: return [(20, 47), (9, 18), (49, 58)]
                case 13, 14: return [(20, 47), (8, 19), (48, 59)]       // tower caps + merlons
                case 15..<23: return [(8, 19), (20, 47), (48, 59)]      // upper towers + keep
                case 23: return [(4, 7), (8, 19), (20, 47), (48, 59), (60, 63)] // sponson roofs
                case 24: return [(3, 7), (8, 19), (20, 47), (48, 59), (60, 64)]
                case 25..<46: return [(2, 19), (20, 47), (48, 65)]      // full fortress body
                case 46..<53: return [(1, 66)]                          // heavy foundation slab
                case 53: return [(0, 67)]                               // ground skirt
                default: return []
                }
            }

            for row in 0..<H {
                for (x0, x1) in spans(at: row) {
                    fill(cg, x: x0, y: row, w: x1 - x0 + 1, h: 1, color: outline)
                    let innerW = x1 - x0 - 1
                    if innerW > 0 {
                        fill(cg, x: x0 + 1, y: row, w: min(3, innerW), h: 1, color: plateL)
                        fill(cg, x: x0 + 4, y: row, w: max(0, innerW - 6), h: 1, color: plateM)
                        fill(cg, x: max(x0 + 1, x1 - 2), y: row, w: min(2, innerW), h: 1, color: plateD)
                    }
                }
            }

            // Central radar array + twin command spires.
            fill(cg, x: 33, y: 0, w: 2, h: 3, color: dark)
            fill(cg, x: 33, y: 0, w: 2, h: 1, color: palette.trim)
            fill(cg, x: 29, y: 1, w: 10, h: 1, color: plateL)
            fill(cg, x: 29, y: 1, w: 2, h: 1, color: palette.trim)
            fill(cg, x: 37, y: 1, w: 2, h: 1, color: palette.trim)
            fill(cg, x: 25, y: 2, w: 2, h: 1, color: gold)
            fill(cg, x: 41, y: 2, w: 2, h: 1, color: gold)

            // Armored citadel dome: bright steel crown + glowing visor band.
            fill(cg, x: 27, y: 3, w: 14, h: 1, color: plateL)
            fill(cg, x: 25, y: 4, w: 4, h: 1, color: .white.withAlphaComponent(0.65))
            fill(cg, x: 22, y: 6, w: 24, h: 2, color: palette.trimDark)
            fill(cg, x: 23, y: 6, w: 22, h: 1, color: palette.trim)
            fill(cg, x: 28, y: 6, w: 12, h: 1, color: .white.withAlphaComponent(0.75))

            // Upper missile parapet: heavy steel lip + crenel notches.
            fill(cg, x: 20, y: 8, w: 28, h: 1, color: plateL)
            fill(cg, x: 20, y: 10, w: 28, h: 1, color: palette.trim)
            for cx in stride(from: 22, to: 46, by: 4) {
                fill(cg, x: cx, y: 9, w: 2, h: 1, color: dark)
            }

            // Keep war-banner frieze (rows 12-16) + gold-trimmed command star.
            fill(cg, x: 21, y: 12, w: 26, h: 1, color: palette.trimDark)
            fill(cg, x: 21, y: 13, w: 26, h: 3, color: palette.trim)
            fill(cg, x: 21, y: 16, w: 26, h: 1, color: palette.trimDark)
            fill(cg, x: 21, y: 13, w: 3, h: 3, color: .white.withAlphaComponent(0.35))
            fill(cg, x: 31, y: 14, w: 6, h: 1, color: gold)
            fill(cg, x: 32, y: 13, w: 4, h: 3, color: .white)
            fill(cg, x: 33, y: 12, w: 2, h: 5, color: .white)

            // Riveted horizontal armor seams across the central keep.
            for row in [19, 26, 31] {
                fill(cg, x: 21, y: row, w: 26, h: 1, color: dark)
                for rx in stride(from: 23, to: 46, by: 4) {
                    fill(cg, x: rx, y: row + 1, w: 1, h: 1, color: plateL)
                }
            }

            // Glowing reactor core matrix above the gate (rows 21-25) +
            // flanking vertical plasma conduits.
            fill(cg, x: 28, y: 20, w: 12, h: 6, color: outline)
            fill(cg, x: 29, y: 21, w: 10, h: 4, color: palette.trimDark)
            fill(cg, x: 30, y: 21, w: 8, h: 3, color: palette.trim)
            fill(cg, x: 31, y: 22, w: 6, h: 1, color: .white)
            for sx in [23, 43] {
                fill(cg, x: sx, y: 18, w: 2, h: 12, color: outline)
                fill(cg, x: sx, y: 19, w: 2, h: 10, color: palette.trimDark)
                fill(cg, x: sx, y: 19, w: 1, h: 10, color: palette.trim)
            }

            // Inner bastion towers (x: 8..19 and 48..59): stepped roofs,
            // gold finials, team pennants, and armored slits.
            for (tx0, tx1) in [(12, 15), (52, 55)] {
                fill(cg, x: tx0, y: 9, w: tx1 - tx0 + 1, h: 1, color: gold)
            }
            for (tx0, tx1) in [(11, 16), (51, 56)] {
                fill(cg, x: tx0, y: 10, w: tx1 - tx0 + 1, h: 1, color: palette.trim)
            }
            for (tx0, tx1) in [(10, 17), (50, 57)] {
                fill(cg, x: tx0, y: 11, w: tx1 - tx0 + 1, h: 1, color: palette.trimDark)
            }
            for (tx0, tx1) in [(9, 18), (49, 58)] {
                fill(cg, x: tx0, y: 12, w: tx1 - tx0 + 1, h: 1, color: palette.trim)
            }
            for bx in [8, 48] {
                fill(cg, x: bx, y: 13, w: 12, h: 1, color: plateL)
                fill(cg, x: bx, y: 14, w: 12, h: 1, color: palette.trim)
                for cx in [bx + 2, bx + 6, bx + 9] {
                    fill(cg, x: cx, y: 13, w: 1, h: 1, color: dark)
                }
                // Bastion armor seams + glowing slits.
                for seamY in [22, 30, 38] {
                    fill(cg, x: bx + 1, y: seamY, w: 10, h: 1, color: dark)
                }
                fill(cg, x: bx + 4, y: 17, w: 4, h: 4, color: outline)
                fill(cg, x: bx + 5, y: 18, w: 2, h: 2, color: palette.trim)
                fill(cg, x: bx + 5, y: 18, w: 2, h: 1, color: .white)
                fill(cg, x: bx + 4, y: 25, w: 4, h: 4, color: outline)
                fill(cg, x: bx + 5, y: 26, w: 2, h: 2, color: palette.trimDark)
                fill(cg, x: bx + 4, y: 33, w: 4, h: 4, color: outline)
                fill(cg, x: bx + 5, y: 34, w: 2, h: 2, color: steel)
            }
            // Flying team pennants on the inner bastion peaks.
            fill(cg, x: 13, y: 5, w: 1, h: 4, color: dark)
            fill(cg, x: 7, y: 5, w: 6, h: 1, color: palette.trim)
            fill(cg, x: 8, y: 6, w: 5, h: 1, color: palette.trimDark)
            fill(cg, x: 54, y: 5, w: 1, h: 4, color: dark)
            fill(cg, x: 55, y: 5, w: 6, h: 1, color: palette.trim)
            fill(cg, x: 55, y: 6, w: 5, h: 1, color: palette.trimDark)

            // Outer armored casemate sponsons (x: 2..7 and 60..65, rows 23..45).
            for sx in [2, 60] {
                fill(cg, x: sx, y: 25, w: 6, h: 1, color: plateL)
                fill(cg, x: sx, y: 26, w: 6, h: 2, color: palette.trim)
                fill(cg, x: sx + 1, y: 30, w: 4, h: 6, color: outline)
                fill(cg, x: sx + 2, y: 31, w: 2, h: 4, color: palette.trimDark)
                fill(cg, x: sx + 2, y: 31, w: 2, h: 1, color: .white.withAlphaComponent(0.8))
                fill(cg, x: sx + 1, y: 39, w: 4, h: 4, color: dark)
            }

            // Grand reinforced spawn gate (centre x=34, rows 32-46).
            fill(cg, x: 28, y: 31, w: 12, h: 15, color: outline)
            fill(cg, x: 29, y: 32, w: 10, h: 14, color: gateDark)
            fill(cg, x: 30, y: 33, w: 8, h: 12, color: palette.trimDark)
            fill(cg, x: 31, y: 34, w: 6, h: 10, color: palette.trim)
            fill(cg, x: 32, y: 35, w: 4, h: 8, color: .white.withAlphaComponent(0.85))
            for gx in 29..<39 {
                fill(cg, x: gx, y: 32, w: 1, h: 2, color: dark)
                fill(cg, x: gx, y: 44, w: 1, h: 2, color: dark)
            }
            // Heavy blast pillars flanking the gate.
            fill(cg, x: 26, y: 31, w: 2, h: 15, color: plateL)
            fill(cg, x: 40, y: 31, w: 2, h: 15, color: plateD)
            // Hazard chevron lintel above the gate (rows 28-29).
            var hx = 26
            var flip = false
            while hx < 42 {
                fill(cg, x: hx, y: 28, w: 2, h: 2, color: flip ? warn : dark)
                hx += 2
                flip.toggle()
            }
            fill(cg, x: 33, y: 27, w: 2, h: 1, color: gold)

            // Massive double-plated foundation (rows 46-53) with hazard strip.
            fill(cg, x: 1, y: 46, w: 66, h: 1, color: plateL)
            fill(cg, x: 1, y: 47, w: 66, h: 2, color: steel)
            var fhx = 3
            var fFlip = false
            while fhx < 64 {
                fill(cg, x: fhx, y: 49, w: 2, h: 1, color: fFlip ? warn : dark)
                fhx += 2
                fFlip.toggle()
            }
            fill(cg, x: 1, y: 50, w: 66, h: 3, color: plateD)
            fill(cg, x: 0, y: 53, w: 68, h: 1, color: outline)
            for rx in stride(from: 4, to: 65, by: 6) {
                fill(cg, x: rx, y: 47, w: 1, h: 1, color: plateL)
                fill(cg, x: rx, y: 51, w: 1, h: 1, color: plateL)
            }
            _ = W
        }
    }

    /// 80×72 finale core-fortress (Level 35 enemy only): a huge Mordor-style
    /// main-main building — needle spire with the Burning Eye, jagged
    /// crown, tapering black tower with ember windows + lava seams, twin
    /// bastion wings with war-braziers, and a grand ember spawn gate.
    /// Row 0 = top. Gate arch centre x=40, opening rows 44-58.
    private static func makeFinaleBodyTexture(palette: Palette) -> SKTexture {
        let W = 80, H = 72
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.05, green: 0.03, blue: 0.05, alpha: 1)
            let rockD = UIColor(red: 0.12, green: 0.09, blue: 0.12, alpha: 1)
            let rockM = UIColor(red: 0.25, green: 0.18, blue: 0.20, alpha: 1)
            let rockL = UIColor(red: 0.48, green: 0.32, blue: 0.28, alpha: 1)
            let dark = UIColor(red: 0.07, green: 0.06, blue: 0.10, alpha: 1)
            let ember = UIColor(red: 1.0, green: 0.42, blue: 0.10, alpha: 1)
            let emberHot = UIColor(red: 1.0, green: 0.75, blue: 0.25, alpha: 1)
            let blood = UIColor(red: 0.65, green: 0.08, blue: 0.06, alpha: 1)
            let bloodDk = UIColor(red: 0.35, green: 0.05, blue: 0.05, alpha: 1)
            let gateDark = UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1)
            let gold = UIColor(red: 0.92, green: 0.78, blue: 0.36, alpha: 1)

            // Silhouette spans per row: needle spire (0-7), crown (8-12),
            // tapering black tower (13-59), bastion wings (17+), grand base.
            func spans(at row: Int) -> [(Int, Int)] {
                switch row {
                case 0: return [(39, 40)]
                case 1: return [(38, 41)]
                case 2: return [(36, 43)]
                case 3..<7: return [(35, 44)]
                case 7: return [(33, 46)]
                case 8: return [(29, 50)]
                case 9: return [(27, 52)]
                case 10: return [(29, 50)]
                case 11: return [(28, 51)]
                case 12: return [(28, 51)]
                case 13..<17: return [(28, 51)]
                case 17: return [(24, 25), (28, 51), (54, 55)]
                case 18: return [(23, 26), (28, 51), (53, 56)]
                case 19: return [(22, 27), (28, 51), (52, 57)]
                case 20: return [(21, 28), (28, 51), (51, 58)]
                case 21, 22: return [(20, 29), (28, 51), (50, 59)]
                case 23: return [(12, 17), (20, 29), (28, 51), (50, 59), (62, 67)]
                case 24: return [(10, 17), (20, 29), (28, 51), (50, 59), (62, 69)]
                case 25..<44: return [(8, 29), (28, 51), (50, 71)]
                case 44..<60: return [(6, 31), (28, 51), (48, 73)]
                case 60..<70: return [(3, 76)]
                case 70: return [(1, 78)]
                case 71: return [(0, 79)]
                default: return []
                }
            }

            for row in 0..<H {
                for (x0, x1) in spans(at: row) {
                    fill(cg, x: x0, y: row, w: x1 - x0 + 1, h: 1, color: outline)
                    let innerW = x1 - x0 - 1
                    if innerW > 0 {
                        fill(cg, x: x0 + 1, y: row, w: min(3, innerW), h: 1, color: rockL)
                        fill(cg, x: x0 + 4, y: row, w: max(0, innerW - 6), h: 1, color: rockM)
                        fill(cg, x: max(x0 + 1, x1 - 2), y: row, w: min(2, innerW), h: 1, color: rockD)
                    }
                }
            }

            // Needle spire: dark needle with ember tip.
            fill(cg, x: 39, y: 0, w: 2, h: 2, color: emberHot)
            fill(cg, x: 38, y: 2, w: 4, h: 1, color: dark)

            // Burning Eye housing (rows 3-6): ember slit + dark pupil.
            fill(cg, x: 35, y: 3, w: 10, h: 4, color: dark)
            fill(cg, x: 36, y: 4, w: 8, h: 2, color: ember)
            fill(cg, x: 37, y: 4, w: 6, h: 1, color: emberHot)
            fill(cg, x: 39, y: 4, w: 2, h: 2, color: UIColor(red: 0.35, green: 0.02, blue: 0.02, alpha: 1))
            fill(cg, x: 33, y: 7, w: 14, h: 1, color: palette.trimDark)
            fill(cg, x: 34, y: 7, w: 12, h: 1, color: blood)

            // Jagged crown teeth (row 9): alternating fangs.
            for (tx, tall) in [(27, 1), (31, 2), (35, 1), (39, 2), (43, 1), (47, 2), (51, 1)] {
                fill(cg, x: tx, y: tall == 2 ? 8 : 9, w: 2, h: tall, color: rockL)
                fill(cg, x: tx, y: 8, w: 1, h: 1, color: emberHot)
            }
            // Crown war-band with skull studs.
            fill(cg, x: 28, y: 11, w: 24, h: 2, color: bloodDk)
            fill(cg, x: 28, y: 11, w: 24, h: 1, color: blood)
            for sx in stride(from: 30, to: 51, by: 5) {
                fill(cg, x: sx, y: 11, w: 2, h: 1, color: emberHot)
            }

            // Tower lava seams: vertical ember cracks down the black rock.
            for sx in [32, 40, 47] {
                for sy in stride(from: 15, to: 42, by: 4) {
                    fill(cg, x: sx, y: sy, w: 1, h: 3, color: ember)
                    fill(cg, x: sx, y: sy, w: 1, h: 1, color: emberHot)
                }
            }
            // Ember window slits flanking the seams.
            for (wx, wy) in [(30, 18), (48, 18), (30, 30), (48, 30), (30, 40), (48, 40)] {
                fill(cg, x: wx, y: wy, w: 2, h: 4, color: outline)
                fill(cg, x: wx, y: wy + 1, w: 2, h: 2, color: ember)
                fill(cg, x: wx, y: wy + 1, w: 2, h: 1, color: emberHot)
            }
            // Horizontal armor rings on the tower.
            for row in [24, 33, 41] {
                fill(cg, x: 29, y: row, w: 22, h: 1, color: dark)
                for rx in stride(from: 31, to: 50, by: 5) {
                    fill(cg, x: rx, y: row + 1, w: 1, h: 1, color: rockL)
                }
            }

            // Bastion wings: stepped roofs, gold fangs, pennants, braziers.
            for (tx0, tx1) in [(24, 25), (54, 55)] {
                fill(cg, x: tx0, y: 17, w: tx1 - tx0 + 1, h: 1, color: gold)
            }
            for (tx0, tx1) in [(23, 26), (53, 56)] {
                fill(cg, x: tx0, y: 18, w: tx1 - tx0 + 1, h: 1, color: blood)
            }
            for (tx0, tx1) in [(22, 27), (52, 57)] {
                fill(cg, x: tx0, y: 19, w: tx1 - tx0 + 1, h: 1, color: bloodDk)
            }
            for bx in [20, 50] {
                fill(cg, x: bx, y: 21, w: 10, h: 1, color: rockL)
                fill(cg, x: bx, y: 22, w: 10, h: 1, color: blood)
                for cx in [bx + 2, bx + 5, bx + 8] {
                    fill(cg, x: cx, y: 21, w: 1, h: 1, color: dark)
                }
                // Wing brazier flames burning on the bastions.
                fill(cg, x: bx + 4, y: 25, w: 3, h: 4, color: ember)
                fill(cg, x: bx + 4, y: 25, w: 3, h: 1, color: emberHot)
            }
            // Outer sponson war-frieze + hazard roots.
            for sx in [8, 62] {
                fill(cg, x: sx, y: 27, w: 9, h: 2, color: blood)
                fill(cg, x: sx, y: 29, w: 9, h: 1, color: bloodDk)
            }
            // Flying war pennants on the bastion peaks.
            fill(cg, x: 24, y: 13, w: 1, h: 4, color: dark)
            fill(cg, x: 18, y: 13, w: 6, h: 1, color: blood)
            fill(cg, x: 19, y: 14, w: 5, h: 1, color: bloodDk)
            fill(cg, x: 55, y: 13, w: 1, h: 4, color: dark)
            fill(cg, x: 56, y: 13, w: 6, h: 1, color: blood)
            fill(cg, x: 56, y: 14, w: 5, h: 1, color: bloodDk)

            // Grand ember spawn gate (centre x=40, rows 44-58).
            fill(cg, x: 34, y: 43, w: 13, h: 16, color: outline)
            fill(cg, x: 35, y: 44, w: 11, h: 15, color: gateDark)
            fill(cg, x: 36, y: 45, w: 9, h: 13, color: bloodDk)
            fill(cg, x: 37, y: 46, w: 7, h: 11, color: ember)
            fill(cg, x: 38, y: 47, w: 5, h: 9, color: emberHot)
            fill(cg, x: 39, y: 48, w: 3, h: 7, color: .white.withAlphaComponent(0.85))
            for gx in 35..<46 {
                fill(cg, x: gx, y: 44, w: 1, h: 2, color: dark)
                fill(cg, x: gx, y: 57, w: 1, h: 2, color: dark)
            }
            // Blast pillars flanking the gate.
            fill(cg, x: 32, y: 43, w: 2, h: 16, color: rockL)
            fill(cg, x: 46, y: 43, w: 2, h: 16, color: rockD)
            // Fanged lintel above the gate.
            var hx = 32
            var flip = false
            while hx < 48 {
                fill(cg, x: hx, y: 41, w: 2, h: 2, color: flip ? ember : dark)
                hx += 2
                flip.toggle()
            }
            fill(cg, x: 39, y: 40, w: 2, h: 1, color: gold)

            // Massive fused foundation (rows 60-71) with ember channel.
            fill(cg, x: 3, y: 60, w: 74, h: 1, color: rockL)
            fill(cg, x: 3, y: 61, w: 74, h: 2, color: rockD)
            for ex in stride(from: 6, to: 74, by: 8) {
                fill(cg, x: ex, y: 63, w: 4, h: 1, color: ember)
                fill(cg, x: ex, y: 63, w: 1, h: 1, color: emberHot)
            }
            fill(cg, x: 3, y: 64, w: 74, h: 5, color: rockD)
            var fhx = 5
            var fFlip = false
            while fhx < 75 {
                fill(cg, x: fhx, y: 69, w: 2, h: 1, color: fFlip ? ember : dark)
                fhx += 2
                fFlip.toggle()
            }
            fill(cg, x: 1, y: 70, w: 78, h: 1, color: rockD)
            fill(cg, x: 0, y: 71, w: 80, h: 1, color: outline)
            for rx in stride(from: 6, to: 75, by: 7) {
                fill(cg, x: rx, y: 61, w: 1, h: 1, color: rockL)
                fill(cg, x: rx, y: 65, w: 1, h: 1, color: rockL)
            }
            _ = W
        }
    }

    /// 6×6 crown-flame sprite for the finale Eye beacon.
    private static func eyeFlameTexture() -> SKTexture {
        pixelTexture(w: 6, h: 6) { cg in
            let ember = UIColor(red: 1.0, green: 0.45, blue: 0.10, alpha: 1)
            let hot = UIColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1)
            fill(cg, x: 2, y: 0, w: 2, h: 6, color: ember)
            fill(cg, x: 2, y: 0, w: 2, h: 2, color: hot)
            fill(cg, x: 1, y: 3, w: 4, h: 2, color: ember)
            fill(cg, x: 0, y: 4, w: 6, h: 1, color: hot)
        }
    }

    /// 22×8 roof cannon (or 28×16 quad-missile pod on Mk-II HQs), barrel
    /// pointing +x.
    private static func makeCannonTexture(palette: Palette, upgraded: Bool,
                                          finale: Bool = false) -> SKTexture {
        if finale { return makeFinaleCannonTexture(palette: palette) }
        if upgraded { return makeUpgradedCannonTexture(palette: palette) }
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

    /// 28×16 Mk-II rooftop quad-missile launcher battery, pointing +x.
    /// Vertically symmetric housing with upper + lower twin rocket pods
    /// (4 visible warhead tips) flanking a central targeter barrel.
    private static func makeUpgradedCannonTexture(palette: Palette) -> SKTexture {
        let W = 28, H = 16
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.07, green: 0.05, blue: 0.08, alpha: 1)
            let metalD = UIColor(red: 0.16, green: 0.17, blue: 0.23, alpha: 1)
            let metalM = UIColor(red: 0.40, green: 0.43, blue: 0.52, alpha: 1)
            let metalL = UIColor(red: 0.72, green: 0.76, blue: 0.84, alpha: 1)
            let barrelD = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1)
            let warhead = UIColor(red: 1.0, green: 0.48, blue: 0.20, alpha: 1)

            // Central targeter rail: x 12..24, y 6..9.
            fill(cg, x: 12, y: 6, w: 13, h: 4, color: outline)
            fill(cg, x: 13, y: 7, w: 11, h: 2, color: barrelD)
            fill(cg, x: 13, y: 7, w: 11, h: 1, color: metalM)
            fill(cg, x: 20, y: 7, w: 2, h: 2, color: palette.trim)
            fill(cg, x: 23, y: 7, w: 1, h: 2, color: .black)

            // Armored breech housing: x 2..13, y 2..13.
            fill(cg, x: 2, y: 2, w: 12, h: 12, color: outline)
            fill(cg, x: 3, y: 3, w: 10, h: 10, color: metalM)
            fill(cg, x: 3, y: 3, w: 10, h: 1, color: metalL)
            fill(cg, x: 3, y: 12, w: 10, h: 1, color: metalD)
            fill(cg, x: 5, y: 5, w: 3, h: 6, color: palette.trim)
            fill(cg, x: 5, y: 5, w: 3, h: 1, color: .white.withAlphaComponent(0.65))
            fill(cg, x: 9, y: 7, w: 2, h: 2, color: .white)

            // Upper + lower twin missile-pod banks (rows 1..4 and 11..14)
            // with 4 glowing warhead tips at the front tubes.
            for bankY in [1, 11] {
                fill(cg, x: 4, y: bankY, w: 16, h: 4, color: outline)
                fill(cg, x: 5, y: bankY + 1, w: 14, h: 2, color: metalD)
                fill(cg, x: 5, y: bankY + 1, w: 14, h: 1, color: metalL)
                fill(cg, x: 7, y: bankY + 1, w: 3, h: 2, color: palette.trimDark)
                // Twin rocket tube mouths + warhead tips at x=18..19.
                fill(cg, x: 18, y: bankY + 1, w: 2, h: 2, color: barrelD)
                fill(cg, x: 19, y: bankY + 1, w: 1, h: 2, color: warhead)
            }
            // Rear exhaust vents.
            fill(cg, x: 0, y: 4, w: 3, h: 2, color: metalD)
            fill(cg, x: 0, y: 10, w: 3, h: 2, color: metalD)
            _ = W
        }
    }

    /// 34×20 finale 5-missile launcher battery, pointing +x. Five stacked
    /// rocket tubes ride out of an armored ember-trimmed housing — one
    /// glowing warhead tip per tube, five in a vertical row.
    private static func makeFinaleCannonTexture(palette: Palette) -> SKTexture {
        let W = 34, H = 20
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.06, green: 0.04, blue: 0.06, alpha: 1)
            let metalD = UIColor(red: 0.14, green: 0.14, blue: 0.20, alpha: 1)
            let metalM = UIColor(red: 0.38, green: 0.40, blue: 0.50, alpha: 1)
            let metalL = UIColor(red: 0.70, green: 0.74, blue: 0.83, alpha: 1)
            let barrelD = UIColor(red: 0.09, green: 0.09, blue: 0.13, alpha: 1)
            let warhead = UIColor(red: 1.0, green: 0.48, blue: 0.16, alpha: 1)
            let warheadHot = UIColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 1)

            // Armored breech housing: x 2..12, y 1..18.
            fill(cg, x: 2, y: 1, w: 11, h: 18, color: outline)
            fill(cg, x: 3, y: 2, w: 9, h: 16, color: metalM)
            fill(cg, x: 3, y: 2, w: 9, h: 1, color: metalL)
            fill(cg, x: 3, y: 17, w: 9, h: 1, color: metalD)
            fill(cg, x: 4, y: 4, w: 3, h: 12, color: palette.trim)
            fill(cg, x: 4, y: 4, w: 3, h: 1, color: .white.withAlphaComponent(0.65))
            fill(cg, x: 8, y: 9, w: 2, h: 2, color: .white)
            // Ember crown rail over the housing.
            fill(cg, x: 2, y: 0, w: 11, h: 1, color: warhead)
            fill(cg, x: 4, y: 0, w: 2, h: 1, color: warheadHot)

            // Five stacked tubes, one warhead tip each (rows 2/5/8/11/14).
            for tubeY in [2, 5, 8, 11, 14] {
                fill(cg, x: 12, y: tubeY, w: 20, h: 3, color: outline)
                fill(cg, x: 13, y: tubeY + 1, w: 18, h: 1, color: metalD)
                fill(cg, x: 13, y: tubeY, w: 18, h: 1, color: metalL)
                fill(cg, x: 15, y: tubeY, w: 3, h: 3, color: palette.trimDark)
                // Tube mouth + glowing warhead tip at x=30..31.
                fill(cg, x: 30, y: tubeY, w: 2, h: 3, color: barrelD)
                fill(cg, x: 30, y: tubeY + 1, w: 2, h: 1, color: warhead)
                fill(cg, x: 31, y: tubeY + 1, w: 1, h: 1, color: warheadHot)
            }
            // Rear exhaust vents.
            fill(cg, x: 0, y: 5, w: 3, h: 2, color: metalD)
            fill(cg, x: 0, y: 12, w: 3, h: 2, color: metalD)
            _ = W
        }
    }
}

// MARK: - CGPoint helpers (file-local)

private func +(lhs: CGPoint, rhs: CGVector) -> CGPoint {
    CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
}
