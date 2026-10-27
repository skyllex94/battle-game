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

    /// Page holding the NEXT beacon, if one exists (mirrors the node
    /// marker logic: unlocked + stars == 0). Nil once everything is
    /// cleared — nothing to locate.
    private var nextPage: Int? {
        let id = CampaignData.unlockedLevel
        guard CampaignData.levels.contains(where: { $0.id == id }),
              CampaignData.stars(for: id) == 0 else { return nil }
        return min(EmraMap.pages - 1, max(0, (id - 1) / 5))
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
                        // Off-screen NEXT locator: jumps the camera back to
                        // the beacon's page. Only shows while paged away.
                        if let nextPage, nextPage != currentPage {
                            HStack {
                                Spacer()
                                Button {
                                    goPage(nextPage)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 10, weight: .black))
                                        Text("NEXT")
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .tracking(2)
                                    }
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(.yellow)
                                    .clipShape(MapPixelShape(cut: 5))
                                    .overlay(MapPixelShape(cut: 5).stroke(.white.opacity(0.6), lineWidth: 2))
                                    .shadow(color: .yellow.opacity(0.4), radius: 8)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                        }
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
    }

    private var content: some View {
        VStack(spacing: 3) {
            ZStack {
                // Pixel-art NEXT beacon: pinned dead-center on the pad so it
                // can never drift toward the level or off the screen — it
                // only breathes + pings in place.
                if isNext {
                    NextLevelMarker()
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
            .frame(height: 92)
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

private struct NextLevelMarker: View {
    /// Radar ping: 0 = tight on the pad, 1 = fully expanded + faded.
    @State private var ping = false
    /// Tight ring breath: expands/contracts in place.
    @State private var breathe = false
    /// Corner-spark blink.
    @State private var blink = false

    var body: some View {
        ZStack {
            // Outer radar ping: chunky pixel diamond that expands from the
            // pad and dissolves — always centered, never travels.
            PixelDiamondRing(edge: 62, line: 4, color: .yellow)
                .scaleEffect(ping ? 1.5 : 0.92)
                .opacity(ping ? 0 : 0.8)
                .animation(.linear(duration: 1.6).repeatForever(autoreverses: false),
                           value: ping)
            // Tight breathing ring hugging the pad.
            PixelDiamondRing(edge: 62, line: 3, color: .yellow)
                .scaleEffect(breathe ? 1.12 : 1.0)
                .opacity(0.95)
                .shadow(color: .yellow.opacity(0.6), radius: 8)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                           value: breathe)
            // Four blinking corner sparks (N/E/S/W) — pixel crumbs that
            // sell the retro beacon read.
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(.yellow)
                    .frame(width: 6, height: 6)
                    .offset(y: -46)
                    .rotationEffect(.degrees(Double(i) * 90))
                    .opacity(blink ? 0.25 : 1)
            }
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                       value: blink)
        }
        .frame(width: 92, height: 92)
        .allowsHitTesting(false)
        .onAppear {
            // Flip once: the repeatForever animations take it from here.
            ping = true
            breathe = true
            blink = true
        }
    }
}

/// Chunky pixel diamond ring: a rotated stroked square with stepped
/// corner blocks so it reads as pixel art, not a smooth vector circle.
private struct PixelDiamondRing: View {
    let edge: CGFloat
    let line: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(color, lineWidth: line)
                .frame(width: edge, height: edge)
                .rotationEffect(.degrees(45))
            // Stepped corner pixels break the smooth-vector read.
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(color)
                    .frame(width: line + 3, height: line + 3)
                    .offset(y: -edge * 0.7071)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
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

#Preview {
    NavigationStack { LevelMapView(path: .constant(NavigationPath())) }
}
