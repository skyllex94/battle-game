import SwiftUI
import UIKit // UIImage enemy portraits

/// EnemyLibrary — a standalone field dossier. Every hostile that can march
/// on Emra is catalogued here with its pixel portrait, role, debut level,
/// threat read and baseline combat stats. Reached from BattlePrep.
struct EnemyLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    private var encountered: Int {
        EnemyKind.allCases.filter { $0.unlockLevel <= CampaignData.unlockedLevel }.count
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 700
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10),
                                count: wide ? 3 : 2)
            ZStack {
                EnemyLibraryBackdrop()

                VStack(spacing: 10) {
                    topBar
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(EnemyKind.allCases, id: \.rawValue) { kind in
                                EnemyDossierCard(kind: kind)
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
                Rectangle().fill(.red).frame(width: 8, height: 8)
                Text("ENEMY LIBRARY")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.red)
            }
            Text("FIELD DOSSIERS // \(EnemyKind.allCases.count) HOSTILES")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            HStack(spacing: 6) {
                Rectangle().fill(.green).frame(width: 7, height: 7)
                Text("\(encountered)/\(EnemyKind.allCases.count) ENCOUNTERED")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Rectangle().fill(.red.opacity(0.7)).frame(width: 6, height: 6)
            Text("DEBUT LVL = FIRST CAMPAIGN MISSION THIS UNIT MARCHES. STATS SHOWN AT BASELINE.")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Dossier card

private struct EnemyDossierCard: View {
    let kind: EnemyKind

    private var seen: Bool { kind.unlockLevel <= CampaignData.unlockedLevel }

    var body: some View {
        HStack(spacing: 10) {
            portrait
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.displayName.uppercased())
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(kind.threatBlurb)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 5) {
                    miniStat("HP", Int(kind.baseHP.rounded()))
                    miniStat("SPD", Int(kind.moveSpeed.rounded()))
                    miniStat("DMG", Int(kind.attackDamage.rounded()))
                }
                HStack(spacing: 5) {
                    Rectangle()
                        .fill(seen ? Color.green : Color.yellow)
                        .frame(width: 5, height: 5)
                    Text(seen ? "ENCOUNTERED" : "DEBUTS LVL \(kind.unlockLevel)")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(seen ? .green : .yellow)
                }
            }
        }
        .padding(8)
        .background(
            LinearGradient(colors: [Color(red: 0.10, green: 0.09, blue: 0.12),
                                    Color.black.opacity(0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(ShopPixelShape(cut: 8))
        .overlay(ShopPixelShape(cut: 8).stroke(.red.opacity(seen ? 0.45 : 0.2),
                                              lineWidth: 2))
    }

    private var portrait: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.red.opacity(0.16), .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
            // Enemy art is authored facing +x; the battle mirrors every
            // hostile to march left toward the player. Flip the dossier
            // portrait the same way so it matches the unit coming at you.
            Image(uiImage: UnitPixelArt.portraitImage(for: kind.pixelKind))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(x: -1, y: 1)
                .frame(width: 92, height: 64)
                .padding(4)
            Text("LVL \(kind.unlockLevel)")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.black)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(seen ? Color.green : Color.yellow)
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

private struct EnemyLibraryBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.05, blue: 0.08),
                                    Color(red: 0.10, green: 0.04, blue: 0.05),
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
                    // Slow radar scan band.
                    let scanY = (t * 26).truncatingRemainder(dividingBy: Double(size.height + 120)) - 60
                    let band = CGRect(x: 0, y: scanY, width: size.width, height: 46)
                    ctx.fill(Path(band), with: .color(.red.opacity(0.06)))
                    ctx.fill(Path(CGRect(x: 0, y: scanY + 45, width: size.width, height: 1)),
                             with: .color(.red.opacity(0.22)))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            // Soft red vignette bias.
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
        EnemyLibraryView()
    }
}
