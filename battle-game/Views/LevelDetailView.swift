import SpriteKit
import SwiftUI
import UIKit // UIImage pixel portraits

/// LevelDetail — mission briefing over a living pixel-art battlefield.
/// No system chrome: custom pixel BACK button, all-pixel type and icons.
/// Left: briefing + debuting hostiles + Continue. Right: field intel —
/// mission stat tiles, the hostile roster for this level and any new unit
/// that joins the army here. The actual loadout is picked on the deployment
/// screen that Continue opens.
struct LevelDetailView: View {
    let level: LevelDef
    /// Campaign path. BACK pops to the map — briefings are only ever
    /// stacked on the map, never on a finished battle.
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss
    /// Briefing diorama. Created lazily in onAppear (never in the @State
    /// initial value — SwiftUI re-evaluates that on every re-render, and a
    /// throwaway scene would fight the running battle for the layout).
    @State private var bgScene: MainMenuBattleScene?
    /// Gates the SpriteView one runloop past the push: the frost diorama's
    /// first bake (Level 21+) is main-thread CoreGraphics, and presenting
    /// it synchronously inside the navigation transition is what freezes
    /// the map tap. The static gradient underneath covers the gap.
    @State private var dioramaReady = false

    /// Enemy kinds debuting on this level (briefing intel).
    private var newEnemies: [EnemyKind] {
        EnemyKind.allCases.filter { $0.unlockLevel == level.id }
    }

    /// Every hostile type this level actually summons (not just every unit
    /// unlocked by this point in the campaign). Debuting hostiles always
    /// close the roster, so the NEW chip never sits ahead of veterans.
    private var activeEnemies: [EnemyKind] {
        let kinds = Balance.layout(for: level.id).enemyKinds
        let veterans = kinds.filter { $0.unlockLevel != level.id }
        let debuts = kinds.filter { $0.unlockLevel == level.id }
        return veterans + debuts
    }

    /// Army unit that joins the roster on this level, if any.
    private var recruit: ArmyKind? {
        ArmyKind.allCases.first { $0.unlockLevel == level.id }
    }

    private var stars: Int { CampaignData.stars(for: level.id) }

    /// The briefing column width follows the hostile roster: chip grid of
    /// six units on one row with the next unit wrapping underneath. Anything
    /// inside the panel (title, desc, new-hostile strip) spans this width.
    private func briefPanelWidth(tight: Bool) -> CGFloat {
        let chip: CGFloat = tight ? 56 : 66
        let gap: CGFloat = 6
        let sixOnOneRow = chip * 6 + gap * 5
        return sixOnOneRow + 8
    }

