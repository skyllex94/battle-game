import SwiftUI

/// Emra campaign map — the planet advanced humanity takes back across
/// 35 regions. A seven-page pixel world (verdant west → dune seas →
/// mountain passes → frozen east → dark core) with castles, blended biome
/// transitions, and a marching invasion route. Arrows page between regions;
/// tap a lit node to open its briefing (LevelDetailView).
struct LevelMapView: View {
    @Environment(\.dismiss) private var dismiss
    /// Campaign path (map pushes briefings by id).
    @Binding var path: NavigationPath
    /// Free pan across the 7-page world, in full-bleed points (0 = west edge).
    @State private var panX: CGFloat = 0
    /// Full-bleed screen size (under notch/home bar), measured by the map layer.
    @State private var fullW: CGFloat = 800
    @State private var fullH: CGFloat = 400
    @State private var refresh = false // flips on appear: re-reads stars/unlocks
    /// Set once: re-appear must never re-snap the camera (briefing back-outs
    /// keep exactly where the player was browsing).
    @State private var didSnapCamera = false

    /// Nearest page to the current pan (drives zone chip + dots).
    private var currentPage: Int {
        min(EmraMap.pages - 1, max(0, Int((panX / fullW).rounded())))
    }

    private func clampPan(_ x: CGFloat) -> CGFloat {
        min(max(0, x), fullW * CGFloat(EmraMap.pages - 1))
    }

    private func goPage(_ p: Int) {
        SoundEngine.shared.uiTap()
        withAnimation(.easeInOut(duration: 0.45)) {
            panX = clampPan(CGFloat(min(EmraMap.pages - 1, max(0, p))) * fullW)
        }
    }

    /// Persist the camera spot (fraction of one screen width, so it
    /// survives orientation changes and app relaunches).
    private func savePan() {
        guard fullW > 0 else { return }
        CampaignData.lastMapPanFraction = Double(panX / fullW)
    }

