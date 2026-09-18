import SpriteKit
import SwiftUI

/// MainMenu — live pixel-art battlefield backdrop (MainMenuBattleScene:
/// twilight sky, mountain + ruin panorama, treeline, moss lane, blue vs
/// red towers trading fire) with a pixel-command UI on top.
/// Landscape: war-room title left, DEPLOY + SETTINGS right.
struct MainMenuView: View {
    @StateObject private var settings = SettingsStore()
    @State private var showSettings = false
    @State private var blink = false

    // One shared scene so the battlefield doesn't restart on redraw.
    private static let battleScene: MainMenuBattleScene = {
        let s = MainMenuBattleScene(size: CGSize(width: 1334, height: 750))
        return s
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                // Living battlefield, edge-to-edge: this layer ignores the
                // safe area so there are no black bars at the notch / home
                // bar. (Sizing it inside a safe-area GeometryReader was
                // what letterboxed it.)
                SpriteView(scene: Self.battleScene, options: [.ignoresSiblingOrder])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .all)
                // Readability grade: lift the left for text, keep the
                // right fight visible. Plus a bottom shade for the footer.
                LinearGradient(colors: [.black.opacity(0.62), .black.opacity(0.18)],
                               startPoint: .leading, endPoint: .trailing)
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)
                LinearGradient(colors: [.clear, .black.opacity(0.45)],
                               startPoint: .center, endPoint: .bottom)
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)

                // Content respects the safe area (text/buttons stay clear
                // of the notch); only the backdrop above goes full-bleed.
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Left: war-room title block
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Rectangle().fill(.cyan).frame(width: 8, height: 8)
                                Text("TWILIGHT FRONT // SECTOR 01")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .tracking(2)
                                    .foregroundStyle(.cyan)
                            }
                            Text("INVADER")
                                .font(.system(size: 52, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .shadow(color: .cyan.opacity(0.6), radius: 12)
                            Text("PUSH")
                                .font(.system(size: 52, weight: .black, design: .monospaced))
                                .foregroundStyle(.yellow)
                                .shadow(color: .red.opacity(0.6), radius: 12)
                                .offset(y: -12)
                            // Pixel divider: line — diamond — line.
                            HStack(spacing: 6) {
                                Rectangle().fill(.cyan.opacity(0.6)).frame(width: 52, height: 2)
                                Rectangle().fill(.cyan).frame(width: 8, height: 8)
                                Rectangle().fill(.cyan.opacity(0.6)).frame(width: 52, height: 2)
                            }
                            Text("Hero-led lane battler — hold the line, push mid, break their HQ.")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                            Text(blink ? "▶ TAP DEPLOY TO JOIN THE FIGHT" : "  TAP DEPLOY TO JOIN THE FIGHT")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(.yellow)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.7).repeatForever()) {
                                        blink.toggle()
                                    }
                                }
                            Spacer()
                            Text("3 MISSIONS • 6 HEROES • BLUE VS RED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(28)

                        Spacer()

                        // Right: command buttons
                        VStack(spacing: 14) {
                            Spacer()
                            NavigationLink {
                                LevelMapView()
                            } label: {
                                PixelCommandButton(title: "DEPLOY", systemIcon: "sword.fill",
                                                   style: .war)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                SoundEngine.shared.uiTap()
                            })
                            Button { showSettings = true } label: {
                                PixelCommandButton(title: "SETTINGS", systemIcon: "gearshape.fill",
                                                   style: .ghost)
                            }
                            HStack(spacing: 6) {
                                Rectangle().fill(.white.opacity(0.25)).frame(width: 30, height: 2)
                                Text("v1.0 • TWILIGHT BUILD")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .tracking(1)
                                    .foregroundStyle(.white.opacity(0.45))
                                Rectangle().fill(.white.opacity(0.25)).frame(width: 30, height: 2)
                            }
                        }
                        .padding(28)
                        .frame(width: min(320, geo.size.width * 0.36))
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsSheet(settings: settings)
            }
        }
    }
}

/// Pixel command button: chamfered hard corners, chunky border, uppercase
/// monospaced label. War = red assault style, ghost = dark outline style.
private struct PixelCommandButton: View {
    enum Style { case war, ghost }
    let title: String
    let systemIcon: String
    let style: Style
    private let shape = PixelMenuPanelShape(cut: 8)

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemIcon)
                .font(.system(size: 15, weight: .black))
            Text(title)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .tracking(2)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(bg)
        .foregroundStyle(fg)
        .clipShape(shape)
        .overlay(shape.stroke(border, lineWidth: 3))
        .shadow(color: shadow, radius: 10)
    }

    private var bg: Color {
        switch style {
        case .war: return .red
        case .ghost: return .black.opacity(0.65)
        }
    }

    private var border: Color {
        switch style {
        case .war: return .white.opacity(0.7)
        case .ghost: return .cyan.opacity(0.6)
        }
    }

    private var fg: Color {
        switch style {
        case .war: return .white
        case .ghost: return .cyan
        }
    }

    private var shadow: Color {
        switch style {
        case .war: return .red.opacity(0.45)
        case .ghost: return .cyan.opacity(0.2)
        }
    }
}

/// Pixel panel: all four corners chamfered — the dialog/card shape.
private struct PixelMenuPanelShape: Shape {
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

private struct SettingsSheet: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    Toggle("Music", isOn: $settings.musicEnabled)
                    Toggle("SFX", isOn: $settings.sfxEnabled)
                }
                Section("Controls") {
                    HStack {
                        Text("Sensitivity")
                        Slider(value: $settings.sensitivity, in: 0.5...1.5, step: 0.1)
                        Text(String(format: "%.1f", settings.sensitivity))
                            .monospacedDigit()
                            .frame(width: 36)
                    }
                }
                Section("Campaign") {
                    Button("Reset progress", role: .destructive) {
                        settings.resetCampaign()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MainMenuView()
}
