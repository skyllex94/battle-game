import SwiftUI

/// Hand-painted pixel continent for the campaign map. The world is a
/// 480x90 cell strip (three screens wide) rendered once per pan change.
/// Biomes blend west to east: verdant woods, dunes, ember wastes, frost,
/// and the umbral core. Everything is deterministic so the map is stable
/// across launches.
enum EmraMap {
    static let pageCols = 160
    static let rows = 90
    static let pages = 3
    static var cols: Int { pageCols * pages }

    private static let slotX: [Double] = [0.14, 0.32, 0.50, 0.68, 0.86]
    private static let slotY: [Double] = [0.60, 0.44, 0.58, 0.42, 0.54]

    static func worldX(_ id: Int) -> Double {
        let p = Double((id - 1) / 5)
        return p + slotX[(id - 1) % 5]
    }

    static func nodeY(_ id: Int) -> Double { slotY[(id - 1) % 5] }

    static func zone(_ page: Int) -> String {
        ["THE VERDANT WEST", "THE SCORCHED MIDLANDS", "THE FROZEN EAST + UMBRAL CORE"][min(2, max(0, page))]
    }

    static func icon(_ id: Int) -> String {
        switch id {
        case 1, 2: return "leaf.fill"
        case 3: return "shield.fill"
        case 4, 5: return "sun.max.fill"
        case 6: return "shield.fill"
        case 7, 8: return "flame.fill"
        case 9: return "shield.fill"
        case 10: return "snowflake"
        case 11: return "shield.fill"
        case 12: return "snowflake"
        case 13: return "bolt.fill"
        case 14: return "moon.fill"
        default: return "crown.fill"
        }
    }

    private static let oceanDeep = Color(red: 0.030, green: 0.140, blue: 0.260)
    private static let oceanMid = Color(red: 0.045, green: 0.235, blue: 0.360)
    private static let oceanShelf = Color(red: 0.070, green: 0.370, blue: 0.450)
    private static let oceanShallow = Color(red: 0.140, green: 0.520, blue: 0.560)
    private static let roadDust = Color(red: 0.66, green: 0.52, blue: 0.34)

    private static func h(_ x: Int, _ y: Int, _ s: Int) -> Int {
        abs((x &* 73856093) ^ (y &* 19349663) ^ (s &* 83492791)) % 100
    }

    private static func gauss(_ x: Double, _ center: Double, _ width: Double) -> Double {
        let d = (x - center) / width
        return exp(-d * d)
    }

    private struct RNG {
        private var state: UInt64
        init(_ seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        private mutating func next() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 2685821657736338717
        }
        mutating func int(_ lo: Int, _ hi: Int) -> Int {
            guard hi > lo else { return lo }
            return lo + Int(next() % UInt64(hi - lo + 1))
        }
        mutating func double(_ lo: Double, _ hi: Double) -> Double {
            lo + Double(next() % 100_000) / 100_000 * (hi - lo)
        }
    }

    private static func landTop(_ gx: Int) -> Int {
        let x = Double(gx)
        var v = 30.0
            + 5.5 * sin(x * 0.031)
            + 2.6 * sin(x * 0.077 + 1.4)
            + 1.4 * sin(x * 0.181 + 0.6)
        v += 6.0 * gauss(x, 86, 15)
        v -= 4.5 * gauss(x, 214, 18)
        v += 3.2 * gauss(x, 348, 20)
        v -= 2.2 * gauss(x, 438, 12)
        if gx < 18 { v += Double(18 - gx) * 1.6 }
        if gx > cols - 18 { v += Double(gx - (cols - 18)) * 1.6 }
        v += Double(h(gx, 3, 61) % 5 - 2) * 0.8
        return min(46, max(8, Int(v.rounded())))
    }

    private static func landBot(_ gx: Int) -> Int {
        let x = Double(gx)
        var v = 62.0
            + 5.5 * sin(x * 0.027 + 2.1)
            + 2.4 * sin(x * 0.069 + 0.4)
            + 1.2 * sin(x * 0.163 + 2.4)
        v -= 6.0 * gauss(x, 168, 17)
        v += 5.0 * gauss(x, 60, 14)
        v -= 3.0 * gauss(x, 280, 22)
        v += 3.5 * gauss(x, 372, 18)
        if gx < 18 { v -= Double(18 - gx) * 1.6 }
        if gx > cols - 18 { v -= Double(gx - (cols - 18)) * 1.6 }
        v += Double(h(gx, 9, 62) % 5 - 2) * 0.7
        return max(48, min(84, Int(v.rounded())))
    }

    private static func biomeAt(_ gx: Int, _ gy: Int) -> Int {
        let warp = Int((7.0 * sin(Double(gy) * 0.085)
                        + 3.0 * sin(Double(gy) * 0.27 + 1.1)).rounded())
        let x = gx + warp
        let n = h(gx, gy, 55)
        if x < 104 { return 0 }
        if x < 120 { return n < (x - 104) * 6 ? 1 : 0 }
        if x < 244 { return 1 }
        if x < 260 { return n < (x - 244) * 6 ? 2 : 1 }
        if x < 300 { return 2 }
        if x < 316 { return n < (x - 300) * 6 ? 3 : 2 }
        if x < 402 { return 3 }
        if x < 418 { return n < (x - 402) * 6 ? 4 : 3 }
        return 4
    }

    private static func terrain(_ gx: Int, _ gy: Int, _ biome: Int) -> Color {
        let n = h(gx, gy, 101)
        switch biome {
        case 0:
            if h(gx / 7, gy / 5, 120) > 62 {
                return n < 45
                    ? Color(red: 0.11, green: 0.30, blue: 0.16)
                    : Color(red: 0.15, green: 0.39, blue: 0.21)
            }
            if n < 18 { return Color(red: 0.15, green: 0.40, blue: 0.22) }
            if n > 88 { return Color(red: 0.34, green: 0.64, blue: 0.33) }
            return Color(red: 0.22, green: 0.52, blue: 0.28)
        case 1:
            let broad = h(gx / 9, gy / 4, 133)
            if broad > 76 { return Color(red: 0.78, green: 0.66, blue: 0.44) }
            if n < 14 { return Color(red: 0.76, green: 0.63, blue: 0.40) }
            if n > 88 { return Color(red: 0.91, green: 0.81, blue: 0.58) }
            return Color(red: 0.85, green: 0.74, blue: 0.50)
        case 2:
            let broad = h(gx / 6, gy / 4, 132)
            if broad > 78 { return Color(red: 0.20, green: 0.14, blue: 0.15) }
            if n < 20 { return Color(red: 0.17, green: 0.12, blue: 0.13) }
            if n > 90 { return Color(red: 0.44, green: 0.33, blue: 0.30) }
            return Color(red: 0.30, green: 0.21, blue: 0.20)
        case 3:
            let broad = h(gx / 8, gy / 5, 131)
            if broad > 74 {
                return n < 30
                    ? Color(red: 0.68, green: 0.78, blue: 0.88)
                    : Color(red: 0.76, green: 0.84, blue: 0.92)
            }
            if n < 16 { return Color(red: 0.66, green: 0.75, blue: 0.86) }
            if n > 90 { return Color(red: 0.94, green: 0.97, blue: 1.00) }
            return Color(red: 0.83, green: 0.89, blue: 0.95)
        default:
            if n < 18 { return Color(red: 0.08, green: 0.06, blue: 0.14) }
            if n > 90 { return Color(red: 0.28, green: 0.19, blue: 0.40) }
            return Color(red: 0.16, green: 0.12, blue: 0.24)
        }
    }

