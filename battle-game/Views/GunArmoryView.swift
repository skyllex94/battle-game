import SwiftUI
import UIKit // UIImage gun portraits from PixelHeroArt

/// GunArmory — full gun selection shop. Opened from the level screen's
/// CHANGE GUN button. Tap an unlocked gun to arm it (persists immediately);
/// locked guns show their unlock level and shake on tap.
struct GunArmoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRaw: Int = GunLocker.selectedGun.rawValue
    @State private var deniedRaw: Int?

    private var unlockedCount: Int { GunLocker.unlockedGuns.count }
    private var selectedGun: HeroWeapon {
        HeroWeapon(rawValue: selectedRaw) ?? GunLocker.selectedGun
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.10)
                    .ignoresSafeArea()
                // Faint animated ember drift so the shop feels alive.
                TimelineView(.animation(minimumInterval: 1 / 8)) { tl in
                    Canvas { ctx, size in
                        GunEmbers.draw(ctx: &ctx, size: size,
                                       t: tl.date.timeIntervalSinceReferenceDate)
                    }
                }
                .ignoresSafeArea()
                .opacity(0.6)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("GUN ARMORY")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .tracking(3)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(unlockedCount)/\(HeroWeapon.allCases.count) UNLOCKED")
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
                        ForEach(HeroWeapon.allCases, id: \.self) { gun in
                            GunArmoryCard(gun: gun,
                                          selected: gun.rawValue == selectedRaw,
                                          denied: deniedRaw == gun.rawValue)
                                .onTapGesture {
                                    if GunLocker.isUnlocked(gun) {
                                        SoundEngine.shared.uiTap()
                                        selectedRaw = gun.rawValue
                                        GunLocker.selectedGun = gun
                                    } else {
                                        deniedRaw = gun.rawValue
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                            if deniedRaw == gun.rawValue { deniedRaw = nil }
                                        }
                                    }
                                }
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Gun Armory")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

/// Large gun card: big live portrait, name + ACTIVE, DMG/RNG/MAG pips,
/// blurb + ammo line. Locked cards veil + LVL tag.
private struct GunArmoryCard: View {
    let gun: HeroWeapon
    let selected: Bool
    let denied: Bool

    private var locked: Bool { !GunLocker.isUnlocked(gun) }
    private let shape = ShopPixelShape(cut: 8)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Image(uiImage: PixelHeroArt.gunImage(gun))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 62)
                    .saturation(locked ? 0 : 1)
                    .opacity(locked ? 0.4 : 1)
                if locked {
                    Color.black.opacity(0.45)
                    VStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("LVL \(gun.unlockLevel)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.cyan)
                    }
                }
            }
            .frame(width: 120, height: 72)
            .background(.black.opacity(0.6))
            .clipShape(shape)
            .overlay(shape.stroke(selected ? .yellow : .white.opacity(locked ? 0.15 : 0.35),
                                  lineWidth: selected ? 3 : 1))
            .shadow(color: selected ? .yellow.opacity(0.5) : .clear, radius: 8)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(gun.name.uppercased())
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(selected ? .yellow : locked ? .white.opacity(0.45) : .white)
                    if selected {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.yellow)
                    }
                    Spacer()
                    Text(gun.hasInfiniteAmmo ? "∞ AMMO" : "\(gun.magSize) SHELLS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(gun.hasInfiniteAmmo ? .cyan : .white.opacity(0.6))
                }
                StatPips(label: "DMG", value: Int(gun.damage), maxValue: 30, color: .red)
                StatPips(label: "RNG", value: Int(gun.maxRange), maxValue: 750, color: .green)
                StatPips(label: "MAG", value: gun.magSize, maxValue: 30, color: .cyan)
                Text(gun.blurb)
                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(12)
        .background(.black.opacity(0.55))
        .clipShape(shape)
        .overlay(shape.stroke(selected ? .yellow.opacity(0.7) : .white.opacity(0.12), lineWidth: selected ? 3 : 1))
        .shadow(color: selected ? .yellow.opacity(0.35) : .clear, radius: 10)
        .offset(x: denied ? -6 : 0)
        .animation(denied ? .easeInOut(duration: 0.06).repeatCount(3, autoreverses: true)
                          : .default,
                   value: denied)
    }
}

/// Drifting embers behind the gun grid (cheap Canvas spark field).
private enum GunEmbers {
    static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for i in 0..<40 {
            let x = Double((i * 149 + Int(t * 24)) % Int(max(1, Int(size.width) + 40))) - 20
            let y = size.height - Double((i * 197 + Int(t * 60)) % Int(max(1, Int(size.height) + 40))) + 20
            let a = 0.25 + 0.35 * (sin(t * 2 + Double(i)) + 1) / 2
            ctx.fill(Path(CGRect(x: x, y: y, width: 3, height: 3)),
                     with: .color((i % 3 == 0 ? Color.cyan : Color.orange).opacity(a)))
        }
    }
}

#Preview {
    NavigationStack {
        GunArmoryView()
    }
}
