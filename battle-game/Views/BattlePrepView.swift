import SpriteKit
import SwiftUI
import UIKit // UIImage portraits

/// BattlePrep — the deployment screen between a mission briefing and the
/// battle. Three columns keep the decision order obvious:
///   1. MISSION BRIEF  — where you are and what is waiting.
///   2. LOADOUT        — hero over gun, each swappable in place.
///   3. FIELD INTEL    — hostile + army dossiers.
/// A bottom action bar confirms the loadout and launches the fight.
struct BattlePrepView: View {
    let level: LevelDef
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHero: HeroDef = HeroRoster.selectedHero
    @State private var selectedGun: HeroWeapon = GunLocker.selectedGun
    /// Level-correct diorama, built lazily on appear (never in the @State
    /// initial value — SwiftUI re-evaluates that on every re-render).
    @State private var bgScene: MainMenuBattleScene?

    /// Enemies debuting on this level.
    private var newEnemies: [EnemyKind] {
        EnemyKind.allCases.filter { $0.unlockLevel == level.id }
    }

    var body: some View {
        // Backdrop lives OUTSIDE the GeometryReader as the root ZStack's
        // bottom layer (same as MainMenuView): sizing the SpriteView inside
        // a safe-area GeometryReader is what letterboxed it — it never
        // stretched full width. Content keeps its own GeometryReader for
        // the tight/roomy breakpoints.
        ZStack {
            // Living battlefield for THIS level, edge-to-edge.
            if let scene = bgScene {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .all)
            }
            LinearGradient(colors: [.black.opacity(0.80), .black.opacity(0.28)],
                           startPoint: .leading, endPoint: .trailing)
                .ignoresSafeArea(edges: .all)
                .allowsHitTesting(false)
            LinearGradient(colors: [.black.opacity(0.45), .clear],
                           startPoint: .bottom, endPoint: .center)
                .ignoresSafeArea(edges: .all)
                .allowsHitTesting(false)

            GeometryReader { geo in
                let tight = geo.size.height < 420
                VStack(spacing: tight ? 6 : 9) {
                    topBar(tight: tight)
                    // Left: mission brief + launch. Right: hero/weapon over
                    // army/enemies. START BATTLE lives on the left rail.
                    HStack(alignment: .top, spacing: 10) {
                        leftColumn(tight: tight)
                            .frame(width: geo.size.width * 0.34)
                        rightDeck(tight: tight)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .padding(.top, 8)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Armories persist their picks; re-read them on every return.
            selectedHero = HeroRoster.selectedHero
            selectedGun = GunLocker.selectedGun
            if bgScene?.levelId != level.id {
                bgScene = MainMenuBattleScene(size: CGSize(width: 1334, height: 750),
                                              levelId: level.id)
            }
            // Pre-warm armory art off the transition path: once the prep
            // screen has settled, build every hero portrait + gun icon so
            // the first opens of the hero/weapon bays have zero generation
            // cost mid-push.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                for hero in HeroRoster.heroes {
                    _ = HeroPixelArt.portraitImage(for: hero.pixelKind)
                }
                for gun in HeroWeapon.allCases {
                    _ = PixelHeroArt.gunImage(gun)
                }
            }
        }
    }

    // MARK: - Header

