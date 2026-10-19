import SwiftUI

/// Full-screen settings command deck. Reached from the main menu's
/// SETTINGS button (Route.settings) — not a sheet — so BACK always returns
/// to the war room. A live pixel-twilight backdrop sits under four panels:
/// Audio, Graphics, Controls and Data. Destructive actions open a
/// hazard-striped danger prompt (the campaign wipe needs a press-and-hold).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SettingsStore()
    @State private var danger: DangerAction?
    @State private var holdProgress: CGFloat = 0
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SettingsBackdropView()
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

                if let danger {
                    DangerOverlay(action: danger, progress: holdProgress,
                                  onCancel: cancelDanger,
                                  onConfirm: { perform(danger) },
                                  onHoldStart: { startHold(danger) },
                                  onHoldEnd: cancelHold)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onChange(of: settings.musicEnabled) { _ in
            SoundEngine.shared.syncMusic()
        }
        .onChange(of: settings.musicVolume) { _ in
            SoundEngine.shared.applyVolumes()
        }
        .onDisappear { holdTask?.cancel() }
    }

    // MARK: - Header

    private func header(wide: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                SoundEngine.shared.uiTap()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    PixelIcon(glyph: .back, color: .cyan, size: 12)
                    Text("MENU")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(2)
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.black.opacity(0.7))
                .clipShape(SettingsPixelShape(cut: 6))
                .overlay(SettingsPixelShape(cut: 6).stroke(.cyan.opacity(0.6), lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("SETTINGS")
                    .font(.system(size: wide ? 30 : 24, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .shadow(color: .cyan.opacity(0.6), radius: 10)
                Text("SYSTEM CONFIGURATION // TWILIGHT FRONT")
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
                .clipShape(SettingsPixelShape(cut: 5))
                .overlay(SettingsPixelShape(cut: 5).stroke(.green.opacity(0.35), lineWidth: 1))
            }

            Text("v1.0")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Panels

    @ViewBuilder
    private func content(wide: Bool) -> some View {
        if wide {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)], spacing: 14) {
                audioPanel
                graphicsPanel
                controlsPanel
                dataPanel
            }
        } else {
            VStack(spacing: 14) {
                audioPanel
                graphicsPanel
                controlsPanel
                dataPanel
            }
        }
    }

    private var audioPanel: some View {
        SettingsPanel(title: "AUDIO", tag: "MIXER", icon: .speaker, accent: .cyan) {
            VStack(spacing: 12) {
                SettingsToggleRow(title: "MUSIC", subtitle: "Battle loop",
                                  isOn: $settings.musicEnabled)
                VolumeRow(title: "MUSIC VOLUME", value: $settings.musicVolume,
                          tint: .cyan, enabled: settings.musicEnabled)
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
                SettingsToggleRow(title: "SFX", subtitle: "Weapons, impacts, UI",
                                  isOn: $settings.sfxEnabled)
                HStack(spacing: 10) {
                    VolumeRow(title: "SFX VOLUME", value: $settings.sfxVolume,
                              tint: .orange, enabled: settings.sfxEnabled)
                    Button {
                        SoundEngine.shared.uiTap()
                    } label: {
                        PixelIcon(glyph: .play,
                                  color: settings.sfxEnabled ? .orange : .white.opacity(0.3),
                                  size: 14)
                            .frame(width: 34, height: 28)
                            .background(.black.opacity(0.5))
                            .overlay(Rectangle().stroke(.orange.opacity(settings.sfxEnabled ? 0.55 : 0.2),
                                                        lineWidth: 1))
                    }
                    .disabled(!settings.sfxEnabled)
                }
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
                SettingsToggleRow(title: "HAPTICS", subtitle: "Destruction feedback",
                                  isOn: $settings.hapticsEnabled)
            }
        }
    }

    private var graphicsPanel: some View {
        SettingsPanel(title: "GRAPHICS", tag: "COMBAT FX", icon: .spark, accent: .yellow) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsToggleRow(title: "PARTICLE EFFECTS", subtitle: "Dust, smoke, sparks, debris",
                                  isOn: $settings.particlesEnabled)
                SettingsToggleRow(title: "MUZZLE FLASHES", subtitle: "Gun-tip light burst",
                                  isOn: $settings.muzzleFlashEnabled)
                VStack(alignment: .leading, spacing: 7) {
                    Text("EFFECTS QUALITY")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(settings.particlesEnabled ? 0.9 : 0.35))
                    HStack(spacing: 6) {
                        ForEach(GameSettings.EffectsQuality.allCases) { quality in
                            optionButton(quality.title,
                                         selected: settings.effectsQuality == quality.rawValue,
                                         enabled: settings.particlesEnabled) {
                                settings.effectsQuality = quality.rawValue
                            }
                        }
                    }
                }
                Text("Higher quality spawns more debris and smoke. Turn particles off to save battery in long sieges.")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var controlsPanel: some View {
        SettingsPanel(title: "CONTROLS", tag: "INPUT", icon: .controller, accent: .green) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("LOOK SENSITIVITY")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Text(sensitivityLabel)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.green)
                    Text(String(format: "%.1f×", settings.sensitivity))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 44, alignment: .trailing)
                }
                PixelSlider(value: $settings.sensitivity, range: 0.5...1.5, step: 0.1,
                            tint: .green)
                HStack {
                    Text("PRECISE")
                    Spacer()
                    Text("STANDARD")
                    Spacer()
                    Text("FAST")
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.35))
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
                Text("Joystick look/turn speed during battle. Raise it for quicker target sweeps.")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dataPanel: some View {
        SettingsPanel(title: "DATA", tag: "SYSTEM", icon: .disk, accent: .red) {
            VStack(spacing: 10) {
                DataButton(title: "RESET CAMPAIGN", icon: .warning,
                           subtitle: "Wipe stars, unlocks and progress",
                           tint: .red) {
                    openDanger(.resetCampaign)
                }
                DataButton(title: "RESTORE DEFAULTS", icon: .disk,
                           subtitle: "Reset every setting above",
                           tint: .cyan) {
                    openDanger(.restoreDefaults)
                }
                HStack(spacing: 6) {
                    Rectangle().fill(.white.opacity(0.2)).frame(width: 24, height: 1)
                    Text("SETTINGS SAVED LOCALLY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.35))
                    Rectangle().fill(.white.opacity(0.2)).frame(width: 24, height: 1)
                }
                .padding(.top, 2)
            }
        }
    }

    private func optionButton(_ title: String, selected: Bool, enabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button {
            action()
            SoundEngine.shared.uiTap()
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(selected ? .black : .white.opacity(0.8))
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(selected ? Color.yellow : Color.black.opacity(0.45))
                .clipShape(SettingsPixelShape(cut: 4))
                .overlay(SettingsPixelShape(cut: 4)
                    .stroke(selected ? .yellow : .white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private var sensitivityLabel: String {
        if settings.sensitivity < 0.85 { return "PRECISE" }
        if settings.sensitivity > 1.15 { return "FAST" }
        return "STANDARD"
    }

    // MARK: - Danger prompt flow

    private func openDanger(_ action: DangerAction) {
        SoundEngine.shared.uiTap()
        holdProgress = 0
        withAnimation(.easeOut(duration: 0.16)) { danger = action }
    }

    private func cancelDanger() {
        cancelHold()
        withAnimation(.easeOut(duration: 0.16)) { danger = nil }
    }

    private func startHold(_ action: DangerAction) {
        guard action.requiresHold, holdTask == nil else { return }
        holdProgress = 0
        holdTask = Task { @MainActor in
            withAnimation(.linear(duration: action.holdDuration)) { holdProgress = 1 }
            try? await Task.sleep(nanoseconds: UInt64(action.holdDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            holdTask = nil
            perform(action)
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        withAnimation(.easeOut(duration: 0.18)) { holdProgress = 0 }
    }

    private func perform(_ action: DangerAction) {
        switch action {
        case .resetCampaign:
            settings.resetCampaign()
        case .restoreDefaults:
            settings.restoreDefaults()
            SoundEngine.shared.syncMusic()
            SoundEngine.shared.applyVolumes()
        }
        SoundEngine.shared.uiTap()
        holdProgress = 0
        withAnimation(.easeOut(duration: 0.16)) { danger = nil }
    }
}

// MARK: - Danger model + overlay

private enum DangerAction: Identifiable {
    case resetCampaign, restoreDefaults

    var id: Int { self == .resetCampaign ? 0 : 1 }
    var requiresHold: Bool { self == .resetCampaign }
    var holdDuration: Double { 1.1 }

    var accent: Color {
        self == .resetCampaign ? Color(red: 1, green: 0.24, blue: 0.2) : .yellow
    }

    var headline: String {
        switch self {
        case .resetCampaign: return "WIPE CAMPAIGN PROGRESS"
        case .restoreDefaults: return "RESTORE FACTORY SETTINGS"
        }
    }

    var message: String {
        switch self {
        case .resetCampaign:
            return "Every sector returns to locked. All stars, mission clears, unlocks and the invasion route are wiped. Loadout and settings are kept. This cannot be undone."
        case .restoreDefaults:
            return "Audio, graphics, controls and haptics return to their first-run values. Campaign progress and unlocks are kept."
        }
    }

    var confirmLabel: String {
        switch self {
        case .resetCampaign: return "HOLD TO WIPE"
        case .restoreDefaults: return "RESTORE"
        }
    }
}

private struct DangerOverlay: View {
    let action: DangerAction
    let progress: CGFloat
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let onHoldStart: () -> Void
    let onHoldEnd: () -> Void
    private let shape = SettingsPixelShape(cut: 10)

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                HazardStripes(color: action.accent)
                    .frame(height: 10)
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        PixelIcon(glyph: .warning, color: action.accent, size: 30)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("DANGER // IRREVERSIBLE")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(action.accent)
                            Text(action.headline)
                                .font(.system(size: 17, weight: .black, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(action.message)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                    HStack(spacing: 10) {
                        Button(action: onCancel) {
                            Text("CANCEL")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(.white.opacity(0.08))
                                .clipShape(SettingsPixelShape(cut: 6))
                                .overlay(SettingsPixelShape(cut: 6)
                                    .stroke(.white.opacity(0.25), lineWidth: 2))
                        }
                        .buttonStyle(.plain)

                        if action.requiresHold {
                            holdButton
                        } else {
                            Button(action: onConfirm) {
                                Text(action.confirmLabel)
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(action.accent)
                                    .clipShape(SettingsPixelShape(cut: 6))
                                    .overlay(SettingsPixelShape(cut: 6)
                                        .stroke(.white.opacity(0.5), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
                HazardStripes(color: action.accent)
                    .frame(height: 10)
            }
            .frame(maxWidth: 470)
            .background(Color(red: 0.06, green: 0.035, blue: 0.05).opacity(0.97))
            .clipShape(shape)
            .overlay(shape.stroke(action.accent.opacity(0.65), lineWidth: 2))
            .shadow(color: action.accent.opacity(0.45), radius: 24)
            .padding(24)
        }
    }

    private var holdButton: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(action.accent.opacity(0.18))
                Rectangle()
                    .fill(action.accent)
                    .frame(width: geo.size.width * progress)
                HStack(spacing: 8) {
                    PixelIcon(glyph: .warning,
                              color: progress > 0 ? .black : action.accent, size: 13)
                    Text(progress > 0 ? "HOLDING — KEEP PRESSING" : action.confirmLabel)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(progress > 0 ? .black : action.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .clipShape(SettingsPixelShape(cut: 6))
        .overlay(SettingsPixelShape(cut: 6).stroke(action.accent.opacity(0.85), lineWidth: 2))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onHoldStart() }
                .onEnded { _ in onHoldEnd() }
        )
    }
}

/// Alternating hazard stripes for danger chrome.
private struct HazardStripes: View {
    var color: Color = Color(red: 0.85, green: 0.12, blue: 0.12)

    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 20
            var x = -size.height
            var i = 0
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + step * 0.5, y: 0))
                p.addLine(to: CGPoint(x: x + step * 0.5, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(i % 2 == 0 ? color : Color.black.opacity(0.9)))
                x += step
                i += 1
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Backdrop

/// Animated twilight command horizon: gradient dusk, pixel ridges, a
/// rotating radar sweep, perspective grid and drifting embers.
private struct SettingsBackdropView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12)) { timeline in
            Canvas { ctx, size in
                SettingsBackdrop.draw(ctx: &ctx, size: size,
                                      t: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }
}

private enum SettingsBackdrop {
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
        ctx.fill(Path(CGRect(x: sun.x - core, y: sun.y - core + core * 0.7,
                             width: core * 2, height: core * 0.25)),
                 with: .color(Color(red: 0.2, green: 0.08, blue: 0.12, opacity: 0.55)))
        ctx.fill(Path(CGRect(x: sun.x - core, y: sun.y - core + core * 0.25,
                             width: core * 2, height: core * 0.18)),
                 with: .color(Color(red: 0.2, green: 0.08, blue: 0.12, opacity: 0.35)))

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
        ctx.fill(Path(CGRect(x: radar.x - 2, y: radar.y - 2, width: 4, height: 4)),
                 with: .color(.cyan.opacity(0.8)))

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

/// 8x8 pixel-art glyphs drawn as hard-edged blocks (no SF Symbols on this
/// screen). `#` = filled cell, `.` = empty.
private enum PixelGlyph {
    case back, chevron, play, speaker, spark, controller, disk, warning

    var pattern: [String] {
        switch self {
        case .chevron:
            return ["...#....",
                    "...##...",
                    "...###..",
                    "...####.",
                    "...###..",
                    "...##...",
                    "...#....",
                    "........"]
        case .back:
            return ["....#...",
                    "...##...",
                    "..###...",
                    ".####...",
                    "..###...",
                    "...##...",
                    "....#...",
                    "........"]
        case .play:
            return ["##......",
                    "####....",
                    "######..",
                    "########",
                    "########",
                    "######..",
                    "####....",
                    "##......"]
        case .speaker:
            return ["...##...",
                    "..###...",
                    ".####.#.",
                    ".####..#",
                    ".####..#",
                    ".####.#.",
                    "..###...",
                    "...##..."]
        case .spark:
            return ["...#....",
                    "...#....",
                    "..###...",
                    "#######.",
                    "..###...",
                    "...#....",
                    "...#....",
                    "........"]
        case .controller:
            return ["........",
                    ".##..##.",
                    "########",
                    "##.##.##",
                    "##.##.##",
                    "########",
                    ".##..##.",
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
        case .warning:
            return ["...##...",
                    "...##...",
                    "..####..",
                    "..####..",
                    ".##..##.",
                    ".##..##.",
                    "########",
                    "........"]
        }
    }
}

private struct PixelIcon: View {
    let glyph: PixelGlyph
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

private struct SettingsPanel<Content: View>: View {
    let title: String
    let tag: String
    let icon: PixelGlyph
    let accent: Color
    @ViewBuilder let content: () -> Content
    private let shape = SettingsPixelShape(cut: 9)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: accent.opacity(0.8), radius: 4)
                PixelIcon(glyph: icon, color: accent, size: 13)
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

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.9))
                Text(subtitle)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .toggleStyle(PixelToggleStyle())
    }
}

private struct VolumeRow: View {
    let title: String
    @Binding var value: Double
    let tint: Color
    var enabled: Bool = true

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(enabled ? 0.75 : 0.3))
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(enabled ? tint : .white.opacity(0.3))
            }
            PixelSlider(value: $value, range: 0...1, step: 0.05, tint: tint)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.35)
        }
    }
}

/// Chunky pixel slider: square track ticks, a bright fill rail and a
/// hard-edged knob. Drag anywhere on the row to set the level.
private struct PixelSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var tint: Color = .cyan

    var body: some View {
        GeometryReader { geo in
            let knob: CGFloat = 18
            let usable = max(1, geo.size.width - knob)
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? (value - range.lowerBound) / span : 0
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: 10)
                Rectangle()
                    .fill(tint.opacity(0.75))
                    .frame(width: knob / 2 + usable * CGFloat(fraction), height: 10)
                    .shadow(color: tint.opacity(0.45), radius: 5)
                HStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle()
                            .fill(.black.opacity(i % 2 == 0 ? 0.25 : 0))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 10)
                .allowsHitTesting(false)
                Rectangle()
                    .fill(.white)
                    .frame(width: knob, height: knob)
                    .overlay(Rectangle().stroke(tint, lineWidth: 2))
                    .shadow(color: tint.opacity(0.6), radius: 6)
                    .offset(x: usable * CGFloat(fraction))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let x = min(max(0, drag.location.x - knob / 2), usable)
                        var raw = range.lowerBound + Double(x / usable) * span
                        if step > 0 {
                            raw = (raw / step).rounded() * step
                        }
                        value = min(range.upperBound, max(range.lowerBound, raw))
                    }
            )
        }
        .frame(height: 26)
    }
}

private struct PixelToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Rectangle()
                        .fill(configuration.isOn ? Color.cyan.opacity(0.25)
                                                 : Color.white.opacity(0.08))
                        .frame(width: 54, height: 28)
                        .overlay(Rectangle().stroke(
                            configuration.isOn ? Color.cyan.opacity(0.75)
                                               : Color.white.opacity(0.20),
                            lineWidth: 2))
                    Rectangle()
                        .fill(configuration.isOn ? Color.cyan : Color.white.opacity(0.35))
                        .frame(width: 22, height: 20)
                        .padding(.horizontal, 3)
                        .shadow(color: configuration.isOn ? Color.cyan.opacity(0.7) : .clear,
                                radius: 5)
                }
                .animation(.easeInOut(duration: 0.16), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DataButton: View {
    let title: String
    let icon: PixelGlyph
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                PixelIcon(glyph: icon, color: tint, size: 15)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(tint)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                PixelIcon(glyph: .chevron, color: .white.opacity(0.35), size: 10)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.black.opacity(0.45))
            .overlay(Rectangle().stroke(tint.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Chamfered pixel panel shape (all four corners cut).
private struct SettingsPixelShape: Shape {
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
    NavigationStack { SettingsView() }
}
