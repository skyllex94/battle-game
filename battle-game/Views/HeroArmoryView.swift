import SwiftUI

/// HeroArmory — full hero selection shop. Opened from the level screen's
/// CHANGE HERO button. Tap an unlocked hero to select it (persists
/// immediately); locked heroes show their unlock level and shake on tap.
struct HeroArmoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedId: String = HeroRoster.selectedHeroId
    @State private var deniedId: String?

    private var unlockedCount: Int { HeroRoster.unlockedHeroes.count }
    private var selectedHero: HeroDef {
        HeroRoster.heroes.first(where: { $0.id == selectedId }) ?? HeroRoster.selectedHero
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.10)
                    .ignoresSafeArea()
                // Faint animated ember drift so the shop feels alive.
                TimelineView(.animation(minimumInterval: 1 / 8)) { tl in
                    Canvas { ctx, size in
                        ArmoryEmbers.draw(ctx: &ctx, size: size,
                                          t: tl.date.timeIntervalSinceReferenceDate)
                    }
                }
                .ignoresSafeArea()
                .opacity(0.6)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("HERO ARMORY")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .tracking(3)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(unlockedCount)/\(HeroRoster.heroes.count) UNLOCKED")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(.cyan)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.black.opacity(0.55))
                                .overlay(Rectangle().stroke(.cyan.opacity(0.5), lineWidth: 1))
                            Button {
                                SoundEngine.shared.uiTap()
                                dismiss()
                            } label: {
                                Text("DONE")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .tracking(2)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(.yellow)
                                    .clipShape(ShopPixelShape(cut: 5))
                                    .overlay(ShopPixelShape(cut: 5).stroke(.white.opacity(0.6), lineWidth: 2))
                            }
                        }
                        HStack(spacing: 6) {
                            Rectangle().fill(.cyan.opacity(0.6)).frame(width: 40, height: 2)
                            Rectangle().fill(.cyan).frame(width: 8, height: 8)
                            Rectangle().fill(.cyan.opacity(0.6)).frame(width: 40, height: 2)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                                  spacing: 14) {
                            ForEach(HeroRoster.heroes) { hero in
                                HeroShopCard(hero: hero,
                                             selected: hero.id == selectedId,
                                             denied: deniedId == hero.id)
                                    .onTapGesture {
                                        if HeroRoster.isUnlocked(hero) {
                                            SoundEngine.shared.uiTap()
                                            selectedId = hero.id
                                            HeroRoster.selectedHeroId = hero.id
                                        } else {
                                            deniedId = hero.id
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                                if deniedId == hero.id { deniedId = nil }
                                            }
                                        }
                                    }
                            }
                        }
                        // Selected-hero readout.
                        HStack(spacing: 12) {
                            ImportedArt.image(named: selectedHero.iconArtName)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .clipShape(ShopPixelShape(cut: 4))
                                .overlay(ShopPixelShape(cut: 4).stroke(.yellow, lineWidth: 2))
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(selectedHero.displayName.uppercased())
                                        .font(.system(size: 15, weight: .black, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(.yellow)
                                    Text("ACTIVE")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(.yellow)
                                }
                                StatPips(label: "HP", value: selectedHero.maxHealth, maxValue: 200, color: .green)
                                StatPips(label: "SPD", value: Int(selectedHero.speed), maxValue: 12, color: .cyan)
                                Text(selectedHero.blurb)
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(.black.opacity(0.55))
                        .clipShape(ShopPixelShape(cut: 8))
                        .overlay(ShopPixelShape(cut: 8).stroke(.yellow.opacity(0.5), lineWidth: 2))
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Armory")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

/// Drifting embers behind the armory grid (cheap Canvas spark field).
private enum ArmoryEmbers {
    static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for i in 0..<40 {
            let x = Double((i * 137 + Int(t * 24)) % Int(max(1, Int(size.width) + 40))) - 20
            let y = size.height - Double((i * 211 + Int(t * 60)) % Int(max(1, Int(size.height) + 40))) + 20
            let a = 0.25 + 0.35 * (sin(t * 2 + Double(i)) + 1) / 2
            ctx.fill(Path(CGRect(x: x, y: y, width: 3, height: 3)),
                     with: .color((i % 3 == 0 ? Color.cyan : Color.orange).opacity(a)))
        }
    }
}

/// Pixel shop card: portrait, name plate, HP/SPD pips. Locked cards wear a
/// dark veil + lock + unlock-level tag; the selected card glows yellow.
struct HeroShopCard: View {
    let hero: HeroDef
    let selected: Bool
    let denied: Bool

    private var locked: Bool { !HeroRoster.isUnlocked(hero) }
    private let shape = ShopPixelShape(cut: 6)

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                ImportedArt.image(named: hero.iconArtName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(height: 64)
                    .saturation(locked ? 0 : 1)
                    .opacity(locked ? 0.45 : 1)
                if locked {
                    Color.black.opacity(0.45)
                    VStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("LVL \(hero.unlockLevel)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.cyan)
                    }
                }
                if selected {
                    VStack {
                        Spacer()
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.yellow)
                    }
                    .padding(.bottom, 4)
                }
            }
            .frame(height: 76)
            .background(.black.opacity(0.6))
            .clipShape(shape)
            .overlay(shape.stroke(selected ? .yellow : .white.opacity(locked ? 0.15 : 0.35),
                                  lineWidth: selected ? 3 : 1))
            .shadow(color: selected ? .yellow.opacity(0.5) : .clear, radius: 8)
            .offset(x: denied ? -6 : 0)
            .animation(denied ? .easeInOut(duration: 0.06).repeatCount(3, autoreverses: true)
                              : .default,
                       value: denied)
            Text(hero.displayName.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(selected ? .yellow : locked ? .white.opacity(0.45) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            StatPips(label: "HP", value: hero.maxHealth, maxValue: 200, color: .green, compact: true)
            StatPips(label: "SPD", value: Int(hero.speed), maxValue: 12, color: .cyan, compact: true)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Pixel stat pips: label + N/6 blocks (e.g. HP 140/200 → 4 lit).
struct StatPips: View {
    let label: String
    let value: Int
    let maxValue: Int
    let color: Color
    var compact: Bool = false

    private var lit: Int {
        min(6, Swift.max(0, Int(round(Double(value) / Double(maxValue) * 6))))
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: compact ? 8 : 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: compact ? 22 : 26, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(i < lit ? color : .white.opacity(0.15))
                        .frame(width: compact ? 7 : 9, height: compact ? 6 : 7)
                }
            }
            Text("\(value)")
                .font(.system(size: compact ? 8 : 9, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

/// Chamfered pixel panel shape (hard corners, no smooth rounds).
struct ShopPixelShape: Shape {
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

#Preview {
    NavigationStack {
        HeroArmoryView()
    }
}