    private static func shoreColor(_ biome: Int) -> Color {
        switch biome {
        case 0: return Color(red: 0.78, green: 0.70, blue: 0.45)
        case 1: return Color(red: 0.92, green: 0.83, blue: 0.62)
        case 2: return Color(red: 0.38, green: 0.27, blue: 0.24)
        case 3: return Color(red: 0.78, green: 0.88, blue: 0.95)
        default: return Color(red: 0.24, green: 0.17, blue: 0.34)
        }
    }

    private static func nodeCell(_ id: Int) -> (x: Int, y: Int) {
        (Int(worldX(id) * Double(pageCols)), Int(nodeY(id) * Double(rows)))
    }

    private static func nearNode(_ x: Int, _ y: Int, _ mx: Int = 9, _ my: Int = 5) -> Bool {
        for id in 1...15 {
            let n = nodeCell(id)
            if abs(n.x - x) <= mx && abs(n.y - y) <= my { return true }
        }
        return false
    }

    static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cw = size.width / CGFloat(cols)
        let chh = size.height / CGFloat(rows)

        func px(_ gx: Int, _ gy: Int, _ w: Int, _ hgt: Int, _ c: Color, _ alpha: Double = 1) {
            guard gx + w > -6, gx < cols + 6, gy + hgt > -4, gy < rows + 4 else { return }
            ctx.fill(Path(CGRect(x: CGFloat(gx) * cw, y: CGFloat(gy) * chh,
                                 width: CGFloat(w) * cw, height: CGFloat(hgt) * chh)),
                     with: .color(c.opacity(alpha)))
        }

        func tree(_ x: Int, _ y: Int) {
            px(x, y - 1, 1, 2, Color(red: 0.28, green: 0.19, blue: 0.11))
            px(x - 2, y - 4, 5, 2, Color(red: 0.15, green: 0.41, blue: 0.21))
            px(x - 1, y - 6, 3, 2, Color(red: 0.15, green: 0.41, blue: 0.21))
            px(x - 2, y - 3, 5, 2, Color(red: 0.15, green: 0.41, blue: 0.21))
            px(x - 2, y - 4, 2, 1, Color(red: 0.31, green: 0.60, blue: 0.29))
            px(x + 1, y - 5, 1, 1, Color(red: 0.31, green: 0.60, blue: 0.29))
            px(x - 1, y - 2, 3, 1, Color(red: 0.10, green: 0.28, blue: 0.14))
        }

        func pine(_ x: Int, _ y: Int) {
            let green = Color(red: 0.11, green: 0.32, blue: 0.24)
            let lit = Color(red: 0.19, green: 0.44, blue: 0.32)
            px(x, y - 1, 1, 2, Color(red: 0.30, green: 0.22, blue: 0.16))
            for r in 0..<7 {
                let half = max(1, (r + 2) / 2)
                px(x - half, y - 2 - r, half * 2 + 1, 1, green)
                if r < 5 { px(x - half, y - 2 - r, 1, 1, lit) }
            }
            px(x - 1, y - 9, 3, 1, Color(white: 1), 0.85)
        }

        func cactus(_ x: Int, _ y: Int) {
            let c = Color(red: 0.24, green: 0.47, blue: 0.24)
            px(x, y - 5, 1, 5, c)
            px(x - 2, y - 3, 2, 1, c)
            px(x - 2, y - 5, 1, 2, c)
            px(x + 1, y - 2, 2, 1, c)
            px(x + 2, y - 4, 1, 2, c)
        }

        func dune(_ x: Int, _ y: Int, _ w: Int) {
            let light = Color(red: 0.96, green: 0.87, blue: 0.66)
            let shade = Color(red: 0.70, green: 0.57, blue: 0.36)
            for ox in -w...w {
                let t = abs(Double(ox) / Double(max(1, w)))
                let yy = y - Int((1 - t) * 3.0)
                px(x + ox, yy, 1, 1, light, 0.85)
                px(x + ox, yy + 1, 1, 1, shade, 0.55)
            }
        }

        func bones(_ x: Int, _ y: Int) {
            let bone = Color(red: 0.93, green: 0.88, blue: 0.73)
            px(x - 7, y, 13, 1, bone, 0.9)
            for i in 0..<4 {
                px(x - 5 + i * 3, y - 3, 1, 3, bone, 0.9)
                px(x - 5 + i * 3, y - 3, 2, 1, bone, 0.9)
            }
            px(x + 7, y - 2, 3, 2, bone, 0.9)
        }

        func palm(_ x: Int, _ y: Int) {
            let trunk = Color(red: 0.45, green: 0.30, blue: 0.16)
            let frond = Color(red: 0.18, green: 0.46, blue: 0.22)
            let lit = Color(red: 0.33, green: 0.62, blue: 0.28)
            px(x, y - 4, 1, 4, trunk)
            px(x - 3, y - 5, 3, 1, frond)
            px(x + 1, y - 5, 3, 1, frond)
            px(x - 2, y - 6, 2, 1, lit)
            px(x + 1, y - 6, 2, 1, lit)
            px(x - 1, y - 7, 3, 1, frond)
            px(x - 4, y - 4, 2, 1, frond)
            px(x + 3, y - 4, 2, 1, frond)
        }

