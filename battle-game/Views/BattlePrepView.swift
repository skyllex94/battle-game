import SpriteKit
import SwiftUI
import UIKit // UIImage portraits

/// BattlePrep — the deployment screen between a mission briefing and the
/// battle. Shows the level's live battlefield, the equipped hero + gun
/// (both swappable in place), a direct line into the enemy library, and the
/// final START BATTLE button that launches the fight.
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
        GeometryReader { geo in
            let tight = geo.size.height < 420
            ZStack {
                // Living battlefield for THIS level.
                if let scene = bgScene {
                    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(edges: .all)
                }
                LinearGradient(colors: [.black.opacity(0.78), .black.opacity(0.30)],
                               startPoint: .leading, endPoint: .trailing)
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)
                LinearGradient(colors: [.black.opacity(0.45), .clear],
                               startPoint: .bottom, endPoint: .center)
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)

                VStack(spacing: tight ? 6 : 10) {
                    topBar(tight: tight)
                    HStack(alignment: .top, spacing: 12) {
                        missionPanel(tight: tight)
                            .frame(width: geo.size.width * 0.31)
                        PrepHeroPanel(hero: selectedHero, tight: tight)
                        PrepGunPanel(gun: selectedGun, tight: tight)
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .padding(.top, 10)
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
                    .padding(.horizontal, 14).padding(.vertical, 8)
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
            HStack(spacing: 6) {
                Rectangle().fill(.green).frame(width: 7, height: 7)
                Text("LOADOUT READY")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Mission panel

    private func missionPanel(tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: tight ? 6 : 8) {
            label("MISSION", color: .cyan)
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
                .lineLimit(tight ? 3 : 4)
                .minimumScaleFactor(0.85)

            HStack(spacing: 6) {
                missionStat("WAVES", "\(level.enemyWaves)")
                missionStat("TOWER", "\(level.towerHP)")
                missionStat("HQ", "\(level.baseHP)")
            }

            if let debut = newEnemies.first {
                HStack(spacing: 7) {
                    Image(uiImage: UnitPixelArt.portraitImage(for: debut.pixelKind))
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
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

            Spacer(minLength: 2)

            // Both field dossiers live here: hostile intel + our own army.
            HStack(spacing: 8) {
                NavigationLink {
                    EnemyLibraryView()
                } label: {
                    PrepLibraryButton(title: "ENEMIES",
                                      subtitle: "\(EnemyKind.allCases.count) HOSTILES",
                                      icon: "binoculars.fill",
                                      tint: .red)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    SoundEngine.shared.uiTap()
                })
                NavigationLink {
                    ArmyLibraryView()
                } label: {
                    PrepLibraryButton(title: "OUR ARMY",
                                      subtitle: "\(ArmyKind.allCases.count) UNITS",
                                      icon: "person.3.fill",
                                      tint: .cyan)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    SoundEngine.shared.uiTap()
                })
            }

            Button {
                SoundEngine.shared.uiTap()
                path.append(Route.game(levelId: level.id, heroId: selectedHero.id))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15, weight: .black))
                    Text("START BATTLE")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(2)
                }
                .frame(maxWidth: .infinity, minHeight: tight ? 44 : 50)
                .background(.red)
                .foregroundStyle(.white)
                .clipShape(ShopPixelShape(cut: 8))
                .overlay(ShopPixelShape(cut: 8).stroke(.white.opacity(0.7), lineWidth: 3))
                .shadow(color: .red.opacity(0.45), radius: 10)
            }
        }
        .padding(12)
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
}

// MARK: - Hero panel

private struct PrepHeroPanel: View {
    let hero: HeroDef
    let tight: Bool

