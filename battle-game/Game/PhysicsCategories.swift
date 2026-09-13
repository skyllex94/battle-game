import SpriteKit

/// Physics bitmasks. Single source of truth for all bodies.
struct PhysicsCategories {
    static let none: UInt32     = 0
    static let hero: UInt32     = 0x1 << 0
    static let ground: UInt32   = 0x1 << 1
    static let platform: UInt32 = 0x1 << 2
    // Reserved for later stages: unit 0x1<<3, tower 0x1<<4, projectile 0x1<<5.
}
