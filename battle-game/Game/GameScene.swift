import SpriteKit

/// Level 1 scene — movement stage: battlefield + parallax + hero + camera.
/// Hero runs/jumps via joystick input (GameView writes hero.inputX / jumpHeld).
/// Movement is a manual character controller (no physics bodies), so the sim
/// is fully deterministic. Combat, army, HUD buttons land in later stages.
///
/// World: 4000pt lane, ground strip, 3 mid platforms, 2 towers + 2 bases (dressed,
/// tinted blue/red, no collision yet). Camera follows the hero with lookahead.
final class GameScene: SKScene {

    // MARK: - Nodes
    private let world = SKNode()          // factor 1.0: ground, platforms, structures, hero
    private let skyLayer = SKNode()       // factor 0.0
    private let farLayer = SKNode()       // factor 0.15 (MapBG tiles)
    private let midLayer = SKNode()       // factor 0.35 (procedural hill silhouettes)
    private let foregroundLayer = SKNode()// factor 1.15 (subtle bottom grass, low alpha)
    private let cam = SKCameraNode()
    private var hero: HeroNode!
    private var lastUpdate: TimeInterval = 0

    // MARK: - Setup
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0, y: 0)
        addChild(skyLayer)
        addChild(farLayer)
        addChild(midLayer)
        addChild(world)
        addChild(foregroundLayer)
        camera = cam
        addChild(cam)

        buildSky()
        buildFar()
        buildMid()
        buildGround()
        buildPlatforms()
        buildStructures()
        buildHero()
        buildForeground()
        snapCamera()
        updateParallax()
    }

    // MARK: - Layer 0: sky gradient (static, factor 0.0)
    private func buildSky() {
        skyLayer.zPosition = -30
        // Vertical gradient via a tall stretched texture drawn once into a sprite.
        let gradient = makeVerticalGradientTexture(
            size: CGSize(width: 4, height: 256),
            top: SKColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1),
            bottom: SKColor(red: 0.35, green: 0.12, blue: 0.16, alpha: 1) // hellish dusk, matches Hell_ground
        )
        let sky = SKSpriteNode(texture: gradient)
        sky.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sky.size = CGSize(width: size.width * 1.2, height: size.height * 1.4)
        sky.zPosition = 0
        skyLayer.addChild(sky)
        skyLayer.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    // MARK: - Layer 1: far MapBG tiles (factor 0.15)
    private func buildFar() {
        farLayer.zPosition = -20
        let texture = ImportedArt.skTexture(named: "MapBG")
        texture.filteringMode = .linear
        // Scale to scene height; tile enough copies to cover the parallax-travelled range.
        let targetH = size.height * 1.05
        let scale = targetH / texture.size().height
        let tileW = texture.size().width * scale
        let needed = Int(ceil((size.width + Balance.levelWidth * Balance.parallaxFar) / tileW)) + 2
        let startX = -size.width // overhang left so the view is covered at min camera
        for i in 0..<needed {
            let tile = SKSpriteNode(texture: texture)
            tile.setScale(scale)
            tile.anchorPoint = CGPoint(x: 0, y: 0.5)
            tile.position = CGPoint(x: startX + CGFloat(i) * tileW, y: 0)
            tile.alpha = 0.38
            farLayer.addChild(tile)
        }
        // Dark veil so the bright map art sits behind the action, not over it.
        let veil = SKSpriteNode(color: SKColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 0.55),
                                size: CGSize(width: CGFloat(needed) * tileW, height: targetH))
        veil.anchorPoint = CGPoint(x: 0, y: 0.5)
        veil.position = CGPoint(x: startX, y: 0)
        veil.zPosition = 1
        farLayer.addChild(veil)
        farLayer.position = CGPoint(x: 0, y: size.height * 0.5)
    }

    // MARK: - Layer 2: mid hill silhouettes (factor 0.35, procedural)
    private func buildMid() {
        midLayer.zPosition = -10
        let hillColor = SKColor(red: 0.10, green: 0.08, blue: 0.14, alpha: 1)
        // Repeating rounded hills across the travelled range.
        let range = size.width + Balance.levelWidth * Balance.parallaxMid
        var x: CGFloat = 0
        var flip = false
        while x < range + 400 {
            let w: CGFloat = flip ? 520 : 380
            let h: CGFloat = flip ? 130 : 190
            let hill = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
            hill.fillColor = hillColor
            hill.strokeColor = .clear
            hill.position = CGPoint(x: x + w / 2, y: -size.height * 0.36)
            midLayer.addChild(hill)
            x += w * 0.75
            flip.toggle()
        }
        // A few dead-tree spikes for the hell-ground mood.
        for i in 0..<12 {
            let spike = SKShapeNode(rectOf: CGSize(width: 14, height: 120 + CGFloat(i % 3) * 40))
            spike.fillColor = hillColor
            spike.strokeColor = .clear
            spike.position = CGPoint(x: CGFloat(i) * (range / 12), y: -size.height * 0.18)
            spike.zRotation = CGFloat(i % 2 == 0 ? 0.08 : -0.08)
            midLayer.addChild(spike)
        }
        midLayer.position = CGPoint(x: 0, y: size.height * 0.5)
    }

    // MARK: - Playfield: ground (factor 1.0)
    private func buildGround() {
        world.zPosition = 0
        let texture = ImportedArt.skTexture(named: "Hell_ground")
        texture.filteringMode = .nearest
        let tileW: CGFloat = 500
        let tileH: CGFloat = 87
        var x: CGFloat = 0
        while x < Balance.levelWidth {
            let tile = SKSpriteNode(texture: texture)
            tile.anchorPoint = CGPoint(x: 0, y: 1) // top edge = walkable surface
            tile.size = CGSize(width: tileW, height: tileH)
            tile.position = CGPoint(x: x, y: Balance.groundTopY)
            tile.zPosition = 1
            world.addChild(tile)
            x += tileW
        }
        // Solid under-fill so gaps below the strip never show sky.
        let fill = SKSpriteNode(color: SKColor(red: 0.13, green: 0.07, blue: 0.08, alpha: 1),
                                size: CGSize(width: Balance.levelWidth, height: Balance.groundTopY))
        fill.anchorPoint = CGPoint(x: 0, y: 1)
        fill.position = CGPoint(x: 0, y: Balance.groundTopY - tileH)
        fill.zPosition = 0
        world.addChild(fill)

        // Team-side ground tint: subtle blue (left half) / red (right half) wash.
        let washL = SKSpriteNode(color: SKColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 0.10),
                                 size: CGSize(width: Balance.levelWidth / 2, height: tileH))
        washL.anchorPoint = CGPoint(x: 0, y: 1)
        washL.position = CGPoint(x: 0, y: Balance.groundTopY)
        washL.zPosition = 2
        world.addChild(washL)
        let washR = SKSpriteNode(color: SKColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 0.10),
                                 size: CGSize(width: Balance.levelWidth / 2, height: tileH))
        washR.anchorPoint = CGPoint(x: 0, y: 1)
        washR.position = CGPoint(x: Balance.levelWidth / 2, y: Balance.groundTopY)
        washR.zPosition = 2
        world.addChild(washR)
    }

    // MARK: - Playfield: floating platforms
    private func buildPlatforms() {
        let texture = ImportedArt.skTexture(named: "Hell_ground")
        for rect in Balance.platforms {
            let platform = SKSpriteNode(texture: texture)
            platform.size = CGSize(width: rect.width, height: rect.height)
            platform.position = CGPoint(x: rect.midX, y: rect.midY)
            platform.color = SKColor(white: 0, alpha: 0.25)
            platform.colorBlendFactor = 0.4
            platform.zPosition = 1
            platform.name = "platform"
            world.addChild(platform)
        }
    }

    // MARK: - Playfield: towers + bases (visual dressing this stage; HP/combat later)
    private func buildStructures() {
        // Towers (Tower.png 120x200 -> ~110pt tall)
        addStructureart(named: "Tower", at: Balance.playerTowerX, height: 190,
                        tint: SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1), name: "playerTower")
        addStructureart(named: "Tower", at: Balance.enemyTowerX, height: 190,
                        tint: SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 1), name: "enemyTower")
        // Bases (Base.png is huge -> ~170pt tall)
        addStructureart(named: "Base", at: Balance.playerBaseX, height: 170,
                        tint: SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1), name: "playerBase")
        addStructureart(named: "Base", at: Balance.enemyBaseX, height: 170,
                        tint: SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 1), name: "enemyBase")
    }

    private func addStructureart(named: String, at x: CGFloat, height: CGFloat, tint: SKColor, name: String) {
        let texture = ImportedArt.skTexture(named: named)
        texture.filteringMode = .linear
        let node = SKSpriteNode(texture: texture)
        node.setScale(height / texture.size().height)
        node.position = CGPoint(x: x, y: Balance.groundTopY + node.size.height / 2)
        node.color = tint
        node.colorBlendFactor = 0.25
        node.zPosition = 5
        node.name = name
        world.addChild(node)
        // Drop shadow ellipse for 2.5D grounding.
        let shadow = SKShapeNode(ellipseOf: CGSize(width: node.size.width * 0.9, height: 18))
        shadow.fillColor = SKColor(white: 0, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: x, y: Balance.groundTopY + 6)
        shadow.zPosition = 4
        world.addChild(shadow)
    }

    // MARK: - Playfield: hero
    /// Exposed so GameView can stream joystick state into the hero.
    var heroInputX: CGFloat {
        get { hero?.inputX ?? 0 }
        set { hero?.inputX = newValue }
    }
    var heroJumpHeld: Bool {
        get { hero?.jumpHeld ?? false }
        set { hero?.jumpHeld = newValue }
    }

    private func buildHero() {
        hero = HeroNode()
        hero.position = CGPoint(x: Balance.heroSpawnX,
                                y: Balance.groundTopY + Balance.heroHeight / 2 + 4)
        world.addChild(hero)
    }

    // MARK: - Foreground layer (factor 1.15, subtle)
    private func buildForeground() {
        foregroundLayer.zPosition = 20
        // Dark grass tufts along the bottom, drifting slightly faster than the world.
        let bladeCount = 90
        for i in 0..<bladeCount {
            let x = CGFloat(i) * (Balance.levelWidth * Balance.parallaxForeground / CGFloat(bladeCount))
            let blade = SKShapeNode(rectOf: CGSize(width: 6, height: 30 + CGFloat(i % 4) * 8))
            blade.fillColor = SKColor(red: 0.05, green: 0.10, blue: 0.06, alpha: 0.4)
            blade.strokeColor = .clear
            blade.position = CGPoint(x: x, y: 18)
            blade.zRotation = CGFloat((i % 5) - 2) * 0.06
            foregroundLayer.addChild(blade)
        }
        foregroundLayer.position = CGPoint(x: 0, y: 0)
    }

    // MARK: - Camera + parallax update
    private var halfViewWidth: CGFloat { size.width * cam.xScale / 2 }
    private var halfViewHeight: CGFloat { size.height * cam.xScale / 2 }

    private func cameraTarget() -> CGPoint {
        let lookahead = hero.velocity.dx * 0.22
        let desiredX = hero.position.x + lookahead
        let x = min(max(desiredX, halfViewWidth), Balance.levelWidth - halfViewWidth)
        // Follow the hero vertically a little so jumps stay framed, but never
        // show below the ground or above the sky.
        // Zoomed views are short: park the ground line near the bottom quarter.
        let baseY: CGFloat = Balance.groundTopY + halfViewHeight * 0.28
        let lift = max(0, hero.position.y - (Balance.groundTopY + Balance.heroHeight)) * 0.35
        let y = min(baseY + lift, size.height - halfViewHeight)
        return CGPoint(x: x, y: max(y, halfViewHeight * 0.6))
    }

    private func snapCamera() {
        cam.setScale(Balance.cameraZoom)
        cam.position = cameraTarget()
    }

    private func smoothCamera(dt: TimeInterval) {
        let target = cameraTarget()
        let rate = min(1, 6 * dt) // ~6/s smoothing: tight but not rigid
        cam.position = CGPoint(x: cam.position.x + (target.x - cam.position.x) * rate,
                               y: cam.position.y + (target.y - cam.position.y) * rate)
    }

    private func updateParallax() {
        let camX = cam.position.x
        // Layer offset = camX * (1 - factor): factor 1.0 -> 0 (locked to world),
        // factor 0.0 -> full camX (static on screen).
        skyLayer.position.x = size.width / 2 // recentred on camera each frame
        // skyLayer is screen-locked: counter-move by full camX relative to scene origin.
        // Since layers live in scene space, screen-locked means position.x = camX.
        skyLayer.position = CGPoint(x: camX, y: size.height / 2)
        farLayer.position.x = camX * (1 - Balance.parallaxFar)
        midLayer.position.x = camX * (1 - Balance.parallaxMid)
        foregroundLayer.position.x = -camX * (Balance.parallaxForeground - 1)
    }

    override func update(_ currentTime: TimeInterval) {
        frameCount += 1
        let dt = lastUpdate > 0 ? currentTime - lastUpdate : 1.0 / 60
        lastUpdate = currentTime
        hero.step(dt: dt, now: currentTime)
        smoothCamera(dt: dt)
        updateParallax()
    }

    // MARK: - Debug (temporary HUD readout)
    private var frameCount = 0
    var debugLine: String {
        let v = hero?.velocity ?? .zero
        let g = hero?.isGrounded ?? false
        let p = hero?.position ?? .zero
        return String(format: "f%d pos %4.0f,%4.0f in %+.2f jmp %@ | v %+4.0f,%+5.0f gnd %@",
                      frameCount, p.x, p.y, heroInputX, heroJumpHeld ? "Y" : "n",
                      v.dx, v.dy, g ? "Y" : "n")
    }

    // MARK: - Helpers
    private func makeVerticalGradientTexture(size: CGSize, top: SKColor, bottom: SKColor) -> SKTexture {
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: 1, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 4, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let topC = top.cgColor.converted(to: colorSpace, intent: .defaultIntent, options: nil),
              let botC = bottom.cgColor.converted(to: colorSpace, intent: .defaultIntent, options: nil),
              let topComps = topC.components, let botComps = botC.components else {
            return ImportedArt.skTexture(named: "MapBG")
        }
        for y in 0..<height {
            let t = CGFloat(y) / CGFloat(height - 1) // 0 bottom -> 1 top
            let r = botComps[0] + (topComps[0] - botComps[0]) * t
            let g = botComps[1] + (topComps[1] - botComps[1]) * t
            let b = botComps[2] + (topComps[2] - botComps[2]) * t
            ctx.setFillColor(red: r, green: g, blue: b, alpha: 1)
            ctx.fill(CGRect(x: 0, y: y, width: 1, height: 1))
        }
        guard let img = ctx.makeImage() else { return ImportedArt.skTexture(named: "MapBG") }
        return SKTexture(cgImage: img)
    }
}