    var body: some View {
        // Backdrop lives OUTSIDE the GeometryReader as the root ZStack's
        // bottom layer (same as MainMenuView): sizing the SpriteView inside
        // a safe-area GeometryReader is what letterboxed it — it never
        // stretched full width. Content keeps its own GeometryReader for
        // the tight/roomy breakpoints.
        ZStack {
            backdrop

            GeometryReader { geo in
                let tight = geo.size.height < 420

                VStack(spacing: tight ? 8 : 10) {
                    header(tight: tight)
                    // Everything lives in one compact column so the rest of
                    // the screen stays clear for the level backdrop.
                    HStack(alignment: .top, spacing: 0) {
                        briefingPanel(tight: tight)
                            .frame(maxWidth: max(0, min(briefPanelWidth(tight: tight),
                                                        geo.size.width - 24)),
                                   alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, tight ? 10 : 14)
                .padding(.top, tight ? 8 : 10)
                .padding(.bottom, tight ? 8 : 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.black.ignoresSafeArea(edges: .all))
        .onAppear {
            // Backdrop must dress THIS level's battlefield, not the last one
            // played — build it once per level. Presentation waits a runloop
            // so the map → briefing push never stalls on a cold bake.
            if bgScene?.levelId != level.id {
                dioramaReady = false
                bgScene = MainMenuBattleScene(size: CGSize(width: 1334, height: 750),
                                              levelId: level.id)
                DispatchQueue.main.async { dioramaReady = true }
            } else if !dioramaReady {
                DispatchQueue.main.async { dioramaReady = true }
            }
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdrop: some View {
        // Static deep-field gradient: instant paint under the diorama so
        // the push never flashes, and full-bleed to the window edges.
        LinearGradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.09),
                                Color(red: 0.01, green: 0.01, blue: 0.03)],
                       startPoint: .top, endPoint: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .all)
        if let scene = bgScene, dioramaReady {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .all)
        }
        LinearGradient(colors: [.black.opacity(0.74), .black.opacity(0.46)],
                       startPoint: .leading, endPoint: .trailing)
            .ignoresSafeArea(edges: .all)
            .allowsHitTesting(false)
        LinearGradient(colors: [.black.opacity(0.5), .clear],
                       startPoint: .bottom, endPoint: .center)
            .ignoresSafeArea(edges: .all)
            .allowsHitTesting(false)
    }

    // MARK: - Header

    private func header(tight: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                SoundEngine.shared.uiTap()
                if !path.isEmpty {
                    path.removeLast()
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 6) {
                    DetailPixelIcon(glyph: .arrowLeft, color: .cyan, size: 11)
                    Text("BACK")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(2)
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.black.opacity(0.65))
                .clipShape(ShopPixelShape(cut: 6))
                .overlay(ShopPixelShape(cut: 6).stroke(.cyan.opacity(0.6), lineWidth: 2))
            }

            HStack(spacing: 6) {
                Rectangle().fill(.cyan).frame(width: 8, height: 8)
                Text("MISSION BRIEFING")
                    .font(.system(size: tight ? 10 : 11, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.cyan)
            }

            Spacer(minLength: 6)

            if stars > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        DetailPixelIcon(glyph: .star,
                                        color: index < stars ? .yellow : .white.opacity(0.2),
                                        size: tight ? 10 : 12)
                    }
                }
                Text("BEST")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Text("UNPLAYED")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Text("MISSION \(level.id) OF \(CampaignData.levels.count)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Left: briefing + Continue

    private func briefingPanel(tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: tight ? 5 : 8) {
            sectionLabel("MISSION BRIEFING", color: .cyan)

            Text("LVL \(level.id) — \(level.name.uppercased())")
                .font(.system(size: tight ? 17 : 20, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(level.subtitle.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(level.briefing)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(tight ? 3 : 5)
                .minimumScaleFactor(0.85)

            newHostileStrip(tight: tight)

            hostileArmy(tight: tight)

            if let recruit {
                newUnitRow(recruit, tight: tight)
            }

            Spacer(minLength: 2)

            HStack(alignment: .bottom, spacing: 8) {
                playgroundButton(tight: tight)
                    .frame(width: tight ? 132 : 150)
                continueButton(tight: tight)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func newHostileStrip(tight: Bool) -> some View {
        if let debut = newEnemies.first {
            HStack(spacing: 8) {
                Image(uiImage: UnitPixelArt.portraitImage(for: debut.pixelKind))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: tight ? 38 : 44, height: tight ? 26 : 30)
                    .background(.black.opacity(0.6))
                    .clipShape(ShopPixelShape(cut: 4))
                    .overlay(ShopPixelShape(cut: 4).stroke(.red.opacity(0.6), lineWidth: 1))

                VStack(alignment: .leading, spacing: 1) {
                    Text("NEW HOSTILE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.red)
                    Text(newEnemies.map { $0.displayName.uppercased() }
                        .joined(separator: "  ·  "))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(debut.threatBlurb)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(tight ? 1 : 2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.5))
            .clipShape(ShopPixelShape(cut: 6))
            .overlay(ShopPixelShape(cut: 6).stroke(.red.opacity(0.45), lineWidth: 1))
        } else {
            HStack(spacing: 6) {
                Rectangle().fill(.white.opacity(0.35)).frame(width: 7, height: 7)
                Text("NO NEW HOSTILES")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.4))
            .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }

    /// DEV: tosses the selected loadout hero straight into the tiny
    /// playground arena (one player tower, no enemy tower, one inspected
    /// unit per wave). The gate releases THIS briefing's debut hostile —
    /// levels with no debut fall back to the Saucer.
    /// Temporary — remove the button with snowFX dev pass done.
    private func playgroundButton(tight: Bool) -> some View {
        Button {
            SoundEngine.shared.uiTap()
            Balance.playgroundUnit = newEnemies.first ?? .saucer
            path.append(Route.game(levelId: Balance.playgroundLevelId,
                                   heroId: HeroRoster.selectedHero.id))
        } label: {
            HStack(spacing: 7) {
                DetailPixelIcon(glyph: .target, color: .cyan, size: tight ? 13 : 15)
                Text("PLAYGROUND")
                    .font(.system(size: tight ? 10 : 11, weight: .black, design: .monospaced))
                    .tracking(1)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: tight ? 44 : 50)
            .foregroundStyle(.cyan)
            .background(.black.opacity(0.75))
            .clipShape(ShopPixelShape(cut: 8))
            .overlay(ShopPixelShape(cut: 8).stroke(.cyan.opacity(0.7), lineWidth: 3))
        }
        .buttonStyle(.plain)
    }

    private func continueButton(tight: Bool) -> some View {
        Button {
            SoundEngine.shared.uiTap()
            path.append(Route.prep(levelId: level.id))
        } label: {
            HStack(spacing: 9) {
                Text("CONTINUE")
                    .font(.system(size: tight ? 14 : 16, weight: .black, design: .monospaced))
                    .tracking(2)
                DetailPixelIcon(glyph: .arrowRight, color: .white, size: tight ? 17 : 20)
            }
            .frame(maxWidth: .infinity, minHeight: tight ? 44 : 50)
            .background(.red)
            .foregroundStyle(.white)
            .clipShape(ShopPixelShape(cut: 8))
            .overlay(ShopPixelShape(cut: 8).stroke(.white.opacity(0.7), lineWidth: 3))
            .shadow(color: .red.opacity(0.45), radius: 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hostile army

    private func hostileArmy(tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                DetailPixelIcon(glyph: .target, color: .red, size: 11)
                Text("HOSTILE ARMY")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.red)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                Text("\(activeEnemies.count) TYPES")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.45))
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
            }

            ChipFlow {
                ForEach(activeEnemies, id: \.rawValue) { kind in
                    HostileChip(kind: kind, isNew: kind.unlockLevel == level.id)
                        .frame(width: tight ? 56 : 66)
                }
            }
        }
    }

    private func newUnitRow(_ recruit: ArmyKind, tight: Bool) -> some View {
        HStack(spacing: 6) {
            Image(uiImage: UnitPixelArt.portraitImage(for: recruit.pixelKind))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: tight ? 28 : 34, height: tight ? 19 : 23)
                .background(.black.opacity(0.5))
                .clipShape(ShopPixelShape(cut: 3))
                .overlay(ShopPixelShape(cut: 3).stroke(.yellow.opacity(0.7), lineWidth: 1))
                .shadow(color: .yellow.opacity(0.3), radius: 4)

            Text("NEW UNIT")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.yellow)
            Text(recruit.name.uppercased())
                .font(.system(size: tight ? 9 : 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("JOINS YOUR ARMY")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
    }

    // MARK: - Shared bits

    private func sectionLabel(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(color)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
        }
    }

}

// MARK: - Wrapping chips row

private struct ChipFlow: Layout {
    private static let gap: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                totalHeight += rowHeight + Self.gap
                rowHeight = 0
            }
            x += size.width + Self.gap
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - Self.gap)
        }
        return CGSize(width: totalWidth, height: totalHeight + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if index > 0, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + Self.gap
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: .unspecified)
            x += size.width + Self.gap
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Hostile roster chip

private struct HostileChip: View {    let kind: EnemyKind
    let isNew: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                // Enemy art is authored facing +x; battle hostiles march
                // left, so mirror the preview to match.
                Image(uiImage: UnitPixelArt.portraitImage(for: kind.pixelKind))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(x: -1, y: 1)
                    .padding(2)
                    .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 38)
                    .background(.black.opacity(0.55))
                    .clipShape(ShopPixelShape(cut: 4))
                    .overlay(ShopPixelShape(cut: 4).stroke(isNew ? .red : .white.opacity(0.15),
                                                           lineWidth: isNew ? 1.5 : 1))
                if isNew {
                    Text("NEW")
                        .font(.system(size: 6, weight: .black, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(.red)
                        .offset(x: 3, y: -3)
                }
            }
            Text(kind.displayName.uppercased())
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(isNew ? .red : .white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Pixel icons

private enum DetailPixelGlyph {
    case arrowLeft, arrowRight, target, star

    var rows: [String] {
        switch self {
        case .arrowLeft:
            return [
                "........",
                "...##...",
                "..###...",
                ".#######",
                ".#######",
                "..###...",
                "...##...",
                "........"
            ]
        case .arrowRight:
            return [
                "........",
                "...##...",
                "...###..",
                "#######.",
                "#######.",
                "...###..",
                "...##...",
                "........"
            ]
        case .target:
            return [
                "...##...",
                "...##...",
                ".#....#.",
                "#..##..#",
                "#..##..#",
                ".#....#.",
                "...##...",
                "...##..."
            ]
        case .star:
            return [
                "...##...",
                "...##...",
                "########",
                ".######.",
                "..####..",
                ".##..##.",
                "##....##",
                "........"
            ]
        }
    }
}

private struct DetailPixelIcon: View {
    let glyph: DetailPixelGlyph
    let color: Color
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let rows = glyph.rows
            guard let columns = rows.first?.count, columns > 0, !rows.isEmpty else { return }
            let cell = min(canvasSize.width / CGFloat(columns),
                           canvasSize.height / CGFloat(rows.count))
            let originX = (canvasSize.width - cell * CGFloat(columns)) / 2
            let originY = (canvasSize.height - cell * CGFloat(rows.count)) / 2
            for (rowIndex, row) in rows.enumerated() {
                for (columnIndex, character) in row.enumerated() where character == "#" {
                    let rect = CGRect(
                        x: originX + CGFloat(columnIndex) * cell,
                        y: originY + CGFloat(rowIndex) * cell,
                        width: cell,
                        height: cell
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        LevelDetailView(level: CampaignData.levels[8], path: .constant(NavigationPath()))
    }
}