    var body: some View {
        VStack(spacing: tight ? 6 : 9) {
            header("YOUR HERO", color: .yellow)
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: HeroPixelArt.portraitImage(for: hero.pixelKind))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)
                    .background(
                        LinearGradient(colors: [.yellow.opacity(0.14), .black.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(ShopPixelShape(cut: 8))
                    .overlay(ShopPixelShape(cut: 8).stroke(.yellow.opacity(0.6), lineWidth: 2))
                PrepChangeBadge(color: .yellow)
                    .padding(8)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 2) {
                Text(hero.displayName.uppercased())
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white)
                Text(hero.trait)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.yellow)
            }
            StatPips(label: "HP", value: hero.maxHealth, maxValue: 220, color: .green,
                     compact: tight)
            StatPips(label: "SPD", value: Int(hero.speed), maxValue: 20, color: .cyan,
                     compact: tight)

            NavigationLink {
                HeroArmoryView()
            } label: {
                PrepWideButton(title: "CHANGE HERO", color: .yellow, dark: true)
            }
            .simultaneousGesture(TapGesture().onEnded {
                SoundEngine.shared.uiTap()
            })
        }
        .padding(12)
        .background(.black.opacity(0.55))
        .clipShape(ShopPixelShape(cut: 10))
        .overlay(ShopPixelShape(cut: 10).stroke(.yellow.opacity(0.35), lineWidth: 2))
    }

    private func header(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(color)
            Spacer()
        }
    }
}

// MARK: - Gun panel

private struct PrepGunPanel: View {
    let gun: HeroWeapon
    let tight: Bool

    var body: some View {
        VStack(spacing: tight ? 6 : 9) {
            header("YOUR GUN", color: .cyan)
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: PixelHeroArt.gunImage(gun))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(12)
                    .background(
                        LinearGradient(colors: [.cyan.opacity(0.14), .black.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(ShopPixelShape(cut: 8))
                    .overlay(ShopPixelShape(cut: 8).stroke(.cyan.opacity(0.6), lineWidth: 2))
                PrepChangeBadge(color: .cyan)
                    .padding(8)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 2) {
                Text(gun.name.uppercased())
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white)
                Text(gun.hasInfiniteAmmo ? "∞ AMMO" : "\(gun.magSize) SHELLS / MAG")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.cyan)
            }
            StatPips(label: "DMG", value: Int(gun.damage), maxValue: 60, color: .red,
                     compact: tight)
            StatPips(label: "AMMO", value: gun.hasInfiniteAmmo ? 6 : min(gun.magSize, 12),
                     maxValue: 12, color: .cyan, compact: tight)

            NavigationLink {
                GunArmoryView()
            } label: {
                PrepWideButton(title: "CHANGE GUN", color: .cyan, dark: true)
            }
            .simultaneousGesture(TapGesture().onEnded {
                SoundEngine.shared.uiTap()
            })
        }
        .padding(12)
        .background(.black.opacity(0.55))
        .clipShape(ShopPixelShape(cut: 10))
        .overlay(ShopPixelShape(cut: 10).stroke(.cyan.opacity(0.35), lineWidth: 2))
    }

    private func header(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(color)
            Spacer()
        }
    }
}

// MARK: - Shared bits

private struct PrepWideButton: View {
    let title: String
    let color: Color
    let dark: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 11, weight: .black))
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1)
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .foregroundStyle(color)
        .background(dark ? .black.opacity(0.75) : color)
        .clipShape(ShopPixelShape(cut: 6))
        .overlay(ShopPixelShape(cut: 6).stroke(color.opacity(0.7), lineWidth: 2))
        .contentShape(Rectangle())
    }
}

private struct PrepChangeBadge: View {
    let color: Color

    var body: some View {
        ZStack {
            Rectangle().fill(color).frame(width: 24, height: 24)
            Rectangle().stroke(.black, lineWidth: 2).frame(width: 24, height: 24)
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.black)
        }
        .shadow(color: .black.opacity(0.6), radius: 3)
    }
}

/// Compact dossier button (enemies / our army) for the mission panel.
private struct PrepLibraryButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.5)
                    .lineLimit(1)
            }
            Text(subtitle)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .opacity(0.72)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(.black.opacity(0.7))
        .clipShape(ShopPixelShape(cut: 6))
        .overlay(ShopPixelShape(cut: 6).stroke(tint.opacity(0.65), lineWidth: 2))
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        BattlePrepView(level: CampaignData.levels[8], path: .constant(NavigationPath()))
    }
}