    private func topBar(tight: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                SoundEngine.shared.uiTap()
                if !path.isEmpty { path.removeLast() } else { dismiss() }
            } label: {
                Text("BACK")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.black.opacity(0.65))
                    .clipShape(ShopPixelShape(cut: 6))
                    .overlay(ShopPixelShape(cut: 6).stroke(.cyan.opacity(0.6), lineWidth: 2))
            }
            HStack(spacing: 6) {
                Rectangle().fill(.yellow).frame(width: 8, height: 8)
                Text("DEPLOYMENT")
                    .font(.system(size: tight ? 10 : 11, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.yellow)
            }
            Text("LVL \(level.id) — \(level.name.uppercased())")
                .font(.system(size: tight ? 12 : 14, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer()
            Text("MISSION \(level.id) OF \(CampaignData.levels.count)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Column 1: mission brief

    private func missionPanel(tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: tight ? 6 : 8) {
            label("MISSION BRIEF", color: .cyan)
            Text(level.name.uppercased())
                .font(.system(size: 19, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

            HStack(spacing: 6) {
                missionStat("WAVES", "\(level.enemyWaves)")
                missionStat("TOWER", "\(Int(Balance.enemyTowerHealth(forLevel: level.id).rounded()))")
                missionStat("HQ", "\(Int(Balance.enemyBaseHealth(forLevel: level.id).rounded()))")
            }

            if let debut = newEnemies.first {
                HStack(spacing: 7) {
                    // Hostiles face left in battle, so the preview does too.
                    Image(uiImage: UnitPixelArt.portraitImage(for: debut.pixelKind))
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(x: -1, y: 1)
                        .frame(width: 42, height: 28)
                        .background(.black.opacity(0.6))
                        .clipShape(ShopPixelShape(cut: 4))
                        .overlay(ShopPixelShape(cut: 4).stroke(.red.opacity(0.6), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("NEW HOSTILE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.red)
                        Text(debut.displayName.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.5))
                .overlay(Rectangle().stroke(.red.opacity(0.4), lineWidth: 1))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.black.opacity(0.55))
        .clipShape(ShopPixelShape(cut: 10))
        .overlay(ShopPixelShape(cut: 10).stroke(.white.opacity(0.2), lineWidth: 2))
    }

    private func label(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(color)
        }
    }

    private func missionStat(_ name: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text(name)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55))
        .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Left rail: mission brief → deployment → launch

    private func leftColumn(tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: tight ? 6 : 8) {
            missionPanel(tight: tight)
                .frame(maxHeight: .infinity)
            deploySummary(tight: tight)
            startButton(tight: tight)
        }
    }

    // MARK: - Right deck: hero | weapon, army | enemies underneath

    private func rightDeck(tight: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                NavigationLink {
                    HeroArmoryView()
                } label: {
                    PrepHeroCard(hero: selectedHero, tight: tight)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { SoundEngine.shared.uiTap() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                NavigationLink {
                    GunArmoryView()
                } label: {
                    PrepGunCard(gun: selectedGun, tight: tight)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { SoundEngine.shared.uiTap() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 8) {
                PrepIntelCard(content: .army)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                PrepIntelCard(content: .enemies)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Deploy summary

    private func deploySummary(tight: Bool) -> some View {
        HStack(spacing: 8) {
            Image(uiImage: HeroPixelArt.portraitImage(for: selectedHero.pixelKind))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 24)
                .background(.black.opacity(0.5))
                .clipShape(ShopPixelShape(cut: 4))
            VStack(alignment: .leading, spacing: 1) {
                Text("DEPLOYING")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 4) {
                    Text(selectedHero.displayName.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("/")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(selectedGun.name.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            if !tight {
                Rectangle().fill(.green).frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.62))
        .clipShape(ShopPixelShape(cut: 6))
        .overlay(ShopPixelShape(cut: 6).stroke(.white.opacity(0.18), lineWidth: 2))
    }

    // MARK: - Launch (left rail)

    private func startButton(tight: Bool) -> some View {
        Button {
            SoundEngine.shared.uiTap()
            path.append(Route.game(levelId: level.id, heroId: selectedHero.id))
        } label: {
            HStack(spacing: 9) {
                PrepPixelIcon(glyph: .shield, color: .white, size: tight ? 19 : 23)
                Text("START BATTLE")
                    .font(.system(size: tight ? 13 : 15, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: tight ? 42 : 50)
            .background(.red)
            .foregroundStyle(.white)
            .clipShape(ShopPixelShape(cut: 8))
            .overlay(ShopPixelShape(cut: 8).stroke(.white.opacity(0.7), lineWidth: 3))
            .shadow(color: .red.opacity(0.45), radius: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero card

private struct PrepHeroCard: View {
    let hero: HeroDef
    let tight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: tight ? 4 : 6) {
            HStack(spacing: 6) {
                PrepSectionLabel(title: "HERO", color: .yellow)
                Spacer(minLength: 4)
                PrepChangeChip(color: .yellow)
            }

            HStack(spacing: 10) {
                Image(uiImage: HeroPixelArt.portraitImage(for: hero.pixelKind))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(7)
                    .frame(width: tight ? 76 : 90)
                    .frame(maxHeight: .infinity)
                    .background(
                        LinearGradient(colors: [.yellow.opacity(0.16), .black.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(ShopPixelShape(cut: 6))
                    .overlay(ShopPixelShape(cut: 6).stroke(.yellow.opacity(0.5), lineWidth: 2))

                VStack(alignment: .leading, spacing: 3) {
                    Text(hero.displayName.uppercased())
                        .font(.system(size: tight ? 14 : 15, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(hero.trait)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    StatPips(label: "HP", value: hero.maxHealth, maxValue: 220,
                             color: .green, compact: true)
                    StatPips(label: "SPD", value: Int(hero.speed), maxValue: 20,
                             color: .cyan, compact: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(9)
        .background(.black.opacity(0.55))
        .clipShape(ShopPixelShape(cut: 10))
        .overlay(ShopPixelShape(cut: 10).stroke(.yellow.opacity(0.35), lineWidth: 2))
    }
}

// MARK: - Gun card

private struct PrepGunCard: View {
    let gun: HeroWeapon
    let tight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: tight ? 4 : 6) {
            HStack(spacing: 6) {
                PrepSectionLabel(title: "WEAPON", color: .cyan)
                Spacer(minLength: 4)
                PrepChangeChip(color: .cyan)
            }

            HStack(spacing: 10) {
                Image(uiImage: PixelHeroArt.gunImage(gun))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(7)
                    .frame(width: tight ? 76 : 90)
                    .frame(maxHeight: .infinity)
                    .background(
                        LinearGradient(colors: [.cyan.opacity(0.16), .black.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(ShopPixelShape(cut: 6))
                    .overlay(ShopPixelShape(cut: 6).stroke(.cyan.opacity(0.5), lineWidth: 2))

                VStack(alignment: .leading, spacing: 3) {
                    Text(gun.name.uppercased())
                        .font(.system(size: tight ? 14 : 15, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(gun.magSize) / MAG · ∞")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    StatPips(label: "DMG", value: Int(gun.damage), maxValue: 60,
                             color: .red, compact: true)
                    StatPips(label: "AMMO", value: min(max(1, Int((Double(gun.magSize) / 50.0 * 12).rounded())), 12),
                             maxValue: 12, color: .cyan, compact: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(9)
        .background(.black.opacity(0.55))
        .clipShape(ShopPixelShape(cut: 10))
        .overlay(ShopPixelShape(cut: 10).stroke(.cyan.opacity(0.35), lineWidth: 2))
    }
}

// MARK: - Field intel card

private struct PrepIntelCard: View {
    enum Content { case enemies, army }

    let content: Content

    private var title: String {
        switch content {
        case .enemies: return "ENEMIES"
        case .army: return "OUR ARMY"
        }
    }

    private var subtitle: String {
        switch content {
        case .enemies: return "HOSTILE DOSSIERS"
        case .army: return "DEPLOYABLE UNITS"
        }
    }

    private var tint: Color {
        switch content {
        case .enemies: return .red
        case .army: return .cyan
        }
    }

    private var glyph: PrepPixelGlyph {
        switch content {
        case .enemies: return .target
        case .army: return .squad
        }
    }

    private var kinds: [(UnitPixelArt.Kind, Bool)] {
        switch content {
        case .enemies:
            return EnemyKind.allCases.map { ($0.pixelKind, true) }
        case .army:
            return ArmyKind.allCases.map { ($0.pixelKind, false) }
        }
    }

    private var count: Int { kinds.count }

    /// Compact square-box columns that wrap onto the next line when the
    /// roster outgrows the row.
    private var boxColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 34), spacing: 4)]
    }

    var body: some View {
        NavigationLink {
            switch content {
            case .enemies: EnemyLibraryView()
            case .army: ArmyLibraryView()
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    PrepPixelIcon(glyph: glyph, color: tint, size: 13)
                    Text(title)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(1)
                    Spacer(minLength: 2)
                    Text("\(count)")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                    Rectangle().fill(tint).frame(width: 7, height: 7)
                }
                .foregroundStyle(tint)

                Text(subtitle)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.55))

                LazyVGrid(columns: boxColumns, spacing: 4) {
                    ForEach(0..<count, id: \.self) { i in
                        // Enemy art is authored facing +x; battle hostiles
                        // march left, so mirror their previews to match.
                        Image(uiImage: UnitPixelArt.portraitImage(for: kinds[i].0))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(x: kinds[i].1 ? -1 : 1, y: 1)
                            .padding(3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(.black.opacity(0.55))
                            .clipShape(ShopPixelShape(cut: 4))
                            .overlay(ShopPixelShape(cut: 4).stroke(tint.opacity(0.5), lineWidth: 1.5))
                    }
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.black.opacity(0.55))
            .clipShape(ShopPixelShape(cut: 10))
            .overlay(ShopPixelShape(cut: 10).stroke(tint.opacity(0.45), lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            SoundEngine.shared.uiTap()
        })
    }
}

// MARK: - Shared bits

private struct PrepSectionLabel: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(color)
        }
    }
}

/// Small in-place swap affordance inside the hero / weapon headers.
private struct PrepChangeChip: View {
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            PrepPixelIcon(glyph: .doubleChevron, color: color, size: 11)
            Text("CHANGE")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.7))
        .clipShape(ShopPixelShape(cut: 5))
        .overlay(ShopPixelShape(cut: 5).stroke(color.opacity(0.7), lineWidth: 1.5))
        .contentShape(Rectangle())
    }
}

// MARK: - Pixel icons

private enum PrepPixelGlyph {
    case shield, target, squad, doubleChevron

    var rows: [String] {
        switch self {
        case .shield:
            return [
                ".######.",
                "###..###",
                "###..###",
                "#......#",
                "###..###",
                ".######.",
                "..####..",
                "...##..."
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
        case .squad:
            return [
                "..####..",
                ".######.",
                "########",
                "########",
                "##....##",
                "##....##",
                "..#..#..",
                "..#..#.."
            ]
        case .doubleChevron:
            return [
                "........",
                "..#..#..",
                ".##..##.",
                "##...##.",
                ".##..##.",
                "..#..#..",
                "........",
                "........"
            ]
        }
    }
}

private struct PrepPixelIcon: View {
    let glyph: PrepPixelGlyph
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
        BattlePrepView(level: CampaignData.levels[8], path: .constant(NavigationPath()))
    }
}