        func oasis(_ x: Int, _ y: Int) {
            let water = Color(red: 0.20, green: 0.62, blue: 0.66)
            let light = Color(red: 0.48, green: 0.88, blue: 0.84)
            for oy in -3...3 {
                let half = Int((1 - Double(oy * oy) / 12.0).squareRoot() * 9)
                px(x - half, y + oy, half * 2, 1, water)
            }
            px(x - 5, y - 1, 10, 1, light, 0.8)
            px(x - 2, y + 2, 5, 1, Color(red: 0.10, green: 0.44, blue: 0.48), 0.7)
            for (dx, dy) in [(-11, -4), (10, -3), (-9, 4), (11, 4)] {
                palm(x + dx, y + dy)
            }
        }

        func mesa(_ x: Int, _ baseY: Int, _ w: Int, _ hgt: Int) {
            px(x - w / 2 + 1, baseY - hgt, w - 2, hgt, Color(red: 0.62, green: 0.48, blue: 0.30))
            px(x - w / 2, baseY - hgt, w - 3, hgt - 1, Color(red: 0.76, green: 0.60, blue: 0.38))
            px(x - w / 2, baseY - hgt, w - 3, 1, Color(red: 0.90, green: 0.74, blue: 0.48))
            px(x - w / 2, baseY - hgt + 2, w - 4, 1, Color(red: 0.60, green: 0.46, blue: 0.29), 0.6)
            px(x - w / 2, baseY - hgt + 4, w - 5, 1, Color(red: 0.60, green: 0.46, blue: 0.29), 0.4)
        }

        func mountain(_ x: Int, _ baseY: Int, _ s: Int, _ snowy: Bool) {
            let rock = Color(red: 0.40, green: 0.42, blue: 0.50)
            let dark = Color(red: 0.28, green: 0.30, blue: 0.38)
            let lit = Color(red: 0.55, green: 0.57, blue: 0.65)
            for r in 0..<s {
                let half = r + 1
                px(x - half, baseY - s + r, half * 2, 1, dark)
                px(x - half, baseY - s + r, max(1, half / 2), 1, lit)
            }
            px(x - 1, baseY - s + 1, 3, 1, rock)
            if snowy {
                px(x - 2, baseY - s, 4, 2, Color(white: 1))
                px(x - 1, baseY - s - 1, 2, 1, Color(white: 1))
            }
        }

        func spire(_ x: Int, _ baseY: Int, _ hgt: Int, _ c: Color, _ glow: Color) {
            for r in 0..<hgt {
                let half = max(1, (hgt - r) / 4)
                px(x - half, baseY - r, half * 2 + 1, 1, r < hgt / 4 ? glow : c)
            }
            px(x, baseY - hgt, 1, 2, Color(white: 1), 0.8)
        }

        func tent(_ x: Int, _ y: Int, _ c: Color) {
            for r in 0..<4 {
                let half = 4 - r
                px(x - half, y - r, half * 2, 1, c)
            }
            px(x, y - 4, 1, 1, Color(white: 1), 0.55)
        }

        func camp(_ x: Int, _ y: Int) {
            let cloth = Color(red: 0.44, green: 0.60, blue: 0.38)
            tent(x - 7, y + 2, cloth)
            tent(x + 3, y + 3, cloth)
            tent(x - 1, y - 3, Color(red: 0.52, green: 0.66, blue: 0.43))
            px(x - 1, y + 5, 4, 1, Color(red: 1.0, green: 0.45, blue: 0.10), 0.35)
            px(x, y + 5, 2, 1, Color(red: 1.0, green: 0.62, blue: 0.16))
            px(x, y + 4, 1, 1, Color(red: 1.0, green: 0.85, blue: 0.40))
        }

        func ruinArch(_ x: Int, _ y: Int) {
            let stone = Color(red: 0.55, green: 0.55, blue: 0.60)
            px(x - 6, y - 6, 2, 7, stone)
            px(x + 5, y - 6, 2, 7, stone)
            px(x - 6, y - 7, 13, 2, stone)
            px(x - 6, y - 7, 13, 1, Color(white: 1), 0.35)
            px(x - 2, y - 2, 3, 1, stone, 0.7)
            px(x + 4, y - 4, 2, 1, stone, 0.6)
        }

        func pyramid(_ x: Int, _ baseY: Int) {
            for r in 0..<6 {
                let half = 1 + r
                px(x - half, baseY - 6 + r, half * 2, 1,
                   r < 2 ? Color(red: 0.86, green: 0.74, blue: 0.50)
                         : Color(red: 0.67, green: 0.54, blue: 0.34))
            }
            px(x, baseY - 6, 1, 1, Color(red: 1.0, green: 0.88, blue: 0.40))
            px(x - 8, baseY - 1, 4, 1, Color(red: 0.52, green: 0.40, blue: 0.24), 0.6)
            px(x + 5, baseY - 1, 5, 1, Color(red: 0.52, green: 0.40, blue: 0.24), 0.6)
        }

        func volcano(_ x: Int, _ baseY: Int) {
            let dark = Color(red: 0.12, green: 0.08, blue: 0.09)
            let rock = Color(red: 0.36, green: 0.25, blue: 0.21)
            let lit = Color(red: 0.50, green: 0.36, blue: 0.30)
            let lava = Color(red: 1.0, green: 0.36, blue: 0.08)
            let core = Color(red: 1.0, green: 0.80, blue: 0.26)
            px(x - 14, baseY - 2, 29, 3, Color(red: 1.0, green: 0.24, blue: 0.04), 0.08)
            px(x - 9, baseY - 5, 19, 3, Color(red: 1.0, green: 0.24, blue: 0.04), 0.07)
            px(x - 4, baseY - 8, 9, 3, Color(red: 1.0, green: 0.24, blue: 0.04), 0.06)
            for r in 0..<9 {
                let half = 3 + r
                px(x - half, baseY - 9 + r, half * 2, 1,
                   r % 2 == 0 ? dark : rock)
                px(x - half, baseY - 9 + r, max(1, half / 3), 1, lit, 0.7)
            }
            px(x - 3, baseY - 10, 6, 2, Color(white: 0.05))
            px(x - 2, baseY - 10, 4, 1, lava)
            px(x - 1, baseY - 10, 2, 1, core)
            for i in 0..<9 {
                let fx = x + (i % 3) - 1
                px(fx, baseY - 8 + i, 2, 1, lava)
                if i % 2 == 0 { px(fx, baseY - 8 + i, 1, 1, core, 0.9) }
            }
            for s in 0..<6 {
                let age = Double(s) * 1.7 + t * 0.4
                let sx = x - 1 + Int(sin(age) * 3)
                let sy = baseY - 14 - s * 2
                px(sx, sy, 2 + s % 2, 2, Color(white: 0.36 + Double(s) * 0.04),
                   0.42 - Double(s) * 0.05)
            }
        }

