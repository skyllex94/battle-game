import SwiftUI

/// Top-center lane minimap: ground line, base squares, tower dots (blue = you,
/// red = enemy), hero diamond, and a white viewport box showing what the
/// camera currently sees. Driven by a MinimapSnapshot polled at ~7Hz.
struct MinimapView: View {
    let snap: MinimapSnapshot
    private let stripWidth: CGFloat = 300
    private let stripHeight: CGFloat = 38
    private let inset: CGFloat = 8

    private func x(_ worldX: CGFloat) -> CGFloat {
        if snap.levelWidth <= 0 { return 0 }
        let frac: CGFloat = worldX / snap.levelWidth
        let scaled: CGFloat = frac * stripWidth
        return scaled
    }

    private var viewportWidth: CGFloat {
        let frac: CGFloat = snap.viewWidth / snap.levelWidth
        let scaled: CGFloat = frac * stripWidth
        return max(8.0, scaled)
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(0.55))
                .frame(width: stripWidth + 16.0, height: stripHeight + 8.0)

            // Viewport box (what the camera sees).
            ZStack {
                Rectangle().fill(.white.opacity(0.08))
                Rectangle().stroke(.white.opacity(0.7), lineWidth: 1)
            }
            .frame(width: viewportWidth, height: stripHeight - 6.0)
            .position(x: inset + x(snap.cameraX), y: (stripHeight + 8.0) / 2.0)

            // Ground line.
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(width: stripWidth, height: 2.0)
                .position(x: inset + stripWidth / 2.0, y: stripHeight - 2.0)

            // Midfield tick.
            Rectangle()
                .fill(.white.opacity(0.5))
                .frame(width: 2.0, height: 8.0)
                .position(x: inset + stripWidth / 2.0, y: stripHeight - 6.0)

            // Bases (squares) + towers (dots).
            minimapMark(worldX: snap.playerBaseX, size: 10.0, color: .blue, square: true)
            minimapMark(worldX: snap.playerTowerX, size: 7.0, color: .blue, square: false)
            minimapMark(worldX: snap.enemyTowerX, size: 7.0, color: .red, square: false)
            minimapMark(worldX: snap.enemyBaseX, size: 10.0, color: .red, square: true)

            // Unit dots: player army (cyan) + enemy marchers (red, smaller
            // than the tower dots so structures still read first).
            ForEach(snap.allyXs.indices, id: \.self) { i in
                Circle()
                    .fill(.cyan)
                    .frame(width: 5, height: 5)
                    .position(x: inset + x(snap.allyXs[i]), y: stripHeight - 12.0)
            }
            ForEach(snap.enemyXs.indices, id: \.self) { i in
                Circle()
                    .fill(.red)
                    .frame(width: 5, height: 5)
                    .position(x: inset + x(snap.enemyXs[i]), y: stripHeight - 12.0)
            }

            // Hero diamond (drawn last so it stays on top of unit dots).
            Image(systemName: "diamond.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .position(x: inset + x(snap.heroX), y: stripHeight - 12.0)
        }
        .frame(width: stripWidth + 16.0, height: stripHeight + 8.0)
    }

    private func minimapMark(worldX: CGFloat, size: CGFloat, color: Color, square: Bool) -> some View {
        Group {
            if square {
                Rectangle().fill(color)
            } else {
                Circle().fill(color)
            }
        }
        .frame(width: size, height: size)
        .position(x: inset + x(worldX), y: stripHeight - 6.0)
    }
}
