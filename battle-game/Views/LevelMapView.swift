import SwiftUI

/// LevelMap — ports Unity's MapLevels.unity (world map w/ MapBG.jpg) + LevelSelection1 flow.
/// Landscape horizontal strip: dotted path + 3 nodes. Locked nodes grey out; tap an
/// unlocked node to open the level intro (LevelDetailView, ex-ConfigurationUI).
struct LevelMapView: View {
    @State private var completedRefresh = false // flips when returning from a level

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ImportedArt.image(named: "MapBG")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.5)
                    .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.6), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    Text("SELECT MISSION")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    // Horizontal node strip with connector line.
                    ZStack {
                        // Dotted path behind nodes.
                        Path { path in
                            let y = geo.size.height * 0.32
                            path.move(to: CGPoint(x: 60, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width - 60, y: y))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(height: geo.size.height * 0.5)

                        HStack(spacing: geo.size.width * 0.12) {
                            ForEach(CampaignData.levels) { level in
                                LevelNode(level: level)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: geo.size.height * 0.5)

                    Spacer()
                }
            }
        }
        .navigationTitle("Missions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LevelNode: View {
    let level: LevelDef
    @State private var tick = false // forces stars/unlock refresh on appear

    private var unlocked: Bool { CampaignData.isUnlocked(level) }
    private var stars: Int { CampaignData.stars(for: level.id) }

    var body: some View {
        Group {
            if unlocked {
                NavigationLink { LevelDetailView(level: level) } label: {
                    nodeContent
                }
            } else {
                nodeContent
                    .opacity(0.45)
                    .allowsHitTesting(false)
            }
        }
        .onAppear { tick.toggle() }
    }

    private var nodeContent: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? Color.blue : Color.gray)
                    .frame(width: 84, height: 84)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(radius: unlocked ? 8 : 0)
                if unlocked {
                    Text("\(level.id)")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                if unlocked && level.id == CampaignData.unlockedLevel && stars == 0 {
                    Circle()
                        .stroke(.yellow, lineWidth: 3)
                        .frame(width: 96, height: 96)
                        .opacity(0.9)
                }
            }
            Text(level.name)
                .font(.headline)
                .foregroundStyle(.white)
            StarRow(count: stars)
        }
    }
}

private struct StarRow: View {
    let count: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .foregroundStyle(i < count ? .yellow : .white.opacity(0.5))
                    .font(.caption)
            }
        }
    }
}

#Preview {
    NavigationStack { LevelMapView() }
}