        func lavaRiver(_ pts: [(Int, Int)]) {
            let dark = Color(red: 0.12, green: 0.08, blue: 0.09)
            let hot = Color(red: 1.0, green: 0.36, blue: 0.08)
            let core = Color(red: 1.0, green: 0.78, blue: 0.25)
            for i in 0..<(pts.count - 1) {
                let a = pts[i], b = pts[i + 1]
                let steps = max(1, max(abs(b.0 - a.0), abs(b.1 - a.1)))
                for s in 0...steps {
                    let x = a.0 + (b.0 - a.0) * s / steps
                    let y = a.1 + (b.1 - a.1) * s / steps
                    px(x - 2, y - 1, 6, 3, Color(red: 1.0, green: 0.22, blue: 0.04), 0.13)
                    px(x - 1, y - 1, 4, 3, dark, 0.7)
                    px(x, y, 2, 1, hot)
                    if h(x, y, 3) < 32 { px(x, y, 1, 1, core) }
                }
            }
        }

        func vein(_ x: Int, _ y: Int, _ c: Color) {
            px(x - 1, y, 3, 1, c, 0.22)
            px(x, y, 1, 1, c, 0.9)
        }

        func corruption(_ x: Int, _ y: Int) {
            let v = Color(red: 0.72, green: 0.36, blue: 1.0)
            for i in 0..<14 {
                let sx = x + Int(sin(Double(i) * 0.7) * 7)
                let sy = y + i
                vein(sx, sy, v)
                if i % 3 == 0 {
                    vein(sx + 3, sy + 1, v)
                    vein(sx - 3, sy + 2, v)
                }
            }
        }

        func chasm(_ x: Int, _ top: Int, _ bot: Int) {
            let void = Color(red: 0.06, green: 0.08, blue: 0.14)
            let rim = Color(red: 0.55, green: 0.70, blue: 0.82)
            for gy in top...bot {
                let wobble = Int(sin(Double(gy) * 0.9) * 1.5)
                px(x + wobble - 2, gy, 5, 1, void)
                px(x + wobble - 3, gy, 1, 1, rim, 0.55)
                px(x + wobble + 3, gy, 1, 1, rim, 0.55)
            }
        }

        func iceBridge(_ x: Int, _ y: Int) {
            let stone = Color(red: 0.66, green: 0.76, blue: 0.86)
            let light = Color(red: 0.92, green: 0.97, blue: 1.0)
            let deep = Color(red: 0.34, green: 0.46, blue: 0.60)
            px(x - 8, y - 2, 1, 5, deep)
            px(x + 8, y - 2, 1, 5, deep)
            px(x - 8, y - 1, 17, 3, stone)
            px(x - 8, y - 1, 17, 1, light)
            px(x - 8, y + 2, 17, 1, deep, 0.7)
            px(x - 8, y - 2, 17, 1, light, 0.55)
        }

        func castle(_ x: Int, _ y: Int, _ allied: Bool, _ big: Bool) {
            let s = big ? 3 : 2
            let biome = biomeAt(x, y)
            let stone: Color
            let shadow: Color
            if !allied {
                stone = Color(red: 0.20, green: 0.15, blue: 0.25)
                shadow = Color(red: 0.12, green: 0.09, blue: 0.16)
            } else if biome <= 0 {
                stone = Color(red: 0.47, green: 0.35, blue: 0.25)
                shadow = Color(red: 0.30, green: 0.22, blue: 0.16)
            } else if biome == 1 {
                stone = Color(red: 0.74, green: 0.63, blue: 0.44)
                shadow = Color(red: 0.50, green: 0.41, blue: 0.27)
            } else if biome == 2 {
                stone = Color(red: 0.38, green: 0.31, blue: 0.29)
                shadow = Color(red: 0.23, green: 0.18, blue: 0.18)
            } else if biome == 3 {
                stone = Color(red: 0.64, green: 0.76, blue: 0.87)
                shadow = Color(red: 0.41, green: 0.53, blue: 0.66)
            } else {
                stone = Color(red: 0.30, green: 0.20, blue: 0.38)
                shadow = Color(red: 0.17, green: 0.11, blue: 0.23)
            }
            let trim = allied ? Color(red: 0.30, green: 0.62, blue: 1.0)
                              : Color(red: 1.0, green: 0.28, blue: 0.14)
            let glow: Double = allied ? 1.0 : 0.55 + 0.45 * sin(t * 3)
            let w = 8 * s
            let hgt = 7 * s
            px(x - w / 2 - s, y - 1, w + 2 * s, 2, Color(white: 0), 0.35)
            if big {
                px(x - w / 2 - 2 * s, y, w + 4 * s, s,
                   Color(red: 1.0, green: 0.30, blue: 0.08), 0.35)
            }
            px(x - w / 2, y - hgt, w, hgt, shadow)
            px(x - w / 2, y - hgt, w - s, hgt - s, stone)
            px(x - w / 2, y - hgt, w - s, s, Color(white: 1), 0.35)
            var bx = x - w / 2
            while bx < x + w / 2 - s {
                px(bx, y - hgt - s, s, s, stone)
                bx += s * 2
            }
            for tx in [x - w / 2 - s, x + w / 2 - s] {
                px(tx, y - hgt - 2 * s, 2 * s, hgt + 2 * s, shadow)
                px(tx, y - hgt - 2 * s, 2 * s - 1, hgt + 2 * s - 1, stone)
                px(tx - 1, y - hgt - 3 * s, 2 * s + 2, s, trim)
                px(tx + s / 2, y - hgt - 4 * s, 1, 2 * s, Color(white: 0.20))
                px(tx + s / 2 + 1, y - hgt - 4 * s, 2, max(1, s / 2 + 1), trim)
            }
            let kw = 3 * s
            px(x - kw / 2, y - hgt - 3 * s, kw, 3 * s, shadow)
            px(x - kw / 2, y - hgt - 3 * s, kw - s / 2, 3 * s - s / 2, stone)
            px(x - kw / 2, y - hgt - 3 * s, kw - s / 2, s, Color(white: 1), 0.28)
            px(x - kw / 2, y - hgt - 4 * s, s, s, stone)
            px(x + kw / 2 - s, y - hgt - 4 * s, s, s, stone)
            px(x - s / 2, y - hgt - 2 * s, s, s, trim, glow)
            px(x, y - hgt - 6 * s, 1, 2 * s, Color(white: 0.20))
            px(x + 1, y - hgt - 6 * s, 2, max(1, s / 2 + 1), trim)
            px(x - s, y - 2 * s, 2 * s, 2 * s, Color(white: 0), 0.85)
            px(x - s, y - 2 * s, 2 * s, 1, trim)
            px(x - w / 4, y - hgt + 2 * s, s, s, trim, glow)
            px(x + w / 4 - s, y - hgt + 2 * s, s, s, trim, glow)
            if big {
                for tx in [x - w / 2 + 2 * s, x + w / 2 - 2 * s] {
                    px(tx, y - hgt - 4 * s, s, 4 * s, stone)
                    px(tx, y - hgt - 4 * s, s, 1, trim, 0.8 + 0.2 * sin(t * 3))
                    px(tx - 1, y - hgt - 4 * s - 1, s + 2, 1, trim)
                }
            }
        }

