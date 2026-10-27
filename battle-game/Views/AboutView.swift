import StoreKit
import SwiftUI
import UIKit

/// About deck. Reached from the main menu's ABOUT button (Route.about).
/// Same command-deck layout as Settings: animated pixel-twilight backdrop,
/// 2-column panel grid on wide screens, 8x8 pixel glyphs, hazard-free.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let supportEmail = "zionstudiosapps@gmail.com"

    private var versionText: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(short) (\(build))"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AboutBackdropView()
                    .ignoresSafeArea(edges: .all)

                VStack(spacing: 12) {
                    header(wide: geo.size.width > 700)
                    ScrollView(.vertical, showsIndicators: false) {
                        content(wide: geo.size.width > 700)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header

    private func header(wide: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                SoundEngine.shared.uiTap()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    AboutPixelIcon(glyph: .back, color: .cyan, size: 12)
                    Text("MENU")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(2)
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.black.opacity(0.7))
                .clipShape(AboutPixelShape(cut: 6))
                .overlay(AboutPixelShape(cut: 6).stroke(.cyan.opacity(0.6), lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("ABOUT")
                    .font(.system(size: wide ? 30 : 24, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .shadow(color: .cyan.opacity(0.6), radius: 10)
                Text("TWILIGHT FRONT // ZION STUDIOS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.cyan.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            if wide {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: .green, radius: 4)
                    Text("LINK STABLE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.green.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.55))
                .clipShape(AboutPixelShape(cut: 5))
                .overlay(AboutPixelShape(cut: 5).stroke(.green.opacity(0.35), lineWidth: 1))
            }

            Text(versionText)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Panels

    @ViewBuilder
    private func content(wide: Bool) -> some View {
        if wide {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)], spacing: 14) {
                gamePanel
                storePanel
                supportPanel
                versionPanel
            }
        } else {
            VStack(spacing: 14) {
                gamePanel
                storePanel
                supportPanel
                versionPanel
            }
        }
    }

    private var gamePanel: some View {
        AboutPanel(title: "THE GAME", tag: "INFO", icon: .info, accent: .cyan) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Hero-led lane battler — hold the line, push mid, break their HQ. Take back the planet Emra region by region, from the Verdant Landing to the Embral Core.")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
                HStack(spacing: 6) {
                    AboutStatChip(label: "REGIONS", value: "\(CampaignData.levels.count)")
                    AboutStatChip(label: "HEROES", value: "\(HeroRoster.heroes.count)")
                    AboutStatChip(label: "SIDES", value: "BLUE VS RED")
                }
            }
        }
    }

    private var storePanel: some View {
        AboutPanel(title: "STORE", tag: "APP STORE", icon: .star, accent: .yellow) {
            VStack(spacing: 10) {
                AboutRow(title: "RATE THE APP", subtitle: "Love the push? Leave a rating",
                         tint: .yellow, glyph: .star) {
                    rateApp()
                }
                AboutRow(title: "MORE APPS", subtitle: "More from Zion Studios",
                         tint: .cyan, glyph: .grid) {
                    openMoreApps()
                }
                Text("Ratings keep the front line supplied. Every star counts, Commander.")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var supportPanel: some View {
        AboutPanel(title: "SUPPORT", tag: "CONTACT", icon: .mail, accent: .green) {
            VStack(spacing: 10) {
                AboutRow(title: "CONTACT SUPPORT", subtitle: supportEmail,
                         tint: .green, glyph: .mail) {
                    openMail(subject: "Support Request")
                }
                AboutRow(title: "REQUEST A FEATURE", subtitle: "Tell us what to build next",
                         tint: .cyan, glyph: .bulb) {
                    openMail(subject: "Feature Request")
                }
                AboutRow(title: "REPORT A BUG", subtitle: "Something broke? Tell us",
                         tint: .red, glyph: .warning) {
                    openMail(subject: "Bug Report")
                }
            }
        }
    }

    private var versionPanel: some View {
        AboutPanel(title: "VERSION", tag: "BUILD", icon: .disk, accent: .white) {
            VStack(spacing: 10) {
                HStack {
                    Text("TWILIGHT BUILD")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Text(versionText)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.cyan)
                }
                HStack(spacing: 6) {
                    Rectangle().fill(.white.opacity(0.2)).frame(width: 24, height: 1)
                    Text("SUPPORT VIA EMAIL")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.35))
                    Rectangle().fill(.white.opacity(0.2)).frame(width: 24, height: 1)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Actions

    private func rateApp() {
        SoundEngine.shared.uiTap()
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        if #available(iOS 18.0, *) {
            Task { try? await AppStore.requestReview(in: scene) }
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func openMoreApps() {
        SoundEngine.shared.uiTap()
        guard let url = URL(string: "https://apps.apple.com/search?term=Zion%20Studios") else { return }
        UIApplication.shared.open(url)
    }

    private func openMail(subject: String) {
        SoundEngine.shared.uiTap()
        var components = URLComponents(string: "mailto:\(supportEmail)")
        components?.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\n\n—\n\(versionText)"),
        ]
        guard let url = components?.url else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Backdrop

/// Animated twilight command horizon, same deck language as Settings:
/// gradient dusk, pixel ridges, rotating radar sweep, perspective grid,
/// drifting embers, scanlines + vignette to seat the UI.
private struct AboutBackdropView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12)) { timeline in
            Canvas { ctx, size in
                AboutBackdrop.draw(ctx: &ctx, size: size,
                                   t: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }
}

private enum AboutBackdrop {
    static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width
        let h = size.height
        let horizon = h * 0.58

        // Dusk sky.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.025, green: 0.035, blue: 0.085),
                                      Color(red: 0.075, green: 0.09, blue: 0.19),
                                      Color(red: 0.24, green: 0.13, blue: 0.22),
                                      Color(red: 0.42, green: 0.20, blue: 0.20)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: horizon)))

        // Stars: deterministic scatter with slow twinkle.
        for i in 0..<90 {
            let sx = CGFloat(hash(i, 11) % 1000) / 1000 * w
            let sy = CGFloat(hash(i, 23) % 1000) / 1000 * horizon * 0.9
            let twinkle = 0.25 + 0.55 * (sin(t * 1.6 + Double(i) * 1.7) + 1) / 2
            let side: CGFloat = i % 7 == 0 ? 3 : 2
            ctx.fill(Path(CGRect(x: sx, y: sy, width: side, height: side)),
                     with: .color(Color.white.opacity(twinkle * 0.6)))
        }

        // Low sun glow behind the ridgeline.
        let sun = CGPoint(x: w * 0.22, y: horizon * 0.94)
        let sunR = min(w, h) * 0.16
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - sunR, y: sun.y - sunR,
                                        width: sunR * 2, height: sunR * 2)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 1, green: 0.55, blue: 0.25, opacity: 0.30),
                                      Color(red: 1, green: 0.35, blue: 0.2, opacity: 0.06),
                                      .clear]),
                    center: sun, startRadius: 0, endRadius: sunR))
        let core = sunR * 0.32
        ctx.fill(Path(CGRect(x: sun.x - core, y: sun.y - core, width: core * 2, height: core * 2)),
                 with: .color(Color(red: 1, green: 0.62, blue: 0.3, opacity: 0.55)))

        // Radar: rings + bearing ticks + rotating sweep, right side.
        let radar = CGPoint(x: w * 0.82, y: horizon * 0.72)
        let radarR = min(w, h) * 0.24
        ctx.fill(Path(ellipseIn: CGRect(x: radar.x - radarR, y: radar.y - radarR,
                                        width: radarR * 2, height: radarR * 2)),
                 with: .radialGradient(
                    Gradient(colors: [Color.cyan.opacity(0.07), .clear]),
                    center: radar, startRadius: 0, endRadius: radarR))
        for k in 1...4 {
            let r = radarR * CGFloat(k) / 4
            ctx.stroke(Path(ellipseIn: CGRect(x: radar.x - r, y: radar.y - r,
                                              width: r * 2, height: r * 2)),
                       with: .color(Color.cyan.opacity(0.10)), lineWidth: 1.5)
        }
        for k in 0..<12 {
            let a = Double(k) * .pi / 6
            let inner = radarR * (k % 3 == 0 ? 0.86 : 0.92)
            var tick = Path()
            tick.move(to: CGPoint(x: radar.x + CGFloat(cos(a)) * inner,
                                  y: radar.y + CGFloat(sin(a)) * inner))
            tick.addLine(to: CGPoint(x: radar.x + CGFloat(cos(a)) * radarR,
                                     y: radar.y + CGFloat(sin(a)) * radarR))
            ctx.stroke(tick, with: .color(Color.cyan.opacity(k % 3 == 0 ? 0.22 : 0.12)),
                       lineWidth: k % 3 == 0 ? 2 : 1)
        }
        let sweepAngle = t * 0.55
        var sweep = Path()
        sweep.move(to: radar)
        sweep.addArc(center: radar, radius: radarR,
                     startAngle: .radians(sweepAngle - 0.55),
                     endAngle: .radians(sweepAngle),
                     clockwise: false)
        sweep.closeSubpath()
        ctx.fill(sweep, with: .color(Color.cyan.opacity(0.10)))
        var beam = Path()
        beam.move(to: radar)
        beam.addLine(to: CGPoint(x: radar.x + CGFloat(cos(sweepAngle)) * radarR,
                                 y: radar.y + CGFloat(sin(sweepAngle)) * radarR))
        ctx.stroke(beam, with: .color(Color.cyan.opacity(0.55)), lineWidth: 2)

        // Two pixel ridgelines (far then near).
        drawRidge(ctx: &ctx, width: w, baseline: horizon, phase: 0.4,
                  amplitude: h * 0.09, step: 22,
                  color: Color(red: 0.10, green: 0.11, blue: 0.20))
        drawRidge(ctx: &ctx, width: w, baseline: horizon + 6, phase: 2.1,
                  amplitude: h * 0.14, step: 16,
                  color: Color(red: 0.045, green: 0.05, blue: 0.10))

        // Perspective floor grid.
        let vanish = CGPoint(x: w * 0.5, y: horizon + 4)
        for k in 0...18 {
            let spread = (CGFloat(k) / 18 - 0.5) * w * 2.4
            var line = Path()
            line.move(to: vanish)
            line.addLine(to: CGPoint(x: w * 0.5 + spread, y: h + 10))
            ctx.stroke(line, with: .color(Color.cyan.opacity(0.055)), lineWidth: 1)
        }
        for k in 0..<12 {
            let p = pow(Double(k) / 11, 2.0)
            let y = horizon + 4 + CGFloat(p) * (h - horizon)
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(line, with: .color(Color.cyan.opacity(0.045)), lineWidth: 1)
        }

        // Rising embers.
        for i in 0..<34 {
            let seed = CGFloat(hash(i, 31) % 1000) / 1000
            let speed = 0.35 + Double(hash(i, 41) % 100) / 100
            let travel = (t * 30 * speed + Double(hash(i, 51) % 500)).truncatingRemainder(
                dividingBy: Double(h) + 40)
            let ex = seed * w + CGFloat(sin(t * 1.2 + Double(i))) * 10
            let ey = h + 10 - CGFloat(travel)
            let alpha = 0.2 + 0.4 * (sin(t * 2 + Double(i)) + 1) / 2
            let size: CGFloat = i % 4 == 0 ? 3 : 2
            let color: Color = i % 5 == 0 ? .cyan : Color(red: 1, green: 0.55, blue: 0.2)
            if ey < horizon + 20 { continue }
            ctx.fill(Path(CGRect(x: ex, y: ey, width: size, height: size)),
                     with: .color(color.opacity(alpha)))
        }

        // Scanlines + vignette to seat the UI.
        var y: CGFloat = 0
        while y < h {
            ctx.fill(Path(CGRect(x: 0, y: y, width: w, height: 1)),
                     with: .color(Color.black.opacity(0.10)))
            y += 4
        }
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(
                    Gradient(colors: [.clear, Color.black.opacity(0.30), Color.black.opacity(0.62)]),
                    center: CGPoint(x: w * 0.5, y: h * 0.45),
                    startRadius: min(w, h) * 0.22,
                    endRadius: max(w, h) * 0.78))
    }

    private static func drawRidge(ctx: inout GraphicsContext, width: CGFloat,
                                  baseline: CGFloat, phase: Double,
                                  amplitude: CGFloat, step: CGFloat, color: Color) {
        var ridge = Path()
        ridge.move(to: CGPoint(x: -step, y: baseline + 4))
        var x: CGFloat = -step
        while x <= width + step {
            let n = sin(Double(x) * 0.010 + phase) * 0.55
                + sin(Double(x) * 0.027 + phase * 2.1) * 0.30
                + sin(Double(x) * 0.061 + phase * 0.7) * 0.15
            let y = baseline - amplitude * CGFloat((n + 1) / 2)
            ridge.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        ridge.addLine(to: CGPoint(x: width + step, y: baseline + 4))
        ridge.closeSubpath()
        ctx.fill(ridge, with: .color(color))
    }

    private static func hash(_ a: Int, _ b: Int) -> Int {
        abs((a &* 73856093) ^ (b &* 19349663)) % 1000
    }
}

