import SwiftUI

/// Emra prologue cutscene — pixel-art scenes with typewriter subtitles.
///
/// Scene 1 (The Long Search): one-shot exploration flyby — the ship enters
/// from the left, crosses the starfield and exits right, then stays gone.
/// Scene 2 (Emra): the second Earth in full focus, ambient life only.
/// Scene 3 (Landing 2198): dropship touchdown + terraforming colony.
///
/// Flow: fade in from black → tap to advance each line → fade through black
/// between scenes → end card. Music hook left for the ambient pad.
struct CutsceneView: View {
    @Environment(\.dismiss) private var dismiss

    private static let typeSpeed = 0.028
    /// One-shot flyby duration: ship crosses left → right, then stays gone.
    private static let flybyDuration = 20.0

    private let scenes: [CutsceneScene] = [
        CutsceneScene(
            chapter: "CHAPTER I — THE LONG SEARCH",
            lines: [
                "By the end of the 22nd century, we have explored every planet and solar system around us.",
                "Thousands of planets, but none suitable for us to live on.",
                "So our ships pushed farther, searching far and wide among all the neighboring solar systems...",
            ]
        ),
        CutsceneScene(
            chapter: "CHAPTER II — EMRA",
            lines: [
                "And then we found it — a planet on which life can exist.",
                "We called it EMRA.",
                "It resembled our planet and had the ability to sustain life, so we set out on a mission to make it our second Earth.",
                "After 2 years, we sent 6 spaceships with 780 people onboard.",
            ]
        ),
        CutsceneScene(
            chapter: "CHAPTER III — LANDING 2198",
            lines: [
                "By the year 2198, we landed on Emra and started making it our own.",
                "Terraforming began — massive buildings, domes and infrastructure rising from the dust.",
            ]
        ),
        CutsceneScene(
            chapter: "CHAPTER IV — SECOND HOME",
            lines: [
                "In 40 years, we turned Emra into our second home.",
                "More than 11 million people made the journey across the stars.",
                "By the year 2238, our total population had grown to 14 million.",
            ]
        ),
        CutsceneScene(
            chapter: "CHAPTER V — THE LAYARDS",
            lines: [
                "In the year 2239, a new alien civilization arrived at Emra.",
                "They called themselves Layards. At first, they came in peace.",
                "But tension started rising soon after their arrival.",
                "They wanted Emra for themselves.",
            ]
        ),
        CutsceneScene(
            chapter: "CHAPTER VI — THE GREAT BATTLE",
            lines: [
                "In the year 2251 came the Great Battle for Emra.",
                "The Layards overwhelmed us — their fleets blotted out the sky.",
                "Our cities fell one by one, until only a few human strongholds remained.",
                "We were almost completely driven out of the world we had made our own.",
            ]
        ),
        CutsceneScene(
            chapter: "CHAPTER VII — THE MARCH BACK",
            lines: [
                "In the last human strongholds, Earth sent us their best new technology and soldiers.",
                "We assembled a new army — survivors and reinforcements, standing as one.",
                "With resupply ships landing day and night, we marched on.",
                "To take back what is ours. To take back Emra.",
            ]
        ),
    ]

    @State private var sceneIndex = 0
    @State private var lineIndex = 0
    @State private var shownChars = 0
    @State private var fadeBlack = 1.0        // opening fade in from black
    @State private var sceneFade = 0.0         // quick dip to black on beats
    @State private var finished = false
    @State private var typeTimer: Timer?
    /// Continue hint: fades in 1s after the full line has typed out.
    @State private var hintVisible = false
    @State private var hintTimer: Timer?
    /// Reference-date timestamp of the current scene's entry — drives all
    /// one-shot (non-looping) animation so beats play like a real cutscene.
    @State private var sceneStart = 0.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea(edges: .all)

                // Animated pixel scene.
                TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                    Canvas { ctx, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let elapsed = max(0, t - sceneStart)
                        if sceneIndex == 0 {
                            CutsceneArt.drawSearch(ctx: &ctx, size: size, t: t,
                                                   elapsed: elapsed,
                                                   flyby: Self.flybyDuration)
                        } else if sceneIndex == 1 {
                            CutsceneArt.drawEmraFocus(ctx: &ctx, size: size, t: t,
                                                      elapsed: elapsed)
                        } else if sceneIndex == 2 {
                            CutsceneArt.drawLanding(ctx: &ctx, size: size, t: t,
                                                    elapsed: elapsed,
                                                    lineIndex: lineIndex)
                        } else if sceneIndex == 3 {
                            CutsceneArt.drawCity(ctx: &ctx, size: size, t: t,
                                                 elapsed: elapsed)
                        } else if sceneIndex == 4 {
                            CutsceneArt.drawInvasion(ctx: &ctx, size: size, t: t,
                                                     elapsed: elapsed)
                        } else if sceneIndex == 5 {
                            CutsceneArt.drawBattle(ctx: &ctx, size: size, t: t,
                                                   elapsed: elapsed)
                        } else {
                            CutsceneArt.drawCounterattack(ctx: &ctx, size: size, t: t,
                                                          elapsed: elapsed)
                        }
                    }
                }
                .ignoresSafeArea(edges: .all)
                .id(sceneIndex)

                // Scene crossfade dip.
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

                // Opening fade in from black.
                Color.black.opacity(fadeBlack)
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)
            }
            // Real cutscene: tap anywhere to continue.
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
                .clipShape(CutsceneChipShape(cut: 6))
                .overlay(CutsceneChipShape(cut: 6).stroke(.white.opacity(0.25), lineWidth: 1))
            }
            Spacer()
        }
    }

    /// Quiet SKIP chip, bottom-right: chamfered pixel corners, translucent.
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
                .clipShape(CutsceneChipShape(cut: 6))
                .overlay(CutsceneChipShape(cut: 6).stroke(.white.opacity(0.25), lineWidth: 1))
        }
    }

    /// Bare subtitle: centered text with a soft shadow, no box — plus a
    /// tiny continue hint. The whole screen is tappable (see root gesture).
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
                Text("EMRA AWAITS")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .shadow(color: .cyan.opacity(0.6), radius: 12)
                Text("PROLOGUE COMPLETE — THE PUSH BEGINS")
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
                // Two chars per tick keeps long lines snappy on 120Hz.
                shownChars = min(total, shownChars + 2)
            } else {
                timer.invalidate()
                scheduleHint()
            }
        }
        if let typeTimer { RunLoop.main.add(typeTimer, forMode: .common) }
    }

    /// Fades the continue hint in 1s after the line finished typing.
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
        // First tap completes the typewriter.
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
            // Fade out and fade into the next slide.
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

private struct CutsceneScene {
    let chapter: String
    let lines: [String]
}

// MARK: - Blinking hint

/// Chamfered pixel chip (all four corners cut) for the quiet SKIP button.
private struct CutsceneChipShape: Shape {
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
    /// Gentle breathing pulse for the continue hint — slow and subtle.
    func blink(period: Double = 2.0) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 12)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            self.opacity(0.75 + 0.25 * (sin(t * .pi * 2 / period) + 1) / 2)
        }
    }
}

// MARK: - Pixel art

/// Canvas pixel-art for the prologue. Everything is hard-edged rects on a
/// coarse grid + gradients for sky glow. Twinkle/shimmer is ambient; every
/// story beat (flyby, descent, reveal) is a one-shot driven by `elapsed`.
private enum CutsceneArt {

    // MARK: Scene 1 — The Long Search (one-shot flyby)

