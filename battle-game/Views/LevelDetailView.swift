import SwiftUI

/// LevelDetail — ports Unity's LevelSelection1 dialog + ConfigurationUI hero picker.
/// Shows mission briefing (waves / tower / base HP taken from your Unity balance:
/// tower 200, base 500, starting gold 500), hero select grid (6 imported icons),
/// then Start Battle -> GameView (gameplay stub lands in Stage 2).
struct LevelDetailView: View {
    let level: LevelDef
    @State private var selectedHero: HeroDef = HeroRoster.selectedHero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ImportedArt.image(named: level.mapArtName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.35)
                    .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.65), .black.opacity(0.35)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                HStack(spacing: 20) {
                    // Left: briefing
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LEVEL \(level.id) — \(level.name.uppercased())")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text(level.subtitle)
                            .foregroundStyle(.white.opacity(0.8))
                        briefingRow(icon: "flag.fill", text: "Enemy waves: \(level.enemyWaves)")
                        briefingRow(icon: "building.columns.fill", text: "Tower HP: \(level.towerHP) each ×2")
                        briefingRow(icon: "shield.fill", text: "Enemy base HP: \(level.baseHP)")
                        briefingRow(icon: "dollarsign.circle.fill", text: "Starting gold: 500 (your Unity value)")
                        Spacer()
                        NavigationLink {
                            GameView(level: level, hero: selectedHero)
                        } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("START BATTLE").fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .frame(width: geo.size.width * 0.34)
                    .padding(20)

                    // Right: hero picker (ConfigurationUI port)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHOOSE HERO")
                            .font(.headline)
                            .foregroundStyle(.white)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                  spacing: 12) {
                            ForEach(HeroRoster.heroes) { hero in
                                HeroCard(hero: hero, selected: hero.id == selectedHero.id)
                                    .onTapGesture {
                                        selectedHero = hero
                                        HeroRoster.selectedHeroId = hero.id
                                    }
                            }
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text(selectedHero.displayName).bold().foregroundStyle(.white)
                                Text("HP \(selectedHero.maxHealth) • Speed \(Int(selectedHero.speed))")
                                    .font(.caption).foregroundStyle(.white.opacity(0.75))
                                Text(selectedHero.blurb)
                                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                        }
                        .padding(.top, 4)
                        Spacer()
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Level \(level.id)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func briefingRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.yellow)
            Text(text).foregroundStyle(.white)
        }
        .font(.subheadline)
    }
}

private struct HeroCard: View {
    let hero: HeroDef
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ImportedArt.image(named: hero.iconArtName)
                .resizable()
                .scaledToFit()
                .frame(height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? .yellow : .white.opacity(0.3), lineWidth: selected ? 3 : 1))
            Text(hero.displayName)
                .font(.caption2.bold())
                .foregroundStyle(selected ? .yellow : .white)
        }
    }
}

#Preview {
    NavigationStack {
        LevelDetailView(level: CampaignData.levels[0])
    }
}