// MARK: - Pixel icon set

/// 8x8 pixel-art glyphs drawn as hard-edged blocks. `#` = filled, `.` = empty.
private enum AboutPixelGlyph {
    case back, chevron, info, star, grid, mail, bulb, warning, disk

    var pattern: [String] {
        switch self {
        case .back:
            return ["....#...",
                    "...##...",
                    "..###...",
                    ".####...",
                    "..###...",
                    "...##...",
                    "....#...",
                    "........"]
        case .chevron:
            return ["...#....",
                    "...##...",
                    "...###..",
                    "...####.",
                    "...###..",
                    "...##...",
                    "...#....",
                    "........"]
        case .info:
            return ["...##...",
                    "...##...",
                    "........",
                    "...##...",
                    "...##...",
                    "...##...",
                    "...##...",
                    "...##..."]
        case .star:
            return ["...##...",
                    "...##...",
                    "########",
                    ".######.",
                    "..####..",
                    ".##..##.",
                    "##....##",
                    "........"]
        case .grid:
            return ["###.###.",
                    "###.###.",
                    "###.###.",
                    "........",
                    "###.###.",
                    "###.###.",
                    "###.###.",
                    "........"]
        case .mail:
            return ["........",
                    "########",
                    "#......#",
                    "##....##",
                    "###..###",
                    "#.####.#",
                    "#......#",
                    "########"]
        case .bulb:
            return ["...##...",
                    "..####..",
                    ".##..##.",
                    ".##..##.",
                    "..####..",
                    "...##...",
                    "...##...",
                    "...##..."]
        case .warning:
            return ["...##...",
                    "...##...",
                    "..####..",
                    "..####..",
                    ".##..##.",
                    ".##..##.",
                    "########",
                    "........"]
        case .disk:
            return ["########",
                    "#..##..#",
                    "#..##..#",
                    "#......#",
                    "#.####.#",
                    "#.#..#.#",
                    "#.#..#.#",
                    "########"]
        }
    }
}