    static func drawSearch(ctx: inout GraphicsContext, size: CGSize, t: Double,
                           elapsed: Double, flyby: Double) {
        let w = size.width, h = size.height
        // Deep-space gradient.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.008, green: 0.01, blue: 0.03),
                                      Color(red: 0.03, green: 0.05, blue: 0.12),
                                      Color(red: 0.07, green: 0.08, blue: 0.20)]),
                    startPoint: .zero, endPoint: CGPoint(x: w * 0.3, y: h)))
        // Nebula washes.
        nebula(ctx: &ctx, at: CGPoint(x: w * 0.78, y: h * 0.24), r: w * 0.35,
               color: Color(red: 0.35, green: 0.2, blue: 0.55, opacity: 0.20))
        nebula(ctx: &ctx, at: CGPoint(x: w * 0.12, y: h * 0.62), r: w * 0.30,
               color: Color(red: 0.1, green: 0.35, blue: 0.55, opacity: 0.16))

        // Stars with twinkle (ambient shimmer, not a story loop).
        for i in 0..<140 {
            let sx = CGFloat(hash(i, 11) % 1000) / 1000 * w
            let sy = CGFloat(hash(i, 23) % 1000) / 1000 * h
            let tw = 0.25 + 0.6 * (sin(t * 1.8 + Double(i) * 1.93) + 1) / 2
            let s: CGFloat = i % 9 == 0 ? 3 : 2
            ctx.fill(Path(CGRect(x: sx, y: sy, width: s, height: s)),
                     with: .color(Color.white.opacity(tw * 0.75)))
        }
        // Single shooting star near the opening — plays once.
        if elapsed >= 1.0 && elapsed < 2.4 {
            let k = (elapsed - 1.0) / 1.4
            let mx = w * 0.85 - k * w * 0.35
            let my = h * 0.12 + k * h * 0.18
            for j in 0..<8 {
                let f = CGFloat(j) / 8
                ctx.fill(Path(CGRect(x: mx + f * 26, y: my - f * 12, width: 3, height: 2)),
                         with: .color(Color.white.opacity(0.5 * (1 - f) * (1 - k * 0.4))))
            }
        }

        // Surveyed worlds: dead rock, ringed giant, ice ball.
        pixelPlanet(ctx: &ctx, center: CGPoint(x: w * 0.16, y: h * 0.26), r: 26,
                    base: Color(red: 0.45, green: 0.42, blue: 0.40),
                    dark: Color(red: 0.22, green: 0.21, blue: 0.20),
                    light: Color(red: 0.62, green: 0.60, blue: 0.57),
                    craters: true, seed: 5)
        pixelPlanet(ctx: &ctx, center: CGPoint(x: w * 0.44, y: h * 0.20), r: 40,
                    base: Color(red: 0.55, green: 0.42, blue: 0.30),
                    dark: Color(red: 0.30, green: 0.22, blue: 0.16),
                    light: Color(red: 0.75, green: 0.60, blue: 0.42),
                    ring: true, seed: 9)
        pixelPlanet(ctx: &ctx, center: CGPoint(x: w * 0.72, y: h * 0.42), r: 20,
                    base: Color(red: 0.45, green: 0.62, blue: 0.75),
                    dark: Color(red: 0.22, green: 0.35, blue: 0.48),
                    light: Color(red: 0.65, green: 0.82, blue: 0.92),
                    craters: false, seed: 13)
        tinyLabel(ctx: &ctx, text: "KEPLER DRIFT", at: CGPoint(x: w * 0.44, y: h * 0.20 + 58))
        tinyLabel(ctx: &ctx, text: "DEAD ROCK 7-B", at: CGPoint(x: w * 0.16, y: h * 0.26 + 42))

        // Dotted survey path (static chart, always visible).
        let laneY = h * 0.52
        var dashX: CGFloat = 20
        while dashX < w - 20 {
            ctx.fill(Path(CGRect(x: dashX, y: laneY + sin(dashX * 0.02) * 6, width: 3, height: 3)),
                     with: .color(Color.cyan.opacity(0.25)))
            dashX += 18
        }

        // ONE-SHOT flyby: left → right, then stays gone.
        let rawK = min(1, max(0, elapsed / flyby))
        let eased = rawK * rawK * (3 - 2 * rawK) // smoothstep
        let sx = -80 + eased * (w + 260)
        if sx < w + 90 {
            let sy = laneY + sin(t * 0.8) * 6
            drawShip(ctx: &ctx, at: CGPoint(x: sx, y: sy), t: t)
            // Single scan pulse as the ship passes mid-screen.
            let pulseAt = flyby * 0.45
            if elapsed >= pulseAt && elapsed < pulseAt + 2 {
                let pk = (elapsed - pulseAt) / 2
                let r = CGFloat(pk) * 130
                ctx.stroke(Path(ellipseIn: CGRect(x: sx - r, y: sy - r * 0.6,
                                                  width: r * 2, height: r * 1.2)),
                           with: .color(Color.cyan.opacity(0.35 * (1 - pk))), lineWidth: 2)
            }
        }

        scanlines(ctx: &ctx, size: size)
        vignette(ctx: &ctx, size: size)
    }

    // MARK: Scene 2 — Emra in focus

    static func drawEmraFocus(ctx: inout GraphicsContext, size: CGSize, t: Double,
                              elapsed: Double) {
        let w = size.width, h = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.005, green: 0.008, blue: 0.025),
                                      Color(red: 0.02, green: 0.04, blue: 0.10),
                                      Color(red: 0.05, green: 0.10, blue: 0.22)]),
                    startPoint: .zero, endPoint: CGPoint(x: w * 0.5, y: h)))
        nebula(ctx: &ctx, at: CGPoint(x: w * 0.15, y: h * 0.20), r: w * 0.32,
               color: Color(red: 0.25, green: 0.15, blue: 0.50, opacity: 0.22))
        nebula(ctx: &ctx, at: CGPoint(x: w * 0.88, y: h * 0.72), r: w * 0.30,
               color: Color(red: 0.08, green: 0.30, blue: 0.45, opacity: 0.18))

        for i in 0..<130 {
            let sx = CGFloat(hash(i, 151) % 1000) / 1000 * w
            let sy = CGFloat(hash(i, 167) % 1000) / 1000 * h
            let tw = 0.25 + 0.6 * (sin(t * 1.6 + Double(i) * 2.1) + 1) / 2
            let s: CGFloat = i % 11 == 0 ? 3 : 2
            ctx.fill(Path(CGRect(x: sx, y: sy, width: s, height: s)),
                     with: .color(Color.white.opacity(tw * 0.7)))
        }

        // Distant sun glow, upper right.
        let sun = CGPoint(x: w * 0.86, y: h * 0.16)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 70, y: sun.y - 70, width: 140, height: 140)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 1, green: 0.75, blue: 0.45, opacity: 0.35), .clear]),
                    center: sun, startRadius: 0, endRadius: 70))
        px(ctx: &ctx, x: sun.x - 7, y: sun.y - 7, w: 14, h: 14,
           color: Color(red: 1, green: 0.85, blue: 0.6))

        // Slow scale-in on entry, then rests at full size.
        let enter = min(1, elapsed / 2.5)
        let enterEase = 1 - pow(1 - enter, 3)
        let scale = 0.72 + 0.28 * enterEase
        let center = CGPoint(x: w * 0.5, y: h * 0.42)
        let r = min(w, h) * 0.27 * scale

        // Breathing atmosphere halo.
        let breathe = 1 + 0.03 * sin(t * 1.1)
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 1.45 * breathe,
                                        y: center.y - r * 1.45 * breathe,
                                        width: r * 2.9 * breathe, height: r * 2.9 * breathe)),
                 with: .radialGradient(
                    Gradient(colors: [Color.cyan.opacity(0.30), .clear]),
                    center: center, startRadius: 0, endRadius: r * 1.45 * breathe))

        // Two moons. Each is drawn behind the planet while on the far side
        // of its orbit and in front while passing over — true occlusion.
        let nearAngle = t * 0.14
        let nearMoon = CGPoint(x: center.x + cos(nearAngle) * r * 1.7,
                               y: center.y + sin(nearAngle) * r * 1.7 * 0.42)
        let farAngle = t * 0.07 + 2.0
        let farMoon = CGPoint(x: center.x + cos(farAngle) * r * 2.6,
                              y: center.y + sin(farAngle) * r * 2.6 * 0.5)
        if sin(nearAngle) < 0 {
            pixelMoon(ctx: &ctx, at: nearMoon, r: max(7, r * 0.10), glow: false)
        }
        if sin(farAngle) < 0 {
            pixelMoon(ctx: &ctx, at: farMoon, r: max(4, r * 0.055), glow: false)
        }

        drawEmraBig(ctx: &ctx, center: center, r: r, t: t)

        if sin(nearAngle) >= 0 {
            pixelMoon(ctx: &ctx, at: nearMoon, r: max(7, r * 0.10), glow: true)
        }
        if sin(farAngle) >= 0 {
            pixelMoon(ctx: &ctx, at: farMoon, r: max(4, r * 0.055), glow: false)
        }

        scanlines(ctx: &ctx, size: size)
        vignette(ctx: &ctx, size: size)
    }

    // MARK: Scene 3 — Landing 2198 (one-shot descent, then hover)

    static func drawLanding(ctx: inout GraphicsContext, size: CGSize, t: Double,
                            elapsed: Double, lineIndex: Int) {
        let w = size.width, h = size.height
        let gy = h * 0.64
        // Terraforming dusk: violet zenith → ember horizon.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.06, green: 0.05, blue: 0.16),
                                      Color(red: 0.20, green: 0.11, blue: 0.28),
                                      Color(red: 0.48, green: 0.22, blue: 0.28),
                                      Color(red: 0.72, green: 0.36, blue: 0.22)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: gy)))
        // Big low moon upper-left + small companion right.
        pixelMoon(ctx: &ctx, at: CGPoint(x: w * 0.16, y: h * 0.20), r: 34, glow: true)
        pixelMoon(ctx: &ctx, at: CGPoint(x: w * 0.84, y: h * 0.15), r: 12, glow: true)
        // Stars up top.
        for i in 0..<50 {
            let sx = CGFloat(hash(i, 41) % 1000) / 1000 * w
            let sy = CGFloat(hash(i, 53) % 1000) / 1000 * h * 0.35
            let tw = 0.2 + 0.5 * (sin(t * 1.5 + Double(i)) + 1) / 2
            ctx.fill(Path(CGRect(x: sx, y: sy, width: 2, height: 2)),
                     with: .color(Color.white.opacity(tw * 0.6)))
        }
        // Drifting dusk clouds, lit underneath by the horizon.
        let cloudBody = Color(red: 0.30, green: 0.16, blue: 0.26, opacity: 0.9)
        let cloudLit = Color(red: 0.85, green: 0.45, blue: 0.32, opacity: 0.8)
        duskCloud(ctx: &ctx, width: w, seed: 3, y: h * 0.30, s: 1.2, t: t, speed: 7,
                  color: cloudBody, lit: cloudLit)
        duskCloud(ctx: &ctx, width: w, seed: 11, y: h * 0.40, s: 0.9, t: t, speed: 11,
                  color: cloudBody, lit: cloudLit)
        duskCloud(ctx: &ctx, width: w, seed: 23, y: h * 0.22, s: 0.7, t: t, speed: 15,
                  color: cloudBody, lit: cloudLit)
        // Wind streaks across the mid-sky.
        for i in 0..<10 {
            let span = w + 200
            let wx = w + 50 - CGFloat((t * 30 + Double(i) * 173).truncatingRemainder(dividingBy: Double(span)))
            let wy = h * 0.30 + CGFloat(hash(i, 401) % 1000) / 1000 * h * 0.32
            let len = 8 + CGFloat(hash(i, 403) % 3) * 5
            ctx.fill(Path(CGRect(x: wx, y: wy, width: len, height: 2)),
                     with: .color(Color.white.opacity(0.12)))
        }
        // Ranges, rooted at the ground — no floating silhouettes: a hazy far
        // ridge, a flat-top butte, and a dark near ridge in front of both.
        ridge(ctx: &ctx, width: w, baseline: h * 0.55, phase: 0.7, amp: h * 0.075, step: 18,
              color: Color(red: 0.24, green: 0.14, blue: 0.26), floor: gy)
        butte(ctx: &ctx, centerX: w * 0.60, groundY: gy, wdt: 130, hgt: 44)
        ridge(ctx: &ctx, width: w, baseline: h * 0.595, phase: 2.4, amp: h * 0.05, step: 14,
              color: Color(red: 0.13, green: 0.08, blue: 0.13), floor: gy)
        // Ember crest light along the near ridge.
        for i in 0..<24 {
            let cx = CGFloat(i) * w / 23
            let n = sin(Double(cx) * 0.010 + 2.4) * 0.55
                + sin(Double(cx) * 0.027 + 5.04) * 0.30
                + sin(Double(cx) * 0.061 + 1.68) * 0.15
            let cy = h * 0.595 - h * 0.05 * CGFloat((n + 1) / 2)
            ctx.fill(Path(CGRect(x: cx, y: cy, width: 6, height: 2)),
                     with: .color(Color(red: 0.85, green: 0.42, blue: 0.30, opacity: 0.55)))
        }

        // Ground: red terraform dust with zone grid.
        ctx.fill(Path(CGRect(x: 0, y: gy, width: w, height: h - gy)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.42, green: 0.20, blue: 0.13),
                                      Color(red: 0.20, green: 0.10, blue: 0.09)]),
                    startPoint: CGPoint(x: 0, y: gy), endPoint: CGPoint(x: 0, y: h)))
        // Terraform grid lines converging.
        for k in 0...10 {
            var p = Path()
            p.move(to: CGPoint(x: w * 0.5, y: gy))
            p.addLine(to: CGPoint(x: CGFloat(k) / 10 * w * 1.6 - w * 0.3, y: h))
            ctx.stroke(p, with: .color(Color.cyan.opacity(0.10)), lineWidth: 1)
        }
        for k in 0..<5 {
            let y = gy + pow(Double(k) / 4, 1.8) * (h - gy)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(p, with: .color(Color.cyan.opacity(0.08)), lineWidth: 1)
        }
        // Distant colony furnaces glowing on the horizon.
        ctx.fill(Path(CGRect(x: 0, y: gy - 24, width: w, height: 24)),
                 with: .linearGradient(
                    Gradient(colors: [.clear,
                                      Color(red: 1, green: 0.55, blue: 0.25, opacity: 0.30)]),
                    startPoint: CGPoint(x: 0, y: gy - 24), endPoint: CGPoint(x: 0, y: gy)))
        for i in 0..<18 {
            let hx = CGFloat(hash(i, 419) % 1000) / 1000 * w
            let hy = gy - 4 - CGFloat(hash(i, 421) % 14)
            let tw = (sin(t * 2 + Double(i) * 1.7) + 1) / 2
            ctx.fill(Path(CGRect(x: hx, y: hy, width: 3, height: 3)),
                     with: .color(Color(red: 1, green: 0.7, blue: 0.35).opacity(0.35 + 0.45 * tw)))
        }
        // Scattered rocks.
        for i in 0..<16 {
            let rx = CGFloat(hash(i, 71) % 1000) / 1000 * w
            let ry = gy + CGFloat(hash(i, 83) % 1000) / 1000 * (h - gy - 30) + 8
            let s: CGFloat = 3 + CGFloat(hash(i, 97) % 3) * 2
            px(ctx: &ctx, x: rx, y: ry, w: s, h: s * 0.7,
               color: Color(red: 0.30, green: 0.16, blue: 0.12))
            px(ctx: &ctx, x: rx, y: ry, w: s, h: 2,
               color: Color(red: 0.55, green: 0.32, blue: 0.22))
        }

        // Colony: finished dome (left), half-built dome + crane (mid),
        // hab blocks (right), beacon tower. Line 2 lights more windows.
        let lit = lineIndex >= 1
        drawDome(ctx: &ctx, center: CGPoint(x: w * 0.20, y: gy + 26), r: 52,
                 finished: true, t: t, lit: lit)
        drawDome(ctx: &ctx, center: CGPoint(x: w * 0.47, y: gy + 30), r: 44,
                 finished: false, t: t, lit: lit)
        drawCrane(ctx: &ctx, base: CGPoint(x: w * 0.47 + 52, y: gy + 66), t: t)
        drawHab(ctx: &ctx, origin: CGPoint(x: w * 0.68, y: gy + 8), wdt: 120, hgt: 58,
                t: t, lit: lit, seed: 1)
        drawHab(ctx: &ctx, origin: CGPoint(x: w * 0.86, y: gy + 22), wdt: 88, hgt: 44,
                t: t, lit: lit, seed: 7)
        drawBeacon(ctx: &ctx, base: CGPoint(x: w * 0.08, y: gy + 70), hgt: 90, t: t)

        // Searchlight sweep from the beacon tower, behind the colony.
        let lampTop = CGPoint(x: w * 0.08, y: gy + 70 - 90 - 4)
        let sweepA = sin(t * 0.35) * 0.6
        let beamLen: CGFloat = 300
        let tip = CGPoint(x: lampTop.x + CGFloat(sin(Double(sweepA))) * beamLen,
                          y: lampTop.y - CGFloat(cos(Double(sweepA))) * beamLen)
        var beam = Path()
        beam.move(to: CGPoint(x: lampTop.x - 3, y: lampTop.y))
        beam.addLine(to: CGPoint(x: lampTop.x + 3, y: lampTop.y))
        beam.addLine(to: CGPoint(x: tip.x + 18, y: tip.y))
        beam.addLine(to: CGPoint(x: tip.x - 18, y: tip.y))
        beam.closeSubpath()
        ctx.fill(beam, with: .color(Color.white.opacity(0.07)))
        ctx.fill(Path(CGRect(x: lampTop.x - 3, y: lampTop.y - 3, width: 6, height: 6)),
                 with: .color(.white.opacity(0.8)))

        // Rover trundling with headlight (ambient patrol) + its track trail.
        let rx = w * 0.30 + CGFloat(sin(t * 0.25) * 0.5 + 0.5) * w * 0.25
        var trackX = w * 0.28
        while trackX < w * 0.58 {
            px(ctx: &ctx, x: trackX, y: h * 0.88 + 4, w: 7, h: 2,
               color: Color.black.opacity(0.45))
            trackX += 12
        }
        drawRover(ctx: &ctx, at: CGPoint(x: rx, y: h * 0.88), t: t)

        // Supply props: pipe run between the domes, crates, barrels, flag.
        let pipeY = gy + 30
        px(ctx: &ctx, x: w * 0.20 + 52, y: pipeY, w: w * 0.47 - 44 - (w * 0.20 + 52), h: 4,
           color: Color(red: 0.45, green: 0.47, blue: 0.54))
        var jointX = w * 0.20 + 58
        while jointX < w * 0.47 - 40 {
            px(ctx: &ctx, x: jointX, y: pipeY - 2, w: 5, h: 8,
               color: Color(red: 0.60, green: 0.62, blue: 0.70))
            jointX += 26
        }
        let crateC = Color(red: 0.42, green: 0.40, blue: 0.30)
        px(ctx: &ctx, x: w * 0.60, y: gy + 22, w: 15, h: 13, color: crateC)
        px(ctx: &ctx, x: w * 0.60, y: gy + 22, w: 15, h: 2, color: Color.white.opacity(0.35))
        px(ctx: &ctx, x: w * 0.60 + 16, y: gy + 24, w: 13, h: 11, color: crateC)
        px(ctx: &ctx, x: w * 0.60 + 7, y: gy + 9, w: 13, h: 11, color: crateC)
        let barrelC = Color(red: 0.55, green: 0.30, blue: 0.18)
        for (i, bx) in [w * 0.60 + 34, w * 0.60 + 44].enumerated() {
            px(ctx: &ctx, x: bx, y: gy + 20, w: 8, h: 15, color: barrelC)
            px(ctx: &ctx, x: bx, y: gy + 24 + CGFloat(i), w: 8, h: 2, color: Color.black.opacity(0.5))
        }
        // Claim flag planted by the pad, pennant rippling.
        let fx = w * 0.47 - 78
        px(ctx: &ctx, x: fx, y: gy + 6, w: 2, h: 34, color: Color(red: 0.55, green: 0.58, blue: 0.66))
        let wave = CGFloat(sin(t * 4) * 2)
        px(ctx: &ctx, x: fx + 2, y: gy + 6, w: 10, h: 7, color: .cyan)
        px(ctx: &ctx, x: fx + 12, y: gy + 6 + wave, w: 8, h: 7, color: .cyan.opacity(0.8))
        px(ctx: &ctx, x: fx + 2, y: gy + 6, w: 4, h: 7, color: .yellow)

        // Dropship: ONE descent, then holds hover over the pad.
        let descend = 1 - pow(1 - min(1, elapsed / 6), 3)
        let shipY = h * 0.16 + descend * (h * 0.30)
        let shipX = w * 0.47 + sin(t * 0.6) * 4 * descend
        // Searchlight cone to the pad.
        var cone = Path()
        cone.move(to: CGPoint(x: shipX - 10, y: shipY + 14))
        cone.addLine(to: CGPoint(x: shipX + 10, y: shipY + 14))
        cone.addLine(to: CGPoint(x: shipX + 44, y: gy + 40))
        cone.addLine(to: CGPoint(x: shipX - 44, y: gy + 40))
        cone.closeSubpath()
        ctx.fill(cone, with: .color(Color.yellow.opacity(0.10 * descend)))
        drawDropship(ctx: &ctx, at: CGPoint(x: shipX, y: shipY), t: t)
        // Landing pad with sequential edge lights + engine glow pool.
        px(ctx: &ctx, x: shipX - 46, y: gy + 38, w: 92, h: 8,
           color: Color(red: 0.25, green: 0.26, blue: 0.30))
        px(ctx: &ctx, x: shipX - 46, y: gy + 38, w: 92, h: 2, color: .yellow.opacity(0.8))
        for i in 0..<6 {
            let lx = shipX - 40 + CGFloat(i) * 16
            let chase = (Int(t * 5) + i) % 6 < 2
            px(ctx: &ctx, x: lx, y: gy + 34, w: 5, h: 5,
               color: chase ? .yellow : .red.opacity(0.45))
        }
        let flick = 0.85 + 0.15 * sin(t * 24)
        ctx.fill(Path(ellipseIn: CGRect(x: shipX - 44, y: gy + 30, width: 88, height: 20)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 1, green: 0.65, blue: 0.3).opacity(0.35 * flick), .clear]),
                    center: CGPoint(x: shipX, y: gy + 38),
                    startRadius: 0, endRadius: 44))
        // Dust kicked up under thrusters once the ship is low.
        if descend > 0.3 {
            for i in 0..<14 {
                let a = Double(hash(i, 131) % 100) / 100 * .pi
                let r = CGFloat((t * 60 + Double(i * 23)).truncatingRemainder(dividingBy: 70))
                let dx = cos(a) * r
                ctx.fill(Path(CGRect(x: shipX + dx - 2, y: gy + 36 - r * 0.35, width: 4, height: 3)),
                         with: .color(Color(red: 0.7, green: 0.45, blue: 0.3).opacity(0.5 * (1 - r / 70))))
            }
        }

        // Welding sparks at the half-built dome.
        if Int(t * 3) % 2 == 0 {
            for i in 0..<5 {
                let jx = CGFloat(hash(i, Int(t * 3)) % 20) - 10
                ctx.fill(Path(CGRect(x: w * 0.47 + 10 + jx, y: gy - 8 - CGFloat(i * 5),
                                      width: 2, height: 2)),
                         with: .color(.yellow))
            }
        }

        // Foreground rock framing, rooted at the bottom corners.
        let fgRock = Color(red: 0.07, green: 0.05, blue: 0.10)
        let fgRim = Color(red: 0.55, green: 0.30, blue: 0.32)
        px(ctx: &ctx, x: -10, y: h - 64, w: 120, h: 64, color: fgRock)
        px(ctx: &ctx, x: 30, y: h - 96, w: 70, h: 40, color: fgRock)
        px(ctx: &ctx, x: -10, y: h - 64, w: 120, h: 3, color: fgRim)
        px(ctx: &ctx, x: 30, y: h - 96, w: 70, h: 3, color: fgRim)
        px(ctx: &ctx, x: w - 100, y: h - 52, w: 110, h: 52, color: fgRock)
        px(ctx: &ctx, x: w - 80, y: h - 78, w: 56, h: 30, color: fgRock)
        px(ctx: &ctx, x: w - 100, y: h - 52, w: 110, h: 3, color: fgRim)
        px(ctx: &ctx, x: w - 80, y: h - 78, w: 56, h: 3, color: fgRim)
        // Alien lichen glimmer on the foreground rocks.
        for (i, lx, ly) in [(0, 44.0, h - 70.0), (1, 78.0, h - 44.0), (2, w - 60.0, h - 58.0)] {
            let glow = 0.4 + 0.4 * (sin(t * 1.4 + Double(i) * 2.1) + 1) / 2
            ctx.fill(Path(CGRect(x: lx, y: ly, width: 3, height: 3)),
                     with: .color(Color.cyan.opacity(glow)))
        }

        scanlines(ctx: &ctx, size: size)
        vignette(ctx: &ctx, size: size)
    }

    // MARK: Scene 4 — Second Home 2238 (thriving night city)

    static func drawCity(ctx: inout GraphicsContext, size: CGSize, t: Double,
                         elapsed: Double) {
        let w = size.width, h = size.height
        let gy = h * 0.70
        // Night sky: deep indigo → teal horizon.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.01, green: 0.02, blue: 0.07),
                                      Color(red: 0.04, green: 0.09, blue: 0.20),
                                      Color(red: 0.08, green: 0.22, blue: 0.30)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: gy)))
        for i in 0..<110 {
            let sx = CGFloat(hash(i, 461) % 1000) / 1000 * w
            let sy = CGFloat(hash(i, 463) % 1000) / 1000 * h * 0.5
            let tw = 0.2 + 0.6 * (sin(t * 1.6 + Double(i) * 2.3) + 1) / 2
            let s: CGFloat = i % 10 == 0 ? 3 : 2
            ctx.fill(Path(CGRect(x: sx, y: sy, width: s, height: s)),
                     with: .color(Color.white.opacity(tw * 0.7)))
        }
        // A ringed neighbor world hanging over the city.
        pixelPlanet(ctx: &ctx, center: CGPoint(x: w * 0.82, y: h * 0.18), r: 30,
                    base: Color(red: 0.45, green: 0.35, blue: 0.45),
                    dark: Color(red: 0.24, green: 0.18, blue: 0.26),
                    light: Color(red: 0.65, green: 0.52, blue: 0.62),
                    ring: true, seed: 77)

        // Far towers, then the near skyline — both rooted at the ground.
        drawTowerRow(ctx: &ctx, width: w, baseY: gy, count: 14,
                     minH: h * 0.08, maxH: h * 0.20, minW: 22, maxW: 38,
                     color: Color(red: 0.10, green: 0.12, blue: 0.24),
                     edge: Color(red: 0.25, green: 0.30, blue: 0.48),
                     t: t, seed: 501, beacons: false, twinkle: false)
        // Warm haze of a million windows above the rooftops.
        ctx.fill(Path(CGRect(x: 0, y: gy - h * 0.24, width: w, height: h * 0.24)),
                 with: .linearGradient(
                    Gradient(colors: [.clear,
                                      Color(red: 1, green: 0.65, blue: 0.35, opacity: 0.18)]),
                    startPoint: CGPoint(x: 0, y: gy - h * 0.24),
                    endPoint: CGPoint(x: 0, y: gy)))
        // Orbital elevator: a thread of light climbing out of the city.
        let elevX = w * 0.18
        var elevBeam = Path()
        elevBeam.move(to: CGPoint(x: elevX - 2, y: gy))
        elevBeam.addLine(to: CGPoint(x: elevX + 2, y: gy))
        elevBeam.addLine(to: CGPoint(x: elevX + 5, y: 0))
        elevBeam.addLine(to: CGPoint(x: elevX - 5, y: 0))
        elevBeam.closeSubpath()
        ctx.fill(elevBeam, with: .color(Color.cyan.opacity(0.13)))
        px(ctx: &ctx, x: elevX - 1, y: 0, w: 2, h: gy, color: Color.cyan.opacity(0.4))
        for i in 0..<2 {
            let climb = CGFloat((t * 46 + Double(i) * 320).truncatingRemainder(dividingBy: Double(gy)))
            let climberY = gy - climb
            ctx.fill(Path(ellipseIn: CGRect(x: elevX - 8, y: climberY - 8, width: 16, height: 16)),
                     with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.6), .clear]),
                        center: CGPoint(x: elevX, y: climberY), startRadius: 0, endRadius: 8))
            px(ctx: &ctx, x: elevX - 3, y: climberY - 3, w: 6, h: 6, color: .white)
        }
        // Elevator anchor station: stepped base rooted at the ground.
        for s in 0..<3 {
            let sw = 64 - CGFloat(s) * 16
            px(ctx: &ctx, x: elevX - sw / 2, y: gy - CGFloat(s + 1) * 12, w: sw, h: 12,
               color: Color(red: 0.10, green: 0.12, blue: 0.20))
        }
        px(ctx: &ctx, x: elevX - 32, y: gy - 12, w: 64, h: 2,
           color: Color.cyan.opacity(0.6))
        // Monorail girder + train gliding across the mid-skyline.
        let railY = gy - h * 0.13
        px(ctx: &ctx, x: 0, y: railY, w: w, h: 3,
           color: Color(red: 0.25, green: 0.27, blue: 0.35))
        var pilX: CGFloat = 24
        while pilX < w {
            px(ctx: &ctx, x: pilX, y: railY, w: 4, h: gy - railY,
               color: Color(red: 0.12, green: 0.13, blue: 0.20))
            pilX += 120
        }
        let trainSpan = w + 200
        let trainX = CGFloat((t * 90).truncatingRemainder(dividingBy: Double(trainSpan))) - 100
        px(ctx: &ctx, x: trainX, y: railY - 12, w: 66, h: 11,
           color: Color(red: 0.55, green: 0.60, blue: 0.70))
        for k in 0..<5 {
            px(ctx: &ctx, x: trainX + 6 + CGFloat(k) * 12, y: railY - 9, w: 8, h: 5,
               color: Color(red: 1, green: 0.85, blue: 0.55, opacity: 0.9))
        }
        px(ctx: &ctx, x: trainX + 66, y: railY - 8, w: 10, h: 3, color: .white)
        drawTowerRow(ctx: &ctx, width: w, baseY: gy, count: 7,
                     minH: h * 0.16, maxH: h * 0.32, minW: 44, maxW: 70,
                     color: Color(red: 0.07, green: 0.08, blue: 0.17),
                     edge: Color(red: 0.35, green: 0.42, blue: 0.62),
                     t: t, seed: 521, beacons: true, twinkle: true)

        // Arcology pyramid anchoring the west end, terraced and green.
        let arcX = w * 0.10
        let arcBase = min(w * 0.20, 150.0)
        for s in 0..<5 {
            let sw = arcBase - CGFloat(s) * arcBase / 5
            let sy = gy - CGFloat(s + 1) * 17
            px(ctx: &ctx, x: arcX - sw / 2, y: sy, w: sw, h: 17,
               color: Color(red: 0.09, green: 0.11, blue: 0.19))
            var wx = arcX - sw / 2 + 6
            while wx < arcX + sw / 2 - 8 {
                px(ctx: &ctx, x: wx, y: sy + 5, w: 5, h: 6,
                   color: Color(red: 1, green: 0.8, blue: 0.5, opacity: 0.8))
                wx += 11
            }
            px(ctx: &ctx, x: arcX - sw / 2, y: sy, w: sw, h: 3,
               color: Color(red: 0.15, green: 0.40, blue: 0.22))
        }
        if Int(t * 1.5) % 2 == 0 {
            px(ctx: &ctx, x: arcX - 3, y: gy - 5 * 17 - 10, w: 6, h: 6, color: .cyan)
        }

        // Central HQ spire with its rotating crown beacon.
        let hqX = w * 0.5
        let hqH = h * 0.40
        px(ctx: &ctx, x: hqX - 26, y: gy - hqH, w: 52, h: hqH,
           color: Color(red: 0.08, green: 0.10, blue: 0.20))
        px(ctx: &ctx, x: hqX - 26, y: gy - hqH, w: 52, h: 3,
           color: Color(red: 0.45, green: 0.75, blue: 0.95))
        px(ctx: &ctx, x: hqX - 2, y: gy - hqH - 26, w: 4, h: 26,
           color: Color(red: 0.30, green: 0.33, blue: 0.45))
        if Int(t * 1.5) % 2 == 0 {
            px(ctx: &ctx, x: hqX - 4, y: gy - hqH - 32, w: 8, h: 8, color: .red)
            ctx.fill(Path(ellipseIn: CGRect(x: hqX - 22, y: gy - hqH - 48, width: 44, height: 44)),
                     with: .radialGradient(
                        Gradient(colors: [Color.red.opacity(0.30), .clear]),
                        center: CGPoint(x: hqX, y: gy - hqH - 28),
                        startRadius: 0, endRadius: 22))
        }
        // Lit HQ windows.
        var hqr = 0
        var hqy = gy - hqH + 12
        while hqy < gy - 10 {
            var hqx = hqX - 19
            while hqx < hqX + 14 {
                let on = (hash(hqr, 541 + Int(t * 0.5)) % 4) != 0
                px(ctx: &ctx, x: hqx, y: hqy, w: 6, h: 7,
                   color: on ? .yellow.opacity(0.9) : .black.opacity(0.5))
                hqx += 11; hqr += 1
            }
            hqy += 13
        }

        // Holographic billboard flickering between the towers.
        let holoX = w * 0.33
        let holoY = gy - h * 0.26
        let holoHue: Color = Int(t * 2) % 2 == 0 ? .cyan : Color(red: 1, green: 0.4, blue: 0.8)
        px(ctx: &ctx, x: holoX - 2, y: holoY - 26, w: 3, h: 30,
           color: Color(red: 0.30, green: 0.32, blue: 0.40))
        ctx.fill(Path(CGRect(x: holoX, y: holoY - 22, width: 44, height: 24)),
                 with: .color(holoHue.opacity(0.28 + 0.10 * sin(t * 9))))
        px(ctx: &ctx, x: holoX, y: holoY - 22, w: 44, h: 2, color: holoHue.opacity(0.8))
        px(ctx: &ctx, x: holoX, y: holoY, w: 44, h: 2, color: holoHue.opacity(0.8))
        for k in 0..<3 {
            px(ctx: &ctx, x: holoX + 5 + CGFloat(k) * 13, y: holoY - 15, w: 8, h: 8,
               color: holoHue.opacity(0.7))
        }

        // Skimmer traffic lanes across the sky.
        for i in 0..<4 {
            let laneY = h * 0.16 + CGFloat(i) * h * 0.055
            let speed = 60 + Double(i) * 22
            let span = w + 140
            let dir: Double = i % 2 == 0 ? 1 : -1
            let prog = (t * speed + Double(i) * 311).truncatingRemainder(dividingBy: Double(span))
            let fx = dir > 0 ? CGFloat(prog) - 70 : w + 70 - CGFloat(prog)
            let bodyC = Color(red: 0.70, green: 0.75, blue: 0.85)
            for j in 0..<5 {
                let tx = fx - CGFloat(dir) * CGFloat(j) * 12
                px(ctx: &ctx, x: tx, y: laneY, w: 10 - CGFloat(j), h: 2,
                   color: Color.cyan.opacity(0.35 - CGFloat(j) * 0.06))
            }
            px(ctx: &ctx, x: fx - 7, y: laneY - 2, w: 16, h: 5, color: bodyC)
            px(ctx: &ctx, x: fx + (dir > 0 ? 9 : -11), y: laneY - 1, w: 3, h: 3, color: .white)
        }

        // Ground: dark streets + lamp posts marching to the horizon.
        ctx.fill(Path(CGRect(x: 0, y: gy, width: w, height: h - gy)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.16),
                                      Color(red: 0.03, green: 0.03, blue: 0.06)]),
                    startPoint: CGPoint(x: 0, y: gy), endPoint: CGPoint(x: 0, y: h)))
        for k in 0...8 {
            var p = Path()
            p.move(to: CGPoint(x: w * 0.5, y: gy))
            p.addLine(to: CGPoint(x: CGFloat(k) / 8 * w * 1.8 - w * 0.4, y: h))
            ctx.stroke(p, with: .color(Color.yellow.opacity(0.07)), lineWidth: 1)
        }
        for i in 0..<9 {
            let lx = CGFloat(i) * w / 8
            px(ctx: &ctx, x: lx, y: gy + 14, w: 2, h: 16,
               color: Color(red: 0.30, green: 0.32, blue: 0.40))
            ctx.fill(Path(ellipseIn: CGRect(x: lx - 7, y: gy + 6, width: 16, height: 16)),
                     with: .radialGradient(
                        Gradient(colors: [Color(red: 1, green: 0.8, blue: 0.5, opacity: 0.5), .clear]),
                        center: CGPoint(x: lx + 1, y: gy + 14),
                        startRadius: 0, endRadius: 8))
            px(ctx: &ctx, x: lx - 1, y: gy + 12, w: 4, h: 4,
               color: Color(red: 1, green: 0.85, blue: 0.6))
        }

        // Park strip + ground traffic gliding past the lamps.
        px(ctx: &ctx, x: 0, y: gy + 38, w: w, h: 6,
           color: Color(red: 0.08, green: 0.22, blue: 0.12))
        var treeX: CGFloat = 12
        while treeX < w {
            px(ctx: &ctx, x: treeX, y: gy + 32, w: 6, h: 6,
               color: Color(red: 0.12, green: 0.34, blue: 0.18))
            treeX += 34
        }
        for i in 0..<6 {
            let laneY = gy + 52 + CGFloat(i % 3) * 13
            let speed = 70 + Double(i) * 18
            let span = w + 80
            let prog = (t * speed + Double(i) * 211).truncatingRemainder(dividingBy: Double(span))
            let rightward = i % 2 == 0
            let carX = rightward ? CGFloat(prog) - 40 : w + 40 - CGFloat(prog)
            let lamp: Color = rightward ? .white : .red
            px(ctx: &ctx, x: carX - 6, y: laneY, w: 12, h: 4,
               color: Color(red: 0.25, green: 0.27, blue: 0.33))
            px(ctx: &ctx, x: carX + (rightward ? 6 : -9), y: laneY, w: 3, h: 3, color: lamp.opacity(0.9))
            px(ctx: &ctx, x: carX + (rightward ? 6 : -9), y: laneY, w: rightward ? 18 : -18, h: 1,
               color: lamp.opacity(0.25))
        }

        // Foreground hill framing, rooted at the bottom.
        let fgHill = Color(red: 0.04, green: 0.05, blue: 0.09)
        px(ctx: &ctx, x: -20, y: h - 56, w: 200, h: 56, color: fgHill)
        px(ctx: &ctx, x: w - 170, y: h - 44, w: 190, h: 44, color: fgHill)
        // Two young colony pines on the hill.
        for (tx, ts) in [(70.0, 1.0), (w - 90.0, 0.8)] {
            let th = CGFloat(34 * ts)
            px(ctx: &ctx, x: tx - 2, y: h - 56 - th, w: 4, h: th,
               color: Color(red: 0.20, green: 0.14, blue: 0.12))
            px(ctx: &ctx, x: tx - 12 * CGFloat(ts), y: h - 56 - th, w: 24 * CGFloat(ts), h: 10,
               color: Color(red: 0.10, green: 0.28, blue: 0.22))
            px(ctx: &ctx, x: tx - 8 * CGFloat(ts), y: h - 56 - th - 10, w: 16 * CGFloat(ts), h: 10,
               color: Color(red: 0.12, green: 0.34, blue: 0.26))
        }

        scanlines(ctx: &ctx, size: size)
        vignette(ctx: &ctx, size: size)
    }

    /// One skyline row of blocky towers with lit windows, rooted at baseY.
    private static func drawTowerRow(ctx: inout GraphicsContext, width w: CGFloat, baseY: CGFloat,
                                     count: Int, minH: CGFloat, maxH: CGFloat,
                                     minW: CGFloat, maxW: CGFloat,
                                     color: Color, edge: Color,
                                     t: Double, seed: Int, beacons: Bool, twinkle: Bool,
                                     alarm: Bool = false) {
        for i in 0..<count {
            let bx = CGFloat(i) * w / CGFloat(count) + CGFloat(hash(i, seed) % 20) - 10
            let tw = minW + CGFloat(hash(i, seed + 1) % 100) / 100 * (maxW - minW)
            let th = minH + CGFloat(hash(i, seed + 2) % 100) / 100 * (maxH - minH)
            px(ctx: &ctx, x: bx, y: baseY - th, w: tw, h: th, color: color)
            px(ctx: &ctx, x: bx, y: baseY - th, w: tw, h: 2, color: edge)
            var r = 0
            var yy = baseY - th + 8
            while yy < baseY - 6 {
                var xx = bx + 5
                while xx < bx + tw - 6 {
                    let on: Bool
                    if twinkle { on = (hash(r, seed + 3 + Int(t * 0.5)) % 4) != 0 }
                    else { on = (hash(r, seed + 3) % 3) != 0 }
                    if alarm {
                        // Rolling red alert wave across the floors.
                        let lit = on && (Int(t * 2.4 + Double(r % 6)) % 2 == 0)
                        px(ctx: &ctx, x: xx, y: yy, w: 4, h: 5,
                           color: lit ? Color.red.opacity(0.95) : Color.black.opacity(0.6))
                    } else {
                        px(ctx: &ctx, x: xx, y: yy, w: 4, h: 5,
                           color: on ? Color(red: 1, green: 0.8, blue: 0.5, opacity: 0.85)
                                     : Color.black.opacity(0.5))
                    }
                    xx += 8; r += 1
                }
                yy += 10
            }
            // Rooftop garden terraces on some towers.
            if hash(i, seed + 6) % 3 == 0 {
                px(ctx: &ctx, x: bx, y: baseY - th - 4, w: tw, h: 4,
                   color: Color(red: 0.12, green: 0.30, blue: 0.16))
                var gx = bx + 4
                while gx < bx + tw - 4 {
                    px(ctx: &ctx, x: gx, y: baseY - th - 9, w: 4, h: 5,
                       color: Color(red: 0.15, green: 0.38, blue: 0.18))
                    gx += 9
                }
            }
            if beacons && (hash(i, seed + 4) % 2 == 0) {
                px(ctx: &ctx, x: bx + tw / 2 - 1, y: baseY - th - 12, w: 3, h: 12, color: edge)
                if Int(t * 1.5 + Double(i)) % 2 == 0 {
                    px(ctx: &ctx, x: bx + tw / 2 - 3, y: baseY - th - 18, w: 7, h: 7, color: .red)
                }
            }
        }
    }

    // MARK: Scene 5 — The Layards (alien arrival, 2239)

    static func drawInvasion(ctx: inout GraphicsContext, size: CGSize, t: Double,
                             elapsed: Double) {
        let w = size.width, h = size.height
        let gy = h * 0.68
        let alien = Color(red: 1.0, green: 0.22, blue: 0.22)

        // Storm sky: bruised violet-black → blood-red horizon.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.02, green: 0.01, blue: 0.05),
                                      Color(red: 0.10, green: 0.04, blue: 0.12),
                                      Color(red: 0.38, green: 0.10, blue: 0.12)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: gy)))
        // Occasional lightning flash tearing across the clouds.
        let boltCycle = elapsed.truncatingRemainder(dividingBy: 9)
        if boltCycle < 0.35 {
            let flash = 1 - boltCycle / 0.35
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color.white.opacity(0.10 * flash)))
            var bolt = Path()
            var bx = w * 0.72
            var by: CGFloat = 0
            bolt.move(to: CGPoint(x: bx, y: by))
            for _ in 0..<7 {
                bx += CGFloat(hash(Int(by), 601) % 40) - 20
                by += gy / 7
                bolt.addLine(to: CGPoint(x: bx, y: by))
            }
            ctx.stroke(bolt, with: .color(Color.white.opacity(0.7 * flash)), lineWidth: 2)
        }
        // Churning storm clouds, dark and fast.
        let storm = Color(red: 0.12, green: 0.06, blue: 0.13, opacity: 0.95)
        duskCloud(ctx: &ctx, width: w, seed: 41, y: h * 0.16, s: 1.6, t: t, speed: 22,
                  color: storm, lit: Color(red: 0.5, green: 0.15, blue: 0.15, opacity: 0.7))
        duskCloud(ctx: &ctx, width: w, seed: 53, y: h * 0.30, s: 1.2, t: t, speed: 30,
                  color: storm, lit: Color(red: 0.5, green: 0.15, blue: 0.15, opacity: 0.6))

        // THE MOTHERSHIP: one slow descent, then it holds and looms.
        let descend = 1 - pow(1 - min(1, elapsed / 9), 3)
        let shipY = -h * 0.10 + descend * (h * 0.34) + sin(t * 0.7) * 4 * descend
        let shipX = w * 0.5
        let shipW = min(w * 0.72, 520.0)
        // Under-glow bleeding onto the clouds.
        ctx.fill(Path(ellipseIn: CGRect(x: shipX - shipW * 0.6, y: shipY - 30,
                                        width: shipW * 1.2, height: 150)),
                 with: .radialGradient(
                    Gradient(colors: [alien.opacity(0.22 * descend), .clear]),
                    center: CGPoint(x: shipX, y: shipY + 20),
                    startRadius: 0, endRadius: shipW * 0.6))
        drawMothership(ctx: &ctx, center: CGPoint(x: shipX, y: shipY), width: shipW, t: t)

        // Tractor beams biting into the colony, flickering + kicking up dust.
        if descend > 0.55 {
            let beamOn = 0.55 + 0.45 * sin(t * 9)
            for (i, fx) in [shipX - shipW * 0.28, shipX, shipX + shipW * 0.28].enumerated() {
                let sway = sin(t * 1.3 + Double(i) * 2.1) * 8
                var cone = Path()
                cone.move(to: CGPoint(x: fx - 14, y: shipY + 30))
                cone.addLine(to: CGPoint(x: fx + 14, y: shipY + 30))
                cone.addLine(to: CGPoint(x: fx + 30 + sway, y: gy + 10))
                cone.addLine(to: CGPoint(x: fx - 30 + sway, y: gy + 10))
                cone.closeSubpath()
                ctx.fill(cone, with: .color(alien.opacity(0.16 * beamOn)))
                var core = Path()
                core.move(to: CGPoint(x: fx - 4, y: shipY + 30))
                core.addLine(to: CGPoint(x: fx + 4, y: shipY + 30))
                core.addLine(to: CGPoint(x: fx + 8 + sway, y: gy + 10))
                core.addLine(to: CGPoint(x: fx - 8 + sway, y: gy + 10))
                core.closeSubpath()
                ctx.fill(core, with: .color(Color.white.opacity(0.35 * beamOn)))
                // Impact glare + rising debris.
                ctx.fill(Path(ellipseIn: CGRect(x: fx + sway - 34, y: gy - 6, width: 68, height: 22)),
                         with: .radialGradient(
                            Gradient(colors: [alien.opacity(0.55 * beamOn), .clear]),
                            center: CGPoint(x: fx + sway, y: gy + 4),
                            startRadius: 0, endRadius: 34))
                for j in 0..<5 {
                    let rise = CGFloat((t * 46 + Double(i * 31 + j * 53)).truncatingRemainder(dividingBy: 60))
                    ctx.fill(Path(CGRect(x: fx + sway + CGFloat(hash(j, i) % 40) - 20,
                                          y: gy + 6 - rise, width: 3, height: 3)),
                             with: .color(alien.opacity(0.7 * (1 - rise / 60))))
                }
            }
        }

        // Layard scout discs zipping between the clouds.
        for i in 0..<3 {
            let laneY = h * 0.34 + CGFloat(i) * h * 0.07
            let speed = 130 + Double(i) * 45
            let span = w + 120
            let prog = (t * speed + Double(i) * 419).truncatingRemainder(dividingBy: Double(span))
            let sx = i % 2 == 0 ? CGFloat(prog) - 60 : w + 60 - CGFloat(prog)
            let dir: CGFloat = i % 2 == 0 ? 1 : -1
            for j in 0..<6 {
                px(ctx: &ctx, x: sx - dir * CGFloat(j) * 10, y: laneY, w: 9 - CGFloat(j), h: 2,
                   color: alien.opacity(0.4 - CGFloat(j) * 0.06))
            }
            px(ctx: &ctx, x: sx - 9, y: laneY - 4, w: 18, h: 7,
               color: Color(red: 0.10, green: 0.12, blue: 0.14))
            px(ctx: &ctx, x: sx - 9, y: laneY + 3, w: 18, h: 2, color: alien.opacity(0.9))
            px(ctx: &ctx, x: sx - 2, y: laneY - 6, w: 5, h: 3, color: alien.opacity(0.9))
        }

        // The colony below: dark blocks, red alarm windows, sweeping searchlights.
        ctx.fill(Path(CGRect(x: 0, y: gy, width: w, height: h - gy)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.14, green: 0.06, blue: 0.07),
                                      Color(red: 0.05, green: 0.02, blue: 0.03)]),
                    startPoint: CGPoint(x: 0, y: gy), endPoint: CGPoint(x: 0, y: h)))
        // The city below: two rooted tower rows caught in the red alert,
        // plus the old terraform dome holding between them.
        drawTowerRow(ctx: &ctx, width: w, baseY: gy, count: 12,
                     minH: h * 0.10, maxH: h * 0.24, minW: 26, maxW: 44,
                     color: Color(red: 0.10, green: 0.07, blue: 0.10),
                     edge: Color(red: 0.35, green: 0.18, blue: 0.18),
                     t: t, seed: 711, beacons: false, twinkle: false, alarm: true)
        drawTowerRow(ctx: &ctx, width: w, baseY: gy, count: 7,
                     minH: h * 0.18, maxH: h * 0.32, minW: 46, maxW: 68,
                     color: Color(red: 0.07, green: 0.05, blue: 0.07),
                     edge: Color(red: 0.45, green: 0.22, blue: 0.22),
                     t: t, seed: 727, beacons: true, twinkle: false, alarm: true)
        drawDome(ctx: &ctx, center: CGPoint(x: w * 0.28, y: gy + 26), r: 40,
                 finished: true, t: t, lit: false)
        // Emergency-red street wash + two burning wrecks.
        for k in 0...8 {
            var p = Path()
            p.move(to: CGPoint(x: w * 0.5, y: gy))
            p.addLine(to: CGPoint(x: CGFloat(k) / 8 * w * 1.8 - w * 0.4, y: h))
            ctx.stroke(p, with: .color(Color.red.opacity(0.08)), lineWidth: 1)
        }
        for (i, wxx) in [w * 0.20, w * 0.63].enumerated() {
            px(ctx: &ctx, x: wxx - 16, y: gy + 34, w: 32, h: 9,
               color: Color(red: 0.12, green: 0.07, blue: 0.07))
            let fh = 10 + 6 * CGFloat(sin(t * 8 + Double(i) * 2.4))
            px(ctx: &ctx, x: wxx - 6, y: gy + 34 - fh, w: 12, h: fh,
               color: Color(red: 1, green: 0.45, blue: 0.1, opacity: 0.9))
        }
        // Twin searchlights raking the sky at the intruder.
        for (i, ox) in [w * 0.22, w * 0.66].enumerated() {
            let a = sin(t * 0.9 + Double(i) * 3.1) * 0.7
            let len: CGFloat = h * 0.55
            let tip = CGPoint(x: ox + CGFloat(sin(Double(a))) * len, y: gy - CGFloat(cos(Double(a))) * len)
            var sl = Path()
            sl.move(to: CGPoint(x: ox - 3, y: gy + 10))
            sl.addLine(to: CGPoint(x: ox + 3, y: gy + 10))
            sl.addLine(to: CGPoint(x: tip.x + 16, y: tip.y))
            sl.addLine(to: CGPoint(x: tip.x - 16, y: tip.y))
            sl.closeSubpath()
            ctx.fill(sl, with: .color(Color.white.opacity(0.08)))
        }

        // Flickering shield dome straining over the colony heart.
        let shieldFlicker = (sin(t * 7.3) + sin(t * 13.7)) / 4 + 0.55
        if shieldFlicker > 0.25 {
            var dome = Path()
            dome.addArc(center: CGPoint(x: w * 0.47, y: gy + 30), radius: w * 0.30,
                        startAngle: .radians(.pi), endAngle: .radians(2 * .pi), clockwise: false)
            ctx.stroke(dome, with: .color(Color.cyan.opacity(0.35 * shieldFlicker)), lineWidth: 3)
            var dome2 = Path()
            dome2.addArc(center: CGPoint(x: w * 0.47, y: gy + 30), radius: w * 0.30 - 8,
                         startAngle: .radians(.pi * 1.1), endAngle: .radians(.pi * 1.9), clockwise: false)
            ctx.stroke(dome2, with: .color(Color.cyan.opacity(0.18 * shieldFlicker)), lineWidth: 6)
        }

        // Foreground rubble, red-lit from the burning horizon.
        let fgRubble = Color(red: 0.08, green: 0.04, blue: 0.05)
        let fgEdge = Color(red: 0.70, green: 0.22, blue: 0.20)
        px(ctx: &ctx, x: -12, y: h - 58, w: 130, h: 58, color: fgRubble)
        px(ctx: &ctx, x: 40, y: h - 88, w: 64, h: 36, color: fgRubble)
        px(ctx: &ctx, x: -12, y: h - 58, w: 130, h: 3, color: fgEdge)
        px(ctx: &ctx, x: 40, y: h - 88, w: 64, h: 3, color: fgEdge)
        px(ctx: &ctx, x: w - 110, y: h - 48, w: 122, h: 48, color: fgRubble)
        px(ctx: &ctx, x: w - 88, y: h - 72, w: 52, h: 28, color: fgRubble)
        px(ctx: &ctx, x: w - 110, y: h - 48, w: 122, h: 3, color: fgEdge)
        px(ctx: &ctx, x: w - 88, y: h - 72, w: 52, h: 3, color: fgEdge)

        scanlines(ctx: &ctx, size: size)
        vignette(ctx: &ctx, size: size)
    }

    /// The Layard mothership: a vast dark wedge ringed with pulsing green ports.
    private static func drawMothership(ctx: inout GraphicsContext, center c: CGPoint,
                                       width shipW: CGFloat, t: Double) {
        let hull = Color(red: 0.09, green: 0.10, blue: 0.13)
        let hullHi = Color(red: 0.20, green: 0.22, blue: 0.28)
        let alien = Color(red: 1.0, green: 0.22, blue: 0.22)
        let hgt = shipW * 0.22
        // Wide wedge hull.
        var hullPath = Path()
        hullPath.move(to: CGPoint(x: c.x - shipW / 2, y: c.y))
        hullPath.addLine(to: CGPoint(x: c.x - shipW * 0.18, y: c.y - hgt))
        hullPath.addLine(to: CGPoint(x: c.x + shipW * 0.18, y: c.y - hgt))
        hullPath.addLine(to: CGPoint(x: c.x + shipW / 2, y: c.y))
        hullPath.addLine(to: CGPoint(x: c.x + shipW * 0.30, y: c.y + hgt * 0.55))
        hullPath.addLine(to: CGPoint(x: c.x - shipW * 0.30, y: c.y + hgt * 0.55))
        hullPath.closeSubpath()
        ctx.fill(hullPath, with: .color(hull))
        // Spine + rim highlights.
        px(ctx: &ctx, x: c.x - shipW * 0.18, y: c.y - hgt, w: shipW * 0.36, h: 3, color: hullHi)
        px(ctx: &ctx, x: c.x - shipW * 0.30, y: c.y + hgt * 0.55 - 3, w: shipW * 0.60, h: 3,
           color: hullHi.opacity(0.7))
        // Crown spire.
        px(ctx: &ctx, x: c.x - 3, y: c.y - hgt - 26, w: 6, h: 26, color: hullHi)
        if Int(t * 2) % 2 == 0 {
            px(ctx: &ctx, x: c.x - 4, y: c.y - hgt - 34, w: 8, h: 8, color: alien)
        }
        // Ring of engine ports, breathing green.
        let ports = 9
        for i in 0..<ports {
            let k = CGFloat(i) / CGFloat(ports - 1) - 0.5
            let portX = c.x + k * shipW * 0.62
            let portY = c.y + hgt * 0.55 - 5
            let pulse = 0.5 + 0.5 * sin(t * 3 + Double(i) * 0.9)
            px(ctx: &ctx, x: portX - 5, y: portY, w: 10, h: 6, color: Color.black.opacity(0.6))
            px(ctx: &ctx, x: portX - 4, y: portY + 1, w: 8, h: 4,
               color: alien.opacity(0.45 + 0.45 * pulse))
        }
        // Running lights along the rim.
        for i in 0..<12 {
            let k = CGFloat(i) / 11 - 0.5
            if Int(t * 1.2 + Double(i)) % 3 == 0 {
                px(ctx: &ctx, x: c.x + k * shipW * 0.9 - 2, y: c.y - hgt * 0.35, w: 4, h: 4,
                   color: alien.opacity(0.9))
            }
        }
    }

    // MARK: Scene 6 — The Great Battle, 2251 (a world on fire)

    static func drawBattle(ctx: inout GraphicsContext, size: CGSize, t: Double,
                           elapsed: Double) {
        let w = size.width, h = size.height
        let gy = h * 0.70
        let alien = Color(red: 0.35, green: 1.0, blue: 0.55)

        // Smoke-choked sky over a burning horizon.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.03, green: 0.02, blue: 0.04),
                                      Color(red: 0.16, green: 0.06, blue: 0.08),
                                      Color(red: 0.55, green: 0.20, blue: 0.10)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: gy)))
        // Burning horizon glare, pulsing with the fires below.
        let glare = 0.30 + 0.08 * sin(t * 2.2)
        ctx.fill(Path(CGRect(x: 0, y: gy - 30, width: w, height: 30)),
                 with: .linearGradient(
                    Gradient(colors: [.clear,
                                      Color(red: 1, green: 0.45, blue: 0.15, opacity: glare)]),
                    startPoint: CGPoint(x: 0, y: gy - 30), endPoint: CGPoint(x: 0, y: gy)))

        // Ruined skyline: broken towers, fires, rubble — rooted at the ground.
        drawRuins(ctx: &ctx, width: w, baseY: gy, t: t)

        // Smoke columns boiling off the ruins.
        for i in 0..<7 {
            let scx = CGFloat(hash(i, 771) % 1000) / 1000 * w
            let drift = sin(t * 0.6 + Double(i)) * 14
            var syy = gy - h * 0.28
            var sw: CGFloat = 10
            while syy > h * 0.08 {
                ctx.fill(Path(CGRect(x: scx + drift * (gy - syy) / 120, y: syy,
                                      width: sw, height: 10)),
                         with: .color(Color.gray.opacity(0.26)))
                syy -= 12; sw += 2.5
            }
        }

        // Rolling explosion barrage across the ruins (staggered cycle).
        for i in 0..<4 {
            let cycle = (t * 0.45 + Double(i) * 1.7).truncatingRemainder(dividingBy: 6.8)
            if cycle < 1.3 {
                let k = cycle / 1.3
                let ex = CGFloat(hash(i, 701) % 1000) / 1000 * w
                let ey = gy - CGFloat(hash(i, 703) % 100) / 100 * h * 0.35 - 10
                // White-hot flash fading out.
                ctx.fill(Path(ellipseIn: CGRect(x: ex - 44, y: ey - 44, width: 88, height: 88)),
                         with: .radialGradient(
                            Gradient(colors: [Color.white.opacity(0.55 * (1 - k)), .clear]),
                            center: CGPoint(x: ex, y: ey), startRadius: 0, endRadius: 44))
                // Fireball shrinking into smoke.
                let fr = 26 * (1 - k) + 6
                pxCircle(ctx: &ctx, center: CGPoint(x: ex, y: ey), r: fr,
                         color: Color(red: 1, green: 0.5, blue: 0.12, opacity: 0.9))
                pxCircle(ctx: &ctx, center: CGPoint(x: ex, y: ey - fr * 0.3), r: fr * 0.55,
                         color: Color(red: 1, green: 0.8, blue: 0.35, opacity: 0.9))
                // Shockwave ring + rising smoke.
                ctx.stroke(Path(ellipseIn: CGRect(x: ex - k * 70, y: ey - k * 34,
                                                  width: k * 140, height: k * 68)),
                           with: .color(Color.white.opacity(0.35 * (1 - k))), lineWidth: 2)
                for j in 0..<4 {
                    let rise = k * 60 + CGFloat(j) * 8
                    ctx.fill(Path(CGRect(x: ex - 8 + CGFloat(hash(j, i) % 16), y: ey - rise,
                                          width: 12, height: 8)),
                             with: .color(Color.gray.opacity(0.4 * (1 - k))))
                }
            }
        }

        // Dogfight overhead: interceptors vs Layard discs, tracers between.
        for i in 0..<3 {
            let laneY = h * 0.14 + CGFloat(i) * h * 0.08
            let span = w + 160
            let hp = (t * (150 + Double(i) * 40) + Double(i) * 521).truncatingRemainder(dividingBy: Double(span))
            let hx = CGFloat(hp) - 80
            for j in 0..<5 {
                px(ctx: &ctx, x: hx - CGFloat(j) * 11, y: laneY, w: 9 - CGFloat(j), h: 2,
                   color: Color.cyan.opacity(0.4 - CGFloat(j) * 0.07))
            }
            px(ctx: &ctx, x: hx - 7, y: laneY - 2, w: 15, h: 5,
               color: Color(red: 0.70, green: 0.75, blue: 0.85))
            let ap = (t * (130 + Double(i) * 35) + Double(i) * 917 + 300).truncatingRemainder(dividingBy: Double(span))
            let ax = w + 80 - CGFloat(ap)
            let ay = laneY + 22
            for j in 0..<5 {
                px(ctx: &ctx, x: ax + CGFloat(j) * 10, y: ay, w: 9 - CGFloat(j), h: 2,
                   color: alien.opacity(0.4 - CGFloat(j) * 0.07))
            }
            px(ctx: &ctx, x: ax - 8, y: ay - 3, w: 17, h: 6,
               color: Color(red: 0.10, green: 0.12, blue: 0.14))
            px(ctx: &ctx, x: ax - 8, y: ay + 3, w: 17, h: 2, color: alien.opacity(0.9))
            // Tracer exchange flashing between the pair.
            if Int(t * 6 + Double(i) * 2) % 3 != 0 {
                var tr = Path()
                tr.move(to: CGPoint(x: hx, y: laneY))
                tr.addLine(to: CGPoint(x: ax, y: ay))
                ctx.stroke(tr, with: .color(Color.yellow.opacity(0.5)), lineWidth: 1.5)
            }
        }

        // Flak bursts blooming in the dogfight lanes + a slow recon flare.
        for i in 0..<5 {
            let cyc = (t * 0.8 + Double(i) * 1.3).truncatingRemainder(dividingBy: 6.5)
            if cyc < 0.5 {
                let k = cyc / 0.5
                let fx2 = CGFloat(hash(i, 781) % 1000) / 1000 * w
                let fy = h * 0.10 + CGFloat(hash(i, 783) % 100) / 100 * h * 0.18
                ctx.fill(Path(ellipseIn: CGRect(x: fx2 - 14, y: fy - 14, width: 28, height: 28)),
                         with: .radialGradient(
                            Gradient(colors: [Color.white.opacity(0.7 * (1 - k)), .clear]),
                            center: CGPoint(x: fx2, y: fy), startRadius: 0, endRadius: 14))
                for a in [0.0, 1.57] {
                    var spark = Path()
                    spark.move(to: CGPoint(x: fx2 - CGFloat(cos(a)) * 20 * k,
                                           y: fy - CGFloat(sin(a)) * 20 * k))
                    spark.addLine(to: CGPoint(x: fx2 + CGFloat(cos(a)) * 20 * k,
                                              y: fy + CGFloat(sin(a)) * 20 * k))
                    ctx.stroke(spark, with: .color(Color.yellow.opacity(0.6 * (1 - k))), lineWidth: 2)
                }
            }
        }
        do {
            let flareCycle = 14.0
            let fk = (t.truncatingRemainder(dividingBy: flareCycle)) / flareCycle
            let flX = w * 0.30 + sin(fk * 5) * 20
            let flY = h * 0.12 + fk * h * 0.30
            ctx.fill(Path(ellipseIn: CGRect(x: flX - 60, y: flY - 60, width: 120, height: 120)),
                     with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.20 * (1 - fk * 0.5)), .clear]),
                        center: CGPoint(x: flX, y: flY), startRadius: 0, endRadius: 60))
            px(ctx: &ctx, x: flX - 3, y: flY - 3, w: 6, h: 6, color: .white)
            px(ctx: &ctx, x: flX - 1, y: flY + 3, w: 2, h: 14, color: Color.white.opacity(0.5))
        }

        // Scorched ground: craters, wreckage, one last stronghold.
        ctx.fill(Path(CGRect(x: 0, y: gy, width: w, height: h - gy)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.16, green: 0.07, blue: 0.06),
                                      Color(red: 0.05, green: 0.02, blue: 0.02)]),
                    startPoint: CGPoint(x: 0, y: gy), endPoint: CGPoint(x: 0, y: h)))
        for i in 0..<5 {
            let cx = CGFloat(hash(i, 731) % 1000) / 1000 * w
            let cw = 26 + CGFloat(hash(i, 733) % 30)
            pxCircle(ctx: &ctx, center: CGPoint(x: cx, y: gy + 26 + CGFloat(i) * 8), r: cw,
                     color: Color.black.opacity(0.55))
            px(ctx: &ctx, x: cx - cw, y: gy + 24 + CGFloat(i) * 8, w: cw * 2, h: 2,
               color: Color(red: 1, green: 0.4, blue: 0.1, opacity: 0.35))
        }
        // Downed interceptor burning in the dirt.
        let wx = w * 0.30
        px(ctx: &ctx, x: wx - 24, y: gy + 46, w: 48, h: 8,
           color: Color(red: 0.25, green: 0.25, blue: 0.30))
        px(ctx: &ctx, x: wx + 4, y: gy + 34, w: 22, h: 12,
           color: Color(red: 0.18, green: 0.18, blue: 0.22))
        let wfl = 0.5 + 0.5 * sin(t * 11)
        px(ctx: &ctx, x: wx - 4, y: gy + 26, w: 12, h: 10,
           color: Color(red: 1, green: 0.5, blue: 0.1, opacity: 0.5 + 0.4 * wfl))
        px(ctx: &ctx, x: wx - 1, y: gy + 28, w: 6, h: 6,
           color: Color(red: 1, green: 0.85, blue: 0.4, opacity: 0.9))
        for j in 0..<3 {
            let rise = CGFloat((t * 30 + Double(j) * 31).truncatingRemainder(dividingBy: 60))
            ctx.fill(Path(CGRect(x: wx + CGFloat(j) * 6 - 6, y: gy + 30 - rise, width: 10, height: 7)),
                     with: .color(Color.gray.opacity(0.45 * (1 - rise / 60))))
        }
        // Downed Layard disc, still burning green.
        let dx = w * 0.52
        px(ctx: &ctx, x: dx - 30, y: gy + 52, w: 60, h: 12,
           color: Color(red: 0.08, green: 0.10, blue: 0.11))
        px(ctx: &ctx, x: dx - 18, y: gy + 44, w: 36, h: 10,
           color: Color(red: 0.10, green: 0.13, blue: 0.14))
        let gfl = 0.5 + 0.5 * sin(t * 8 + 2)
        px(ctx: &ctx, x: dx - 8, y: gy + 46, w: 16, h: 8,
           color: alien.opacity(0.5 + 0.4 * gfl))
        ctx.fill(Path(ellipseIn: CGRect(x: dx - 30, y: gy + 38, width: 60, height: 22)),
                 with: .radialGradient(
                    Gradient(colors: [alien.opacity(0.30), .clear]),
                    center: CGPoint(x: dx, y: gy + 48), startRadius: 0, endRadius: 30))
        // Collapsed overpass slabs + rebar.
        px(ctx: &ctx, x: w * 0.08, y: gy + 52, w: 70, h: 9,
           color: Color(red: 0.20, green: 0.19, blue: 0.22))
        px(ctx: &ctx, x: w * 0.08 + 10, y: gy + 40, w: 56, h: 9,
           color: Color(red: 0.24, green: 0.23, blue: 0.26))
        px(ctx: &ctx, x: w * 0.08 + 22, y: gy + 30, w: 40, h: 8,
           color: Color(red: 0.18, green: 0.17, blue: 0.20))
        for k in 0..<4 {
            var rebar = Path()
            rebar.move(to: CGPoint(x: w * 0.08 + 14 + CGFloat(k) * 14, y: gy + 40))
            rebar.addLine(to: CGPoint(x: w * 0.08 + 20 + CGFloat(k) * 14, y: gy + 28))
            ctx.stroke(rebar, with: .color(Color.gray.opacity(0.6)), lineWidth: 1.5)
        }
        // Ground fire fronts chewing through the blocks.
        for (i, bxx) in [w * 0.13, w * 0.44, w * 0.86].enumerated() {
            px(ctx: &ctx, x: bxx - 22, y: gy + 40, w: 44, h: 12,
               color: Color(red: 0.14, green: 0.08, blue: 0.07))
            ctx.fill(Path(ellipseIn: CGRect(x: bxx - 30, y: gy + 22, width: 60, height: 30)),
                     with: .radialGradient(
                        Gradient(colors: [Color(red: 1, green: 0.45, blue: 0.1, opacity: 0.35), .clear]),
                        center: CGPoint(x: bxx, y: gy + 36), startRadius: 0, endRadius: 30))
            for j in 0..<3 {
                let fh = 12 + 8 * CGFloat(sin(t * (7 + Double(j)) + Double(i) * 2 + Double(j)))
                px(ctx: &ctx, x: bxx - 14 + CGFloat(j) * 11, y: gy + 40 - fh, w: 8, h: fh,
                   color: Color(red: 1, green: 0.5, blue: 0.1, opacity: 0.85))
                px(ctx: &ctx, x: bxx - 12 + CGFloat(j) * 11, y: gy + 40 - fh * 0.5, w: 4, h: fh * 0.5,
                   color: Color(red: 1, green: 0.85, blue: 0.4, opacity: 0.9))
            }
        }
        // Evac dropship clawing low across the field, spotlight sweeping.
        do {
            let span = w + 220
            let ex = CGFloat((t * 70).truncatingRemainder(dividingBy: Double(span))) - 110
            let ey = gy - 120 + sin(t * 1.4) * 10
            var cone = Path()
            cone.move(to: CGPoint(x: ex - 8, y: ey + 10))
            cone.addLine(to: CGPoint(x: ex + 8, y: ey + 10))
            cone.addLine(to: CGPoint(x: ex + 40, y: gy + 20))
            cone.addLine(to: CGPoint(x: ex - 40, y: gy + 20))
            cone.closeSubpath()
            ctx.fill(cone, with: .color(Color.white.opacity(0.09)))
            drawDropship(ctx: &ctx, at: CGPoint(x: ex, y: ey), t: t)
        }
        // The stronghold: low bastion, AA tracers, straining shield.
        let sx = w * 0.68
        px(ctx: &ctx, x: sx - 60, y: gy + 22, w: 120, h: 30,
           color: Color(red: 0.22, green: 0.23, blue: 0.28))
        px(ctx: &ctx, x: sx - 60, y: gy + 22, w: 120, h: 3,
           color: Color(red: 0.50, green: 0.55, blue: 0.65))
        for (i, gx) in [sx - 34, sx + 22].enumerated() {
            px(ctx: &ctx, x: gx, y: gy + 8, w: 10, h: 16,
               color: Color(red: 0.30, green: 0.31, blue: 0.38))
            let aim = -0.5 + sin(t * 1.1 + Double(i) * 3.1) * 0.35
            let mx = gx + 5 + CGFloat(sin(Double(aim))) * 26
            let my = gy + 8 - CGFloat(cos(Double(aim))) * 60
            var tracer = Path()
            tracer.move(to: CGPoint(x: gx + 5, y: gy + 8))
            tracer.addLine(to: CGPoint(x: mx, y: my))
            ctx.stroke(tracer, with: .color(Color.yellow.opacity(
                Int(t * 14 + Double(i) * 5) % 2 == 0 ? 0.8 : 0.15)), lineWidth: 2)
            if Int(t * 14 + Double(i) * 5) % 2 == 0 {
                px(ctx: &ctx, x: gx + 2, y: gy + 4, w: 6, h: 5,
                   color: Color(red: 1, green: 0.8, blue: 0.4))
            }
        }
        // Perimeter wall: the firing line holds the rubble.
        px(ctx: &ctx, x: sx - 95, y: gy + 40, w: 190, h: 10,
           color: Color(red: 0.18, green: 0.18, blue: 0.22))
        px(ctx: &ctx, x: sx - 95, y: gy + 40, w: 190, h: 2,
           color: Color(red: 0.45, green: 0.45, blue: 0.50))
        var postX = sx - 88
        while postX < sx + 90 {
            px(ctx: &ctx, x: postX, y: gy + 34, w: 4, h: 6,
               color: Color(red: 1, green: 0.8, blue: 0.45, opacity: 0.8))
            postX += 24
        }
        for i in 0..<8 {
            if Int(t * 9 + Double(i) * 1.7) % 3 == 0 {
                let mx = sx - 84 + CGFloat(i) * 24
                px(ctx: &ctx, x: mx, y: gy + 30, w: 5, h: 4,
                   color: Color(red: 1, green: 0.9, blue: 0.55))
                var mtr = Path()
                mtr.move(to: CGPoint(x: mx + 2, y: gy + 30))
                mtr.addLine(to: CGPoint(x: mx + 8, y: gy - 6))
                ctx.stroke(mtr, with: .color(Color.yellow.opacity(0.6)), lineWidth: 1.5)
            }
        }
        let shieldK = (sin(t * 5.1) + sin(t * 9.7)) / 4 + 0.6
        if shieldK > 0.2 {
            var dome = Path()
            dome.addArc(center: CGPoint(x: sx, y: gy + 30), radius: 86,
                        startAngle: .radians(.pi), endAngle: .radians(2 * .pi), clockwise: false)
            ctx.stroke(dome, with: .color(Color.cyan.opacity(0.4 * shieldK)), lineWidth: 3)
        }

        // Embers rising off the burning world.
        for i in 0..<40 {
            let seed = CGFloat(hash(i, 751) % 1000) / 1000
            let rise = CGFloat((t * 34 + Double(hash(i, 753) % 500)).truncatingRemainder(dividingBy: Double(h + 40)))
            let ex = seed * w + CGFloat(sin(t * 1.4 + Double(i))) * 12
            let ey = h + 10 - rise
            if ey < gy - h * 0.3 { continue }
            let ember: Color = i % 4 == 0 ? .yellow : Color(red: 1, green: 0.45, blue: 0.12)
            let esz: CGFloat = i % 5 == 0 ? 3 : 2
            ctx.fill(Path(CGRect(x: ex, y: ey, width: esz, height: esz)),
                     with: .color(ember.opacity(0.75)))
        }

        // Foreground rubble silhouettes.
        let fgAsh = Color(red: 0.06, green: 0.03, blue: 0.03)
        let fgFire = Color(red: 0.80, green: 0.30, blue: 0.12)
        px(ctx: &ctx, x: -12, y: h - 60, w: 140, h: 60, color: fgAsh)
        px(ctx: &ctx, x: 44, y: h - 92, w: 60, h: 36, color: fgAsh)
        px(ctx: &ctx, x: -12, y: h - 60, w: 140, h: 3, color: fgFire)
        px(ctx: &ctx, x: 44, y: h - 92, w: 60, h: 3, color: fgFire)
        px(ctx: &ctx, x: w - 120, y: h - 50, w: 132, h: 50, color: fgAsh)
        px(ctx: &ctx, x: w - 120, y: h - 50, w: 132, h: 3, color: fgFire)

        scanlines(ctx: &ctx, size: size)
        vignette(ctx: &ctx, size: size)
    }

    /// Broken skyline: jagged towers with burning windows and rubble bases.
    private static func drawRuins(ctx: inout GraphicsContext, width w: CGFloat,
                                  baseY: CGFloat, t: Double) {
        for i in 0..<9 {
            let bx = CGFloat(i) * w / 8 + CGFloat(hash(i, 761) % 24) - 12
            let tw = 34 + CGFloat(hash(i, 763) % 26)
            let th = hFraction(i) * (baseY * 0.55)
            let body = Color(red: 0.11, green: 0.08, blue: 0.09)
            px(ctx: &ctx, x: bx, y: baseY - th, w: tw, h: th, color: body)
            // Jagged broken crown.
            let teeth = 2 + hash(i, 765) % 3
            for k in 0..<teeth {
                let tx = bx + CGFloat(k) * tw / CGFloat(teeth)
                let tall = 8 + CGFloat(hash(k, i + 80) % 14)
                px(ctx: &ctx, x: tx, y: baseY - th - tall, w: tw / CGFloat(teeth), h: tall, color: body)
            }
            px(ctx: &ctx, x: bx - 8, y: baseY - 10, w: tw + 16, h: 10,
               color: Color(red: 0.16, green: 0.10, blue: 0.09))
            // Windows: mostly dead, some burning.
            var r = 0
            var yy = baseY - th + 10
            while yy < baseY - 10 {
                var xx = bx + 5
                while xx < bx + tw - 7 {
                    let roll = hash(r, 767 + Int(t * 0.8))
                    if roll % 9 == 0 {
                        let fl = 0.5 + 0.5 * sin(t * 9 + Double(r))
                        px(ctx: &ctx, x: xx, y: yy, w: 5, h: 6,
                           color: Color(red: 1, green: 0.5, blue: 0.1, opacity: 0.5 + 0.4 * fl))
                    } else if roll % 9 == 1 {
                        px(ctx: &ctx, x: xx, y: yy, w: 5, h: 6, color: Color.black.opacity(0.7))
                    }
                    xx += 10; r += 1
                }
                yy += 11
            }
        }
    }

    /// Deterministic tower heights: middle towers stood tallest.
    private static func hFraction(_ i: Int) -> CGFloat {
        let base: [CGFloat] = [0.45, 0.7, 0.55, 0.9, 0.65, 1.0, 0.6, 0.8, 0.5]
        return base[i % base.count]
    }

    // MARK: Scene 7 — The March Back (mustering at dawn)

    static func drawCounterattack(ctx: inout GraphicsContext, size: CGSize, t: Double,
                                  elapsed: Double) {
        let w = size.width, h = size.height
        let gy = h * 0.66

        // Pre-dawn sky breaking into sunrise gold.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.14),
                                      Color(red: 0.20, green: 0.16, blue: 0.32),
                                      Color(red: 0.85, green: 0.45, blue: 0.25)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: gy)))
        // Last fading stars.
        for i in 0..<30 {
            let sx = CGFloat(hash(i, 801) % 1000) / 1000 * w
            let sy = CGFloat(hash(i, 803) % 1000) / 1000 * h * 0.30
            ctx.fill(Path(CGRect(x: sx, y: sy, width: 2, height: 2)),
                     with: .color(Color.white.opacity(0.35)))
        }
        // The sun clawing over the ridge — hope, one slow rise.
        let rise = 1 - pow(1 - min(1, elapsed / 14), 2)
        let sun = CGPoint(x: w * 0.62, y: gy - 26 - rise * 26)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 80, y: sun.y - 80, width: 160, height: 160)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 1, green: 0.7, blue: 0.4, opacity: 0.55), .clear]),
                    center: sun, startRadius: 0, endRadius: 80))
        pxCircle(ctx: &ctx, center: sun, r: 24,
                 color: Color(red: 1, green: 0.82, blue: 0.55))
        pxCircle(ctx: &ctx, center: CGPoint(x: sun.x - 6, y: sun.y - 6), r: 16,
                 color: Color(red: 1, green: 0.92, blue: 0.72))
        // Pink dawn clouds.
        duskCloud(ctx: &ctx, width: w, seed: 61, y: h * 0.30, s: 1.1, t: t, speed: 8,
                  color: Color(red: 0.35, green: 0.18, blue: 0.30, opacity: 0.9),
                  lit: Color(red: 1, green: 0.6, blue: 0.4, opacity: 0.8))
        duskCloud(ctx: &ctx, width: w, seed: 71, y: h * 0.20, s: 0.8, t: t, speed: 12,
                  color: Color(red: 0.30, green: 0.16, blue: 0.30, opacity: 0.9),
                  lit: Color(red: 1, green: 0.6, blue: 0.4, opacity: 0.7))
        // Birds returning to the sky.
        for i in 0..<5 {
            let span = w + 60
            let bx = CGFloat((t * (24 + Double(i) * 6) + Double(i) * 173).truncatingRemainder(dividingBy: Double(span))) - 30
            let by = h * 0.24 + CGFloat(i) * 14 + sin(t * 1.2 + Double(i)) * 6
            let flap: CGFloat = Int(t * 6 + Double(i)) % 2 == 0 ? 3 : 1
            var gull = Path()
            gull.move(to: CGPoint(x: bx - 6, y: by - flap))
            gull.addLine(to: CGPoint(x: bx, y: by))
            gull.addLine(to: CGPoint(x: bx + 6, y: by - flap))
            ctx.stroke(gull, with: .color(Color.black.opacity(0.6)), lineWidth: 2)
        }

        // Far ridge, grounded, catching first light on its crest.
        ridge(ctx: &ctx, width: w, baseline: h * 0.56, phase: 1.9, amp: h * 0.06, step: 18,
              color: Color(red: 0.20, green: 0.12, blue: 0.24), floor: gy)
        for i in 0..<20 {
            let cx = CGFloat(i) * w / 19
            let n = sin(Double(cx) * 0.010 + 1.9) * 0.55
                + sin(Double(cx) * 0.027 + 3.99) * 0.30
                + sin(Double(cx) * 0.061 + 1.33) * 0.15
            let cy = h * 0.56 - h * 0.06 * CGFloat((n + 1) / 2)
            ctx.fill(Path(CGRect(x: cx, y: cy, width: 7, height: 2)),
                     with: .color(Color(red: 1, green: 0.6, blue: 0.35, opacity: 0.6)))
        }

        // Parade ground dust.
        ctx.fill(Path(CGRect(x: 0, y: gy, width: w, height: h - gy)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.38, green: 0.22, blue: 0.15),
                                      Color(red: 0.16, green: 0.09, blue: 0.08)]),
                    startPoint: CGPoint(x: 0, y: gy), endPoint: CGPoint(x: 0, y: h)))

        // The stronghold wall with its glowing gate + banner towers.
        let wallY = gy + 6
        px(ctx: &ctx, x: 0, y: wallY, w: w, h: 26,
           color: Color(red: 0.26, green: 0.26, blue: 0.32))
        var crenX: CGFloat = 4
        while crenX < w {
            px(ctx: &ctx, x: crenX, y: wallY - 6, w: 10, h: 6,
               color: Color(red: 0.26, green: 0.26, blue: 0.32))
            crenX += 20
        }
        // Gate: warm light spilling out.
        let gateX = w * 0.5
        px(ctx: &ctx, x: gateX - 22, y: wallY - 2, w: 44, h: 28,
           color: Color(red: 1, green: 0.7, blue: 0.35, opacity: 0.9))
        px(ctx: &ctx, x: gateX - 26, y: wallY - 6, w: 6, h: 34,
           color: Color(red: 0.20, green: 0.20, blue: 0.26))
        px(ctx: &ctx, x: gateX + 20, y: wallY - 6, w: 6, h: 34,
           color: Color(red: 0.20, green: 0.20, blue: 0.26))
        ctx.fill(Path(ellipseIn: CGRect(x: gateX - 46, y: wallY - 4, width: 92, height: 40)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 1, green: 0.7, blue: 0.35, opacity: 0.35), .clear]),
                    center: CGPoint(x: gateX, y: wallY + 12), startRadius: 0, endRadius: 46))
        // Banner towers flanking the gate.
        for tx in [gateX - 90, gateX + 90] {
            px(ctx: &ctx, x: tx - 14, y: wallY - 52, w: 28, h: 52,
               color: Color(red: 0.22, green: 0.23, blue: 0.30))
            px(ctx: &ctx, x: tx - 14, y: wallY - 52, w: 28, h: 3,
               color: Color(red: 0.50, green: 0.55, blue: 0.65))
            if Int(t * 1.5 + Double(tx)) % 2 == 0 {
                px(ctx: &ctx, x: tx - 3, y: wallY - 60, w: 6, h: 6, color: .cyan)
            }
            // Blue war banner rippling.
            px(ctx: &ctx, x: tx + 2, y: wallY - 50, w: 2, h: 26,
               color: Color(red: 0.50, green: 0.53, blue: 0.60))
            let wave = CGFloat(sin(t * 4 + Double(tx)) * 2)
            px(ctx: &ctx, x: tx + 4, y: wallY - 50, w: 11, h: 16, color: .cyan.opacity(0.9))
            px(ctx: &ctx, x: tx + 15, y: wallY - 50 + wave, w: 9, h: 16, color: .cyan.opacity(0.7))
            px(ctx: &ctx, x: tx + 6, y: wallY - 47, w: 6, h: 5, color: .white)
        }

        // Resupply pads: one dropship down, one on final approach.
        for (i, padX) in [w * 0.13, w * 0.87].enumerated() {
            px(ctx: &ctx, x: padX - 42, y: gy + 66, w: 84, h: 8,
               color: Color(red: 0.25, green: 0.26, blue: 0.30))
            px(ctx: &ctx, x: padX - 42, y: gy + 66, w: 84, h: 2, color: .yellow.opacity(0.7))
            for k in 0..<5 {
                let lx = padX - 36 + CGFloat(k) * 18
                let chase = (Int(t * 4) + k + i * 3) % 5 < 2
                px(ctx: &ctx, x: lx, y: gy + 62, w: 5, h: 5,
                   color: chase ? .yellow : .red.opacity(0.4))
            }
        }
        // Landed freighter, ramp down, crates rolling out.
        drawDropship(ctx: &ctx, at: CGPoint(x: w * 0.13, y: gy + 48), t: t)
        let crateC = Color(red: 0.42, green: 0.40, blue: 0.30)
        px(ctx: &ctx, x: w * 0.13 + 30, y: gy + 58, w: 15, h: 13, color: crateC)
        px(ctx: &ctx, x: w * 0.13 + 46, y: gy + 60, w: 13, h: 11, color: crateC)
        px(ctx: &ctx, x: w * 0.13 + 37, y: gy + 47, w: 13, h: 11, color: crateC)
        px(ctx: &ctx, x: w * 0.13 + 30, y: gy + 58, w: 15, h: 2, color: Color.white.opacity(0.3))
        // Inbound ship: one descent, then it holds over the east pad.
        let descend = 1 - pow(1 - min(1, elapsed / 8), 3)
        let inY = h * 0.14 + descend * (gy + 30 - h * 0.14)
        let inX = w * 0.87 + sin(t * 0.6) * 4 * descend
        var cone = Path()
        cone.move(to: CGPoint(x: inX - 10, y: inY + 14))
        cone.addLine(to: CGPoint(x: inX + 10, y: inY + 14))
        cone.addLine(to: CGPoint(x: inX + 40, y: gy + 66))
        cone.addLine(to: CGPoint(x: inX - 40, y: gy + 66))
        cone.closeSubpath()
        ctx.fill(cone, with: .color(Color.yellow.opacity(0.10 * descend)))
        drawDropship(ctx: &ctx, at: CGPoint(x: inX, y: inY), t: t)

        // Troop columns marching out of the gate toward the field.
        for row in 0..<3 {
            let rowY = gy + 96 + CGFloat(row) * 16
            for k in 0..<6 {
                let span = w + 80
                let mx = CGFloat((t * 26 + Double(k) * 90 + Double(row) * 47)
                    .truncatingRemainder(dividingBy: Double(span))) - 40
                drawSoldier(ctx: &ctx, at: CGPoint(x: mx, y: rowY), t: t,
                            phase: Double(k * 2 + row * 3))
            }
        }
        // Armor rolling with them.
        for i in 0..<2 {
            let span = w + 240
            let tx = CGFloat((t * 20 + Double(i) * 420).truncatingRemainder(dividingBy: Double(span))) - 120
            drawTank(ctx: &ctx, at: CGPoint(x: tx, y: gy + 150 + CGFloat(i) * 22), t: t, seed: i)
        }

        // Foreground ridge with first green shoots of regrowth.
        let fgSoil = Color(red: 0.10, green: 0.07, blue: 0.08)
        px(ctx: &ctx, x: -16, y: h - 46, w: 220, h: 46, color: fgSoil)
        px(ctx: &ctx, x: w - 190, y: h - 38, w: 206, h: 38, color: fgSoil)
        px(ctx: &ctx, x: -16, y: h - 46, w: 220, h: 3,
           color: Color(red: 0.85, green: 0.5, blue: 0.3))
        var tuftX: CGFloat = 20
        while tuftX < 190 {
            px(ctx: &ctx, x: tuftX, y: h - 54, w: 3, h: 8,
               color: Color(red: 0.25, green: 0.55, blue: 0.25))
            tuftX += 22
        }

        scanlines(ctx: &ctx, size: size)
        vignette(ctx: &ctx, size: size)
    }

    /// One marching soldier: helmet, visor, rifle, alternating stride + dust.
    private static func drawSoldier(ctx: inout GraphicsContext, at p: CGPoint, t: Double, phase: Double) {
        let step = Int(t * 6 + phase) % 2 == 0
        let bob: CGFloat = step ? 0 : -1
        let armor = Color(red: 0.45, green: 0.52, blue: 0.60)
        let dark = Color(red: 0.22, green: 0.24, blue: 0.30)
        // Striding legs.
        px(ctx: &ctx, x: p.x - 3, y: p.y - 4 + (step ? 0 : -1), w: 2, h: 4, color: dark)
        px(ctx: &ctx, x: p.x + 1, y: p.y - 4 + (step ? -1 : 0), w: 2, h: 4, color: dark)
        // Torso + helmet + visor.
        px(ctx: &ctx, x: p.x - 3, y: p.y - 10 + bob, w: 6, h: 6, color: armor)
        px(ctx: &ctx, x: p.x - 3, y: p.y - 14 + bob, w: 6, h: 4, color: dark)
        px(ctx: &ctx, x: p.x + 1, y: p.y - 13 + bob, w: 3, h: 2, color: .cyan)
        // Rifle forward.
        px(ctx: &ctx, x: p.x + 3, y: p.y - 9 + bob, w: 8, h: 2, color: dark)
        // Dust kicked up every few strides.
        if Int(t * 3 + phase) % 3 == 0 {
            ctx.fill(Path(CGRect(x: p.x - 6, y: p.y - 3, width: 4, height: 3)),
                     with: .color(Color(red: 0.6, green: 0.45, blue: 0.3).opacity(0.5)))
        }
    }

    /// Human battle tank rolling with headlight and idle exhaust.
    private static func drawTank(ctx: inout GraphicsContext, at p: CGPoint, t: Double, seed: Int) {
        let hull = Color(red: 0.38, green: 0.42, blue: 0.46)
        let dark = Color(red: 0.20, green: 0.21, blue: 0.26)
        px(ctx: &ctx, x: p.x - 23, y: p.y - 8, w: 46, h: 8, color: hull)
        px(ctx: &ctx, x: p.x - 23, y: p.y - 8, w: 46, h: 2, color: Color.white.opacity(0.35))
        px(ctx: &ctx, x: p.x - 8, y: p.y - 15, w: 18, h: 7, color: dark)
        px(ctx: &ctx, x: p.x + 10, y: p.y - 13, w: 18, h: 3, color: dark)
        // Tracks with rolling tread ticks.
        px(ctx: &ctx, x: p.x - 25, y: p.y, w: 50, h: 6, color: .black)
        let tread = Int(t * 10 + Double(seed) * 3) % 2 == 0
        var tx = p.x - 25
        while tx < p.x + 25 {
            px(ctx: &ctx, x: tx, y: p.y + (tread ? 0 : 2), w: 3, h: 2, color: Color.gray)
            tx += 8
        }
        // Headlight beam + exhaust shimmer.
        var beam = Path()
        beam.move(to: CGPoint(x: p.x + 23, y: p.y - 6))
        beam.addLine(to: CGPoint(x: p.x + 52, y: p.y))
        beam.addLine(to: CGPoint(x: p.x + 52, y: p.y - 10))
        beam.closeSubpath()
        ctx.fill(beam, with: .color(Color.yellow.opacity(0.15)))
        px(ctx: &ctx, x: p.x + 23, y: p.y - 7, w: 3, h: 3, color: .yellow.opacity(0.9))
        if Int(t * 4 + Double(seed)) % 2 == 0 {
            ctx.fill(Path(CGRect(x: p.x - 28, y: p.y - 12, width: 5, height: 4)),
                     with: .color(Color.gray.opacity(0.5)))
        }
        if Int(t * 1.5 + Double(seed)) % 2 == 0 {
            px(ctx: &ctx, x: p.x - 4, y: p.y - 19, w: 4, h: 4, color: .cyan.opacity(0.9))
        }
    }

    // MARK: - Pieces

    private static func drawShip(ctx: inout GraphicsContext, at p: CGPoint, t: Double) {
        let c = Color.white
        let hull = Color(red: 0.75, green: 0.80, blue: 0.88)
        let dark = Color(red: 0.35, green: 0.40, blue: 0.50)
        // Hull: chunky arrow.
        px(ctx: &ctx, x: p.x - 22, y: p.y - 4, w: 34, h: 8, color: hull)
        px(ctx: &ctx, x: p.x + 12, y: p.y - 6, w: 10, h: 12, color: hull)
        px(ctx: &ctx, x: p.x - 22, y: p.y - 4, w: 34, h: 2, color: c.opacity(0.9))
        px(ctx: &ctx, x: p.x - 6, y: p.y - 8, w: 10, h: 4, color: .cyan) // cockpit
        px(ctx: &ctx, x: p.x - 26, y: p.y - 2, w: 6, h: 4, color: dark)  // cargo
        // Engine flame flicker.
        let f = 10 + CGFloat(sin(t * 30) * 4)
        px(ctx: &ctx, x: p.x - 22 - f, y: p.y - 3, w: f, h: 6,
           color: Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.85))
        px(ctx: &ctx, x: p.x - 22 - f * 0.5, y: p.y - 1, w: f * 0.5, h: 2, color: .white)
        // Blinking nav light.
        if Int(t * 2) % 2 == 0 {
            px(ctx: &ctx, x: p.x + 8, y: p.y - 10, w: 4, h: 4, color: .red)
        }
    }

    private static func drawDropship(ctx: inout GraphicsContext, at p: CGPoint, t: Double) {
        let hull = Color(red: 0.72, green: 0.75, blue: 0.82)
        let dark = Color(red: 0.30, green: 0.33, blue: 0.42)
        px(ctx: &ctx, x: p.x - 30, y: p.y - 8, w: 60, h: 16, color: hull)
        px(ctx: &ctx, x: p.x - 30, y: p.y - 8, w: 60, h: 3, color: .white.opacity(0.85))
        px(ctx: &ctx, x: p.x - 18, y: p.y - 14, w: 36, h: 6, color: dark)
        px(ctx: &ctx, x: p.x - 10, y: p.y - 14, w: 20, h: 3, color: .cyan.opacity(0.9))
        px(ctx: &ctx, x: p.x - 38, y: p.y - 2, w: 8, h: 6, color: dark)
        px(ctx: &ctx, x: p.x + 30, y: p.y - 2, w: 8, h: 6, color: dark)
        // Twin thrusters.
        for dx in [-18, 18] as [CGFloat] {
            let f = 12 + CGFloat(sin(t * 28 + Double(dx)) * 4)
            px(ctx: &ctx, x: p.x + dx - 4, y: p.y + 8, w: 8, h: f,
               color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.9))
            px(ctx: &ctx, x: p.x + dx - 2, y: p.y + 8, w: 4, h: f * 0.6, color: .white)
        }
        if Int(t * 2) % 2 == 0 {
            px(ctx: &ctx, x: p.x - 2, y: p.y - 20, w: 4, h: 4, color: .red)
        }
    }

    private static func drawDome(ctx: inout GraphicsContext, center c: CGPoint, r: CGFloat,
                                 finished: Bool, t: Double, lit: Bool) {
        // Base ring.
        px(ctx: &ctx, x: c.x - r, y: c.y, w: r * 2, h: 10,
           color: Color(red: 0.28, green: 0.29, blue: 0.34))
        let glass = finished
            ? Color(red: 0.45, green: 0.75, blue: 0.85, opacity: 0.85)
            : Color(red: 0.35, green: 0.38, blue: 0.45, opacity: 0.8)
        // Stepped dome (pixel arch).
        let steps = 6
        for i in 0..<steps {
            let k = CGFloat(i) / CGFloat(steps)
            let half = r * sin(acos(1 - (k + 0.5) / CGFloat(steps) * 1.0))
            let y = c.y - CGFloat(i + 1) / CGFloat(steps) * r
            px(ctx: &ctx, x: c.x - half, y: y, w: half * 2, h: r / CGFloat(steps) + 1, color: glass)
        }
        // Frame ribs.
        for dx in [-0.6, -0.2, 0.2, 0.6] as [CGFloat] {
            px(ctx: &ctx, x: c.x + dx * r - 2, y: c.y - r, w: 4, h: r, color: Color.black.opacity(0.35))
        }
        if finished {
            // Glass shine sweep + warm interior windows.
            let shine = (t * 0.3).truncatingRemainder(dividingBy: 1)
            px(ctx: &ctx, x: c.x - r * 0.5 + (shine - 0.5) * r, y: c.y - r * 0.85,
               w: 12, h: r * 0.6, color: Color.white.opacity(0.25))
            if lit {
                for i in 0..<4 {
                    let wx = c.x - r * 0.6 + CGFloat(i) * r * 0.38
                    let on = (hash(i, Int(t * 0.7)) % 3) != 0
                    px(ctx: &ctx, x: wx, y: c.y - 6, w: 10, h: 8,
                       color: on ? .yellow.opacity(0.95) : .black.opacity(0.5))
                }
            }
        } else {
            // Open skeleton top: exposed beams.
            px(ctx: &ctx, x: c.x - 20, y: c.y - r - 6, w: 40, h: 6,
               color: Color(red: 0.55, green: 0.55, blue: 0.60))
            if Int(t * 1.5) % 2 == 0 {
                px(ctx: &ctx, x: c.x + 18, y: c.y - r - 12, w: 6, h: 6, color: .yellow)
            }
        }
    }

    private static func drawCrane(ctx: inout GraphicsContext, base b: CGPoint, t: Double) {
        let steel = Color(red: 0.75, green: 0.55, blue: 0.25)
        px(ctx: &ctx, x: b.x - 3, y: b.y - 80, w: 6, h: 80, color: steel)
        let sway = sin(t * 0.9) * 8
        px(ctx: &ctx, x: b.x - 30, y: b.y - 80, w: 70 + sway, h: 5, color: steel)
        // Hanging cable + beam.
        px(ctx: &ctx, x: b.x + 30 + sway - 1, y: b.y - 75, w: 2, h: 30, color: .white.opacity(0.7))
        px(ctx: &ctx, x: b.x + 30 + sway - 8, y: b.y - 45, w: 16, h: 8,
           color: Color(red: 0.55, green: 0.58, blue: 0.65))
        if Int(t * 1.2) % 2 == 0 {
            px(ctx: &ctx, x: b.x - 3, y: b.y - 86, w: 6, h: 6, color: .red)
        }
    }

    private static func drawHab(ctx: inout GraphicsContext, origin o: CGPoint,
                                wdt: CGFloat, hgt: CGFloat, t: Double, lit: Bool, seed: Int) {
        let body = Color(red: 0.30, green: 0.31, blue: 0.38)
        let edge = Color(red: 0.55, green: 0.58, blue: 0.68)
        px(ctx: &ctx, x: o.x, y: o.y, w: wdt, h: hgt, color: body)
        px(ctx: &ctx, x: o.x, y: o.y, w: wdt, h: 3, color: edge)
        px(ctx: &ctx, x: o.x, y: o.y, w: 3, h: hgt, color: edge.opacity(0.6))
        // Window grid — more lit on the terraforming line.
        var r = 0
        var y = o.y + 10
        while y < o.y + hgt - 8 {
            var x = o.x + 8
            while x < o.x + wdt - 10 {
                let on: Bool
                if lit { on = (hash(r, seed + Int(t * 0.5)) % 4) != 0 }
                else { on = (hash(r, seed) % 4) == 0 }
                px(ctx: &ctx, x: x, y: y, w: 8, h: 6,
                   color: on ? .yellow.opacity(0.9) : .black.opacity(0.55))
                x += 14; r += 1
            }
            y += 12
        }
        // Roof antenna with blinking tip.
        px(ctx: &ctx, x: o.x + wdt * 0.7, y: o.y - 14, w: 3, h: 14, color: edge)
        if Int(t * 1.8 + Double(seed)) % 2 == 0 {
            px(ctx: &ctx, x: o.x + wdt * 0.7 - 2, y: o.y - 20, w: 7, h: 7, color: .red)
        }
    }

    private static func drawBeacon(ctx: inout GraphicsContext, base b: CGPoint, hgt: CGFloat, t: Double) {
        px(ctx: &ctx, x: b.x - 2, y: b.y - hgt, w: 4, h: hgt,
           color: Color(red: 0.4, green: 0.42, blue: 0.5))
        for i in stride(from: 0, to: Int(hgt), by: 12) {
            px(ctx: &ctx, x: b.x - 4, y: b.y - CGFloat(i) - 8, w: 8, h: 3,
               color: Color(red: 0.5, green: 0.52, blue: 0.6))
        }
        if Int(t * 1.5) % 2 == 0 {
            px(ctx: &ctx, x: b.x - 4, y: b.y - hgt - 8, w: 8, h: 8, color: .red)
            ctx.fill(Path(ellipseIn: CGRect(x: b.x - 18, y: b.y - hgt - 22, width: 36, height: 36)),
                     with: .radialGradient(
                        Gradient(colors: [Color.red.opacity(0.35), .clear]),
                        center: CGPoint(x: b.x, y: b.y - hgt - 4),
                        startRadius: 0, endRadius: 18))
        }
    }

    private static func drawRover(ctx: inout GraphicsContext, at p: CGPoint, t: Double) {
        let body = Color(red: 0.65, green: 0.62, blue: 0.55)
        px(ctx: &ctx, x: p.x - 14, y: p.y - 10, w: 28, h: 8, color: body)
        px(ctx: &ctx, x: p.x - 6, y: p.y - 16, w: 14, h: 6, color: Color(red: 0.4, green: 0.45, blue: 0.5))
        let spin = Int(t * 8) % 2 == 0
        px(ctx: &ctx, x: p.x - 10, y: p.y - 4, w: 7, h: 7, color: .black)
        px(ctx: &ctx, x: p.x + 4, y: p.y - 4, w: 7, h: 7, color: .black)
        if spin {
            px(ctx: &ctx, x: p.x - 10, y: p.y - 1, w: 7, h: 2, color: Color.gray)
            px(ctx: &ctx, x: p.x + 4, y: p.y - 1, w: 7, h: 2, color: Color.gray)
        }
        // Headlight beam.
        var beam = Path()
        beam.move(to: CGPoint(x: p.x + 14, y: p.y - 8))
        beam.addLine(to: CGPoint(x: p.x + 44, y: p.y - 2))
        beam.addLine(to: CGPoint(x: p.x + 44, y: p.y - 12))
        beam.closeSubpath()
        ctx.fill(beam, with: .color(Color.yellow.opacity(0.18)))
    }

    // MARK: - Emra (hero planet)

    /// Large hero render: layered oceans, hand-placed continents with
    /// highlands and peaks, ice caps, night-side city lights and drifting
    /// cloud bands. Lit only by the atmosphere halo — no outline ring.
    private static func drawEmraBig(ctx: inout GraphicsContext, center c: CGPoint, r: CGFloat,
                                    t: Double) {
        // Ocean base + upper-ocean light.
        pxCircle(ctx: &ctx, center: c, r: r,
                 color: Color(red: 0.12, green: 0.30, blue: 0.60))
        pxCircle(ctx: &ctx, center: CGPoint(x: c.x - r * 0.15, y: c.y - r * 0.12), r: r * 0.82,
                 color: Color(red: 0.18, green: 0.42, blue: 0.72))
        // Hand-placed continents, in units of r: (dx, dy, w, h).
        // A — "Verdant Reach", the great northern landmass.
        // B — "Ember Chain", equatorial islands. C — "Southern Shelf".
        let land = Color(red: 0.24, green: 0.54, blue: 0.29)
        let landHi = Color(red: 0.38, green: 0.68, blue: 0.36)
        let continents: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.52, -0.44, 0.34, 0.18), (-0.46, -0.56, 0.22, 0.14),
            (-0.24, -0.40, 0.12, 0.18), (-0.60, -0.28, 0.18, 0.08),
            (0.02, -0.08, 0.11, 0.08), (0.16, 0.00, 0.09, 0.07),
            (0.29, -0.08, 0.10, 0.07), (0.10, -0.16, 0.07, 0.05),
            (-0.34, 0.30, 0.44, 0.24), (-0.24, 0.20, 0.22, 0.12),
            (0.04, 0.36, 0.15, 0.12), (-0.02, -0.60, 0.13, 0.09),
            (0.46, 0.28, 0.10, 0.08), (0.30, 0.22, 0.09, 0.07),
            (-0.54, 0.06, 0.12, 0.09), (0.22, -0.36, 0.10, 0.08),
            (-0.10, 0.02, 0.09, 0.07), (0.44, -0.30, 0.08, 0.07),
        ]
        for (dx, dy, bw, bh) in continents {
            let bx = c.x + dx * r
            let by = c.y + dy * r
            let wdt = bw * r, hgt = bh * r
            // Skip chunks that fall off the disc edge.
            let edge = sqrt(pow(dx, 2) + pow(dy, 2)) + max(bw, bh) * 0.5
            if edge > 0.92 { continue }
            px(ctx: &ctx, x: bx - wdt / 2, y: by - hgt / 2, w: wdt, h: hgt, color: land)
            px(ctx: &ctx, x: bx - wdt / 2, y: by - hgt / 2, w: wdt, h: hgt * 0.30, color: landHi)
        }
        // Peaks on the two great landmasses.
        px(ctx: &ctx, x: c.x - 0.44 * r - 3, y: c.y - 0.50 * r, w: 7, h: 6,
           color: Color(red: 0.55, green: 0.52, blue: 0.48))
        px(ctx: &ctx, x: c.x - 0.44 * r - 3, y: c.y - 0.50 * r, w: 7, h: 2, color: .white.opacity(0.9))
        px(ctx: &ctx, x: c.x - 0.20 * r - 3, y: c.y + 0.32 * r, w: 7, h: 6,
           color: Color(red: 0.55, green: 0.52, blue: 0.48))
        px(ctx: &ctx, x: c.x - 0.20 * r - 3, y: c.y + 0.32 * r, w: 7, h: 2, color: .white.opacity(0.9))
        // Night-side shadow (lower right) + city lights inside it.
        pxCircle(ctx: &ctx, center: CGPoint(x: c.x + r * 0.38, y: c.y + r * 0.12), r: r * 0.92,
                 color: Color.black.opacity(0.34))
        for i in 0..<14 {
            let a = Double(hash(i, 331) % 90 + 270) * .pi / 180
            let d = r * (0.45 + CGFloat(hash(i, 337) % 40) / 100)
            let lx = c.x + cos(a) * d
            let ly = c.y + sin(a) * d * 0.85
            if abs(lx - c.x) < r * 0.88 && abs(ly - c.y) < r * 0.88 {
                let on = (hash(i, Int(t * 0.8)) % 3) != 0
                if on {
                    ctx.fill(Path(CGRect(x: lx, y: ly, width: 2.5, height: 2.5)),
                             with: .color(Color.yellow.opacity(0.9)))
                }
            }
        }
        // Drifting cloud bands.
        for i in 0..<6 {
            let cx = c.x - r + CGFloat((Double(i) * 0.19 + t * 0.025).truncatingRemainder(dividingBy: 1)) * r * 2
            let cy = c.y - r * 0.55 + CGFloat(i) * r * 0.22
            if abs(cx - c.x) < r * 0.85 {
                px(ctx: &ctx, x: cx - 14, y: cy, w: 28, h: 5, color: Color.white.opacity(0.45))
                px(ctx: &ctx, x: cx - 8, y: cy - 4, w: 16, h: 4, color: Color.white.opacity(0.30))
            }
        }
    }

    // MARK: - Planet helpers

    private static func pixelPlanet(ctx: inout GraphicsContext, center c: CGPoint, r: CGFloat,
                                    base: Color, dark: Color, light: Color,
                                    craters: Bool = false, ring: Bool = false, seed: Int) {
        if ring {
            // Back half of ring.
            var back = Path()
            back.move(to: CGPoint(x: c.x - r * 1.9, y: c.y + r * 0.35))
            back.addLine(to: CGPoint(x: c.x + r * 1.9, y: c.y - r * 0.35))
            ctx.stroke(back, with: .color(Color(red: 0.7, green: 0.6, blue: 0.5).opacity(0.5)), lineWidth: 7)
        }
        pxCircle(ctx: &ctx, center: c, r: r, color: base)
        pxCircle(ctx: &ctx, center: CGPoint(x: c.x - r * 0.2, y: c.y - r * 0.2), r: r * 0.75, color: light.opacity(0.5))
        pxCircle(ctx: &ctx, center: CGPoint(x: c.x + r * 0.3, y: c.y + r * 0.25), r: r * 0.7,
                 color: Color.black.opacity(0.35))
        // Banding for the giant.
        if ring {
            px(ctx: &ctx, x: c.x - r * 0.9, y: c.y - r * 0.2, w: r * 1.8, h: r * 0.22,
               color: dark.opacity(0.7))
            px(ctx: &ctx, x: c.x - r * 0.9, y: c.y + r * 0.25, w: r * 1.8, h: r * 0.16,
               color: light.opacity(0.6))
        }
        if craters {
            for i in 0..<5 {
                let bx = c.x - r * 0.5 + CGFloat(hash(i, seed) % 100) / 100 * r
                let by = c.y - r * 0.4 + CGFloat(hash(i, seed + 1) % 100) / 100 * r * 0.9
                px(ctx: &ctx, x: bx, y: by, w: 7, h: 6, color: dark)
                px(ctx: &ctx, x: bx, y: by, w: 7, h: 2, color: light.opacity(0.7))
            }
        }
        if ring {
            var front = Path()
            front.move(to: CGPoint(x: c.x - r * 1.9, y: c.y + r * 0.45))
            front.addLine(to: CGPoint(x: c.x + r * 1.9, y: c.y - r * 0.25))
            ctx.stroke(front, with: .color(Color(red: 0.78, green: 0.68, blue: 0.55).opacity(0.85)), lineWidth: 6)
        }
    }

    private static func pixelMoon(ctx: inout GraphicsContext, at p: CGPoint, r: CGFloat, glow: Bool) {
        if glow {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 1.8, y: p.y - r * 1.8,
                                            width: r * 3.6, height: r * 3.6)),
                     with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.20), .clear]),
                        center: p, startRadius: 0, endRadius: r * 1.8))
        }
        pxCircle(ctx: &ctx, center: p, r: r, color: Color(red: 0.82, green: 0.80, blue: 0.75))
        pxCircle(ctx: &ctx, center: CGPoint(x: p.x + r * 0.25, y: p.y + r * 0.2), r: r * 0.8,
                 color: Color.black.opacity(0.25))
        px(ctx: &ctx, x: p.x - r * 0.4, y: p.y - r * 0.3, w: 5, h: 5,
           color: Color(red: 0.6, green: 0.58, blue: 0.55))
    }

    // MARK: - Generic helpers

    private static func px(ctx: inout GraphicsContext, x: CGFloat, y: CGFloat,
                           w: CGFloat, h: CGFloat, color: Color) {
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
    }

    /// Blocky filled circle from axis-aligned rects.
    private static func pxCircle(ctx: inout GraphicsContext, center c: CGPoint, r: CGFloat, color: Color) {
        let step: CGFloat = max(2, r / 12)
        var y = c.y - r
        while y <= c.y + r {
            let dy = (y - c.y) / r
            let half = sqrt(max(0, 1 - dy * dy)) * r
            // Snap to pixel grid for the hard-edged look.
            let qHalf = (half / step).rounded(.down) * step
            ctx.fill(Path(CGRect(x: c.x - qHalf, y: y, width: qHalf * 2, height: step + 0.5)),
                     with: .color(color))
            y += step
        }
    }

    private static func ridge(ctx: inout GraphicsContext, width w: CGFloat, baseline: CGFloat,
                              phase: Double, amp: CGFloat, step: CGFloat, color: Color,
                              floor floorY: CGFloat? = nil) {
        let bottom = floorY ?? baseline + 4
        var p = Path()
        p.move(to: CGPoint(x: -step, y: bottom))
        var x: CGFloat = -step
        while x <= w + step {
            let n = sin(Double(x) * 0.010 + phase) * 0.55
                + sin(Double(x) * 0.027 + phase * 2.1) * 0.30
                + sin(Double(x) * 0.061 + phase * 0.7) * 0.15
            p.addLine(to: CGPoint(x: x, y: baseline - amp * CGFloat((n + 1) / 2)))
            x += step
        }
        p.addLine(to: CGPoint(x: w + step, y: bottom))
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }

    /// Flat-top mesa butte rooted at the ground line, ember-lit crest.
    private static func butte(ctx: inout GraphicsContext, centerX: CGFloat, groundY: CGFloat,
                              wdt: CGFloat, hgt: CGFloat) {
        let body = Color(red: 0.19, green: 0.11, blue: 0.17)
        px(ctx: &ctx, x: centerX - wdt / 2, y: groundY - hgt, w: wdt, h: hgt, color: body)
        px(ctx: &ctx, x: centerX - wdt / 2 - 8, y: groundY - hgt + 10, w: 16, h: hgt - 10, color: body)
        px(ctx: &ctx, x: centerX + wdt / 2 - 8, y: groundY - hgt + 14, w: 16, h: hgt - 14, color: body)
        // Ember-lit crest + strata lines.
        px(ctx: &ctx, x: centerX - wdt / 2, y: groundY - hgt, w: wdt, h: 3,
           color: Color(red: 0.55, green: 0.30, blue: 0.30))
        px(ctx: &ctx, x: centerX - wdt / 2 + 6, y: groundY - hgt + 16, w: wdt - 12, h: 2,
           color: Color.black.opacity(0.4))
        px(ctx: &ctx, x: centerX - wdt / 2 + 10, y: groundY - hgt + 28, w: wdt - 20, h: 2,
           color: Color.black.opacity(0.4))
    }

    /// One dusk cloud: blocky lit cluster drifting slowly across the sky.
    private static func duskCloud(ctx: inout GraphicsContext, width w: CGFloat, seed: Int,
                                  y: CGFloat, s: CGFloat, t: Double, speed: Double,
                                  color: Color, lit: Color) {
        let span = w + 260
        let bx = CGFloat((Double(seed) * 137 + t * speed).truncatingRemainder(dividingBy: Double(span))) - 130
        px(ctx: &ctx, x: bx, y: y, w: 76 * s, h: 8 * s, color: color)
        px(ctx: &ctx, x: bx + 16 * s, y: y - 6 * s, w: 44 * s, h: 6 * s, color: color)
        px(ctx: &ctx, x: bx - 18 * s, y: y + 5 * s, w: 42 * s, h: 5 * s, color: color)
        px(ctx: &ctx, x: bx, y: y + 7 * s, w: 76 * s, h: 2 * s, color: lit)
    }

    private static func nebula(ctx: inout GraphicsContext, at p: CGPoint, r: CGFloat, color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 0.6, width: r * 2, height: r * 1.2)),
                 with: .radialGradient(Gradient(colors: [color, .clear]),
                                        center: p, startRadius: 0, endRadius: r))
    }

    private static func label(ctx: inout GraphicsContext, text: String, at p: CGPoint,
                              color: Color, size: CGFloat) {
        ctx.draw(Text(text)
            .font(.system(size: size, weight: .black, design: .monospaced))
            .tracking(1.5)
            .foregroundColor(color),
                 at: p, anchor: .center)
    }

    private static func tinyLabel(ctx: inout GraphicsContext, text: String, at p: CGPoint) {
        label(ctx: &ctx, text: text, at: p, color: .white.opacity(0.4), size: 8)
    }

    private static func scanlines(ctx: inout GraphicsContext, size: CGSize) {
        var y: CGFloat = 0
        while y < size.height {
            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                     with: .color(Color.black.opacity(0.10)))
            y += 4
        }
    }

    private static func vignette(ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(
                    Gradient(colors: [.clear, Color.black.opacity(0.30), Color.black.opacity(0.55)]),
                    center: CGPoint(x: size.width * 0.5, y: size.height * 0.45),
                    startRadius: min(size.width, size.height) * 0.30,
                    endRadius: max(size.width, size.height) * 0.75))
    }

    private static func hash(_ a: Int, _ b: Int) -> Int {
        abs((a &* 73856093) ^ (b &* 19349663)) % 1000
    }
}

#Preview {
    NavigationStack { CutsceneView() }
}
