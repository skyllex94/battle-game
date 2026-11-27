import SwiftUI

/// Ending cutscene — same design language as the prologue: full-bleed
/// pixel art, bare bottom subtitles, tap anywhere to continue, quiet
/// floating MENU + SKIP chips, fade in from black, end card.
///
/// Chapter I (Victory, 4 beats): the defeated Layards lift off in their
/// leftover ships while humanity watches from the rebuilding field.
struct EndCutsceneView: View {
    @Environment(\.dismiss) private var dismiss

    private static let typeSpeed = 0.028

    private let scenes: [EndScene] = [
        EndScene(
            chapter: "CHAPTER I — DEPARTURE",
            lines: [
                "Defeated, the Layards crawled back to their leftover ships.",
                "One by one, they lifted off from the world they tried to steal.",
                "And Emra watched them go — never to return.",
            ]
        ),
        EndScene(
            chapter: "CHAPTER II — VICTORY",
            lines: [
                "Above the home world, the human fleet gathered in triumph.",
                "Carriers, escorts, interceptors — every ship that survived the fire.",
                "From the surface, our cities answered with light.",
                "The world we made our own... is ours again.",
            ]
        ),
    ]

    @State private var sceneIndex = 0
    @State private var lineIndex = 0
    @State private var shownChars = 0
    @State private var fadeBlack = 1.0
    @State private var sceneFade = 0.0
    @State private var finished = false
    @State private var typeTimer: Timer?
    @State private var hintVisible = false
    @State private var hintTimer: Timer?
    @State private var sceneStart = 0.0

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black.ignoresSafeArea(edges: .all)

                TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                    Canvas { ctx, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let elapsed = max(0, t - sceneStart)
                        if sceneIndex == 0 {
                            EndDeparture.draw(ctx: &ctx, size: size, t: t,
                                              elapsed: elapsed)
                        } else {
                            EndArt.drawVictory(ctx: &ctx, size: size, t: t,
                                               elapsed: elapsed, lineIndex: lineIndex)
                        }
                    }
                }
                .ignoresSafeArea(edges: .all)
                .id(sceneIndex)

                Color.black.opacity(sceneFade)
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    if !finished {
                        ZStack(alignment: .bottomTrailing) {
                            subtitleView
                            skipButton
                                .padding(.trailing, 4)
                                .padding(.bottom, 8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 0)

                if finished {
                    endCard
                }

                Color.black.opacity(fadeBlack)
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)
            }
            .onTapGesture {
                if !finished { advance() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            sceneStart = Date().timeIntervalSinceReferenceDate
            withAnimation(.easeOut(duration: 1.8)) { fadeBlack = 0 }
            startTyping()
        }
        .onDisappear {
            typeTimer?.invalidate()
            typeTimer = nil
            hintTimer?.invalidate()
            hintTimer = nil
        }
        .onChange(of: sceneIndex) { _ in
            sceneStart = Date().timeIntervalSinceReferenceDate
            startTyping()
        }
        .onChange(of: lineIndex) { _ in startTyping() }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                SoundEngine.shared.uiTap()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("MENU")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.35))
                .clipShape(EndChipShape(cut: 6))
                .overlay(EndChipShape(cut: 6).stroke(.white.opacity(0.25), lineWidth: 1))
            }
            Spacer()
        }
    }

    private var skipButton: some View {
        Button {
            SoundEngine.shared.uiTap()
            dismiss()
        } label: {
            Text("SKIP ▸▸")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.35))
                .clipShape(EndChipShape(cut: 6))
                .overlay(EndChipShape(cut: 6).stroke(.white.opacity(0.25), lineWidth: 1))
        }
    }

    private var subtitleView: some View {
        let full = scenes[sceneIndex].lines[lineIndex]
        let shown = String(full.prefix(shownChars))
        let typing = shownChars < full.count
        return VStack(spacing: 8) {
            Text(shown + (typing ? "▌" : ""))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .shadow(color: .black.opacity(0.95), radius: 4)
                .shadow(color: .black.opacity(0.9), radius: 1)
                .padding(.horizontal, 28)
                .frame(minHeight: 60, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(typing ? " " : "— TAP TO CONTINUE —")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(.white.opacity(0.5))
                .shadow(color: .black.opacity(0.9), radius: 2)
                .opacity(hintVisible && !typing ? 1 : 0)
                .blink(period: 2.0)
        }
        .padding(.bottom, 6)
    }

    private var endCard: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea(edges: .all)
            VStack(spacing: 12) {
                Text("EMRA IS OURS")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .shadow(color: .cyan.opacity(0.6), radius: 12)
                Text("ENDING COMPLETE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.yellow)
                HStack(spacing: 12) {
                    Button {
                        SoundEngine.shared.uiTap()
                        replay()
                    } label: {
                        Text("↻ REPLAY")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.black.opacity(0.8))
                            .overlay(Rectangle().stroke(.cyan.opacity(0.6), lineWidth: 2))
                    }
                    Button {
                        SoundEngine.shared.uiTap()
                        dismiss()
                    } label: {
                        Text("MENU ▸")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.yellow)
                    }
                }
                .padding(.top, 6)
            }
            .padding(24)
            .background(.black.opacity(0.85))
            .overlay(Rectangle().stroke(.yellow.opacity(0.5), lineWidth: 2))
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Flow

    private var isLastLine: Bool {
        lineIndex >= scenes[sceneIndex].lines.count - 1
    }

    private var isLastScene: Bool {
        sceneIndex >= scenes.count - 1
    }

    private func startTyping() {
        typeTimer?.invalidate()
        hintTimer?.invalidate()
        hintVisible = false
        shownChars = 0
        let total = scenes[sceneIndex].lines[lineIndex].count
        typeTimer = Timer.scheduledTimer(withTimeInterval: Self.typeSpeed, repeats: true) { timer in
            if shownChars < total {
                shownChars = min(total, shownChars + 2)
            } else {
                timer.invalidate()
                scheduleHint()
            }
        }
        if let typeTimer { RunLoop.main.add(typeTimer, forMode: .common) }
    }

    private func scheduleHint() {
        hintTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            withAnimation(.easeIn(duration: 0.6)) { hintVisible = true }
        }
        hintTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func advance() {
        SoundEngine.shared.uiTap()
        let full = scenes[sceneIndex].lines[lineIndex]
        if shownChars < full.count {
            shownChars = full.count
            typeTimer?.invalidate()
            scheduleHint()
            return
        }
        if !isLastLine {
            lineIndex += 1
            return
        }
        if !isLastScene {
            withAnimation(.easeIn(duration: 0.45)) { sceneFade = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                sceneIndex += 1
                lineIndex = 0
                withAnimation(.easeOut(duration: 0.8)) { sceneFade = 0 }
            }
            return
        }
        withAnimation(.easeIn(duration: 0.4)) { finished = true }
    }

    private func replay() {
        finished = false
        sceneIndex = 0
        lineIndex = 0
        sceneStart = Date().timeIntervalSinceReferenceDate
        fadeBlack = 1
        withAnimation(.easeOut(duration: 1.2)) { fadeBlack = 0 }
    }
}

