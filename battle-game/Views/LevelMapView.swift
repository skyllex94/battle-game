import SwiftUI
import Combine // Timer publisher for joystick pan integration

/// Emra campaign map — the planet advanced humanity takes back across
/// 15 regions. A three-page pixel world (verdant west → scorched midlands
/// → frozen east + umbral core) with castles, blended biome transitions,
/// and a marching invasion route. Arrows page between regions; tap a lit
/// node to open its briefing (LevelDetailView).
struct LevelMapView: View {
    @Environment(\.dismiss) private var dismiss
    /// Free pan across the 3-page world, in full-bleed points (0 = west edge).
    @State private var panX: CGFloat = 0
    /// Full-bleed screen size (under notch/home bar), measured by the map layer.
    @State private var fullW: CGFloat = 800
    @State private var fullH: CGFloat = 400
    /// Joystick knob deflection (x only); drives pan velocity while held.
    @State private var knob = CGSize.zero
    @State private var refresh = false // flips on appear: re-reads stars/unlocks
    private let panTimer = Timer.publish(every: 1 / 60, on: .main, in: .common).autoconnect()

    /// Nearest page to the current pan (drives zone chip + dots).
    private var currentPage: Int {
        min(2, max(0, Int((panX / fullW).rounded())))
    }

    private func clampPan(_ x: CGFloat) -> CGFloat {
        min(max(0, x), fullW * 2)
    }

    private func goPage(_ p: Int) {
        SoundEngine.shared.uiTap()
        withAnimation(.easeInOut(duration: 0.45)) {
            panX = clampPan(CGFloat(min(2, max(0, p))) * fullW)
        }
    }

    var body: some View {
        ZStack {
            // Full-bleed world layer: measures the REAL screen (under the
            // notch/home bar) so there is no safe-area cutout anywhere.
            GeometryReader { full in
                HStack(spacing: 0) {
                    ZStack {
                        Canvas { ctx, _ in
                            EmraMap.draw(ctx: &ctx,
                                         size: CGSize(width: fullW * 3, height: fullH),
                                         center: Double(panX / fullW),
                                         t: 4.2)
                        }
                        .frame(width: fullW * 3, height: fullH)
                        ForEach(CampaignData.levels) { level in
                            EmraNodeView(level: level)
                                .position(x: EmraMap.worldX(level.id) * fullW,
                                          y: EmraMap.nodeY(level.id) * fullH)
                        }
                    }
                    .frame(width: fullW * 3, height: fullH)
                    .offset(x: -panX)
                    Spacer(minLength: 0)
                }
                .frame(width: full.size.width, height: full.size.height)
                .onAppear {
                    fullW = full.size.width
                    fullH = full.size.height
                    // Open on the page holding the current objective.
                    panX = clampPan(CGFloat(min(2, max(0, (CampaignData.unlockedLevel - 1) / 5))) * fullW)
                }
                .onChange(of: full.size) { newSize in
                    fullW = newSize.width
                    fullH = newSize.height
                    panX = clampPan(panX)
                }
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
                    MapCornerFrame()
                        .padding(10)
                        .allowsHitTesting(false)

                    // Page arrows on each end.
                    HStack(spacing: 0) {
                        if currentPage > 0 {
                            EmraArrow(dir: -1) { goPage(currentPage - 1) }
                        }
                        Spacer()
                        if currentPage < 2 {
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
                            .padding(.leading, 132)
                    }

                    // Map joystick, bottom-left: hold + lean to scroll.
                    VStack {
                        Spacer()
                        HStack {
                            MapJoystick(knob: $knob)
                                .padding(.leading, 14)
                                .padding(.bottom, 86)
                            Spacer()
                        }
                    }
                    .allowsHitTesting(true)
                }
                .onReceive(panTimer) { _ in
                    // Knob deflection = pan velocity (up to ~350 pt/s).
                    if knob.width != 0 {
                        withAnimation(.linear(duration: 1 / 60)) {
                            panX = clampPan(panX + knob.width * 0.18)
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

/// Small map joystick: lean the knob left/right to scroll the world.
/// Springs back to center on release.
private struct MapJoystick: View {
    @Binding var knob: CGSize
    private let maxR: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(.black.opacity(0.5))
                .frame(width: 104, height: 104)
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(.cyan.opacity(0.5), lineWidth: 2))
            // Direction ticks.
            HStack(spacing: 0) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.cyan.opacity(0.6))
                    .frame(width: 104, alignment: .leading)
                    .padding(.leading, 6)
                Spacer(minLength: 0)
            }
            .frame(width: 104)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.cyan.opacity(0.6))
                    .frame(width: 104, alignment: .trailing)
                    .padding(.trailing, 6)
            }
            .frame(width: 104)
            RoundedRectangle(cornerRadius: 14)
                .fill(.cyan.opacity(0.85))
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.7), lineWidth: 2))
                .shadow(color: .cyan.opacity(0.5), radius: 8)
                .offset(x: knob.width, y: 0)
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { v in
                            let w = v.translation.width
                            knob = CGSize(width: min(max(-maxR, w), maxR), height: 0)
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                knob = .zero
                            }
                        }
                )
        }
        .frame(width: 104, height: 104)
    }
}