        func lightning(_ x: Int, _ y: Int) {
            let bolt: [(Int, Int)] = [(0, 0), (1, 3), (-1, 5), (1, 8), (-1, 11), (0, 14)]
            for (dx, dy) in bolt {
                px(x + dx, y + dy, 1, 2, Color(white: 1), 0.9)
                px(x + dx - 1, y + dy, 1, 1, Color(red: 0.70, green: 0.85, blue: 1.0), 0.4)
            }
        }

        func cloud(_ x: Int, _ y: Int, _ w: Int, _ a: Double) {
            let white = Color(white: 1)
            px(x + w / 5, y + 5, w * 3 / 5, 1, Color(red: 0.02, green: 0.12, blue: 0.20), a * 0.30)
            px(x, y + 2, w, 2, white, a)
            px(x + w / 6, y + 1, w / 2, 2, white, a)
            px(x + w / 2, y, w / 3, 2, white, a)
            px(x + w / 5, y + 1, w / 4, 1, white, min(1, a + 0.14))
            px(x + w / 8, y + 4, w * 3 / 4, 1, white, a * 0.45)
            px(x + w / 3, y + 3, w / 3, 1, white, max(0, a - 0.10))
        }

        func islet(_ cx: Int, _ cy: Int, _ r: Int, _ kind: Int) {
            for gy in (cy - r)...(cy + r) {
                for gx in (cx - r)...(cx + r) {
                    let d = Double((gx - cx) * (gx - cx) + (gy - cy) * (gy - cy)) / Double(max(1, r * r))
                    guard d < 1.0 - Double(h(gx, gy, 5)) / 100 * 0.3 else { continue }
                    let c: Color
                    switch kind {
                    case 0: c = Color(red: 0.24, green: 0.55, blue: 0.28)
                    case 1: c = Color(red: 0.88, green: 0.78, blue: 0.55)
                    case 2: c = Color(red: 0.88, green: 0.93, blue: 0.98)
                    default: c = Color(red: 0.52, green: 0.49, blue: 0.44)
                    }
                    px(gx, gy, 1, 1, c)
                    if h(gx, gy, 8) < 18 {
                        px(gx, gy, 1, 2, Color(red: 0.08, green: 0.30, blue: 0.16), 0.8)
                    }
                }
            }
            for a in stride(from: 0, to: 360, by: 14) {
                let rad = Double(a) * .pi / 180
                let sx = cx + Int(cos(rad) * Double(r + 1))
                let sy = cy + Int(sin(rad) * Double(r + 1) * 0.55)
                px(sx, sy, 1, 1, Color(white: 1), 0.45)
            }
        }

        func ship(_ x: Int, _ y: Int, _ ally: Bool) {
            let hull = Color(red: 0.28, green: 0.18, blue: 0.12)
            let sail = ally ? Color(red: 0.45, green: 0.72, blue: 1.0)
                            : Color(red: 0.90, green: 0.25, blue: 0.20)
            px(x - 4, y, 9, 1, hull)
            px(x - 3, y - 1, 7, 1, hull)
            px(x, y - 8, 1, 8, Color(red: 0.50, green: 0.40, blue: 0.30))
            px(x - 3, y - 7, 3, 3, sail)
            px(x + 1, y - 6, 2, 3, sail)
            px(x - 7, y + 1, 3, 1, Color(white: 1), 0.30)
        }

        func compass(_ x: Int, _ y: Int) {
            let gold = Color(red: 0.72, green: 0.62, blue: 0.38)
            for i in -4...4 {
                px(x + i, y, 1, 1, gold, 0.45)
                px(x, y + i, 1, 1, gold, 0.45)
            }
            px(x, y - 5, 1, 2, gold)
            px(x, y + 4, 1, 2, gold)
            px(x - 5, y, 2, 1, gold)
            px(x + 4, y, 2, 1, gold)
            px(x - 3, y - 3, 1, 1, gold, 0.6)
            px(x + 3, y - 3, 1, 1, gold, 0.6)
            px(x - 3, y + 3, 1, 1, gold, 0.6)
            px(x + 3, y + 3, 1, 1, gold, 0.6)
            px(x, y, 1, 1, Color(white: 1), 0.8)
        }

