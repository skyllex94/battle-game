import SpriteKit
import SwiftUI
import UIKit // UIImage gun portraits from PixelHeroArt

/// LevelDetail — mission briefing over a living pixel-art battlefield.
/// No system chrome: custom pixel BACK button, all-pixel type and icons.
/// Left: planet intro + objective + new-unit callout + deploy. Right:
/// preselected hero + gun loadout with armory links. Compact by design —
/// everything fits a landscape phone screen with no scrolling.
struct LevelDetailView: View {
    let level: LevelDef
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHero: HeroDef = HeroRoster.selectedHero
    @State private var selectedGun: HeroWeapon = GunLocker.selectedGun
    @State private var bgScene = MainMenuBattleScene(size: CGSize(width: 1334, height: 750))

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Animated terrain backdrop (no static image).
                SpriteView(scene: bgScene, options: [.ignoresSiblingOrder])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .all)
                LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.34)],
                               startPoint: .leading, endPoint: .trailing)
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)
                LinearGradient(colors: [.black.opacity(0.45), .clear],
                               startPoint: .bottom, endPoint: .center)
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)

                HStack(spacing: 12) {
                    // Left: briefing
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Rectangle().fill(.cyan).frame(width: 8, height: 8)
                            Text("MISSION BRIEFING")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(.cyan)
                        }
                        Text("LVL \(level.id) — \(level.name.uppercased())")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(level.briefing)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(5)
                        HStack(spacing: 8) {
                            PixelIcon.crosshair
                            Text("TARGET: ENEMY HQ — \(level.baseHP) HP")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(.yellow)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.black.opacity(0.55))
                        .overlay(Rectangle().stroke(.yellow.opacity(0.5), lineWidth: 1))
                        Spacer(minLength: 2)
                        // New-unit showcase: units debuting on THIS level get
                        // a pixel-art callout right above START BATTLE.
                        if let recruit = ArmyKind.allCases.first(where: { $0.unlockLevel == level.id }) {
                            HStack(spacing: 10) {
                                Image(uiImage: UnitPixelArt.portraitImage(for: recruit.pixelKind))
                                    .interpolation(.none)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 42)
                                    .background(.black.opacity(0.6))
                                    .clipShape(ShopPixelShape(cut: 5))
                                    .overlay(ShopPixelShape(cut: 5).stroke(.yellow, lineWidth: 2))
                                    .shadow(color: .yellow.opacity(0.4), radius: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("NEW UNIT")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .tracking(2)
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(.yellow)
                                    Text(recruit.name.uppercased())
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(.white)
                                    Text("JOINS YOUR ARMY HERE")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(.cyan)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(.black.opacity(0.55))
                            .clipShape(ShopPixelShape(cut: 8))
                            .overlay(ShopPixelShape(cut: 8).stroke(.yellow.opacity(0.55), lineWidth: 2))
                        }
                        NavigationLink {
                            GameView(level: level, hero: selectedHero)
                        } label: {
                            HStack {
                                PixelIcon.bolt
                                Text("START BATTLE").fontWeight(.black)
                            }
                            .font(.system(size: 15, design: .monospaced))
                            .tracking(1)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(ShopPixelShape(cut: 8))
                            .overlay(ShopPixelShape(cut: 8).stroke(.white.opacity(0.7), lineWidth: 3))
                            .shadow(color: .red.opacity(0.45), radius: 10)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            SoundEngine.shared.uiTap()
                        })
                    }
                    .frame(width: geo.size.width * 0.36)
                    .padding(14)

                    Spacer(minLength: 0)

                    // Right: current hero + current gun only.
                    // Each card wears a change badge (bottom-right) and opens
                    // its shop — no full roster here, just the equipped pick.
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Rectangle().fill(.yellow).frame(width: 8, height: 8)
                            Text("YOUR HERO")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(.yellow)
                        }
                        NavigationLink {
                            HeroArmoryView()
                        } label: {
                            HStack(spacing: 10) {
                                ZStack(alignment: .bottomTrailing) {
                                    ImportedArt.image(named: selectedHero.iconArtName)
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: 56, height: 56)
                                        .clipShape(ShopPixelShape(cut: 6))
                                        .overlay(ShopPixelShape(cut: 6).stroke(.yellow, lineWidth: 2))
                                        .shadow(color: .yellow.opacity(0.35), radius: 8)
                                    ChangeBadge()
                                        .offset(x: 6, y: 6)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(selectedHero.displayName.uppercased())
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    StatPips(label: "HP", value: selectedHero.maxHealth, maxValue: 200, color: .green)
                                    StatPips(label: "SPD", value: Int(selectedHero.speed), maxValue: 12, color: .cyan)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            SoundEngine.shared.uiTap()
                        })
                        HStack(spacing: 6) {
                            Rectangle().fill(.cyan).frame(width: 8, height: 8)
                            Text("YOUR GUN")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(.cyan)
                        }
                        NavigationLink {
                            GunArmoryView()
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                GunShopCard(gun: selectedGun,
                                            selected: true,
                                            denied: false)
                                    .allowsHitTesting(false)
                                ChangeBadge()
                                    .offset(x: 6, y: 6)
                            }
                            .contentShape(Rectangle())
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            SoundEngine.shared.uiTap()
                        })
                    }
                    .padding(14)
                    .frame(width: min(320, geo.size.width * 0.32))
                }
                .padding(.top, 54)

                // Game-designed back button, top-left over everything.
                VStack {
                    HStack {
                        Button {
                            SoundEngine.shared.uiTap()
                            dismiss()
                        } label: {
                            HStack(spacing: 7) {
                                PixelIcon.back
                                Text("BACK")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .tracking(2)
                            }
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.black.opacity(0.65))
                            .clipShape(ShopPixelShape(cut: 6))
                            .overlay(ShopPixelShape(cut: 6).stroke(.cyan.opacity(0.6), lineWidth: 2))
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Refresh: the armories may have changed the picks while away.
            selectedHero = HeroRoster.selectedHero
            selectedGun = GunLocker.selectedGun
        }
    }
}