// MARK: - Nodes

private struct EmraNodeView: View {
    let level: LevelDef
    @State private var tick = false

    private var unlocked: Bool { CampaignData.isUnlocked(level) }
    private var stars: Int { CampaignData.stars(for: level.id) }
    private var isNext: Bool { unlocked && level.id == CampaignData.unlockedLevel && stars == 0 }

    var body: some View {
        Group {
            if unlocked {
                NavigationLink { LevelDetailView(level: level) } label: { content }
                    .simultaneousGesture(TapGesture().onEnded {
                        SoundEngine.shared.uiTap()
                    })
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
            Text(level.name.uppercased())
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

/// Stepped pixel corner brackets framing the world map.
private struct MapCornerFrame: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                MapCorner().position(x: 14, y: 14)
                MapCorner()
                    .rotationEffect(.degrees(90))
                    .position(x: geo.size.width - 14, y: 14)
                MapCorner()
                    .rotationEffect(.degrees(180))
                    .position(x: geo.size.width - 14, y: geo.size.height - 14)
                MapCorner()
                    .rotationEffect(.degrees(270))
                    .position(x: 14, y: geo.size.height - 14)
            }
        }
    }
}

private struct MapCorner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Color.cyan.frame(width: 22, height: 5)
                Color.cyan.frame(width: 5, height: 5).opacity(0.55)
            }
            HStack(spacing: 0) {
                Color.cyan.frame(width: 5, height: 22)
                Color.clear.frame(width: 22, height: 22)
            }
            HStack(spacing: 0) {
                Color.cyan.opacity(0.55).frame(width: 5, height: 5)
                Color.clear.frame(width: 22, height: 5)
            }
        }
        .opacity(0.8)
    }
}
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
                ForEach(0..<3, id: \.self) { i in
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

// MARK: - Pixel planet

/// Code-drawn planet Emra: a 480x90-pixel continent (3 screen-pages) with
/// biomes blending west → east (verdant → desert → ember → frost → umbral),
/// castles at strongholds, ocean + islets, drifting clouds, and a marching
/// invasion route through all 15 regions.
///
/// Paint helpers are nested inside `draw` so they capture the `px` pixel
/// plotter with its default alpha intact.
enum EmraMap {
    static let pageCols = 160
    static let rows = 90
    static let pages = 3
    static var cols: Int { pageCols * pages } // 480

    // Node layout: 5 regions per page, winding down/up the continent.
    private static let slotX: [Double] = [0.14, 0.32, 0.50, 0.68, 0.86]
    private static let slotY: [Double] = [0.60, 0.44, 0.58, 0.42, 0.54]

    /// World x in page units (0..<3) — multiply by screen width.
    static func worldX(_ id: Int) -> Double {
        let p = Double((id - 1) / 5)
        return p + slotX[(id - 1) % 5]
    }

    static func nodeY(_ id: Int) -> Double { slotY[(id - 1) % 5] }

    static func zone(_ page: Int) -> String {
        ["THE VERDANT WEST", "THE SCORCHED MIDLANDS", "THE FROZEN EAST + UMBRAL CORE"][min(2, max(0, page))]
    }

    static func icon(_ id: Int) -> String {
        switch id {
        case 1, 2: return "leaf.fill"
        case 3: return "shield.fill"
        case 4, 5: return "sun.max.fill"
        case 6: return "shield.fill"
        case 7, 8: return "flame.fill"
        case 9: return "shield.fill"
        case 10: return "snowflake"
        case 11: return "shield.fill"
        case 12: return "snowflake"
        case 13: return "bolt.fill"
        case 14: return "moon.fill"
        default: return "crown.fill"
        }
    }

    /// Castle strongholds: node id → allied? (id 15 is the enemy citadel).
    private static let castles: [Int: Bool] = [3: true, 6: true, 9: true, 11: true, 15: false]

    private static func h(_ x: Int, _ y: Int, _ s: Int) -> Int {
        abs((x &* 73856093) ^ (y &* 19349663) ^ (s &* 83492791)) % 100
    }

    /// Continent silhouette: walkable band between top/bot curves.
    private static func landTop(_ gx: Int) -> Int {
        var t = 30 + Int(6 * sin(Double(gx) * 0.035)) + (h(gx, 3, 61) % 7 - 3)
        if gx < 10 { t += (10 - gx) * 2 }            // pinch west cape
        if gx > cols - 11 { t += (gx - (cols - 11)) * 2 } // pinch east cape
        return t
    }

    private static func landBot(_ gx: Int) -> Int {
        var b = 66 + Int(6 * sin(Double(gx) * 0.028 + 2.0)) + (h(gx, 9, 62) % 7 - 3)
        if gx < 10 { b -= (10 - gx) * 2 }
        if gx > cols - 11 { b -= (gx - (cols - 11)) * 2 }
        return b
    }

    /// Biome index by world x: 0 verdant, 1 desert, 2 ember, 3 frost/umbral.
    /// Transition bands dither between neighbours per-cell (see pickBiome).
    private static func biomePair(_ gx: Int) -> (a: Int, b: Int, f: Double) {
        if gx < 130 { return (0, 0, 0) }
        if gx < 150 { return (0, 1, Double(gx - 130) / 20) }
        if gx < 230 { return (1, 1, 0) }
        if gx < 250 { return (1, 2, Double(gx - 230) / 20) }
        if gx < 320 { return (2, 2, 0) }
        if gx < 340 { return (2, 3, Double(gx - 320) / 20) }
        return (3, 3, 0)
    }

    private static func pickBiome(gx: Int, gy: Int) -> Int {
        let p = biomePair(gx)
        if p.f <= 0 { return p.a }
        return Double(h(gx, gy, 50)) / 100 < p.f ? p.b : p.a
    }

    static func draw(ctx: inout GraphicsContext, size: CGSize, center: Double, t: Double) {
        let cw = size.width / CGFloat(cols)
        let chh = size.height / CGFloat(rows)
        // Paint only around the visible page (+margin) — center is the
        // fractional page (0..2) so free joystick panning never pops.
        let visX0 = Int(center * Double(pageCols)) - 16
        let visX1 = Int((center + 1) * Double(pageCols)) + 16
        func visible(_ gx: Int, _ m: Int = 0) -> Bool { gx >= visX0 - m && gx <= visX1 + m }
        func px(_ gx: Int, _ gy: Int, _ w: Int, _ hgt: Int, _ c: Color, _ alpha: Double = 1) {
            guard gx + w > visX0 - 24 && gx < visX1 + 24 && gy + hgt > 0 && gy < rows else { return }
            ctx.fill(Path(CGRect(x: CGFloat(gx) * cw, y: CGFloat(gy) * chh,
                                 width: CGFloat(w) * cw, height: CGFloat(hgt) * chh)),
                     with: .color(c.opacity(alpha)))
        }

        // -- terrain painters (biome 0..3) --
        func baseVerdant(gx: Int, gy: Int) {
            px(gx, gy, 1, 1, h(gx, gy, 7) < 30
                ? Color(red: 0.18, green: 0.46, blue: 0.23)
                : Color(red: 0.29, green: 0.60, blue: 0.31))
            if h(gx, gy, 8) < 15 {
                px(gx, gy, 1, 2, Color(red: 0.08, green: 0.30, blue: 0.16))
                px(gx, gy + 2, 1, 1, Color(red: 0.35, green: 0.22, blue: 0.12))
            }
            if h(gx, gy, 9) > 94 { px(gx, gy, 1, 1, .white) }
        }

        func baseDesert(gx: Int, gy: Int) {
            px(gx, gy, 1, 1, gy % 4 == 0 && h(gx, gy, 7) < 40
                ? Color(red: 0.78, green: 0.65, blue: 0.42)
                : Color(red: 0.87, green: 0.76, blue: 0.53))
            if h(gx, gy, 8) > 96 {
                px(gx, gy, 1, 3, Color(red: 0.20, green: 0.50, blue: 0.25))
                px(gx - 1, gy + 1, 1, 1, Color(red: 0.20, green: 0.50, blue: 0.25))
            }
        }

        func baseEmber(gx: Int, gy: Int) {
            px(gx, gy, 1, 1, h(gx, gy, 7) < 35
                ? Color(red: 0.27, green: 0.20, blue: 0.20)
                : Color(red: 0.36, green: 0.25, blue: 0.22))
            if (h(gx, gy, 10) + Int(t * 10)) % 46 < 3 {
                let hot = (sin(t * 4 + Double(gx)) + 1) / 2
                px(gx, gy, 1, 1, Color(red: 1, green: 0.25 + 0.35 * hot, blue: 0.08))
            }
        }

        func baseFrost(gx: Int, gy: Int) {
            let line = 46 + h(gx, 1, 16) % 8
            if gy < line {
                px(gx, gy, 1, 1, Color(red: 0.93, green: 0.95, blue: 0.98))
            } else {
                px(gx, gy, 1, 1, Color(red: 0.42, green: 0.45, blue: 0.52))
                if h(gx, gy, 8) < 13 {
                    px(gx, gy, 1, 2, Color(red: 0.10, green: 0.25, blue: 0.28))
                    px(gx, gy - 1, 1, 1, .white)
                }
            }
            if gx > 430 { // umbral dark creeps into the far east
                px(gx, gy, 1, 1, Color(red: 0.13, green: 0.11, blue: 0.20),
                   Double(h(gx, gy, 19)) / 100 * Double(gx - 430) / 50)
            }
        }

        // -- landmarks --
        func tents(gx: Int, gy: Int) {
            px(gx - 4, gy - 4, 9, 9, Color(red: 0.35, green: 0.62, blue: 0.30))
            px(gx - 3, gy - 1, 3, 2, Color(red: 0.75, green: 0.70, blue: 0.60))
            px(gx - 3, gy - 2, 3, 1, Color(red: 0.55, green: 0.50, blue: 0.42))
            px(gx + 1, gy, 2, 2, Color(red: 0.30, green: 0.60, blue: 1.0))
        }

        func pyramid(gx: Int, gy: Int) {
            for r in 0..<5 {
                let half = 5 - r
                px(gx - half, gy - 2 + r, half * 2, 1,
                   r < 2 ? Color(red: 0.80, green: 0.68, blue: 0.45)
                         : Color(red: 0.62, green: 0.50, blue: 0.32))
            }
            px(gx, gy - 2, 1, 1, .yellow)
        }

        func volcano(gx: Int, gy: Int) {
            let vy = gy - 12
            for r in 0..<6 {
                let half = 6 - r
                px(gx - half, vy - 5 + r, half * 2, 1, Color(red: 0.25, green: 0.17, blue: 0.15))
            }
            let hot = (sin(t * 4) + 1) / 2
            px(gx - 2, vy - 5, 5, 2, Color(red: 1, green: 0.3 + 0.4 * hot, blue: 0.05))
            px(gx - 1, vy - 5, 3, 1, .yellow, 0.6 + 0.4 * hot)
            for s in 0..<5 {
                let age = (t * 3 + Double(s) * 2.4).truncatingRemainder(dividingBy: 12)
                px(gx - 1 + Int(age * 0.9) + h(s, 1, 15) % 2, vy - 6 - Int(age),
                   2, 1, Color(white: 0.25 + age / 40), 0.55 - age * 0.04)
            }
        }

        func peaks(gx: Int, gy: Int) {
            for r in 0..<7 {
                let half = 7 - r
                px(gx - 4 - half, gy - 16 + r, half * 2, 1,
                   Color(red: 0.45, green: 0.48, blue: 0.55))
            }
            px(gx - 8, gy - 16, 9, 2, .white)
            px(gx - 7, gy - 16, 3, 1, Color(red: 0.65, green: 0.85, blue: 1.0))
        }

        func crystalSpire(gx: Int, gy: Int) {
            let pulse = (sin(t * 3) + 1) / 2
            px(gx - 1, gy - 13, 3, 5, Color(red: 0.55, green: 0.30, blue: 0.95))
            px(gx, gy - 13, 1, 5, .white, 0.5 + 0.4 * pulse)
            px(gx - 2, gy - 11, 5, 1, Color(red: 0.6, green: 0.35, blue: 1.0), 0.25 + 0.2 * pulse)
        }

        /// Pixel castle at a node gate. Allied = stone + blue banners + warm
        /// windows; enemy citadel (big) = dark basalt + red glow + spires.
        func castle(gx: Int, gy: Int, allied: Bool, big: Bool) {
            let s = big ? 3 : 2 // unit scale
            let stone = allied ? Color(red: 0.58, green: 0.57, blue: 0.62)
                               : Color(red: 0.18, green: 0.15, blue: 0.24)
            let trim = allied ? Color(red: 0.30, green: 0.60, blue: 1.0)
                              : Color(red: 1.0, green: 0.25, blue: 0.15)
            let W = 7 * s, H = (big ? 10 : 7) * s
            // Main keep.
            px(gx - W / 2, gy - H, W, H, stone)
            px(gx - W / 2, gy - H, W, 1, .white.opacity(0.5)) // top catch-light
            // Crenellations.
            var bx = gx - W / 2
            while bx < gx + W / 2 {
                px(bx, gy - H - s, s, s, stone)
                bx += s * 2
            }
            // Side towers with caps.
            for tx in [gx - W / 2 - s, gx + W / 2] {
                px(tx, gy - H - 2 * s, 2 * s, H + 2 * s, stone)
                px(tx - 1, gy - H - 3 * s, 2 * s + 2, s, trim)
            }
            // Gate arch at the node point.
            px(gx - s, gy - 2 * s, 2 * s, 2 * s, .black)
            px(gx - s, gy - 2 * s, 2 * s, 1, trim)
            // Windows: warm for allies, ember-red for the citadel (pulse).
            let winGlow: Double = allied ? 0.9 : 0.5 + 0.5 * sin(t * 3)
            px(gx - W / 4, gy - H + 2 * s, s, s, trim, winGlow)
            px(gx + W / 4 - s, gy - H + 2 * s, s, s, trim, winGlow)
            // War banners on the towers.
            for tx in [gx - W / 2, gx + W / 2 - 1] {
                px(tx, gy - H - 4 * s, 1, 2 * s, Color(white: 0.2))
                px(tx + 1, gy - H - 4 * s, 3, 2, trim)
            }
            if big { // citadel spires + lava moat
                for tx in [gx - W / 2 + 2 * s, gx + W / 2 - 2 * s] {
                    px(tx, gy - H - 6 * s, s, 4 * s, stone)
                    px(tx, gy - H - 6 * s, s, 1, trim, 0.8 + 0.2 * sin(t * 3))
                }
                for mx in stride(from: gx - W / 2 - 2, to: gx + W / 2 + 2, by: 2) {
                    if h(mx, gy, 20) < 60 {
                        px(mx, gy - 1, 2, 1, Color(red: 1, green: 0.3, blue: 0.08),
                           0.5 + 0.4 * sin(t * 4 + Double(mx)))
                    }
                }
            }
        }

        func bannerPost(gx: Int) {
            let top = landTop(gx) + 3
            guard top < landBot(gx) - 4 else { return }
            px(gx, top, 1, 7, Color(white: 0.25))
            px(gx + 1, top, 3, 2, Color(red: 0.30, green: 0.60, blue: 1.0))
        }

        func nodeCell(_ id: Int) -> (x: Int, y: Int) {
            (Int(worldX(id) * Double(pageCols)), Int(nodeY(id) * Double(rows)))
        }

        // ---- frame ----
        // Ocean body (one fill for the whole world strip).
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .color(Color(red: 0.05, green: 0.29, blue: 0.41)))
        for gy in stride(from: 4, to: rows, by: 7) { // depth dither
            for gx in stride(from: (gy * 5) % 16, to: cols, by: 16) {
                if visible(gx) {
                    px(gx, gy, 6, 1, Color(red: 0.08, green: 0.36, blue: 0.48))
                }
            }
        }
        for i in 0..<110 { // swell sparkles drifting east
            let wx = (h(i, 3, 11) * 4 + Int(t * 6)) % (cols + 10) - 5
            let wy = h(i, 7, 12) * rows / 100
            if visible(wx) && h(i, wy, 13) < 30 {
                px(wx, wy, 2, 1, Color(red: 0.45, green: 0.82, blue: 0.88),
                   0.45 + 0.3 * sin(t * 2 + Double(i)))
            }
        }

        // Continent body.
        let foamA = 0.5 + 0.4 * sin(t * 3)
        for gx in visX0...visX1 where gx >= 0 && gx < cols {
            let top = landTop(gx), bot = landBot(gx)
            guard top < bot else { continue }
            let frosty = pickBiome(gx: gx, gy: (top + bot) / 2) == 3
            for gy in (top - 1)...(bot + 1) {
                guard gy >= 0 && gy < rows else { continue }
                if gy <= top + 1 || gy >= bot - 1 { // shore rim + foam
                    px(gx, gy, 1, 1, frosty
                        ? Color(red: 0.70, green: 0.85, blue: 0.92)
                        : Color(red: 0.85, green: 0.76, blue: 0.52))
                    if h(gx, gy, 6) < Int(30 + 25 * foamA) {
                        px(gx, gy, 1, 1, .white, 0.65)
                    }
                    continue
                }
                switch pickBiome(gx: gx, gy: gy) {
                case 0: baseVerdant(gx: gx, gy: gy)
                case 1: baseDesert(gx: gx, gy: gy)
                case 2: baseEmber(gx: gx, gy: gy)
                default: baseFrost(gx: gx, gy: gy)
                }
            }
        }

        // Ocean islets: palm cay, floe, mosaic shoal.
        for (ix, iy, ir, kind) in [(60, 80, 4, 0), (380, 14, 5, 3), (200, 78, 5, 4)] as [(Int, Int, Int, Int)] {
            guard visible(ix, ir + 4) else { continue }
            for gy in (iy - ir - 1)...(iy + ir + 1) {
                for gx in (ix - ir - 1)...(ix + ir + 1) {
                    let d = Double((gx - ix) * (gx - ix) + (gy - iy) * (gy - iy)) / Double(ir * ir)
                    guard d < 1 - Double(h(gx, gy, 5)) / 100 * 0.25 else { continue }
                    if kind == 0 {
                        px(gx, gy, 1, 1, Color(red: 0.24, green: 0.54, blue: 0.27))
                        if h(gx, gy, 8) < 25 {
                            px(gx, gy, 1, 2, Color(red: 0.08, green: 0.30, blue: 0.16))
                        }
                    } else if kind == 3 {
                        px(gx, gy, 1, 1, Color(red: 0.90, green: 0.93, blue: 0.97))
                    } else {
                        px(gx, gy, 1, 1, Color(red: 0.55, green: 0.52, blue: 0.42))
                        if h(gx, gy, 17) > 90 {
                            px(gx, gy, 1, 1, Color(red: 0.4, green: 0.85, blue: 1.0),
                               0.3 + 0.5 * (sin(t * 2 + Double(gx + gy)) + 1) / 2)
                        }
                    }
                }
            }
        }

        // Banner posts along the campaign road.
        for wx in stride(from: 20, to: cols - 10, by: 36) where visible(wx) {
            if h(wx, 1, 22) < 70 { bannerPost(gx: wx) }
        }

        // Landmarks: tents, pyramid, volcano, peaks, storm crystal.
        let n1 = nodeCell(1); tents(gx: n1.x, gy: n1.y)
        let n5 = nodeCell(5); pyramid(gx: n5.x + 9, gy: n5.y + 4)
        let n8 = nodeCell(8); volcano(gx: n8.x, gy: n8.y)
        let n12 = nodeCell(12); peaks(gx: n12.x - 10, gy: n12.y + 2)
        let n13 = nodeCell(13); crystalSpire(gx: n13.x + 8, gy: n13.y - 2)

        // Castles at the strongholds (behind the node pads).
        for (id, allied) in castles {
            let n = nodeCell(id)
            if visible(n.x, 24) {
                castle(gx: n.x, gy: n.y, allied: allied, big: id == 15)
            }
        }

        // Invasion route through all 15 regions: marching ants.
        var pts: [(x: Double, y: Double)] = []
        for id in 1...15 {
            pts.append((worldX(id) * Double(pageCols), nodeY(id) * Double(rows)))
        }
        var dots: [(x: Double, y: Double)] = []
        for k in 0..<(pts.count - 1) {
            let a = pts[k], b = pts[k + 1]
            let mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2 - 5 // S-curve bow
            var prev = a
            for seg in [(mx, my), b] as [(Double, Double)] {
                let len = max(1, hypot(seg.0 - prev.0, seg.1 - prev.1))
                var d: Double = 0
                while d < len {
                    dots.append((prev.0 + (seg.0 - prev.0) * d / len,
                                 prev.1 + (seg.1 - prev.1) * d / len))
                    d += 2.2
                }
                prev = seg
            }
        }
        for (i, d) in dots.enumerated() {
            if Int(d.x) >= visX0 && Int(d.x) <= visX1 && (i + Int(t * 8)) % 9 < 5 {
                px(Int(d.x), Int(d.y), 1, 1, Color(red: 1, green: 0.9, blue: 0.6))
            }
        }

        // Mission banner pads under the SwiftUI node buttons.
        for level in CampaignData.levels {
            let n = nodeCell(level.id)
            guard visible(n.x, 6) else { continue }
            let unlocked = CampaignData.isUnlocked(level)
            let stars = CampaignData.stars(for: level.id)
            let base: Color = !unlocked ? Color(white: 0.35)
                : stars > 0 ? .blue : .green
            px(n.x - 3, n.y - 3, 7, 7, .black)
            px(n.x - 2, n.y - 2, 5, 5, base)
            if unlocked && stars == 0 && level.id == CampaignData.unlockedLevel {
                let blink = (sin(t * 5) + 1) / 2
                px(n.x - 1, n.y - 1, 3, 3, .yellow, 0.5 + 0.5 * blink)
            } else {
                px(n.x, n.y, 1, 1, .white)
            }
        }

        // Clouds + water shadows drifting east, wrap-around.
        for c in 0..<5 {
            let speed = [7, 5, 9, 6, 8][c]
            let base = [30, 200, 330, 120, 420][c]
            let cy = [14, 26, 66, 78, 10][c]
            let span = cols + 36
            let cx = (base + Int(t * Double(speed))) % span - 18
            if !visible(cx, 34) { continue }
            let wdt = [22, 30, 18, 26, 20][c]
            for ox in 0..<wdt {
                let lift = abs(ox - wdt / 2) * 2 / max(1, wdt / 6)
                px(cx + ox, cy, 1, max(1, 3 - lift), .white, 0.75)
            }
            for ox in 0..<wdt {
                px(cx + ox, cy + 3, 1, 1, Color(red: 0.03, green: 0.20, blue: 0.30), 0.45)
            }
        }
    }
}

#Preview {
    NavigationStack { LevelMapView() }
}