        func serpent(_ x: Int, _ y: Int) {
            let c = Color(red: 0.08, green: 0.32, blue: 0.32)
            for i in 0..<3 {
                let hx = x + i * 7
                let hy = y - (i % 2) * 2
                px(hx - 2, hy, 5, 1, c, 0.8)
                px(hx - 1, hy - 1, 3, 1, c, 0.8)
                px(hx, hy - 2, 1, 1, c, 0.8)
            }
            for i in 0..<8 {
                px(x + i * 3, y + 2, 2, 1, Color(white: 1), 0.28)
            }
        }

        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(oceanDeep))

        for band in 0..<3 {
            let baseY = [7.0, 74.0, 84.0][band]
            let amp = [2.5, 4.0, 2.0][band]
            let phase = [0.0, 1.7, 3.4][band]
            for gx in stride(from: 0, to: cols, by: 2) {
                let yy = Int(baseY + amp * sin(Double(gx) * 0.045 + phase))
                if h(gx, yy, 30 + band) < 34 {
                    px(gx, yy, 2, 1, Color(red: 0.22, green: 0.55, blue: 0.63), 0.32)
                }
            }
        }

        for i in 0..<90 {
            let gx = h(i, 2, 40) * cols / 100
            let gy = h(i, 5, 41) * rows / 100
            px(gx, gy, 1, 1, Color(red: 0.30, green: 0.62, blue: 0.70),
               0.18 + Double(h(i, 7, 42)) / 100 * 0.20)
        }

        for gx in 0..<cols {
            let top = landTop(gx)
            let bot = landBot(gx)
            guard top < bot else { continue }

            for d in 1...11 {
                let gyT = top - d
                if gyT >= 0 {
                    let c: Color = d <= 3 ? oceanShallow : d <= 7 ? oceanShelf : oceanMid
                    if h(gx, gyT, 14) < 94 { px(gx, gyT, 1, 1, c) }
                }
                let gyB = bot + d
                if gyB < rows {
                    let c: Color = d <= 3 ? oceanShallow : d <= 7 ? oceanShelf : oceanMid
                    if h(gx, gyB, 14) < 94 { px(gx, gyB, 1, 1, c) }
                }
            }

            for gy in top...bot {
                let biome = biomeAt(gx, gy)
                px(gx, gy, 1, 1, terrain(gx, gy, biome))
            }

            let shore = shoreColor(biomeAt(gx, top + 2))
            px(gx, top, 1, 1, shore)
            px(gx, bot, 1, 1, shore)
            px(gx, top + 1, 1, 1, shore, 0.55)
            px(gx, bot - 1, 1, 1, shore, 0.55)
            if h(gx, top, 6) < 72 { px(gx, top - 1, 1, 1, Color(white: 1), 0.55) }
            if h(gx, bot, 6) < 72 { px(gx, bot + 1, 1, 1, Color(white: 1), 0.55) }
        }

        let river: [(Int, Int)] = [(48, 32), (51, 37), (47, 42), (52, 47), (55, 52), (52, 58), (58, 64)]
        for i in 0..<(river.count - 1) {
            let a = river[i], b = river[i + 1]
            let steps = max(1, max(abs(b.0 - a.0), abs(b.1 - a.1)))
            for s in 0...steps {
                let x = a.0 + (b.0 - a.0) * s / steps
                let y = a.1 + (b.1 - a.1) * s / steps
                px(x, y, 2, 1, Color(red: 0.12, green: 0.42, blue: 0.56))
                px(x, y, 1, 1, Color(red: 0.30, green: 0.68, blue: 0.78), 0.8)
            }
        }

        let lake: [(Int, Int)] = [(63, 44), (65, 43), (67, 44), (66, 46), (63, 46), (62, 45)]
        for p in lake { px(p.0, p.1, 1, 1, Color(red: 0.20, green: 0.55, blue: 0.68)) }
        px(64, 44, 2, 1, Color(red: 0.45, green: 0.80, blue: 0.86), 0.7)

        for i in 0..<9 {
            let gy = 30 + i * 2
            let x = 360 + Int(sin(Double(i) * 0.8) * 4)
            px(x, gy, 3, 1, Color(red: 0.62, green: 0.84, blue: 0.92), 0.7)
            px(x + 2, gy, 1, 1, Color(red: 0.85, green: 0.96, blue: 1.0), 0.8)
        }
        px(352, 33, 20, 1, Color(red: 0.55, green: 0.75, blue: 0.86), 0.45)
        px(354, 45, 18, 1, Color(red: 0.55, green: 0.75, blue: 0.86), 0.35)

        chasm(356, landTop(356) + 2, landBot(356) - 2)
        iceBridge(356, 40)

        var frng = RNG(20240601)
        for _ in 0..<170 {
            let x = frng.int(10, 106)
            let y = frng.int(0, rows - 1)
            let top = landTop(x), bot = landBot(x)
            guard y > top + 3, y < bot - 2, !nearNode(x, y) else { continue }
            if biomeAt(x, y) != 0 { continue }
            tree(x, y)
        }

        for x in [12, 18, 25, 31, 38, 44, 52, 59, 66, 73, 79, 86, 93, 100] where x < 104 {
            let top = landTop(x) + 4
            let bot = landBot(x) - 6
            guard top < bot else { continue }
            let y = top + h(x, 1, 70) % max(1, bot - top)
            if !nearNode(x, y) && biomeAt(x, y) == 0 { pine(x, y) }
        }

        for _ in 0..<30 {
            let x = frng.int(122, 240)
            let y = frng.int(0, rows - 1)
            let top = landTop(x), bot = landBot(x)
            guard y > top + 4, y < bot - 3, !nearNode(x, y) else { continue }
            if biomeAt(x, y) == 1 { dune(x, y, frng.int(7, 15)) }
        }

        for _ in 0..<38 {
            let x = frng.int(116, 244)
            let y = frng.int(0, rows - 1)
            let top = landTop(x), bot = landBot(x)
            guard y > top + 3, y < bot - 2, !nearNode(x, y, 5, 3) else { continue }
            if biomeAt(x, y) != 1 { continue }
            let s = frng.int(2, 4)
            px(x, y, s, 1, Color(red: 0.48, green: 0.37, blue: 0.24), 0.9)
            px(x, y - 1, max(1, s - 1), 1, Color(red: 0.67, green: 0.55, blue: 0.38), 0.85)
        }

        let wadi: [(Int, Int)] = [(160, 38), (169, 41), (178, 44), (188, 46),
                                  (197, 50), (207, 52), (218, 57), (228, 59)]
        for i in 0..<(wadi.count - 1) {
            let a = wadi[i], b = wadi[i + 1]
            let steps = max(1, max(abs(b.0 - a.0), abs(b.1 - a.1)))
            for s in 0...steps {
                let x = a.0 + (b.0 - a.0) * s / steps
                let y = a.1 + (b.1 - a.1) * s / steps
                px(x - 1, y, 3, 1, Color(red: 0.72, green: 0.59, blue: 0.38), 0.55)
                px(x, y, 1, 1, Color(red: 0.56, green: 0.44, blue: 0.27), 0.75)
            }
        }

        for _ in 0..<20 {
            let x = frng.int(124, 240)
            let y = frng.int(0, rows - 1)
            let top = landTop(x), bot = landBot(x)
            guard y > top + 5, y < bot - 2, !nearNode(x, y) else { continue }
            if biomeAt(x, y) == 1 { cactus(x, y) }
        }

        for _ in 0..<9 {
            let x = frng.int(128, 238)
            let y = frng.int(0, rows - 1)
            let top = landTop(x), bot = landBot(x)
            guard y > top + 4, y < bot - 4, !nearNode(x, y) else { continue }
            if biomeAt(x, y) == 1 { bones(x, y) }
        }

        mesa(150, 52, 17, 7)
        mesa(218, 58, 19, 8)
        oasis(232, 56)
        pyramid(151, 57)
        pyramid(160, 59)

        let reef: [(Int, Int)] = [(126, 62), (130, 64), (134, 63), (138, 65), (142, 63)]
        for (x, y) in reef {
            px(x, y, 2, 1, Color(red: 0.86, green: 0.50, blue: 0.46), 0.65)
        }

        for i in 0..<7 {
            let bx = 250 + h(i, 60, 114) * 20 / 100
            let by = 50 + h(i, 61, 115) * 9 / 100
            for j in 0..<6 {
                px(bx + j, by + (j % 2), 1, 1, Color(red: 0.14, green: 0.10, blue: 0.10), 0.75)
                px(bx + j, by + 1 + (j % 2), 1, 1, Color(red: 0.44, green: 0.33, blue: 0.30), 0.35)
            }
        }

        for i in 0..<6 {
            let x = 262 + h(i, 62, 116) * 34 / 100
            let top = landTop(x), bot = landBot(x)
            guard bot - top > 12 else { continue }
            let y = top + 8 + h(i, 63, 117) % max(1, bot - top - 14)
            spire(x, y, 3, Color(red: 0.15, green: 0.10, blue: 0.12),
                  Color(red: 0.20, green: 0.13, blue: 0.15))
        }

        var ashRNG = RNG(987654321)

        for _ in 0..<7 {
            let x = ashRNG.int(266, 298)
            let y = ashRNG.int(0, rows - 1)
            let top = landTop(x), bot = landBot(x)
            guard y > top + 5, y < bot - 3, !nearNode(x, y) else { continue }
            if biomeAt(x, y) == 2 { px(x, y, 2, 1, Color(red: 0.13, green: 0.10, blue: 0.10), 0.8) }
        }

        volcano(282, 54)
        lavaRiver([(268, 49), (273, 52), (279, 54), (285, 56), (291, 57), (297, 57)])
        px(294, 55, 5, 1, Color(white: 1), 0.20)
        px(296, 53, 3, 1, Color(white: 1), 0.15)
        px(292, 51, 2, 1, Color(white: 1), 0.12)

        for _ in 0..<20 {
            let x = ashRNG.int(320, 398)
            let y = ashRNG.int(0, rows - 1)
            let top = landTop(x), bot = landBot(x)
            guard y > top + 3, y < bot - 2, !nearNode(x, y) else { continue }
            if biomeAt(x, y) == 3 && h(x, y, 72) < 45 {
                px(x, y, 1, 1, Color(red: 0.38, green: 0.40, blue: 0.48), 0.75)
            }
        }

        for x in [324, 331, 338, 372, 380, 389, 397] {
            let top = landTop(x) + 4
            let bot = landBot(x) - 8
            guard top < bot else { continue }
            let y = top + h(x, 2, 71) % max(1, bot - top)
            if !nearNode(x, y) { pine(x, y) }
        }

        let iceLake: [(Int, Int)] = [(370, 47), (376, 46), (382, 47), (386, 49), (381, 51), (374, 51), (369, 49)]
        for p in iceLake {
            px(p.0 - 2, p.1 - 1, 5, 3, Color(red: 0.42, green: 0.62, blue: 0.74), 0.85)
            px(p.0 - 1, p.1 - 1, 3, 1, Color(red: 0.74, green: 0.90, blue: 0.98), 0.9)
        }
        px(374, 48, 10, 1, Color(red: 0.90, green: 0.98, blue: 1.0), 0.75)
        px(377, 49, 1, 2, Color(red: 0.55, green: 0.74, blue: 0.86), 0.7)

        for i in 0..<12 {
            let x = 320 + h(i, 40, 110) * 84 / 100
            let top = landTop(x), bot = landBot(x)
            guard bot - top > 12 else { continue }
            let y = top + 4 + h(i, 41, 111) % max(1, bot - top - 8)
            for j in 0..<9 {
                px(x + j, y - j / 3, 1, 1, Color(white: 1), 0.28)
            }
        }

        let crevasse: [(Int, Int)] = [(328, 35), (331, 38), (330, 41), (334, 44),
                                      (332, 47), (336, 50), (335, 53)]
        for (x, y) in crevasse {
            px(x, y, 1, 1, Color(red: 0.38, green: 0.56, blue: 0.73), 0.85)
            px(x - 1, y, 1, 1, Color(white: 1), 0.35)
        }

        for (x, y) in [(325, 40), (341, 49), (350, 36), (365, 55), (390, 40)] {
            px(x, y - 1, 1, 3, Color(red: 0.60, green: 0.82, blue: 0.93), 0.7)
            px(x - 1, y, 3, 1, Color(red: 0.86, green: 0.96, blue: 1.0), 0.7)
            px(x, y, 1, 1, Color(white: 1), 0.9)
        }

        for i in 0..<8 {
            let x = 320 + h(i, 50, 112) * 82 / 100
            let top = landTop(x), bot = landBot(x)
            guard bot - top > 14 else { continue }
            let y = top + 6 + h(i, 51, 113) % max(1, bot - top - 12)
            px(x, y, 7, 1, Color(white: 1), 0.22)
        }

        for _ in 0..<6 {
            let x = ashRNG.int(414, 472)
            let y = ashRNG.int(0, rows - 1)
            let top = landTop(x), bot = landBot(x)
            guard y > top + 4, y < bot - 2, !nearNode(x, y) else { continue }
            if biomeAt(x, y) == 4 { corruption(x, y) }
        }

        spire(396, 46, 11, Color(red: 0.52, green: 0.28, blue: 0.92),
              Color(red: 0.78, green: 0.56, blue: 1.0))
        spire(414, 52, 8, Color(red: 0.40, green: 0.24, blue: 0.72),
              Color(red: 0.68, green: 0.44, blue: 1.0))
        spire(440, 38, 9, Color(red: 0.35, green: 0.20, blue: 0.60),
              Color(red: 0.62, green: 0.38, blue: 0.96))
        lightning(384, 20)

        for (x, y, s) in [(432, 62, 6), (447, 36, 5), (466, 60, 7)] {
            px(x - s / 2, y - s / 3, s, s / 2, Color(red: 0.22, green: 0.15, blue: 0.34), 0.8)
            px(x - s / 2, y + s / 3, s, 1, Color(red: 0.62, green: 0.36, blue: 1.0), 0.35)
        }

        let ridges: [(Int, Int, Int, Bool)] = [
            (190, 42, 7, false), (200, 41, 9, false), (211, 43, 7, false),
            (333, 44, 8, true), (343, 43, 10, true), (353, 45, 7, true),
            (390, 34, 6, false), (401, 35, 7, false),
        ]
        for (x, y, s, snowy) in ridges {
            let top = landTop(x), bot = landBot(x)
            guard y - s > top, y < bot else { continue }
            mountain(x, y, s, snowy)
        }

        camp(33, 59)
        ruinArch(60, 44)
        ruinArch(110, 44)
        castle(80, 52, true, false)
        castle(182, 52, true, false)
        castle(268, 52, true, false)
        castle(320, 52, true, false)
        castle(458, 49, false, true)

        let path = routePoints()
        for p in path {
            px(Int(p.x.rounded()), Int(p.y.rounded()), 2, 1, roadDust, 0.16)
        }
        for (i, p) in path.enumerated() where i % 3 == 0 {
            let x = Int(p.x.rounded()), y = Int(p.y.rounded())
            if p.level < CampaignData.unlockedLevel {
                px(x, y, 1, 1, Color(red: 1.0, green: 0.88, blue: 0.52), 0.92)
                px(x - 1, y, 1, 1, Color(red: 1.0, green: 0.95, blue: 0.70), 0.30)
            } else {
                px(x, y, 1, 1, Color(red: 0.96, green: 0.94, blue: 0.82), 0.55)
            }
        }

        for level in CampaignData.levels {
            let n = nodeCell(level.id)
            let unlocked = CampaignData.isUnlocked(level)
            let stars = CampaignData.stars(for: level.id)
            let isNext = unlocked && level.id == CampaignData.unlockedLevel && stars == 0
            let base: Color = !unlocked ? Color(white: 0.40) : stars > 0 ? .blue : .green
            px(n.x - 7, n.y - 7, 15, 15, Color(white: 0), 0.14)
            for (ox, oy) in [(-5, 0), (5, 0), (0, -5), (0, 5), (-4, -4), (4, -4), (-4, 4), (4, 4)] {
                px(n.x + ox, n.y + oy, 1, 1, base, unlocked ? 0.85 : 0.35)
            }
            px(n.x - 3, n.y - 3, 7, 7, Color(white: 0))
            px(n.x - 2, n.y - 2, 5, 5, base)
            if isNext {
                let blink = (sin(t * 5) + 1) / 2
                px(n.x - 1, n.y - 1, 3, 3, .yellow, 0.5 + 0.5 * blink)
                for i in stride(from: -6, through: 6, by: 3) {
                    px(n.x + i, n.y - 7, 1, 1, .yellow, 0.55)
                    px(n.x + i, n.y + 7, 1, 1, .yellow, 0.55)
                }
            } else {
                px(n.x, n.y, 1, 1, Color(white: 1))
            }
        }

        islet(60, 80, 4, 0)
        islet(132, 80, 3, 1)
        islet(206, 79, 4, 1)
        islet(304, 82, 3, 3)
        islet(380, 12, 4, 2)
        islet(402, 82, 3, 3)
        islet(464, 14, 3, 2)
        ship(72, 76, true)
        ship(432, 10, false)
        compass(452, 79)
        serpent(246, 82)

        for i in 0..<28 {
            let x = 8 + h(i, 1, 90) * 92 / 100
            let top = landTop(x), bot = landBot(x)
            guard bot - top > 10 else { continue }
            let y = top + 4 + h(i, 2, 91) * max(1, bot - top - 8) / 100
            px(x, y, 1, 1, Color(red: 0.86, green: 1.0, blue: 0.48),
               0.45 + Double(h(i, 3, 92)) / 100 * 0.45)
        }
        for i in 0..<22 {
            let x = 262 + h(i, 14, 93) * 46 / 100
            let top = landTop(x), bot = landBot(x)
            guard bot - top > 10 else { continue }
            let y = top + 3 + h(i, 15, 94) * max(1, bot - top - 6) / 100
            px(x, y, 1, 1, Color(red: 0.95, green: 0.55, blue: 0.22),
               0.35 + Double(h(i, 16, 95)) / 100 * 0.35)
        }
        for i in 0..<34 {
            let x = 318 + h(i, 20, 96) * 88 / 100
            let top = landTop(x), bot = landBot(x)
            guard bot - top > 10 else { continue }
            let y = top + 2 + h(i, 21, 97) * max(1, bot - top - 4) / 100
            px(x, y, 1, 1, Color(white: 1), 0.45 + Double(h(i, 22, 98)) / 100 * 0.45)
        }
        for i in 0..<24 {
            let x = 416 + h(i, 30, 99) * 58 / 100
            let top = landTop(x), bot = landBot(x)
            guard bot - top > 10 else { continue }
            let y = top + 3 + h(i, 31, 100) * max(1, bot - top - 6) / 100
            px(x, y, 1, 1, Color(red: 0.72, green: 0.42, blue: 1.0),
               0.35 + Double(h(i, 32, 101)) / 100 * 0.45)
        }

        let clouds: [(Int, Int, Int)] = [(30, 12, 26), (168, 24, 30), (300, 11, 22), (386, 70, 28), (120, 76, 20)]
        for (i, c) in clouds.enumerated() {
            let span = cols + 40
            let speed = [6, 4, 8, 5, 9][i]
            let x = ((c.0 + Int(t * Double(speed))) % span) - 20
            cloud(x, c.1, c.2, 0.72)
        }
    }

    private static func routePoints() -> [(x: Double, y: Double, level: Int)] {
        var points: [(x: Double, y: Double, level: Int)] = []
        for k in 1..<15 {
            let a = nodeCell(k)
            let b = nodeCell(k + 1)
            let ax = Double(a.x), ay = Double(a.y)
            let bx = Double(b.x), by = Double(b.y)
            let dx = bx - ax, dy = by - ay
            let len = max(1, (dx * dx + dy * dy).squareRoot())
            let bow = (k % 2 == 0 ? 5.0 : -4.5)
            let cx = (ax + bx) / 2 + (-dy / len) * bow
            let cy = (ay + by) / 2 + (dx / len) * bow
            let steps = max(8, Int(len * 1.4))
            for s in 0...steps {
                let u = Double(s) / Double(steps)
                let x = (1 - u) * (1 - u) * ax + 2 * (1 - u) * u * cx + u * u * bx
                var y = (1 - u) * (1 - u) * ay + 2 * (1 - u) * u * cy + u * u * by
                let gx = min(cols - 1, max(0, Int(x.rounded())))
                let lo = Double(landTop(gx) + 2)
                let hi = Double(landBot(gx) - 2)
                if hi > lo { y = min(hi, max(lo, y)) }
                points.append((x, y, k))
            }
        }
        return points
    }
}
