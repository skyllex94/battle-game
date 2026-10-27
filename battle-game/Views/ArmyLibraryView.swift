import SwiftUI
import UIKit // UIImage army portraits

/// ArmyLibrary — the player's deployable-unit dossier. Every summonable
/// unit is catalogued with its pixel portrait, role, unlock level, gold
/// cost, recharge time and baseline combat stats. Reached from BattlePrep.
struct ArmyLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    private var available: Int {
        ArmyKind.allCases.filter { CampaignData.unlockedLevel >= $0.unlockLevel }.count
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 700
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10),
                                count: wide ? 2 : 1)
            ZStack {
                ArmyLibraryBackdrop()

                VStack(spacing: 10) {
                    topBar
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(ArmyKind.allCases) { kind in
                                ArmyDossierCard(kind: kind)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    footer
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                SoundEngine.shared.uiTap()
                dismiss()
            } label: {
                Text("BACK")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.7))
                    .clipShape(ShopPixelShape(cut: 6))
                    .overlay(ShopPixelShape(cut: 6).stroke(.cyan.opacity(0.6), lineWidth: 2))
            }
            HStack(spacing: 6) {
                Rectangle().fill(.cyan).frame(width: 8, height: 8)
                Text("ARMY LIBRARY")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.cyan)
            }
            Text("OUR DEPLOYABLE UNITS // \(ArmyKind.allCases.count) TYPES")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            HStack(spacing: 6) {
                Rectangle().fill(.green).frame(width: 7, height: 7)
                Text("\(available)/\(ArmyKind.allCases.count) AVAILABLE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Rectangle().fill(.cyan.opacity(0.7)).frame(width: 6, height: 6)
            Text("SUMMON UNITS MID-BATTLE WITH WAR GOLD. EACH TYPE HAS ITS OWN RECHARGE.")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Dossier card

private struct ArmyDossierCard: View {
    let kind: ArmyKind

    private var ready: Bool { CampaignData.unlockedLevel >= kind.unlockLevel }

    var body: some View {
        HStack(spacing: 10) {
            portrait
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.name.uppercased())
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(kind.blurb)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 5) {
                    miniStat("HP", Int(kind.hp.rounded()))
                    miniStat("SPD", Int(kind.speed.rounded()))
                    miniStat("DMG", Int(kind.damage.rounded()))
                }
                HStack(spacing: 6) {
                    Text("COST \(kind.cost)G")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.yellow)
                    Text("CD \(Int(kind.cooldown))s")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.cyan)
                    Spacer(minLength: 2)
                    Rectangle()
                        .fill(ready ? Color.green : Color.yellow)
                        .frame(width: 5, height: 5)
                    Text(ready ? "READY" : "UNLOCKS LVL \(kind.unlockLevel)")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(ready ? .green : .yellow)
                }
            }
        }
        .padding(8)
        .background(
            LinearGradient(colors: [Color(red: 0.07, green: 0.10, blue: 0.13),
                                    Color.black.opacity(0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(ShopPixelShape(cut: 8))
        .overlay(ShopPixelShape(cut: 8).stroke(.cyan.opacity(ready ? 0.45 : 0.2),
                                              lineWidth: 2))
    }

    private var portrait: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.cyan.opacity(0.16), .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
            Image(uiImage: UnitPixelArt.portraitImage(for: kind.pixelKind))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 92, height: 64)
                .padding(4)
            Text("LVL \(kind.unlockLevel)")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.black)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(ready ? Color.green : Color.yellow)
                .padding(3)
        }
        .frame(width: 100, height: 72)
        .clipShape(ShopPixelShape(cut: 6))
        .overlay(ShopPixelShape(cut: 6).stroke(.white.opacity(0.16), lineWidth: 1))
    }

    private func miniStat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .background(.black.opacity(0.55))
        .overlay(Rectangle().stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Backdrop

private struct ArmyLibraryBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.09),
                                    Color(red: 0.03, green: 0.10, blue: 0.13),
                                    Color.black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.animation(minimumInterval: 1 / 10)) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    // Pixel grid.
                    let step: CGFloat = 34
                    var x: CGFloat = 0
                    while x < size.width {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                                 with: .color(.white.opacity(0.035)))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y < size.height {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                 with: .color(.white.opacity(0.035)))
                        y += step
                    }
                    // Slow cyan scan band.
                    let scanY = (t * 22).truncatingRemainder(dividingBy: Double(size.height + 120)) - 60
                    let band = CGRect(x: 0, y: scanY, width: size.width, height: 46)
                    ctx.fill(Path(band), with: .color(.cyan.opacity(0.05)))
                    ctx.fill(Path(CGRect(x: 0, y: scanY + 45, width: size.width, height: 1)),
                             with: .color(.cyan.opacity(0.2)))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            RadialGradient(colors: [.clear, .black.opacity(0.55)],
                           center: .center, startRadius: 120, endRadius: 620)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        ArmyLibraryView()
    }
}