    var body: some View {
        ZStack {
            // Full-bleed world layer: measures the REAL screen (under the
            // notch/home bar) so there is no safe-area cutout anywhere.
            GeometryReader { full in
                HStack(spacing: 0) {
                    ZStack {
                        // Live pixel world, painted in full every render —
                        // nothing is ever culled, so no region can pop in
                        // or go missing while panning. Repaints only happen
                        // when pan state changes (active scroll / page jump).
                        Canvas { ctx, _ in
                            EmraMap.draw(ctx: &ctx,
                                         size: CGSize(width: fullW * CGFloat(EmraMap.pages),
                                                      height: fullH),
                                         t: 4.2)
                        }
                        .frame(width: fullW * CGFloat(EmraMap.pages), height: fullH)
                        ForEach(CampaignData.levels) { level in
                            EmraNodeView(level: level, path: $path)
                                .position(x: EmraMap.worldX(level.id) * fullW,
                                          y: EmraMap.nodeY(level.id) * fullH)
                        }
                    }
                    .frame(width: fullW * CGFloat(EmraMap.pages), height: fullH,
                           alignment: .leading)
                    .offset(x: -panX)
                    Spacer(minLength: 0)
                }
                .frame(width: full.size.width, height: full.size.height, alignment: .leading)
                .onAppear {
                    fullW = full.size.width
                    fullH = full.size.height
                    // Land where the player last browsed — persisted across
                    // sessions. First visit ever: the objective's page.
                    if !didSnapCamera {
                        didSnapCamera = true
                        if let frac = CampaignData.lastMapPanFraction {
                            panX = clampPan(CGFloat(frac) * fullW)
                        } else {
                            let page = min(EmraMap.pages - 1,
                                           max(0, (CampaignData.unlockedLevel - 1) / 5))
                            panX = clampPan(CGFloat(page) * fullW)
                        }
                    }
                }
                .onChange(of: full.size) { newSize in
                    fullW = newSize.width
                    fullH = newSize.height
                    panX = clampPan(panX)
                    savePan()
                }
                .onChange(of: panX) { _ in savePan() }
            }
            .ignoresSafeArea(edges: .all)

            // Safe-area chrome on top.
            GeometryReader { geo in
                ZStack {
                    // Readability grades.
                    LinearGradient(colors: [.black.opacity(0.30), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 150)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                    LinearGradient(colors: [.clear, .black.opacity(0.35)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 110)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)
                    RadialGradient(colors: [.clear, .black.opacity(0.22)],
                                   center: .center, startRadius: 80, endRadius: 520)
                        .ignoresSafeArea(edges: .all)
                        .allowsHitTesting(false)

                    // Page arrows on each end.
                    HStack(spacing: 0) {
                        if currentPage > 0 {
                            EmraArrow(dir: -1) { goPage(currentPage - 1) }
                        }
                        Spacer()
                        if currentPage < EmraMap.pages - 1 {
                            EmraArrow(dir: 1) { goPage(currentPage + 1) }
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(maxHeight: .infinity)
                    .offset(y: -30)

                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            Button {
                                SoundEngine.shared.uiTap()
                                dismiss()
                            } label: {
                                Text("MENU")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .tracking(2)
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(.black.opacity(0.65))
                                    .clipShape(MapPixelShape(cut: 6))
                                    .overlay(MapPixelShape(cut: 6).stroke(.cyan.opacity(0.6), lineWidth: 2))
                            }
                            Spacer()
                            EmraTopBarChips()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        EmraZoneChip(page: currentPage) { goPage($0) }
                        Spacer()
                        EmraIntelStrip()
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { refresh.toggle() }
    }
}

// MARK: - Nodes

private struct EmraNodeView: View {
    let level: LevelDef
    @Binding var path: NavigationPath
    @State private var tick = false

    private var unlocked: Bool { CampaignData.isUnlocked(level) }
    private var stars: Int { CampaignData.stars(for: level.id) }
    private var isNext: Bool { unlocked && level.id == CampaignData.unlockedLevel && stars == 0 }

    var body: some View {
        Group {
            if unlocked {
                Button {
                    SoundEngine.shared.uiTap()
                    path.append(Route.detail(levelId: level.id))
                } label: { content }
            } else {
                content.opacity(0.55).allowsHitTesting(false)
            }
        }
        .onAppear { tick.toggle() }
    }

    private var content: some View {
        VStack(spacing: 3) {
            ZStack {
                if isNext {
                    Circle()
                        .stroke(.yellow, lineWidth: 3)
                        .frame(width: 62, height: 62)
                        .opacity(0.9)
                        .scaleEffect(tick ? 1.12 : 1.0)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                                   value: tick)
                        .onAppear { tick = true }
                }
                // Pixel diamond pad.
                Rectangle()
                    .fill(padFill)
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(45))
                    .overlay(
                        Rectangle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 42, height: 42)
                            .rotationEffect(.degrees(45))
                    )
                    .shadow(color: padFill.opacity(0.7), radius: unlocked ? 10 : 0)
                if unlocked {
                    Image(systemName: EmraMap.icon(level.id))
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(height: 66)
            if isNext {
                Text("NEXT")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.yellow)
            }
            Text("\(level.id). \(level.name)".uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 4)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            StarRow(count: stars)
        }
        .frame(width: 120)
    }

    private var padFill: Color {
        if !unlocked { return .gray }
        if stars > 0 { return .blue }
        return .green
    }
}

private struct StarRow: View {
    let count: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .foregroundStyle(i < count ? .yellow : .white.opacity(0.5))
                    .font(.system(size: 10, weight: .bold))
                    .shadow(color: .black, radius: 2)
            }
        }
    }
}

// MARK: - Chrome

/// Slim progress chips (stars + region) for the top-right corner.
private struct EmraTopBarChips: View {
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
                Text("\(totalStars)/\(CampaignData.levels.count * 3)")
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.black.opacity(0.55))
            .overlay(Rectangle().stroke(.yellow.opacity(0.5), lineWidth: 1))
            HStack(spacing: 5) {
                Image(systemName: "flag.fill").foregroundStyle(.cyan)
                Text("R\(min(CampaignData.unlockedLevel, CampaignData.levels.count))/\(CampaignData.levels.count)")
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.black.opacity(0.55))
            .overlay(Rectangle().stroke(.cyan.opacity(0.5), lineWidth: 1))
        }
    }

    private var totalStars: Int {
        CampaignData.levels.reduce(0) { $0 + CampaignData.stars(for: $1.id) }
    }
}

/// Chamfered pixel panel shape for map chrome.
private struct MapPixelShape: Shape {
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

/// Current zone banner + page dots (dots jump pages).
private struct EmraZoneChip: View {
    let page: Int
    let jump: (Int) -> Void
    var body: some View {
        HStack(spacing: 10) {
            Text(EmraMap.zone(page))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                ForEach(0..<EmraMap.pages, id: \.self) { i in
                    Button { jump(i) } label: {
                        Circle()
                            .fill(i == page ? .yellow : .white.opacity(0.35))
                            .frame(width: 9, height: 9)
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(.black.opacity(0.5))
        .overlay(Rectangle().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

private struct EmraArrow: View {
    let dir: Int // -1 left, +1 right
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            Image(systemName: dir < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 52, height: 72)
                .background(.black.opacity(0.55))
                .overlay(Rectangle().stroke(.cyan.opacity(0.6), lineWidth: 2))
                .shadow(color: .cyan.opacity(0.25), radius: 8)
        }
    }
}

private struct EmraIntelStrip: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(.cyan).frame(width: 8, height: 8)
            if let next = CampaignData.levels.first(where: { $0.id == CampaignData.unlockedLevel }) {
                Text("NEXT — \(next.name.uppercased()): \(next.subtitle). Tap a lit region to deploy.")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            } else {
                Text("EMRA SECURED — every region taken. Replay missions for ★★★.")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
            }
            Spacer()
            Text("● SECURED  ● NEXT  ○ LOCKED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.55))
        .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
    }
}

#Preview {
    NavigationStack { LevelMapView(path: .constant(NavigationPath())) }
}
