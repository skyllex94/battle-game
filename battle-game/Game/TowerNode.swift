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
    /// Mk-III siege tower (Level 31+): taller, bulkier — ~26% taller
    /// shell on a wider foundation, turret mounted higher.
    static let megaTowerHeight: CGFloat = 240
    static let megaMountHeight: CGFloat = 195
    private static let megaHpBarY: CGFloat = 255

    let team: Team
    /// Level 18+ Mk-II refit: heavier armor shell + missile-pod turret.
    let upgraded: Bool
    /// Level 31+ Mk-III siege refit: taller bulkier shell + quad-pod turret.
    /// Implies `upgraded` visually (Mk-III builds on the Mk-II shell).
    let mkIII: Bool

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

    init(team: Team, upgraded: Bool = false, mkIII: Bool = false) {
        self.team = team
        self.upgraded = upgraded || mkIII
        self.mkIII = mkIII

        let palette = TowerNode.palette(for: team)
        let baseTex = TowerNode.makeBaseTexture(palette: palette, upgraded: self.upgraded, mkIII: mkIII)
        baseTex.filteringMode = .nearest
        baseSprite = SKSpriteNode(texture: baseTex)
        let targetHeight = mkIII ? TowerNode.megaTowerHeight : TowerNode.towerHeight
        let baseScale = targetHeight / baseTex.size().height
        baseSprite.setScale(baseScale)
        baseSprite.anchorPoint = CGPoint(x: 0.5, y: 0)

        let headTex = TowerNode.makeHeadTexture(palette: palette, upgraded: self.upgraded, mkIII: mkIII)
        headTex.filteringMode = .nearest
        headSprite = SKSpriteNode(texture: headTex)
        // Housing centre sits ~7px from the left of the head texture
        // (Mk-III siege head pivots at x ≈ 8px).
        let pivotU: CGFloat = mkIII ? 8.0 / headTex.size().width : 7.0 / headTex.size().width
        headSprite.anchorPoint = CGPoint(x: pivotU, y: 0.5)

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

        // Turret mount (Mk-III sits higher on the taller shell).
        headPivot.position = CGPoint(x: 0, y: mkIII ? TowerNode.megaMountHeight : TowerNode.mountHeight)
        headPivot.zPosition = 2
        // Start parked toward home so the enemy tower doesn't open facing away.
        headPivot.zRotation = homeAngle
        addChild(headPivot)

        // Head visual scale: ~90pt barrel assembly (Mk-III siege head
        // runs slightly larger so the quad pods read at battle zoom).
        let headScale: CGFloat = mkIII ? 3.7 : 3.4
        headSprite.setScale(headScale)
        headSprite.position = .zero
        headPivot.addChild(headSprite)

        // Muzzle socket at the barrel tip (head-space x depends on variant).
        let tipX: CGFloat = mkIII ? 27 : (self.upgraded ? 22 : 19)
        muzzleSocket.position = CGPoint(x: tipX * headScale, y: 0)
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

    /// Hitbox size for projectile tests (matches the old ~124x195 box;
    /// Mk-III siege towers stand taller and wider).
    var hitSize: CGSize {
        mkIII ? CGSize(width: 150, height: 245) : CGSize(width: 124, height: 195)
    }

    /// Static pixel-art portrait of the in-battle tower (procedural base +
    /// turret). Enemy towers face left, matching their home angle. Cached
    /// because SwiftUI re-evaluates the intel card while the battle is paused.
    static func previewImage(for team: Team, upgraded: Bool = false, mkIII: Bool = false) -> UIImage {
        if mkIII {
            switch team {
            case .player: return playerMegaPreviewImage
            case .enemy: return enemyMegaPreviewImage
            default: return neutralMegaPreviewImage
            }
        }
        switch (team, upgraded) {
        case (.player, false): return playerPreviewImage
        case (.enemy, false): return enemyPreviewImage
        case (.neutral, false): return neutralPreviewImage
        case (.player, true): return playerUpgradedPreviewImage
        case (.enemy, true): return enemyUpgradedPreviewImage
        default: return neutralUpgradedPreviewImage
        }
    }

    private static let playerPreviewImage = makePreviewImage(for: .player)
    private static let enemyPreviewImage = makePreviewImage(for: .enemy)
    private static let neutralPreviewImage = makePreviewImage(for: .neutral)
    private static let playerUpgradedPreviewImage = makePreviewImage(for: .player, upgraded: true)
    private static let enemyUpgradedPreviewImage = makePreviewImage(for: .enemy, upgraded: true)
    private static let neutralUpgradedPreviewImage = makePreviewImage(for: .neutral, upgraded: true)
    private static let playerMegaPreviewImage = makePreviewImage(for: .player, upgraded: true, mkIII: true)
    private static let enemyMegaPreviewImage = makePreviewImage(for: .enemy, upgraded: true, mkIII: true)
    private static let neutralMegaPreviewImage = makePreviewImage(for: .neutral, upgraded: true, mkIII: true)

    private static func makePreviewImage(for team: Team, upgraded: Bool = false, mkIII: Bool = false) -> UIImage {
        let palette = palette(for: team)
        let baseImg = UIImage(cgImage: makeBaseTexture(palette: palette, upgraded: upgraded, mkIII: mkIII).cgImage())
        let headImg = UIImage(cgImage: makeHeadTexture(palette: palette, upgraded: upgraded, mkIII: mkIII).cgImage())

        let baseH: CGFloat = mkIII ? 240 : 190
        let baseW = baseH * baseImg.size.width / baseImg.size.height
        let headScale: CGFloat = mkIII ? 3.7 : 3.4
        let headW = headImg.size.width * headScale
        let headH = headImg.size.height * headScale
        let pivotU: CGFloat = mkIII ? 8.0 / headImg.size.width : 7.0 / headImg.size.width
        let pivotX = pivotU * headW
        let mountY: CGFloat = mkIII ? 195 : 150
        let groundInset: CGFloat = 8
        let width = max(baseW, headW) + 16
        let height = baseH + groundInset + 12
        let groundY = height - groundInset
        let centerX = width / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height),
                                       format: format).image { ctx in
            let cg = ctx.cgContext
            cg.interpolationQuality = .none
            baseImg.draw(in: CGRect(x: (width - baseW) / 2,
                                    y: groundY - baseH,
                                    width: baseW, height: baseH))
            cg.saveGState()
            cg.translateBy(x: centerX, y: groundY - mountY)
            if team == .enemy { cg.rotate(by: .pi) }
            headImg.draw(in: CGRect(x: -pivotX, y: -headH / 2,
                                    width: headW, height: headH))
            cg.restoreGState()
        }
    }

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
                                size: mkIII ? TowerNode.megaTowerHeight : TowerNode.towerHeight)
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

    /// Pinned above units (z=9) but below the hero (z=10): readable
    /// through marching armies, covered only by the hero passing by.
    private func buildHPBar(palette: Palette) {
        let w: CGFloat = mkIII ? 112 : 96, h: CGFloat = 12
        let barY = mkIII ? TowerNode.megaHpBarY : TowerNode.hpBarY
        hpBG.color = SKColor(white: 0, alpha: 0.65)
        hpBG.size = CGSize(width: w + 4, height: h + 4)
        hpBG.position = CGPoint(x: 0, y: barY)
        hpBG.zPosition = 9.2
        addChild(hpBG)
        // Pixel border ticks.
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

    /// 34×48 armored steel body (28×40 stone bunker): layered armor plates
    /// with bolted seams, corner buttress pylons, glowing team energy ring,
    /// watch mast on the deck, hazard strip and a wide riveted foundation.
    private static func makeUpgradedBaseTexture(palette: Palette) -> SKTexture {
        let W = 34, H = 48
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.07, green: 0.05, blue: 0.08, alpha: 1)
            let plateD = UIColor(red: 0.16, green: 0.17, blue: 0.23, alpha: 1)
            let plateM = UIColor(red: 0.33, green: 0.35, blue: 0.43, alpha: 1)
            let plateL = UIColor(red: 0.60, green: 0.64, blue: 0.74, alpha: 1)
            let steel = UIColor(red: 0.22, green: 0.24, blue: 0.31, alpha: 1)
            let dark = UIColor(red: 0.09, green: 0.09, blue: 0.13, alpha: 1)
            let warn = UIColor(red: 0.95, green: 0.72, blue: 0.18, alpha: 1)
            let cx = W / 2 // 17

            // Tapered armored shell: 20px turret deck -> 32px foundation.
            func halfWidth(at row: Int) -> Int {
                if row < 4 { return 10 }
                if row < 40 { return 10 + (row - 4) * 6 / 36 } // out to 11+
                return 16
            }

            // Body: outline + armor gradient per row.
            for row in 0..<H {
                let hw = halfWidth(at: row)
                fill(cg, x: cx - hw - 1, y: row, w: hw * 2 + 2, h: 1, color: outline)
                fill(cg, x: cx - hw, y: row, w: 3, h: 1, color: plateL)
                fill(cg, x: cx - hw + 3, y: row, w: hw * 2 - 6, h: 1, color: plateM)
                fill(cg, x: cx + hw - 3, y: row, w: 3, h: 1, color: plateD)
            }
            // Corner buttress pylons (full height, steel) at the flanks.
            for px in 2...3 {
                fill(cg, x: px, y: 10, w: 1, h: 26, color: steel)
                fill(cg, x: W - 4, y: 10, w: 1, h: 26, color: steel)
                fill(cg, x: W - 3, y: 14, w: 1, h: 22, color: plateD)
            }
            // Riveted armor seams every 8 rows.
            for row in stride(from: 9, to: 39, by: 8) {
                let hw = halfWidth(at: row)
                fill(cg, x: cx - hw, y: row, w: hw * 2, h: 2, color: dark)
                fill(cg, x: cx - hw, y: row, w: hw * 2, h: 1, color: plateD)
                for rx in stride(from: cx - hw + 2, to: cx + hw - 2, by: 5) {
                    fill(cg, x: rx, y: row + 2, w: 1, h: 1, color: plateL)
                    fill(cg, x: rx + 1, y: row + 2, w: 1, h: 1, color: dark)
                }
            }
            // Heavy top deck (rows 1-4): dark plate + rivets + team edge.
            fill(cg, x: cx - 10, y: 1, w: 20, h: 3, color: dark)
            fill(cg, x: cx - 10, y: 1, w: 20, h: 1, color: plateL)
            fill(cg, x: cx - 10, y: 4, w: 20, h: 1, color: palette.trim)
            for rx in [cx - 9, cx - 5, cx, cx + 4, cx + 8] {
                fill(cg, x: rx, y: 2, w: 1, h: 1, color: plateL)
            }
            // Watch mast on the deck (rows -): little radar pylon.
            fill(cg, x: cx + 6, y: 0, w: 1, h: 2, color: plateL)
            fill(cg, x: cx + 5, y: 0, w: 3, h: 1, color: plateM)
            // Team banner band (rows 6-10) with dark border + emblem.
            let hwB = halfWidth(at: 6)
            fill(cg, x: cx - hwB, y: 6, w: hwB * 2, h: 1, color: palette.trimDark)
            fill(cg, x: cx - hwB, y: 7, w: hwB * 2, h: 3, color: palette.trim)
            fill(cg, x: cx - hwB, y: 10, w: hwB * 2, h: 1, color: palette.trimDark)
            fill(cg, x: cx - hwB, y: 7, w: 2, h: 3, color: .white.withAlphaComponent(0.35))
            fill(cg, x: cx - 1, y: 8, w: 3, h: 1, color: .white)
            fill(cg, x: cx, y: 7, w: 1, h: 3, color: .white)
            // Glowing energy ring (rows 17-20): team cell behind a shield frame.
            let hwC = halfWidth(at: 18)
            fill(cg, x: cx - hwC + 1, y: 16, w: (hwC - 1) * 2, h: 6, color: outline)
            fill(cg, x: cx - hwC + 2, y: 17, w: (hwC - 2) * 2, h: 1, color: plateL)
            fill(cg, x: cx - hwC + 2, y: 19, w: (hwC - 2) * 2, h: 1, color: plateL)
            fill(cg, x: cx - 5, y: 17, w: 10, h: 4, color: palette.trimDark)
            fill(cg, x: cx - 4, y: 17, w: 8, h: 3, color: palette.trim)
            fill(cg, x: cx - 4, y: 17, w: 8, h: 1, color: .white)
            fill(cg, x: cx - 6, y: 16, w: 1, h: 6, color: palette.trimDark)
            fill(cg, x: cx + 5, y: 16, w: 1, h: 6, color: palette.trimDark)
            // Vented core slit rows 28-31: darker steel grill.
            fill(cg, x: cx - 4, y: 28, w: 8, h: 4, color: dark)
            for vx in stride(from: cx - 3, to: cx + 4, by: 2) {
                fill(cg, x: vx, y: 29, w: 1, h: 2, color: plateD)
            }
            // Hazard chevrons above the foundation (row 42).
            let hwH = halfWidth(at: 42)
            var hx = cx - hwH + 1
            var flip = false
            while hx < cx + hwH - 2 {
                fill(cg, x: hx, y: 42, w: 2, h: 2, color: flip ? warn : dark)
                hx += 2
                flip.toggle()
            }
            // Wide foundation block (rows 45-47).
            fill(cg, x: cx - 16, y: 44, w: 32, h: 1, color: plateL)
            fill(cg, x: cx - 16, y: 45, w: 32, h: 3, color: plateD)
            fill(cg, x: cx - 16, y: 47, w: 32, h: 1, color: outline)
            for rx in [cx - 13, cx - 6, cx + 1, cx + 7, cx + 12] {
                fill(cg, x: rx, y: 46, w: 1, h: 1, color: plateL)
            }
            // Right-side drop shadow strip for depth.
            fill(cg, x: cx + 12, y: 6, w: 2, h: 38, color: UIColor(white: 0, alpha: 0.25))
        }
    }

    /// 28×40 bunker: tapered stone body, brick courses, team banner,
    /// glowing core slit, riveted foundation cap and turret deck.
    private static func makeBaseTexture(palette: Palette, upgraded: Bool, mkIII: Bool = false) -> SKTexture {
        if mkIII { return makeMegaBaseTexture(palette: palette) }
        if upgraded { return makeUpgradedBaseTexture(palette: palette) }
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

    /// 28×12 turret head, barrel pointing +x. Housing is vertically
    /// symmetric so full 360° rotation still reads correctly.
    private static func makeHeadTexture(palette: Palette, upgraded: Bool, mkIII: Bool = false) -> SKTexture {
        if mkIII { return makeMegaHeadTexture(palette: palette) }
        if upgraded { return makeUpgradedHeadTexture(palette: palette) }
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

    /// Mk-II turret head (32×18), barrel pointing +x. Heavy housing with
    /// missile-pod banks above and below the barrel (kept vertically
    /// symmetric so 360° rotation still reads), twin muzzle brake, pod lip
    /// at the barrel root. Muzzle tip sits at x = 22.
    private static func makeUpgradedHeadTexture(palette: Palette) -> SKTexture {
        let W = 32, H = 18
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.07, green: 0.05, blue: 0.08, alpha: 1)
            let metalD = UIColor(red: 0.16, green: 0.17, blue: 0.23, alpha: 1)
            let metalM = UIColor(red: 0.40, green: 0.43, blue: 0.52, alpha: 1)
            let metalL = UIColor(red: 0.72, green: 0.76, blue: 0.84, alpha: 1)
            let barrelD = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1)
            let podD = UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)

            // Thick barrel: x 14..21, rows 7..10 (4px), highlight + shade.
            fill(cg, x: 14, y: 6, w: 9, h: 6, color: outline)
            fill(cg, x: 15, y: 7, w: 7, h: 4, color: barrelD)
            fill(cg, x: 15, y: 7, w: 7, h: 1, color: metalM)
            // Twin muzzle brake rings + muzzle mouth.
            fill(cg, x: 18, y: 7, w: 1, h: 4, color: palette.trimDark)
            fill(cg, x: 19, y: 7, w: 2, h: 4, color: palette.trim)
            fill(cg, x: 21, y: 7, w: 1, h: 4, color: outline)
            fill(cg, x: 21, y: 7, w: 1, h: 4, color: .black)

            // Heavy housing: x 2..13, rows 2..15.
            fill(cg, x: 2, y: 2, w: 12, h: 14, color: outline)
            fill(cg, x: 3, y: 3, w: 10, h: 12, color: metalM)
            fill(cg, x: 3, y: 3, w: 10, h: 1, color: metalL)   // top highlight
            fill(cg, x: 3, y: 14, w: 10, h: 1, color: metalD)  // bottom shade
            fill(cg, x: 3, y: 4, w: 1, h: 10, color: metalL)   // left light edge
            fill(cg, x: 12, y: 4, w: 1, h: 10, color: metalD)  // right shade
            // Team stripe across the housing + white sight dot.
            fill(cg, x: 5, y: 5, w: 2, h: 8, color: palette.trim)
            fill(cg, x: 5, y: 5, w: 2, h: 1, color: .white.withAlphaComponent(0.6))
            fill(cg, x: 9, y: 7, w: 2, h: 2, color: metalD)
            fill(cg, x: 9, y: 7, w: 2, h: 1, color: .white)
            // Pivot bolt.
            fill(cg, x: 6, y: 7, w: 3, h: 2, color: outline)
            fill(cg, x: 7, y: 7, w: 1, h: 2, color: metalL)

            // Missile-pod banks (above + below the housing, symmetric).
            for bankY: Int in [2, 13] {
                fill(cg, x: 3, y: bankY, w: 10, h: 2, color: podD)
                fill(cg, x: 3, y: bankY, w: 10, h: 1, color: metalD)
                // Team trim dot on the bank + tube mouths at the front lip.
                fill(cg, x: 4, y: bankY, w: 2, h: 1, color: palette.trim)
                for tx in [8, 11] {
                    let tubeY = bankY == 2 ? 4 : 11
                    fill(cg, x: tx, y: tubeY, w: 2, h: 2, color: barrelD)
                    fill(cg, x: tx + 1, y: bankY, w: 1, h: 1,
                         color: SKColor(red: 1.0, green: 0.45, blue: 0.2, alpha: 1))
                }
            }
            // Rear exhaust fins.
            fill(cg, x: 0, y: 5, w: 3, h: 2, color: metalD)
            fill(cg, x: 0, y: 11, w: 3, h: 2, color: metalD)
            _ = W
        }
    }

    // MARK: - Mk-III siege art (Level 31+)

    /// 40×58 siege shell: taller + bulkier than the Mk-II — wider tapered
    /// armor body on a double-step foundation, twin team banner bands,
    /// twin energy cells, taller watch mast and heavy hazard base.
    private static func makeMegaBaseTexture(palette: Palette) -> SKTexture {
        let W = 40, H = 58
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.06, green: 0.045, blue: 0.07, alpha: 1)
            let plateD = UIColor(red: 0.14, green: 0.15, blue: 0.21, alpha: 1)
            let plateM = UIColor(red: 0.31, green: 0.33, blue: 0.42, alpha: 1)
            let plateL = UIColor(red: 0.62, green: 0.66, blue: 0.76, alpha: 1)
            let steel = UIColor(red: 0.20, green: 0.22, blue: 0.29, alpha: 1)
            let dark = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
            let warn = UIColor(red: 0.95, green: 0.72, blue: 0.18, alpha: 1)
            let cx = W / 2 // 20

            // Tapered siege shell: 22px turret deck -> 38px foundation.
            func halfWidth(at row: Int) -> Int {
                if row < 5 { return 11 }
                if row < 48 { return 11 + (row - 5) * 8 / 43 }
                return 19
            }

            // Body: outline + armor gradient per row.
            for row in 0..<H {
                let hw = halfWidth(at: row)
                fill(cg, x: cx - hw - 1, y: row, w: hw * 2 + 2, h: 1, color: outline)
                fill(cg, x: cx - hw, y: row, w: 3, h: 1, color: plateL)
                fill(cg, x: cx - hw + 3, y: row, w: hw * 2 - 6, h: 1, color: plateM)
                fill(cg, x: cx + hw - 3, y: row, w: 3, h: 1, color: plateD)
            }
            // Twin side buttress towers (full height, steel + rivets).
            for px in [2, 3, W - 4, W - 3] {
                fill(cg, x: px, y: 12, w: 1, h: 30, color: steel)
            }
            for px in [4, W - 5] {
                fill(cg, x: px, y: 16, w: 1, h: 26, color: plateD)
            }
            // Riveted armor seams every 9 rows.
            for row in stride(from: 11, to: 46, by: 9) {
                let hw = halfWidth(at: row)
                fill(cg, x: cx - hw, y: row, w: hw * 2, h: 2, color: dark)
                fill(cg, x: cx - hw, y: row, w: hw * 2, h: 1, color: plateD)
                for rx in stride(from: cx - hw + 2, to: cx + hw - 2, by: 5) {
                    fill(cg, x: rx, y: row + 2, w: 1, h: 1, color: plateL)
                    fill(cg, x: rx + 1, y: row + 2, w: 1, h: 1, color: dark)
                }
            }
            // Heavy top deck (rows 1-5): dark plate + rivets + team edge.
            fill(cg, x: cx - 11, y: 1, w: 22, h: 4, color: dark)
            fill(cg, x: cx - 11, y: 1, w: 22, h: 1, color: plateL)
            fill(cg, x: cx - 11, y: 5, w: 22, h: 1, color: palette.trim)
            for rx in [cx - 10, cx - 5, cx, cx + 5, cx + 9] {
                fill(cg, x: rx, y: 2, w: 1, h: 1, color: plateL)
            }
            // Taller watch mast + twin antennae on the deck.
            fill(cg, x: cx + 7, y: 0, w: 1, h: 3, color: plateL)
            fill(cg, x: cx + 6, y: 0, w: 4, h: 1, color: plateM)
            fill(cg, x: cx - 8, y: 0, w: 1, h: 2, color: plateL)
            // Twin team banner bands (rows 7-11 and 13-16).
            for bandY in [7, 13] {
                let hwB = halfWidth(at: bandY)
                fill(cg, x: cx - hwB, y: bandY, w: hwB * 2, h: 1, color: palette.trimDark)
                fill(cg, x: cx - hwB, y: bandY + 1, w: hwB * 2, h: 3, color: palette.trim)
                fill(cg, x: cx - hwB, y: bandY + 4, w: hwB * 2, h: 1, color: palette.trimDark)
                fill(cg, x: cx - hwB, y: bandY + 1, w: 2, h: 3, color: .white.withAlphaComponent(0.35))
            }
            // Chevron emblem on the upper band.
            fill(cg, x: cx - 1, y: 9, w: 3, h: 1, color: .white)
            fill(cg, x: cx, y: 8, w: 1, h: 3, color: .white)
            // Twin glowing energy cells (rows 22-25 and 28-31).
            for cellY in [22, 28] {
                let hwC = halfWidth(at: cellY + 1)
                fill(cg, x: cx - hwC + 1, y: cellY - 1, w: (hwC - 1) * 2, h: 6, color: outline)
                fill(cg, x: cx - hwC + 2, y: cellY, w: (hwC - 2) * 2, h: 1, color: plateL)
                fill(cg, x: cx - hwC + 2, y: cellY + 2, w: (hwC - 2) * 2, h: 1, color: plateL)
                fill(cg, x: cx - 5, y: cellY, w: 10, h: 3, color: palette.trimDark)
                fill(cg, x: cx - 4, y: cellY, w: 8, h: 2, color: palette.trim)
                fill(cg, x: cx - 4, y: cellY, w: 8, h: 1, color: .white)
            }
            // Vented core slit rows 36-39: darker steel grill.
            fill(cg, x: cx - 5, y: 36, w: 10, h: 4, color: dark)
            for vx in stride(from: cx - 4, to: cx + 5, by: 2) {
                fill(cg, x: vx, y: 37, w: 1, h: 2, color: plateD)
            }
            // Hazard chevrons above the foundation (row 50).
            let hwH = halfWidth(at: 50)
            var hx = cx - hwH + 1
            var flip = false
            while hx < cx + hwH - 2 {
                fill(cg, x: hx, y: 50, w: 2, h: 2, color: flip ? warn : dark)
                hx += 2
                flip.toggle()
            }
            // Double-step foundation block (rows 53-57).
            fill(cg, x: cx - 17, y: 52, w: 34, h: 1, color: steel)
            fill(cg, x: cx - 19, y: 53, w: 38, h: 1, color: plateL)
            fill(cg, x: cx - 19, y: 54, w: 38, h: 3, color: plateD)
            fill(cg, x: cx - 19, y: 57, w: 38, h: 1, color: outline)
            for rx in [cx - 15, cx - 7, cx + 1, cx + 8, cx + 14] {
                fill(cg, x: rx, y: 55, w: 1, h: 1, color: plateL)
            }
            // Right-side drop shadow strip for depth.
            fill(cg, x: cx + 14, y: 7, w: 2, h: 45, color: UIColor(white: 0, alpha: 0.25))
        }
    }

    /// Mk-III siege turret head (38×22), barrel pointing +x. Twin heavy
    /// barrels stacked vertically + quad missile-pod banks (two above, two
    /// below the housing, kept symmetric so 360° rotation still reads).
    /// Four tube mouths = the 4-missile volley. Muzzle tip sits at x = 27.
    private static func makeMegaHeadTexture(palette: Palette) -> SKTexture {
        let W = 38, H = 22
        return pixelTexture(w: W, h: H) { cg in
            let outline = UIColor(red: 0.06, green: 0.045, blue: 0.07, alpha: 1)
            let metalD = UIColor(red: 0.14, green: 0.15, blue: 0.21, alpha: 1)
            let metalM = UIColor(red: 0.38, green: 0.41, blue: 0.51, alpha: 1)
            let metalL = UIColor(red: 0.74, green: 0.78, blue: 0.86, alpha: 1)
            let barrelD = UIColor(red: 0.09, green: 0.09, blue: 0.13, alpha: 1)
            let podD = UIColor(red: 0.11, green: 0.11, blue: 0.15, alpha: 1)
            let ember = SKColor(red: 1.0, green: 0.45, blue: 0.2, alpha: 1)

            // Twin stacked barrels: rows 8-10 and 11-13, x 16..26.
            for barrelY in [8, 11] {
                fill(cg, x: 16, y: barrelY - 1, w: 11, h: 4, color: outline)
                fill(cg, x: 17, y: barrelY, w: 9, h: 2, color: barrelD)
                fill(cg, x: 17, y: barrelY, w: 9, h: 1, color: metalM)
            }
            // Twin muzzle brake rings + mouths.
            for barrelY in [8, 11] {
                fill(cg, x: 22, y: barrelY, w: 1, h: 2, color: palette.trimDark)
                fill(cg, x: 23, y: barrelY, w: 2, h: 2, color: palette.trim)
                fill(cg, x: 25, y: barrelY, w: 1, h: 2, color: outline)
                fill(cg, x: 25, y: barrelY, w: 1, h: 2, color: .black)
            }
            // Pod lip at the barrel root.
            fill(cg, x: 15, y: 7, w: 2, h: 8, color: metalD)
            fill(cg, x: 15, y: 7, w: 2, h: 1, color: palette.trim)

            // Heavy housing: x 3..15, rows 3..18.
            fill(cg, x: 3, y: 3, w: 13, h: 16, color: outline)
            fill(cg, x: 4, y: 4, w: 11, h: 14, color: metalM)
            fill(cg, x: 4, y: 4, w: 11, h: 1, color: metalL)
            fill(cg, x: 4, y: 17, w: 11, h: 1, color: metalD)
            fill(cg, x: 4, y: 5, w: 1, h: 12, color: metalL)
            fill(cg, x: 14, y: 5, w: 1, h: 12, color: metalD)
            // Twin team stripes + sight dot + pivot bolt.
            fill(cg, x: 6, y: 6, w: 2, h: 10, color: palette.trim)
            fill(cg, x: 6, y: 6, w: 2, h: 1, color: .white.withAlphaComponent(0.6))
            fill(cg, x: 11, y: 9, w: 2, h: 2, color: metalD)
            fill(cg, x: 11, y: 9, w: 2, h: 1, color: .white)
            fill(cg, x: 7, y: 9, w: 3, h: 3, color: outline)
            fill(cg, x: 8, y: 9, w: 1, h: 3, color: metalL)

            // Quad missile-pod banks (two above + two below, symmetric).
            // Each bank carries one tube mouth: 4 mouths = 4 missiles.
            for bankY: Int in [1, 4, 16, 19] {
                fill(cg, x: 4, y: bankY, w: 11, h: 2, color: podD)
                fill(cg, x: 4, y: bankY, w: 11, h: 1, color: metalD)
                fill(cg, x: 5, y: bankY, w: 2, h: 1, color: palette.trim)
                let tubeY: Int
                let glowY: Int
                switch bankY {
                case 1: tubeY = 3; glowY = 1
                case 4: tubeY = 6; glowY = 4
                case 16: tubeY = 14; glowY = 16
                default: tubeY = 17; glowY = 19
                }
                for tx in [9, 12] {
                    fill(cg, x: tx, y: tubeY, w: 2, h: 2, color: barrelD)
                    fill(cg, x: tx, y: glowY, w: 2, h: 1, color: ember)
                }
            }
            // Rear exhaust stack (taller: 3 fins).
            fill(cg, x: 0, y: 5, w: 3, h: 2, color: metalD)
            fill(cg, x: 0, y: 10, w: 3, h: 2, color: metalD)
            fill(cg, x: 0, y: 15, w: 3, h: 2, color: metalD)
            // Top sensor fin.
            fill(cg, x: 7, y: 1, w: 4, h: 2, color: metalD)
            fill(cg, x: 8, y: 0, w: 2, h: 1, color: palette.trim)
            _ = W
        }
    }
}
