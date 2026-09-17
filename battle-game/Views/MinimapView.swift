import SwiftUI

/// Top-center lane minimap: slim dusk-styled strip with territory tint,
/// glowing structure marks (blue = you, red = enemy), unit dots, hero
/// diamond, and a viewport box showing what the camera currently sees.
/// Driven by a MinimapSnapshot polled at ~7Hz.
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
            // Outer shell: dark pill + hairline border.
            RoundedRectangle(cornerRadius: 7)
                .fill(.black.opacity(0.62))
                .frame(width: stripWidth + 14, height: stripHeight + 8)
            RoundedRectangle(cornerRadius: 7)
                .stroke(.white.opacity(0.18), lineWidth: 1)
                .frame(width: stripWidth + 14, height: stripHeight + 8)

            // Territory tint: blue home -> neutral mid -> red home.
            LinearGradient(
                stops: [
                    .init(color: .blue.opacity(0.30), location: 0),
                    .init(color: .blue.opacity(0.06), location: 0.32),
                    .init(color: .white.opacity(0.03), location: 0.5),
                    .init(color: .red.opacity(0.06), location: 0.68),
                    .init(color: .red.opacity(0.30), location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: stripWidth, height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .position(x: inset + stripWidth / 2, y: stripHeight - 5)

            // Ground hairline.
            Rectangle()
                .fill(.white.opacity(0.30))
                .frame(width: stripWidth, height: 1)
                .position(x: inset + stripWidth / 2, y: stripHeight - 2)

            // Midfield tick.
            Rectangle()
                .fill(.white.opacity(0.45))
                .frame(width: 1, height: 6)
                .position(x: inset + stripWidth / 2, y: stripHeight - 6)

            // Viewport box (what the camera sees).
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.10))
                RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.65), lineWidth: 1)
            }
            .frame(width: viewportWidth, height: stripHeight - 8)
                .position(x: inset + x(snap.cameraX), y: (stripHeight + 8) / 2 - 1)
                .allowsHitTesting(false)

            // Bases (rounded squares, glowing) + towers (dots, glowing, two per side).
            minimapMark(worldX: snap.playerBaseX, size: 8, color: .blue, square: true)
            ForEach(snap.playerTowerXs, id: \.self) { tx in
                minimapMark(worldX: tx, size: 5, color: .blue, square: false)
            }
            ForEach(snap.enemyTowerXs, id: \.self) { tx in
                minimapMark(worldX: tx, size: 5, color: .red, square: false)
            }
            minimapMark(worldX: snap.enemyBaseX, size: 8, color: .red, square: true)

            // Unit dots: player army (cyan) + enemy marchers (pink-red).
            ForEach(snap.allyXs.indices, id: \.self) { i in
                Circle()
                    .fill(.cyan)
                    .frame(width: 4, height: 4)
                    .shadow(color: .cyan.opacity(0.8), radius: 2)
                    .position(x: inset + x(snap.allyXs[i]), y: stripHeight - 11)
            }
            ForEach(snap.enemyXs.indices, id: \.self) { i in
                Circle()
                    .fill(Color(red: 1, green: 0.35, blue: 0.4))
                    .frame(width: 4, height: 4)
                    .shadow(color: .red.opacity(0.8), radius: 2)
                    .position(x: inset + x(snap.enemyXs[i]), y: stripHeight - 11)
            }

            // Hero diamond on top, outlined so it reads over dots.
            Image(systemName: "diamond.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 1)
                .position(x: inset + x(snap.heroX), y: stripHeight - 11)
        }
        .frame(width: stripWidth + 14, height: stripHeight + 8)
    }

    private func minimapMark(worldX: CGFloat, size: CGFloat, color: Color, square: Bool) -> some View {
        Group {
            if square {
                RoundedRectangle(cornerRadius: 1.5).fill(color)
            } else {
                Circle().fill(color)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.8), radius: 2)
        .position(x: inset + x(worldX), y: stripHeight - 7)
    }
}