/// Change badge pinned to the bottom-right of the hero portrait and the
/// gun card. Pixel square with a swap glyph — the affordance that the card
/// opens its shop (heroes / guns respectively).
private struct ChangeBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.cyan)
                .frame(width: 22, height: 22)
            Rectangle()
                .stroke(.black, lineWidth: 2)
                .frame(width: 22, height: 22)
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.black)
        }
        .shadow(color: .black.opacity(0.6), radius: 3)
    }
}

/// Hand-drawn pixel glyphs (hard squares, no SF Symbols): back chevron,
/// crosshair target, lightning bolt. Game-designed icon language.
private enum PixelIcon {
    static var back: some View {
        HStack(spacing: 1.5) {
            VStack(spacing: 1.5) {
                Color.clear.frame(width: 5, height: 5)
                Color.cyan.frame(width: 5, height: 5)
                Color.cyan.frame(width: 5, height: 5)
                Color.clear.frame(width: 5, height: 5)
            }
            VStack(spacing: 1.5) {
                Color.cyan.frame(width: 5, height: 5)
                Color.clear.frame(width: 5, height: 5)
                Color.clear.frame(width: 5, height: 5)
                Color.cyan.frame(width: 5, height: 5)
            }
            VStack(spacing: 1.5) {
                Color.cyan.frame(width: 5, height: 5)
                Color.cyan.frame(width: 5, height: 5)
                Color.cyan.frame(width: 5, height: 5)
                Color.cyan.frame(width: 5, height: 5)
            }
        }
    }

    static var crosshair: some View {
        ZStack {
            Rectangle().fill(.yellow).frame(width: 16, height: 4)
            Rectangle().fill(.yellow).frame(width: 4, height: 16)
            Rectangle().fill(.black).frame(width: 6, height: 6)
            Rectangle().fill(.yellow).frame(width: 2, height: 2)
        }
        .frame(width: 18, height: 18)
    }

    static var bolt: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 6, height: 6)
                Color.yellow.frame(width: 6, height: 6)
            }
            HStack(spacing: 0) {
                Color.yellow.frame(width: 6, height: 6)
                Color.yellow.frame(width: 6, height: 6)
            }
            HStack(spacing: 0) {
                Color.yellow.frame(width: 6, height: 6)
                Color.clear.frame(width: 6, height: 6)
            }
        }
    }
}

/// Pixel gun card: live gun portrait, name, ammo line. Locked guns wear a
/// dark veil + lock + unlock-level tag; the picked gun glows yellow.
private struct GunShopCard: View {
    let gun: HeroWeapon
    let selected: Bool
    let denied: Bool

    private var locked: Bool { !GunLocker.isUnlocked(gun) }
    private let shape = ShopPixelShape(cut: 6)

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Image(uiImage: PixelHeroArt.gunImage(gun))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 28)
                    .saturation(locked ? 0 : 1)
                    .opacity(locked ? 0.4 : 1)
                if locked {
                    Color.black.opacity(0.45)
                    VStack(spacing: 1) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                        Text("LVL \(gun.unlockLevel)")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.cyan)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(.black.opacity(0.6))
            .clipShape(shape)
            .overlay(shape.stroke(selected ? .yellow : .white.opacity(locked ? 0.15 : 0.35),
                                  lineWidth: selected ? 2 : 1))
            .shadow(color: selected ? .yellow.opacity(0.5) : .clear, radius: 6)
            .offset(x: denied ? -5 : 0)
            .animation(denied ? .easeInOut(duration: 0.06).repeatCount(3, autoreverses: true)
                              : .default,
                       value: denied)
            Text(gun.name.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(selected ? .yellow : locked ? .white.opacity(0.45) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(gun.hasInfiniteAmmo ? "∞ AMMO" : "\(gun.magSize) SHELLS")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(gun.hasInfiniteAmmo ? .cyan : .white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        LevelDetailView(level: CampaignData.levels[0])
    }
}