// MARK: - Model

private struct EndScene {
    let chapter: String
    let lines: [String]
}

private struct EndChipShape: Shape {
    var cut: CGFloat = 6
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

private extension View {
    func blink(period: Double = 2.0) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 12)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            self.opacity(0.75 + 0.25 * (sin(t * .pi * 2 / period) + 1) / 2)
        }
    }
}

// MARK: - Victory art

/// The Layards leave: three leftover wedges climb out of a rebuilding
/// field at dawn, staggered one-shot ascents, then they stay gone.
private enum EndDeparture {

    static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double, elapsed: Double) {
        let w = size.width, h = size.height
        let gy = h * 0.68
        let alien = Color(red: 1.0, green: 0.25, blue: 0.25)

        // Pale morning after the war.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.10, green: 0.20, blue: 0.42),
                                      Color(red: 0.38, green: 0.46, blue: 0.58),
                                      Color(red: 0.95, green: 0.68, blue: 0.42)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: gy)))
        let sun = CGPoint(x: w * 0.20, y: gy - 64)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 80, y: sun.y - 80, width: 160, height: 160)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.6, opacity: 0.5), .clear]),
                    center: sun, startRadius: 0, endRadius: 80))
        EndArt.epx(ctx: &ctx, x: sun.x - 10, y: sun.y - 10, w: 20, h: 20,
                   color: Color(red: 1, green: 0.93, blue: 0.75))
        EndArt.ecloud(ctx: &ctx, width: w, seed: 91, y: h * 0.30, s: 1.1, t: t, speed: 7)
        EndArt.ecloud(ctx: &ctx, width: w, seed: 97, y: h * 0.42, s: 0.8, t: t, speed: 11)
        for i in 0..<4 {
            let span = w + 60
            let bx = CGFloat((t * (20 + Double(i) * 5) + Double(i) * 211).truncatingRemainder(dividingBy: Double(span))) - 30
            let by = h * 0.22 + CGFloat(i) * 13 + sin(t * 1.1 + Double(i)) * 6
            let flap: CGFloat = Int(t * 6 + Double(i)) % 2 == 0 ? 3 : 1
            var gull = Path()
            gull.move(to: CGPoint(x: bx - 6, y: by - flap))
            gull.addLine(to: CGPoint(x: bx, y: by))
            gull.addLine(to: CGPoint(x: bx + 6, y: by - flap))
            ctx.stroke(gull, with: .color(Color.black.opacity(0.55)), lineWidth: 2)
        }

        // Rebuilding ridge: fresh towers with a crane, all rooted.
        EndArt.eridge(ctx: &ctx, width: w, baseline: h * 0.60, phase: 0.9, amp: h * 0.05,
                      step: 18, color: Color(red: 0.22, green: 0.24, blue: 0.36), floor: gy)
        // Low fire-glow throbbing behind the ruins.
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.02 - 90, y: gy - 120, width: 180, height: 130)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 1, green: 0.45, blue: 0.15,
                                            opacity: 0.30 + 0.06 * sin(t * 2.2)), .clear]),
                    center: CGPoint(x: w * 0.02, y: gy - 55), startRadius: 0, endRadius: 90))
        // War's leftovers on the west side: ruined blocks, two still burning.
        for i in 0..<4 {
            let rx = w * 0.03 + CGFloat(i) * 44
            let rh = h * (0.05 + CGFloat(EndArt.ehash(i, 441) % 60) / 100 * 0.06)
            EndArt.epx(ctx: &ctx, x: rx, y: gy - rh, w: 34, h: rh,
                       color: Color(red: 0.13, green: 0.11, blue: 0.14))
            EndArt.epx(ctx: &ctx, x: rx + 4, y: gy - rh - 10, w: 12, h: 10,
                       color: Color(red: 0.13, green: 0.11, blue: 0.14))
            EndArt.epx(ctx: &ctx, x: rx + 20, y: gy - rh - 7, w: 10, h: 7,
                       color: Color(red: 0.13, green: 0.11, blue: 0.14))
            if i % 2 == 0 {
                let fl = 0.5 + 0.5 * sin(t * 9 + Double(i) * 2)
                EndArt.epx(ctx: &ctx, x: rx + 8, y: gy - rh - 4, w: 14, h: 12,
                           color: Color(red: 1, green: 0.5, blue: 0.1, opacity: 0.5 + 0.4 * fl))
            }
        }
        // Smoke columns still boiling off the ruins.
        for i in 0..<5 {
            let scx = w * 0.05 + CGFloat(i) * 40 + sin(t * 0.5 + Double(i)) * 10
            var syy = gy - h * 0.22
            var sw: CGFloat = 9
            while syy > h * 0.10 {
                ctx.fill(Path(CGRect(x: scx, y: syy, width: sw, height: 9)),
                         with: .color(Color.gray.opacity(0.26)))
                syy -= 11; sw += 2.2
            }
        }
        for (i, tx) in [w * 0.24, w * 0.72].enumerated() {
            let th = h * (i == 0 ? 0.15 : 0.19)
            EndArt.epx(ctx: &ctx, x: tx - 22, y: gy - th, w: 44, h: th,
                       color: Color(red: 0.30, green: 0.32, blue: 0.42))
            var wy = gy - th + 8
            while wy < gy - 6 {
                EndArt.epx(ctx: &ctx, x: tx - 14, y: wy, w: 8, h: 6,
                           color: Color(red: 1, green: 0.85, blue: 0.55, opacity: 0.85))
                EndArt.epx(ctx: &ctx, x: tx + 6, y: wy, w: 8, h: 6,
                           color: Color(red: 1, green: 0.85, blue: 0.55, opacity: 0.85))
                wy += 13
            }
        }

        // Trampled field, already greening back.
        ctx.fill(Path(CGRect(x: 0, y: gy, width: w, height: h - gy)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.35, green: 0.38, blue: 0.20),
                                      Color(red: 0.14, green: 0.13, blue: 0.10)]),
                    startPoint: CGPoint(x: 0, y: gy), endPoint: CGPoint(x: 0, y: h)))

        // A Layard scout that never made it off the ground.
        do {
            let wx = w * 0.30
            let wy2 = gy + 40
            EndArt.epx(ctx: &ctx, x: wx - 30, y: wy2, w: 60, h: 12,
                       color: Color(red: 0.09, green: 0.08, blue: 0.09))
            EndArt.epx(ctx: &ctx, x: wx - 16, y: wy2 - 10, w: 30, h: 12,
                       color: Color(red: 0.11, green: 0.10, blue: 0.11))
            let dying = 0.4 + 0.3 * sin(t * 1.8)
            EndArt.epx(ctx: &ctx, x: wx - 6, y: wy2 - 4, w: 12, h: 6,
                       color: Color(red: 1.0, green: 0.25, blue: 0.25, opacity: dying))
            ctx.fill(Path(ellipseIn: CGRect(x: wx - 26, y: wy2 - 12, width: 52, height: 24)),
                     with: .radialGradient(
                        Gradient(colors: [Color(red: 1, green: 0.25, blue: 0.25, opacity: 0.25 * dying), .clear]),
                        center: CGPoint(x: wx, y: wy2), startRadius: 0, endRadius: 26))
            let wsmoke = CGFloat((t * 26).truncatingRemainder(dividingBy: 48))
            ctx.fill(Path(CGRect(x: wx + 4, y: wy2 - 12 - wsmoke, width: 9, height: 7)),
                     with: .color(Color.gray.opacity(0.4 * (1 - wsmoke / 48))))
            for j in 0..<5 {
                EndArt.epx(ctx: &ctx, x: wx - 34 + CGFloat(j) * 15, y: wy2 + 13, w: 5, h: 4,
                           color: Color(red: 0.16, green: 0.14, blue: 0.14))
            }
        }

        // THEY LEAVE: three wedges climb out, staggered, one-shot.
        for i in 0..<3 {
            let start = Double(i) * 4.5
            let raw = min(1, max(0, (elapsed - start) / 12))
            if raw <= 0 { continue }
            let eased = 1 - pow(1 - raw, 2)
            let baseX = w * (0.30 + Double(i) * 0.20) + sin(t * 0.5 + Double(i)) * 4 * (1 - eased)
            let shipY = gy - 30 - eased * (gy + 60)
            if shipY < -50 { continue }
            let scale = 1 - eased * 0.55
            var trail = Path()
            trail.move(to: CGPoint(x: baseX - 6 * scale, y: shipY + 14 * scale))
            trail.addLine(to: CGPoint(x: baseX + 6 * scale, y: shipY + 14 * scale))
            trail.addLine(to: CGPoint(x: baseX + 16, y: gy))
            trail.addLine(to: CGPoint(x: baseX - 16, y: gy))
            trail.closeSubpath()
            ctx.fill(trail, with: .color(alien.opacity(0.20 * (1 - eased))))
            drawRiser(ctx: &ctx, center: CGPoint(x: baseX, y: shipY), width: 120 * scale,
                      t: t, seed: i)
        }

        // Mech sentries standing guard over the field — small and still.
        for (i, mx) in [w * 0.40, w * 0.62].enumerated() {
            drawMech(ctx: &ctx, feet: CGPoint(x: mx, y: gy + 36 + CGFloat(i) * 8), t: t, seed: i * 3)
        }

        // Humanity watches from the rise, banners high.
        for k in 0..<7 {
            let sx = w * 0.5 - 90 + CGFloat(k) * 30
            let sy = h - 84 + CGFloat((k % 2) * 6)
            let step = Int(t * 2 + Double(k)) % 2 == 0
            let dark = Color(red: 0.12, green: 0.13, blue: 0.18)
            EndArt.epx(ctx: &ctx, x: sx - 2, y: sy - 6, w: 4, h: 6, color: dark)
            EndArt.epx(ctx: &ctx, x: sx - 3, y: sy - 10, w: 6, h: 4, color: dark)
            EndArt.epx(ctx: &ctx, x: sx + 1, y: sy - 9 + (step ? -1 : 0), w: 3, h: 6,
                       color: Color(red: 0.30, green: 0.34, blue: 0.42))
        }
        for (i, fx) in [w * 0.5 - 120, w * 0.5 + 120].enumerated() {
            EndArt.epx(ctx: &ctx, x: fx, y: h - 130, w: 2, h: 48,
                       color: Color(red: 0.50, green: 0.53, blue: 0.60))
            let wave = CGFloat(sin(t * 4 + Double(i) * 2) * 2)
            EndArt.epx(ctx: &ctx, x: fx + 2, y: h - 130, w: 12, h: 18, color: .cyan.opacity(0.9))
            EndArt.epx(ctx: &ctx, x: fx + 14, y: h - 130 + wave, w: 10, h: 18, color: .cyan.opacity(0.7))
            EndArt.epx(ctx: &ctx, x: fx + 4, y: h - 126, w: 7, h: 6, color: .white)
        }
        // Our ride home: a dropship on its pad, ramp down, crates aboard.
        do {
            let px2 = w * 0.80
            EndArt.epx(ctx: &ctx, x: px2 - 45, y: h - 108, w: 90, h: 8,
                       color: Color(red: 0.25, green: 0.26, blue: 0.30))
            EndArt.epx(ctx: &ctx, x: px2 - 45, y: h - 108, w: 90, h: 2, color: .yellow.opacity(0.7))
            for k in 0..<5 {
                let lx = px2 - 39 + CGFloat(k) * 18
                let chase = (Int(t * 4) + k) % 5 < 2
                EndArt.epx(ctx: &ctx, x: lx, y: h - 112, w: 5, h: 5,
                           color: chase ? .yellow : .red.opacity(0.4))
            }
            EndArt.epx(ctx: &ctx, x: px2 - 28, y: h - 128, w: 56, h: 16,
                       color: Color(red: 0.66, green: 0.70, blue: 0.78))
            EndArt.epx(ctx: &ctx, x: px2 - 28, y: h - 128, w: 56, h: 3,
                       color: Color.white.opacity(0.8))
            EndArt.epx(ctx: &ctx, x: px2 + 8, y: h - 126, w: 16, h: 5, color: .cyan.opacity(0.9))
            EndArt.epx(ctx: &ctx, x: px2 - 32, y: h - 112, w: 5, h: 12, color: .black)
            EndArt.epx(ctx: &ctx, x: px2 + 27, y: h - 112, w: 5, h: 12, color: .black)
            var ramp = Path()
            ramp.move(to: CGPoint(x: px2 - 28, y: h - 114))
            ramp.addLine(to: CGPoint(x: px2 - 44, y: h - 100))
            ramp.addLine(to: CGPoint(x: px2 - 40, y: h - 100))
            ramp.addLine(to: CGPoint(x: px2 - 24, y: h - 114))
            ramp.closeSubpath()
            ctx.fill(ramp, with: .color(Color(red: 0.45, green: 0.47, blue: 0.54)))
            if Int(t * 1.5) % 2 == 0 {
                EndArt.epx(ctx: &ctx, x: px2 - 2, y: h - 136, w: 5, h: 5, color: .red)
            }
            EndArt.epx(ctx: &ctx, x: px2 + 34, y: h - 114, w: 13, h: 11,
                       color: Color(red: 0.42, green: 0.40, blue: 0.30))
            // Claim banner planted by the pad, snapping in the wind.
            EndArt.epx(ctx: &ctx, x: px2 - 62, y: h - 168, w: 3, h: 62,
                       color: Color(red: 0.55, green: 0.58, blue: 0.66))
            let wave2 = CGFloat(sin(t * 5) * 2)
            EndArt.epx(ctx: &ctx, x: px2 - 59, y: h - 168, w: 16, h: 22, color: .cyan.opacity(0.95))
            EndArt.epx(ctx: &ctx, x: px2 - 43, y: h - 168 + wave2, w: 12, h: 22, color: .cyan.opacity(0.75))
            EndArt.epx(ctx: &ctx, x: px2 - 57, y: h - 162, w: 9, h: 8, color: .white)
        }

        // Foreground rise, grass coming back.
        EndArt.epx(ctx: &ctx, x: -16, y: h - 44, w: 220, h: 44,
                   color: Color(red: 0.10, green: 0.11, blue: 0.08))
        EndArt.epx(ctx: &ctx, x: w - 190, y: h - 36, w: 206, h: 36,
                   color: Color(red: 0.10, green: 0.11, blue: 0.08))
        var tuftX: CGFloat = 20
        while tuftX < 190 {
            EndArt.epx(ctx: &ctx, x: tuftX, y: h - 52, w: 3, h: 8,
                       color: Color(red: 0.30, green: 0.60, blue: 0.28))
            tuftX += 22
        }

        // One last sweep from a human searchlight + ash on the wind.
        do {
            let lampX = w * 0.12
            let sweepA = sin(t * 0.5) * 0.55
            let blen: CGFloat = 320
            let tip = CGPoint(x: lampX + CGFloat(sin(Double(sweepA))) * blen,
                              y: gy - CGFloat(cos(Double(sweepA))) * blen)
            var sl = Path()
            sl.move(to: CGPoint(x: lampX - 3, y: gy))
            sl.addLine(to: CGPoint(x: lampX + 3, y: gy))
            sl.addLine(to: CGPoint(x: tip.x + 16, y: tip.y))
            sl.addLine(to: CGPoint(x: tip.x - 16, y: tip.y))
            sl.closeSubpath()
            ctx.fill(sl, with: .color(Color.white.opacity(0.07)))
        }
        for i in 0..<26 {
            let span = w + 40
            let ax = CGFloat((Double(EndArt.ehash(i, 451) % 1000) / 1000 * Double(span)
                + t * (8 + Double(i % 5) * 3)).truncatingRemainder(dividingBy: Double(span))) - 20
            let ay = CGFloat((Double(EndArt.ehash(i, 453) % 1000) / 1000 * Double(h)
                + t * (12 + Double(i % 4) * 4)).truncatingRemainder(dividingBy: Double(h + 20))) - 10
            ctx.fill(Path(CGRect(x: ax, y: ay, width: 2, height: 2)),
                     with: .color(Color.gray.opacity(0.5)))
        }

        // Ground fog drifting low over the field.
        for i in 0..<4 {
            let span = w + 240
            let fogX = CGFloat((Double(i) * 173 + t * (9 + Double(i) * 3))
                .truncatingRemainder(dividingBy: Double(span))) - 120
            let fogY = gy + 12 + CGFloat(i) * 14
            ctx.fill(Path(ellipseIn: CGRect(x: fogX, y: fogY, width: 190, height: 22)),
                     with: .radialGradient(
                        Gradient(colors: [Color(red: 0.7, green: 0.75, blue: 0.85, opacity: 0.10), .clear]),
                        center: CGPoint(x: fogX + 95, y: fogY + 11), startRadius: 0, endRadius: 95))
        }
        // Celebration bunting strung over the watchers.
        do {
            let bx0 = w * 0.5 - 150
            let bx1 = w * 0.5 + 150
            let byTop = h - 162
            EndArt.epx(ctx: &ctx, x: bx0, y: byTop, w: 3, h: 76, color: Color(red: 0.4, green: 0.42, blue: 0.5))
            EndArt.epx(ctx: &ctx, x: bx1, y: byTop, w: 3, h: 76, color: Color(red: 0.4, green: 0.42, blue: 0.5))
            for k in 0...16 {
                let f = CGFloat(k) / 16
                let px = bx0 + 3 + f * (bx1 - bx0 - 3)
                let py = byTop + 6 + sin(f * .pi) * 20
                let bulb: Color = (k + Int(t * 2)) % 2 == 0 ? .cyan : .yellow
                EndArt.epx(ctx: &ctx, x: px - 2, y: py - 2, w: 4, h: 4, color: bulb.opacity(0.9))
            }
        }
        // A rover parked by the pad, headlight on.
        do {
            let rx = w * 0.60
            let ry = gy + 52
            EndArt.epx(ctx: &ctx, x: rx - 14, y: ry - 10, w: 28, h: 8,
                       color: Color(red: 0.60, green: 0.58, blue: 0.52))
            EndArt.epx(ctx: &ctx, x: rx - 6, y: ry - 16, w: 14, h: 6,
                       color: Color(red: 0.38, green: 0.42, blue: 0.48))
            EndArt.epx(ctx: &ctx, x: rx - 10, y: ry - 4, w: 7, h: 7, color: .black)
            EndArt.epx(ctx: &ctx, x: rx + 4, y: ry - 4, w: 7, h: 7, color: .black)
            var beam = Path()
            beam.move(to: CGPoint(x: rx + 14, y: ry - 8))
            beam.addLine(to: CGPoint(x: rx + 44, y: ry - 2))
            beam.addLine(to: CGPoint(x: rx + 44, y: ry - 12))
            beam.closeSubpath()
            ctx.fill(beam, with: .color(Color.yellow.opacity(0.15)))
            EndArt.epx(ctx: &ctx, x: rx + 14, y: ry - 9, w: 3, h: 3, color: .yellow.opacity(0.9))
        }
        // Wildflowers in the foreground grass.
        for i in 0..<14 {
            let fx = CGFloat(EndArt.ehash(i, 461) % 1000) / 1000 * w
            let fy = h - 38 + CGFloat(EndArt.ehash(i, 463) % 22)
            let fc: Color = [Color.white, Color.yellow, Color(red: 1, green: 0.6, blue: 0.7)][i % 3]
            EndArt.epx(ctx: &ctx, x: fx, y: fy, w: 2, h: 3, color: fc.opacity(0.9))
            EndArt.epx(ctx: &ctx, x: fx, y: fy + 3, w: 2, h: 3,
                       color: Color(red: 0.25, green: 0.5, blue: 0.25))
        }

        EndArt.escan(ctx: &ctx, size: size)
        EndArt.evig(ctx: &ctx, size: size)
    }

    /// A battered Layard wedge climbing out — red ports straining.
    private static func drawRiser(ctx: inout GraphicsContext, center c: CGPoint,
                                  width shipW: CGFloat, t: Double, seed: Int) {
        let hull = Color(red: 0.12, green: 0.10, blue: 0.11)
        let alien = Color(red: 1.0, green: 0.25, blue: 0.25)
        let hgt = shipW * 0.24
        var body = Path()
        body.move(to: CGPoint(x: c.x - shipW / 2, y: c.y))
        body.addLine(to: CGPoint(x: c.x - shipW * 0.16, y: c.y - hgt))
        body.addLine(to: CGPoint(x: c.x + shipW * 0.16, y: c.y - hgt))
        body.addLine(to: CGPoint(x: c.x + shipW / 2, y: c.y))
        body.addLine(to: CGPoint(x: c.x, y: c.y + hgt * 0.6))
        body.closeSubpath()
        ctx.fill(body, with: .color(hull))
        let ports = 7
        for i in 0..<ports {
            let k = CGFloat(i) / CGFloat(ports - 1) - 0.5
            let flick = 0.5 + 0.5 * sin(t * 11 + Double(i + seed * 3))
            EndArt.epx(ctx: &ctx, x: c.x + k * shipW * 0.6 - 4, y: c.y + 2,
                       w: 8, h: max(3, 5 * flick),
                       color: alien.opacity(0.5 + 0.4 * flick))
        }
        if Int(t * 2 + Double(seed)) % 2 == 0 {
            EndArt.epx(ctx: &ctx, x: c.x - 3, y: c.y - hgt - 6, w: 6, h: 6,
                       color: alien.opacity(0.9))
        }
    }

    /// Human mech standing sentry: smaller, still, visor lit.
    private static func drawMech(ctx: inout GraphicsContext, feet p: CGPoint, t: Double, seed: Int) {
        let s: CGFloat = 0.62
        let saved = ctx.transform
        ctx.translateBy(x: p.x, y: p.y)
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: -p.x, y: -p.y)
        defer { ctx.transform = saved }
        let armor = Color(red: 0.48, green: 0.52, blue: 0.58)
        let dark = Color(red: 0.22, green: 0.24, blue: 0.30)
        // Planted legs + feet.
        EndArt.epx(ctx: &ctx, x: p.x - 11, y: p.y - 18, w: 7, h: 16, color: dark)
        EndArt.epx(ctx: &ctx, x: p.x + 4, y: p.y - 18, w: 7, h: 16, color: dark)
        EndArt.epx(ctx: &ctx, x: p.x - 13, y: p.y - 4, w: 11, h: 4, color: dark)
        EndArt.epx(ctx: &ctx, x: p.x + 2, y: p.y - 4, w: 11, h: 4, color: dark)
        // Hips + torso with panel lines.
        EndArt.epx(ctx: &ctx, x: p.x - 9, y: p.y - 24, w: 18, h: 7, color: dark)
        EndArt.epx(ctx: &ctx, x: p.x - 12, y: p.y - 42, w: 24, h: 18, color: armor)
        EndArt.epx(ctx: &ctx, x: p.x - 12, y: p.y - 42, w: 24, h: 2, color: Color.white.opacity(0.4))
        EndArt.epx(ctx: &ctx, x: p.x - 2, y: p.y - 40, w: 4, h: 14, color: dark.opacity(0.7))
        // Chest light.
        if Int(t * 1.5 + Double(seed)) % 2 == 0 {
            EndArt.epx(ctx: &ctx, x: p.x + 6, y: p.y - 36, w: 4, h: 4, color: .cyan)
        }
        // Shoulder pads.
        EndArt.epx(ctx: &ctx, x: p.x - 19, y: p.y - 42, w: 8, h: 11, color: armor)
        EndArt.epx(ctx: &ctx, x: p.x + 11, y: p.y - 42, w: 8, h: 11, color: armor)
        // Head + visor slit.
        EndArt.epx(ctx: &ctx, x: p.x - 6, y: p.y - 50, w: 12, h: 8, color: dark)
        EndArt.epx(ctx: &ctx, x: p.x - 6, y: p.y - 48, w: 12, h: 2, color: .cyan.opacity(0.95))
        // Antenna + tip blink.
        EndArt.epx(ctx: &ctx, x: p.x + 5, y: p.y - 58, w: 2, h: 8, color: dark)
        if Int(t * 2 + Double(seed)) % 2 == 0 {
            EndArt.epx(ctx: &ctx, x: p.x + 3, y: p.y - 62, w: 5, h: 5, color: .red)
        }
        // Arm cannon lowered.
        EndArt.epx(ctx: &ctx, x: p.x + 11, y: p.y - 34, w: 20, h: 6, color: dark)
        EndArt.epx(ctx: &ctx, x: p.x + 29, y: p.y - 33, w: 4, h: 4, color: Color.gray)
    }
}

