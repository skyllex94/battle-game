import SwiftUI

/// Top-center lane minimap: chunky pixel-art strip with stepped territory
/// blocks, hard-square structure marks (blue = you, red = enemy), square
/// unit pixels, a pixel-diamond hero, and a hard viewport box showing what
/// the camera currently sees. Driven by a MinimapSnapshot polled at ~7Hz.
/// No rounded corners, no gradients, no blur glows — crisp squares only.
struct MinimapView: View {
    let snap: MinimapSnapshot
    /// Lane strip width. The HUD embeds a compact 160pt version on narrow
    /// screens (via ViewThatFits); defaults to the slim 230pt strip.
    var stripWidth: CGFloat = 230
    private let stripHeight: CGFloat = 28
    private let inset: CGFloat = 7

    private func x(_ worldX: CGFloat) -> CGFloat {
        if snap.levelWidth <= 0 { return 0 }
        let frac: CGFloat = worldX / snap.levelWidth
        return frac * stripWidth
    }

    private var viewportWidth: CGFloat {
        let frac: CGFloat = snap.viewWidth / snap.levelWidth
        return max(8.0, frac * stripWidth)
    }

    var body: some View {
        ZStack {
            // Outer shell: pixel-cut panel + hard 1px border.
            ShopPixelShape(cut: 5)
                .fill(.black.opacity(0.72))
                .frame(width: stripWidth + 14, height: stripHeight + 8)
            ShopPixelShape(cut: 5)
                .stroke(.white.opacity(0.22), lineWidth: 1)
                .frame(width: stripWidth + 14, height: stripHeight + 8)

            // Territory blocks: hard blue home / dark mid / hard red home.
            // Stepped segments, not a gradient — pixel style.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.blue.opacity(0.32))
                    .frame(width: stripWidth * 0.30)
                Rectangle()
                    .fill(.white.opacity(0.05))
                    .frame(width: stripWidth * 0.40)
                Rectangle()
                    .fill(.red.opacity(0.32))
                    .frame(width: stripWidth * 0.30)
            }
            .frame(width: stripWidth, height: 10)
            .position(x: inset + stripWidth / 2, y: stripHeight - 5)

            // Ground line: chunky 2px pixel row.
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(width: stripWidth, height: 2)
                .position(x: inset + stripWidth / 2, y: stripHeight - 2)

            // Midfield tick: 2px wide pixel post.
            Rectangle()
                .fill(.white.opacity(0.6))
                .frame(width: 2, height: 6)
                .position(x: inset + stripWidth / 2, y: stripHeight - 6)

            // Viewport box (what the camera sees): hard square, no rounding.
            ZStack {
                Rectangle().fill(.white.opacity(0.08))
                Rectangle().stroke(.white.opacity(0.7), lineWidth: 1)
            }
            .frame(width: viewportWidth, height: stripHeight - 8)
                .position(x: inset + x(snap.cameraX), y: (stripHeight + 8) / 2 - 1)
                .allowsHitTesting(false)

            // Bases (8px squares) + towers (5px squares, two per side).
            minimapMark(worldX: snap.playerBaseX, size: 8, color: .blue)
            ForEach(snap.playerTowerXs, id: \.self) { tx in
                minimapMark(worldX: tx, size: 5, color: .blue)
            }
            ForEach(snap.enemyTowerXs, id: \.self) { tx in
                minimapMark(worldX: tx, size: 5, color: .red)
            }
            minimapMark(worldX: snap.enemyBaseX, size: 8, color: .red)

            // Unit pixels: player army (cyan) + enemy marchers (pink-red).
            // Hard 3px squares with a dark separator so packs read as
            // individual pixels instead of one glowing blob.
            ForEach(snap.allyXs.indices, id: \.self) { i in
                Rectangle()
                    .fill(.cyan)
                    .frame(width: 3, height: 3)
                    .overlay(Rectangle().stroke(.black.opacity(0.6), lineWidth: 0.5))
                    .position(x: inset + x(snap.allyXs[i]), y: stripHeight - 11)
            }
            ForEach(snap.enemyXs.indices, id: \.self) { i in
                Rectangle()
                    .fill(Color(red: 1, green: 0.35, blue: 0.4))
                    .frame(width: 3, height: 3)
                    .overlay(Rectangle().stroke(.black.opacity(0.6), lineWidth: 0.5))
                    .position(x: inset + x(snap.enemyXs[i]), y: stripHeight - 11)
            }

            // Hero pixel-diamond: white square rotated 45° on a black
            // backing pixel so it reads over unit pixels.
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.9))
                    .frame(width: 9, height: 9)
                Rectangle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
            }
            .rotationEffect(.degrees(45))
            .position(x: inset + x(snap.heroX), y: stripHeight - 11)
        }
        .frame(width: stripWidth + 14, height: stripHeight + 8)
    }

    private func minimapMark(worldX: CGFloat, size: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Rectangle().stroke(.black.opacity(0.55), lineWidth: 1))
            .position(x: inset + x(worldX), y: stripHeight - 7)
    }
}
