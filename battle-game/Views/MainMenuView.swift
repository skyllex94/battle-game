import SwiftUI

/// MainMenu — ports Unity's MainMenu.unity (StartGame -> MapLevels, QuitGame).
/// Landscape layout: art/beats left, Play + Settings right.
struct MainMenuView: View {
    @StateObject private var settings = SettingsStore()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    // Imported world-map art as menu backdrop (MapBG.jpg), dimmed.
                    ImportedArt.image(named: "MapBG")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(0.45)
                        .ignoresSafeArea()
                    LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.25)],
                                   startPoint: .leading, endPoint: .trailing)
                        .ignoresSafeArea()

                    HStack(spacing: 0) {
                        // Left: title block
                        VStack(alignment: .leading, spacing: 8) {
                            Text("INVADER PUSH")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Hero-led lane battler — rebuilt in SpriteKit")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.8))
                            HStack(spacing: 6) {
                                ImportedArt.image(named: "Stars")
                                    .resizable().scaledToFit().frame(width: 22, height: 22)
                                Text("Ported from your 3-month Unity build")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            Text("Landscape • iPhone • Stage 1: menus + levels")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(28)

                        Spacer()

                        // Right: actions
                        VStack(spacing: 14) {
                            NavigationLink {
                                LevelMapView()
                            } label: {
                                MenuButtonLabel(title: "PLAY", systemIcon: "play.fill", tint: .green)
                            }
                            Button { showSettings = true } label: {
                                MenuButtonLabel(title: "SETTINGS", systemIcon: "gearshape.fill", tint: .blue)
                            }
                        }
                        .padding(28)
                        .frame(width: min(320, geo.size.width * 0.36))
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsSheet(settings: settings)
            }
        }
    }
}

private struct MenuButtonLabel: View {
    let title: String
    let systemIcon: String
    let tint: Color

    var body: some View {
        HStack {
            Image(systemName: systemIcon)
            Text(title).fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(tint)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