// MARK: - Victory art

/// Morning after the war: the Layard remnants lift off one by one while
/// humanity watches from a rebuilding field. Departures are one-shot —
/// each ship climbs, shrinks into the sky and stays gone.
private enum EndArt {

    static func drawVictory(ctx: inout GraphicsContext, size: CGSize, t: Double,
                            elapsed: Double, lineIndex: Int) {
        let w = size.width, h = size.height

        // Deep space over the home world.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.008, green: 0.015, blue: 0.06),
                                      Color(red: 0.03, green: 0.07, blue: 0.18),
                                      Color(red: 0.08, green: 0.15, blue: 0.30)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.60, y: h * 0.05, width: w * 0.5, height: h * 0.3)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 0.3, green: 0.2, blue: 0.5, opacity: 0.18), .clear]),
                    center: CGPoint(x: w * 0.85, y: h * 0.2), startRadius: 0, endRadius: w * 0.25))
        for i in 0..<130 {
            let sx = CGFloat(ehash(i, 911) % 1000) / 1000 * w
            let sy = CGFloat(ehash(i, 913) % 1000) / 1000 * h
            let tw = 0.25 + 0.6 * (sin(t * 1.6 + Double(i) * 2.1) + 1) / 2
            let s: CGFloat = i % 10 == 0 ? 3 : 2
            ctx.fill(Path(CGRect(x: sx, y: sy, width: s, height: s)),
                     with: .color(Color.white.opacity(tw * 0.7)))
        }

        // EMRA'S LIMB below, alive with lights.
        let pc = CGPoint(x: w * 0.5, y: h * 1.58)
        let pr = h * 1.0
        ctx.fill(Path(ellipseIn: CGRect(x: pc.x - pr * 1.12, y: pc.y - pr * 1.12,
                                        width: pr * 2.24, height: pr * 2.24)),
                 with: .radialGradient(
                    Gradient(colors: [Color.cyan.opacity(0.25), .clear]),
                    center: pc, startRadius: pr * 0.8, endRadius: pr * 1.12))
        epxCircle(ctx: &ctx, center: pc, r: pr,
                  color: Color(red: 0.10, green: 0.26, blue: 0.52))
        epxCircle(ctx: &ctx, center: CGPoint(x: pc.x - pr * 0.1, y: pc.y - pr * 0.12), r: pr * 0.86,
                  color: Color(red: 0.16, green: 0.38, blue: 0.66))
        var limb = Path()
        limb.addArc(center: pc, radius: pr + 2,
                    startAngle: .radians(.pi * 1.08), endAngle: .radians(.pi * 1.92),
                    clockwise: false)
        ctx.stroke(limb, with: .color(Color.cyan.opacity(0.8)), lineWidth: 3)
        // City lights glittering on the night side.
        for i in 0..<44 {
            let a = Double.pi * (1.12 + Double(ehash(i, 925) % 76) / 100)
            let rr = pr * (0.965 + CGFloat(ehash(i, 927) % 3) / 100)
            let lx = pc.x + cos(a) * rr
            let ly = pc.y + sin(a) * rr
            let tw = (sin(t * 2 + Double(i) * 1.7) + 1) / 2
            ctx.fill(Path(CGRect(x: lx, y: ly, width: 2.5, height: 2.5)),
                     with: .color(Color(red: 1, green: 0.8, blue: 0.45).opacity(0.35 + 0.5 * tw)))
        }
        // Cloud streaks sliding along the limb.
        for i in 0..<5 {
            let a = Double.pi * (1.2 + Double(ehash(i, 929) % 60) / 100)
            let rr = pr * 0.985
            let cx = pc.x + cos(a) * rr + CGFloat((t * 6 + Double(i) * 90).truncatingRemainder(dividingBy: 120)) - 60
            let cy = pc.y + sin(a) * rr
            epx(ctx: &ctx, x: cx - 13, y: cy, w: 26, h: 4,
                color: Color.white.opacity(0.28))
        }

        // THE FLEET: one arrival burn, then it holds formation over its world.
        let arr = 1 - pow(1 - min(1, elapsed / 11), 3)
        let fleetX = -w * 0.45 + arr * w * 0.95
        let fleetY = h * 0.32 + sin(t * 0.6) * 4
        let flagshipW = min(w * 0.52, 400.0)
        ctx.fill(Path(ellipseIn: CGRect(x: fleetX - flagshipW * 0.62, y: fleetY - 30,
                                        width: flagshipW * 0.5, height: 70)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 0.4, green: 0.7, blue: 1.0, opacity: 0.30 * arr), .clear]),
                    center: CGPoint(x: fleetX - flagshipW * 0.45, y: fleetY),
                    startRadius: 0, endRadius: flagshipW * 0.25))
        drawCarrier(ctx: &ctx, center: CGPoint(x: fleetX, y: fleetY), width: flagshipW, t: t)
        for (i, off) in [(-150.0, -74.0), (-150.0, 74.0), (-245.0, -132.0), (-245.0, 132.0)].enumerated() {
            let k = flagshipW / 400
            let ex = fleetX + CGFloat(off.0) * k
            let ey = fleetY + CGFloat(off.1) * k + sin(t * 0.8 + Double(i) * 1.9) * 3
            drawFrigate(ctx: &ctx, center: CGPoint(x: ex, y: ey),
                        width: 92 * k, t: t, seed: i)
        }

        // Celebration beams rising from the surface cities.
        let beamK: CGFloat = lineIndex >= 2 ? 1.0 : 0.55
        for i in 0..<5 {
            let a = Double.pi * (1.25 + Double(i) * 0.125)
            let bx = pc.x + cos(a) * pr
            let by = pc.y + sin(a) * pr
            let sway = sin(t * 0.9 + Double(i) * 2.2) * 10
            let beamC: Color = i % 2 == 0 ? Color(red: 1, green: 0.8, blue: 0.4) : .cyan
            var pillar = Path()
            pillar.move(to: CGPoint(x: bx - 3, y: by))
            pillar.addLine(to: CGPoint(x: bx + 3, y: by))
            pillar.addLine(to: CGPoint(x: bx + sway + 10, y: by - h * 0.30))
            pillar.addLine(to: CGPoint(x: bx + sway - 10, y: by - h * 0.30))
            pillar.closeSubpath()
            ctx.fill(pillar, with: .color(beamC.opacity(0.10 * beamK)))
            epx(ctx: &ctx, x: bx - 3, y: by - 6, w: 6, h: 6, color: beamC.opacity(0.8 * beamK))
        }
        // Fireworks once the defeat is admitted.
        if lineIndex >= 1 {
            let party: [Color] = [Color(red: 1, green: 0.8, blue: 0.35), .cyan, .white]
            for i in 0..<3 {
                let cyc = (t * 0.5 + Double(i) * 2.0).truncatingRemainder(dividingBy: 6)
                if cyc < 1.2 {
                    let fx = w * (0.20 + Double(i) * 0.30)
                    let fy = h * (0.14 + Double(ehash(i, 931) % 10) / 100)
                    drawFirework(ctx: &ctx, at: CGPoint(x: fx, y: fy), k: cyc / 1.2,
                                 maxR: 46, color: party[i])
                }
            }
        }

        // The Layard hulk: broken, tumbling, going dark in the corner.
        let hulkX = w * 0.84 + sin(t * 0.1) * 8
        let hulkY = h * 0.20 + cos(t * 0.13) * 6
        drawHulk(ctx: &ctx, center: CGPoint(x: hulkX, y: hulkY), width: 110, t: t)

        // Honor flypast: interceptors saluting across the formation.
        for i in 0..<2 {
            let laneY = h * 0.16 + CGFloat(i) * 34
            let span = w + 140
            let hx = CGFloat((t * (120 + Double(i) * 30) + Double(i) * 433)
                .truncatingRemainder(dividingBy: Double(span))) - 70
            for j in 0..<5 {
                epx(ctx: &ctx, x: hx - CGFloat(j) * 11, y: laneY, w: 9 - CGFloat(j), h: 2,
                    color: Color.cyan.opacity(0.4 - CGFloat(j) * 0.07))
            }
            epx(ctx: &ctx, x: hx - 7, y: laneY - 2, w: 15, h: 5,
                color: Color(red: 0.70, green: 0.75, blue: 0.85))
        }

        // The watchers: tiny celebration lights along the limb cities.
        for k in 0..<9 {
            let a = Double.pi * (1.25 + Double(k) * 0.075)
            let rr = h * 0.985
            let sx = w * 0.5 + cos(a) * rr
            let sy = h * 1.58 + sin(a) * rr
            if Int(t * 1.5 + Double(k)) % 2 == 0 {
                epx(ctx: &ctx, x: sx, y: sy - 8, w: 3, h: 6,
                    color: Color.cyan.opacity(0.9))
            }
        }

        escan(ctx: &ctx, size: size)
        evig(ctx: &ctx, size: size)
    }

    /// Human supercarrier: long deck, bridge tower, hangar glow, engine wall.
    private static func drawCarrier(ctx: inout GraphicsContext, center c: CGPoint,
                                    width shipW: CGFloat, t: Double) {
        let hull = Color(red: 0.62, green: 0.66, blue: 0.74)
        let dark = Color(red: 0.30, green: 0.33, blue: 0.42)
        let hgt = shipW * 0.075
        // Main hull + tapered nose.
        epx(ctx: &ctx, x: c.x - shipW / 2, y: c.y - hgt / 2, w: shipW - 36, h: hgt, color: hull)
        epx(ctx: &ctx, x: c.x + shipW / 2 - 36, y: c.y - hgt / 2 + 3, w: 24, h: hgt - 6, color: hull)
        epx(ctx: &ctx, x: c.x + shipW / 2 - 12, y: c.y - hgt / 2 + 6, w: 12, h: hgt - 12, color: hull)
        epx(ctx: &ctx, x: c.x - shipW / 2, y: c.y - hgt / 2, w: shipW - 36, h: 3,
            color: Color.white.opacity(0.7))
        epx(ctx: &ctx, x: c.x - shipW / 2, y: c.y + hgt / 2 - 3, w: shipW - 36, h: 3, color: dark)
        // Hull greebles.
        epx(ctx: &ctx, x: c.x - shipW * 0.30, y: c.y - hgt / 2 - 5, w: 26, h: 5, color: dark)
        epx(ctx: &ctx, x: c.x + shipW * 0.05, y: c.y + hgt / 2, w: 30, h: 5, color: dark)
        // Deck running lights.
        var lx = c.x - shipW / 2 + 10
        while lx < c.x + shipW / 2 - 40 {
            epx(ctx: &ctx, x: lx, y: c.y - hgt / 2 - 3, w: 4, h: 3, color: .cyan.opacity(0.9))
            lx += 22
        }
        // Bridge tower + mast + windows.
        epx(ctx: &ctx, x: c.x - shipW * 0.15 - 15, y: c.y - hgt / 2 - 22, w: 30, h: 22, color: dark)
        epx(ctx: &ctx, x: c.x - shipW * 0.15 - 15, y: c.y - hgt / 2 - 22, w: 30, h: 3,
            color: Color.white.opacity(0.6))
        var qx = c.x - shipW * 0.15 - 11
        while qx < c.x - shipW * 0.15 + 11 {
            epx(ctx: &ctx, x: qx, y: c.y - hgt / 2 - 15, w: 5, h: 5,
                color: Color(red: 1, green: 0.85, blue: 0.55))
            qx += 9
        }
        epx(ctx: &ctx, x: c.x - shipW * 0.15 - 1, y: c.y - hgt / 2 - 34, w: 3, h: 12, color: dark)
        if Int(t * 1.5) % 2 == 0 {
            epx(ctx: &ctx, x: c.x - shipW * 0.15 - 3, y: c.y - hgt / 2 - 40, w: 6, h: 6, color: .red)
        }
        // Sponson lights.
        epx(ctx: &ctx, x: c.x + shipW * 0.18, y: c.y - hgt / 2 - 6, w: 14, h: 5, color: dark)
        if Int(t * 2) % 2 == 0 {
            epx(ctx: &ctx, x: c.x + shipW * 0.18 + 4, y: c.y - hgt / 2 - 8, w: 5, h: 5,
                color: Color.green.opacity(0.9))
        }
        // Hangar bay glow under the bow.
        epx(ctx: &ctx, x: c.x + shipW * 0.22, y: c.y + hgt / 2 - 2, w: 44, h: 7,
            color: Color(red: 1, green: 0.75, blue: 0.4, opacity: 0.9))
        // Engine wall: five blue throats, breathing.
        for i in 0..<5 {
            let ex = c.x - shipW / 2 - 4
            let ey = c.y - hgt / 2 + 4 + CGFloat(i) * (hgt - 8) / 4
            let fl = 12 + CGFloat(sin(t * 26 + Double(i) * 1.3) * 4)
            epx(ctx: &ctx, x: ex - fl, y: ey, w: fl, h: 5,
                color: Color(red: 0.4, green: 0.75, blue: 1.0, opacity: 0.85))
            epx(ctx: &ctx, x: ex - fl * 0.5, y: ey + 1, w: fl * 0.5, h: 3, color: .white)
        }
    }

    /// Escort frigate with a short engine trail.
    private static func drawFrigate(ctx: inout GraphicsContext, center c: CGPoint,
                                    width shipW: CGFloat, t: Double, seed: Int) {
        let hull = Color(red: 0.58, green: 0.62, blue: 0.70)
        let dark = Color(red: 0.30, green: 0.33, blue: 0.42)
        let hgt = shipW * 0.16
        for j in 0..<4 {
            epx(ctx: &ctx, x: c.x - shipW / 2 - CGFloat(j) * 12 - 24, y: c.y - 1,
                w: 10 - CGFloat(j), h: 2,
                color: Color.cyan.opacity(0.35 - CGFloat(j) * 0.08))
        }
        epx(ctx: &ctx, x: c.x - shipW / 2, y: c.y - hgt / 2, w: shipW - 14, h: hgt, color: hull)
        epx(ctx: &ctx, x: c.x + shipW / 2 - 14, y: c.y - hgt / 2 + 2, w: 10, h: hgt - 4, color: hull)
        epx(ctx: &ctx, x: c.x - shipW / 2, y: c.y - hgt / 2, w: shipW - 14, h: 2,
            color: Color.white.opacity(0.6))
        epx(ctx: &ctx, x: c.x - 6, y: c.y - hgt / 2 - 7, w: 14, h: 7, color: dark)
        epx(ctx: &ctx, x: c.x - 2, y: c.y - hgt / 2 - 6, w: 6, h: 3, color: .cyan.opacity(0.9))
        for i in 0..<2 {
            let ey = c.y - hgt / 4 + CGFloat(i) * hgt / 2
            let fl = 8 + CGFloat(sin(t * 24 + Double(seed * 2 + i)) * 3)
            epx(ctx: &ctx, x: c.x - shipW / 2 - fl, y: ey, w: fl, h: 4,
                color: Color(red: 0.4, green: 0.75, blue: 1.0, opacity: 0.85))
        }
        if Int(t * 2 + Double(seed)) % 2 == 0 {
            epx(ctx: &ctx, x: c.x + shipW / 2 - 8, y: c.y - hgt / 2 - 5, w: 4, h: 4, color: .red)
        }
    }

    /// Celebration burst: flash, expanding ring, radiating sparks.
    private static func drawFirework(ctx: inout GraphicsContext, at p: CGPoint, k: CGFloat,
                                     maxR: CGFloat, color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 20, y: p.y - 20, width: 40, height: 40)),
                 with: .radialGradient(
                    Gradient(colors: [color.opacity(0.6 * (1 - k)), .clear]),
                    center: p, startRadius: 0, endRadius: 20))
        ctx.stroke(Path(ellipseIn: CGRect(x: p.x - k * maxR, y: p.y - k * maxR,
                                          width: k * maxR * 2, height: k * maxR * 2)),
                   with: .color(color.opacity(0.6 * (1 - k))), lineWidth: 2)
        for i in 0..<8 {
            let a = Double(i) / 8 * .pi * 2
            let len = k * maxR
            var spark = Path()
            spark.move(to: p)
            spark.addLine(to: CGPoint(x: p.x + CGFloat(cos(a)) * len,
                                      y: p.y + CGFloat(sin(a)) * len + k * 10))
            ctx.stroke(spark, with: .color(color.opacity(0.8 * (1 - k))), lineWidth: 2)
        }
    }

    /// The Layard hulk: split hull, dying light, drifting debris.
    private static func drawHulk(ctx: inout GraphicsContext, center c: CGPoint,
                                 width shipW: CGFloat, t: Double) {
        let hull = Color(red: 0.10, green: 0.08, blue: 0.09)
        let dying = Color(red: 1.0, green: 0.25, blue: 0.25)
        let hgt = shipW * 0.22
        // Two broken hull chunks with a dark gap between them.
        var fore = Path()
        fore.move(to: CGPoint(x: c.x - shipW * 0.05, y: c.y - hgt))
        fore.addLine(to: CGPoint(x: c.x + shipW * 0.16, y: c.y - hgt * 0.7))
        fore.addLine(to: CGPoint(x: c.x + shipW / 2, y: c.y))
        fore.addLine(to: CGPoint(x: c.x - shipW * 0.05, y: c.y + hgt * 0.5))
        fore.closeSubpath()
        ctx.fill(fore, with: .color(hull))
        var aft = Path()
        aft.move(to: CGPoint(x: c.x - shipW / 2, y: c.y - hgt * 0.4))
        aft.addLine(to: CGPoint(x: c.x - shipW * 0.18, y: c.y - hgt * 0.5))
        aft.addLine(to: CGPoint(x: c.x - shipW * 0.18, y: c.y + hgt * 0.4))
        aft.addLine(to: CGPoint(x: c.x - shipW / 2, y: c.y + hgt * 0.2))
        aft.closeSubpath()
        ctx.fill(aft, with: .color(hull))
        // Bent spine still joining the wreck.
        var spine = Path()
        spine.move(to: CGPoint(x: c.x - shipW * 0.18, y: c.y))
        spine.addLine(to: CGPoint(x: c.x - shipW * 0.05, y: c.y - hgt * 0.2))
        ctx.stroke(spine, with: .color(Color(red: 0.25, green: 0.2, blue: 0.2)), lineWidth: 3)
        // Dying heart-light, slow and fading.
        if Int(t * 0.7) % 3 != 0 {
            epx(ctx: &ctx, x: c.x - shipW * 0.12, y: c.y - 3, w: 7, h: 7,
                color: dying.opacity(0.8))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - shipW * 0.12 - 12, y: c.y - 15,
                                            width: 30, height: 30)),
                     with: .radialGradient(
                        Gradient(colors: [dying.opacity(0.25), .clear]),
                        center: CGPoint(x: c.x - shipW * 0.12 + 3, y: c.y),
                        startRadius: 0, endRadius: 15))
        }
        // Occasional short-circuit spark + drifting debris.
        if Int(t * 0.9) % 5 == 0 {
            epx(ctx: &ctx, x: c.x + shipW * 0.2, y: c.y - hgt * 0.6, w: 4, h: 4, color: .white)
        }
        for i in 0..<6 {
            let a = t * 0.12 + Double(i) * 1.05
            let dx = c.x + CGFloat(cos(a)) * (shipW * 0.7)
            let dy = c.y + CGFloat(sin(a)) * (shipW * 0.3)
            epx(ctx: &ctx, x: dx, y: dy, w: 3, h: 3, color: Color.gray.opacity(0.6))
        }
    }

    // MARK: - Tiny helpers (self-contained pixel kit)

    static func epx(ctx: inout GraphicsContext, x: CGFloat, y: CGFloat,
                            w: CGFloat, h: CGFloat, color: Color) {
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
    }

    static func epxCircle(ctx: inout GraphicsContext, center c: CGPoint, r: CGFloat, color: Color) {
        let step: CGFloat = max(2, r / 12)
        var y = c.y - r
        while y <= c.y + r {
            let dy = (y - c.y) / r
            let half = sqrt(max(0, 1 - dy * dy)) * r
            let qHalf = (half / step).rounded(.down) * step
            ctx.fill(Path(CGRect(x: c.x - qHalf, y: y, width: qHalf * 2, height: step + 0.5)),
                     with: .color(color))
            y += step
        }
    }

    static func eridge(ctx: inout GraphicsContext, width w: CGFloat, baseline: CGFloat,
                               phase: Double, amp: CGFloat, step: CGFloat, color: Color,
                               floor floorY: CGFloat) {
        var p = Path()
        p.move(to: CGPoint(x: -step, y: floorY))
        var x: CGFloat = -step
        while x <= w + step {
            let n = sin(Double(x) * 0.010 + phase) * 0.55
                + sin(Double(x) * 0.027 + phase * 2.1) * 0.30
                + sin(Double(x) * 0.061 + phase * 0.7) * 0.15
            p.addLine(to: CGPoint(x: x, y: baseline - amp * CGFloat((n + 1) / 2)))
            x += step
        }
        p.addLine(to: CGPoint(x: w + step, y: floorY))
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }

    static func ecloud(ctx: inout GraphicsContext, width w: CGFloat, seed: Int,
                               y: CGFloat, s: CGFloat, t: Double, speed: Double) {
        let span = w + 260
        let bx = CGFloat((Double(seed) * 137 + t * speed).truncatingRemainder(dividingBy: Double(span))) - 130
        let body = Color(red: 0.75, green: 0.72, blue: 0.80, opacity: 0.85)
        epx(ctx: &ctx, x: bx, y: y, w: 76 * s, h: 8 * s, color: body)
        epx(ctx: &ctx, x: bx + 16 * s, y: y - 6 * s, w: 44 * s, h: 6 * s, color: body)
        epx(ctx: &ctx, x: bx - 18 * s, y: y + 5 * s, w: 42 * s, h: 5 * s, color: body)
    }

    static func escan(ctx: inout GraphicsContext, size: CGSize) {
        var y: CGFloat = 0
        while y < size.height {
            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                     with: .color(Color.black.opacity(0.10)))
            y += 4
        }
    }

    static func evig(ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(
                    Gradient(colors: [.clear, Color.black.opacity(0.30), Color.black.opacity(0.55)]),
                    center: CGPoint(x: size.width * 0.5, y: size.height * 0.45),
                    startRadius: min(size.width, size.height) * 0.30,
                    endRadius: max(size.width, size.height) * 0.75))
    }

    static func ehash(_ a: Int, _ b: Int) -> Int {
        abs((a &* 73856093) ^ (b &* 19349663)) % 1000
    }
}

#Preview {
    NavigationStack { EndCutsceneView() }
}