private struct AboutPixelIcon: View {
    let glyph: AboutPixelGlyph
    var color: Color = .white
    var size: CGFloat = 14

    var body: some View {
        Canvas { ctx, canvas in
            let rows = glyph.pattern
            let n = CGFloat(rows.count)
            let cell = floor(min(canvas.width, canvas.height) / n)
            let originX = (canvas.width - cell * n) / 2
            let originY = (canvas.height - cell * n) / 2
            for (r, row) in rows.enumerated() {
                for (c, ch) in row.enumerated() where ch == "#" {
                    let rect = CGRect(x: originX + CGFloat(c) * cell,
                                      y: originY + CGFloat(r) * cell,
                                      width: cell, height: cell)
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Panel chrome

private struct AboutPanel<Content: View>: View {
    let title: String
    let tag: String
    let icon: AboutPixelGlyph
    let accent: Color
    @ViewBuilder let content: () -> Content
    private let shape = AboutPixelShape(cut: 9)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: accent.opacity(0.8), radius: 4)
                AboutPixelIcon(glyph: icon, color: accent, size: 13)
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white)
                Spacer(minLength: 6)
                Text(tag)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Rectangle()
                .fill(accent.opacity(0.35))
                .frame(height: 1)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.62))
        .clipShape(shape)
        .overlay(shape.stroke(accent.opacity(0.30), lineWidth: 2))
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(accent)
                .frame(width: 3, height: 20)
                .offset(x: 1, y: 13)
        }
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
    }
}

private struct AboutRow: View {
    let title: String
    let subtitle: String
    let tint: Color
    let glyph: AboutPixelGlyph
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AboutPixelIcon(glyph: glyph, color: tint, size: 15)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(tint)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                AboutPixelIcon(glyph: .chevron, color: .white.opacity(0.35), size: 10)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.black.opacity(0.45))
            .overlay(Rectangle().stroke(tint.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct AboutStatChip: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.cyan)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.white.opacity(0.06))
        .overlay(Rectangle().stroke(.white.opacity(0.18), lineWidth: 1))
    }
}

/// Chamfered pixel panel shape (all four corners cut).
private struct AboutPixelShape: Shape {
    var cut: CGFloat = 8
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        p.closeSubpath()
        return p
    }
}

#Preview {
    NavigationStack { AboutView() }
}
