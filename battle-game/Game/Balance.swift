import CoreGraphics

/// Single tuning file for Level 1. Ported from your Unity balance:
/// tower HP 200, base HP 500, starting gold 500 — plus layout numbers.
/// No magic numbers in GameScene; everything reads from here.
enum Balance {
    // MARK: - Level layout (points)
    static let levelWidth: CGFloat = 4000
    static let groundTopY: CGFloat = 120        // y of the walkable surface
    static let groundThickness: CGFloat = 120
    static let viewHeight: CGFloat = 750        // logical scene height

    // MARK: - Structures (x centers, from your Unity lane: base -> tower -> mid -> tower -> base)
    static let playerBaseX: CGFloat = 220
    static let playerTowerX: CGFloat = 800
    static let enemyTowerX: CGFloat = 3200
    static let enemyBaseX: CGFloat = 3780

    // MARK: - Platforms (mid-map verticality for the hero; physics lands next stage)
    static let platforms: [CGRect] = [
        CGRect(x: 1650, y: 300, width: 320, height: 36),
        CGRect(x: 2050, y: 420, width: 320, height: 36),
        CGRect(x: 2450, y: 300, width: 320, height: 36),
    ]

    // MARK: - Hero (visual only this stage; movement stats used next stage)
    static let heroSpawnX: CGFloat = 420
    static let heroHeight: CGFloat = 96

    // MARK: - Hero movement feel
    static let heroRunSpeed: CGFloat = 520
    static let heroJumpVelocity: CGFloat = 1050
    static let heroGravity: CGFloat = -2000   // jump apex ≈ 275pt: clears the 216pt rise to platform 1
    static let heroAccelGround: CGFloat = 4200
    static let heroAccelAir: CGFloat = 2800   // strong air control: steer freely mid-jump
    static let heroCoyoteTime: Double = 0.12
    static let heroJumpBuffer: Double = 0.15  // taps just before landing still jump

    // MARK: - Parallax scroll factors (ported from your Unity Parallaxing.cs idea:
    // background moves slower than the camera; factor 1.0 = locked to world)
    static let parallaxSky: CGFloat = 0.0
    static let parallaxFar: CGFloat = 0.15
    static let parallaxMid: CGFloat = 0.35
    static let parallaxForeground: CGFloat = 1.15

    // MARK: - Camera
    static let cameraZoom: CGFloat = 0.62  // visible slice ≈ 830x465pt: hero fills ~20% of height
    static let cameraYOffset: CGFloat = 120     // look slightly above ground
}
