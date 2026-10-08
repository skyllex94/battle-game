import SwiftUI
import UIKit // UIImage gun portraits from PixelHeroArt

/// GunArmory — professional hero arsenal. Opened from the level screen's
/// gun card. Layout: loadout slot bar + featured showcase + scrollable
/// rack grid (2-pane in landscape, stacked on narrow screens). Data-driven
/// over HeroWeapon, so future guns appear with zero UI changes.
/// Tap a slot to pick it, tap an unlocked rack tile to fill it (starter =
/// slot 1, the battle gun); locked tiles show unlock level and shake, with
/// diamond buyouts in the footer and extra slots for sale in the bar.
struct GunArmoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var guns: [HeroWeapon] = LoadoutStore.loadout
    @State private var activeSlot: Int = 0
    @State private var deniedRaw: Int?
    @ObservedObject private var wallet = WalletStore.shared

    private var unlockedCount: Int { GunLocker.unlockedGuns.count }
    private var showcaseGun: HeroWeapon? {
        activeSlot < guns.count ? guns[activeSlot] : nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Gun-shop interior: riveted steel wall, warm work lamp with
                // a faint flicker, hazard stripe along the wall/floor seam,
                // giant crosshair watermark, drifting embers. One Canvas.
                TimelineView(.animation(minimumInterval: 1 / 8)) { tl in
                    Canvas { ctx, size in
                        ArmoryBackdrop.draw(ctx: &ctx, size: size,
                                            t: tl.date.timeIntervalSinceReferenceDate)
                    }
                }
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 10) {
                    SlimTopBar(unlocked: unlockedCount,
                               total: HeroWeapon.allCases.count,
                               diamonds: wallet.diamonds) {
                        SoundEngine.shared.uiTap()
                        dismiss()
                    }
                    if geo.size.width > 700 {
                        // Landscape: showcase pinned left, rack scrolls right.
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 10) {
                                LoadoutBar(guns: guns, activeSlot: activeSlot,
                                           onSlot: { activeSlot = $0; SoundEngine.shared.uiTap() },
                                           onBuySlot: buySlot)
                                if let gun = showcaseGun {
                                    ShowcaseCard(gun: gun, slot: activeSlot)
                                } else {
                                    EmptyShowcaseCard(slot: activeSlot)
                                }
                            }
                            .frame(width: 300)
                            ScrollView(.vertical, showsIndicators: false) {
                                RackGrid(slotted: guns,
                                         deniedRaw: deniedRaw,
                                         onTap: handleTap,
                                         onBuy: handleBuy)
                            }
                        }
                    } else {
                        // Narrow: loadout + showcase on top, rack below.
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                LoadoutBar(guns: guns, activeSlot: activeSlot,
                                           onSlot: { activeSlot = $0; SoundEngine.shared.uiTap() },
                                           onBuySlot: buySlot)
                                if let gun = showcaseGun {
                                    ShowcaseCard(gun: gun, slot: activeSlot)
                                } else {
                                    EmptyShowcaseCard(slot: activeSlot)
                                }
                                RackGrid(slotted: guns,
                                         deniedRaw: deniedRaw,
                                         onTap: handleTap,
                                         onBuy: handleBuy)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Rack tap: unlocked guns fill the active slot (already-slotted guns
    /// just reselect their slot); locked ones shake. Persists immediately.
    private func handleTap(_ gun: HeroWeapon) {
        guard GunLocker.isUnlocked(gun) else {
            deny(gun)
            return
        }
        SoundEngine.shared.uiTap()
        if let s = LoadoutStore.slot(of: gun) {
            activeSlot = s
        } else if let s = LoadoutStore.assign(gun, to: activeSlot) {
            activeSlot = s
        }
        refresh()
    }

    /// Buyout tap: spend diamonds to claim a locked gun early (the wallet
    /// change re-renders the rack automatically). Broke taps shake.
    private func handleBuy(_ gun: HeroWeapon) {
        if UnlockStore.buy(gun) {
            SoundEngine.shared.pickup()
        } else {
            deny(gun)
        }
        refresh()
    }

    /// Slot purchase: diamonds for slots 3…6 (wallet change refreshes).
    private func buySlot() {
        if LoadoutStore.buySlot() {
            SoundEngine.shared.pickup()
        }
        refresh()
    }

    private func refresh() {
        guns = LoadoutStore.loadout
        activeSlot = min(activeSlot, max(0, LoadoutStore.slotCount - 1))
    }

    private func deny(_ gun: HeroWeapon) {
        deniedRaw = gun.rawValue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if deniedRaw == gun.rawValue { deniedRaw = nil }
        }
    }
}

/// Slim floating strip: no title — the shop interior speaks for itself.
/// Unlocked counter + diamond balance left, DONE right.
private struct SlimTopBar: View {
    let unlocked: Int
    let total: Int
    let diamonds: Int
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                DiamondChip()
                Text("\(diamonds)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.black.opacity(0.6))
            .overlay(Rectangle().stroke(.cyan.opacity(0.45), lineWidth: 1))
            Text("\(unlocked)/\(total)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.yellow)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.black.opacity(0.6))
                .overlay(Rectangle().stroke(.yellow.opacity(0.45), lineWidth: 1))
            Spacer()
            Button(action: onDone) {
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
    }
}

/// Gun-shop interior backdrop (one cheap Canvas): riveted steel wall over
/// a dark floor, warm work lamp with a faint mains flicker + light cone,
/// hazard stripe on the wall/floor seam, giant crosshair watermark, and
/// the familiar drifting embers.
private enum ArmoryBackdrop {
    static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let seamY = h * 0.68
        // Wall + floor base.
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: seamY)),
                 with: .color(Color(red: 0.055, green: 0.07, blue: 0.11)))
        ctx.fill(Path(CGRect(x: 0, y: seamY, width: w, height: h - seamY)),
                 with: .color(Color(red: 0.03, green: 0.035, blue: 0.055)))
        // Steel panel seams + rivets.
        let seamColor = Color.white.opacity(0.05)
        var x: CGFloat = 60
        while x < w {
            ctx.fill(Path(CGRect(x: x, y: 0, width: 2, height: seamY)), with: .color(seamColor))
            var y: CGFloat = 24
            while y < seamY {
                ctx.fill(Path(CGRect(x: x - 3, y: y, width: 8, height: 8)), with: .color(seamColor))
                y += 120
            }
            x += 140
        }
        ctx.fill(Path(CGRect(x: 0, y: seamY - 2, width: w, height: 2)), with: .color(seamColor))
        // Work lamp: flickering warm glow + cone over the bench zone.
        let flicker = 0.9 + 0.1 * (sin(t * 7) * 0.6 + sin(t * 13) * 0.4)
        let lampX = w * 0.30, lampY: CGFloat = -30
        for (r, a) in [(260.0, 0.05), (190.0, 0.07), (120.0, 0.10)] as [(CGFloat, Double)] {
            let rect = CGRect(x: lampX - r, y: lampY - r * 0.6, width: r * 2, height: r * 1.2)
            ctx.fill(Path(ellipseIn: rect),
                     with: .color(Color(red: 1.0, green: 0.8, blue: 0.5, opacity: a * flicker)))
        }
        var cone = Path()
        cone.move(to: CGPoint(x: lampX - 26, y: 0))
        cone.addLine(to: CGPoint(x: lampX + 26, y: 0))
        cone.addLine(to: CGPoint(x: lampX + 190, y: seamY))
        cone.addLine(to: CGPoint(x: lampX - 190, y: seamY))
        cone.closeSubpath()
        ctx.fill(cone, with: .color(Color(red: 1.0, green: 0.82, blue: 0.55, opacity: 0.045 * flicker)))
        // Lamp fixture bar.
        ctx.fill(Path(CGRect(x: lampX - 34, y: 0, width: 68, height: 10)),
                 with: .color(Color(white: 0.12)))
        ctx.fill(Path(CGRect(x: lampX - 34, y: 8, width: 68, height: 3)),
                 with: .color(Color(red: 1.0, green: 0.82, blue: 0.5, opacity: 0.8 * flicker)))
        // Hazard stripe along the wall/floor seam.
        let stripeH: CGFloat = 10
        var sx: CGFloat = -20
        var flip = false
        while sx < w + 20 {
            ctx.fill(Path(CGRect(x: sx, y: seamY, width: 20, height: stripeH)),
                     with: .color(flip ? Color(red: 0.75, green: 0.6, blue: 0.1, opacity: 0.5)
                                        : Color(white: 0.02, opacity: 0.6)))
            sx += 20
            flip.toggle()
        }
        // Giant crosshair watermark, right side.
        let cx = w * 0.82, cy = h * 0.34, cr = min(w, h) * 0.22
        let mark = Color.white.opacity(0.045)
        ctx.stroke(Path(ellipseIn: CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2)),
                   with: .color(mark), lineWidth: 3)
        ctx.fill(Path(CGRect(x: cx - cr - 24, y: cy - 2, width: cr * 2 + 48, height: 4)),
                 with: .color(mark))
        ctx.fill(Path(CGRect(x: cx - 2, y: cy - cr - 24, width: 4, height: cr * 2 + 48)),
                 with: .color(mark))
        // Floor sheen under the lamp.
        let sheen = CGRect(x: lampX - 150, y: seamY + 12, width: 300, height: 26)
        ctx.fill(Path(ellipseIn: sheen),
                 with: .color(Color(red: 1.0, green: 0.82, blue: 0.55, opacity: 0.05 * flicker)))
        // Drifting embers.
        for i in 0..<40 {
            let ex = Double((i * 149 + Int(t * 24)) % Int(max(1, Int(w) + 40))) - 20
            let ey = h - Double((i * 197 + Int(t * 60)) % Int(max(1, Int(h) + 40))) + 20
            let a = 0.25 + 0.35 * (sin(t * 2 + Double(i)) + 1) / 2
            ctx.fill(Path(CGRect(x: ex, y: ey, width: 3, height: 3)),
                     with: .color((i % 3 == 0 ? Color.cyan : Color.orange).opacity(a)))
        }
    }
}

/// Loadout slot bar: filled slots wear their gun portrait, the next empty
/// slot shows a +, and the following locked slot carries its diamond price
/// (up to 6). Tap a slot to work it; slot 1 is the battle starter.
private struct LoadoutBar: View {
    let guns: [HeroWeapon]
    let activeSlot: Int
    let onSlot: (Int) -> Void
    let onBuySlot: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOADOUT // SLOT 1 STARTS THE BATTLE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.yellow)
            HStack(spacing: 8) {
                ForEach(0..<LoadoutStore.slotCount, id: \.self) { slot in
                    SlotTile(slot: slot,
                             gun: slot < guns.count ? guns[slot] : nil,
                             active: slot == activeSlot,
                             onTap: { onSlot(slot) })
                }
                if let cost = LoadoutStore.nextSlotCost {
                    Button(action: onBuySlot) {
                        VStack(spacing: 2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                            HStack(spacing: 2) {
                                DiamondChip()
                                Text("\(cost)")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .monospacedDigit()
                                    .foregroundStyle(WalletStore.shared.canAfford(cost) ? .cyan : .gray)
                            }
                        }
                        .frame(width: 52, height: 52)
                        .background(.black.opacity(0.6))
                        .overlay(Rectangle().stroke(.white.opacity(0.2), lineWidth: 1))
                    }
                    .disabled(!WalletStore.shared.canAfford(cost))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(Color(red: 0.07, green: 0.08, blue: 0.115).opacity(0.92))
        .clipShape(ShopPixelShape(cut: 6))
        .overlay(ShopPixelShape(cut: 6).stroke(.yellow.opacity(0.3), lineWidth: 2))
    }
}

/// One loadout slot: gun portrait, STARTER ribbon on slot 1, + on empty,
/// yellow ring on the active slot.
private struct SlotTile: View {
    let slot: Int
    let gun: HeroWeapon?
    let active: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    if let gun {
                        Image(uiImage: PixelHeroArt.gunImage(gun))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 26)
                    } else {
                        Text("+")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.65))
                .overlay(Rectangle().stroke(active ? .yellow : .white.opacity(0.2),
                                            lineWidth: active ? 2 : 1))
                if slot == 0 {
                    Text("START")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(.yellow)
                        .offset(x: 4, y: -6)
                }
            }
        }
    }
}

/// Slotted weapon on the inspection bench: warm lamp glow behind a big
/// live portrait resting over a wooden bench plank, slot tag, full stat
/// lines, blurb and ammo readout. Follows the active slot.
private struct ShowcaseCard: View {
    let gun: HeroWeapon
    let slot: Int
    private let shape = ShopPixelShape(cut: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(slot == 0 ? "SLOT 1 · STARTER" : "SLOT \(slot + 1)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.yellow)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.yellow)
                Spacer()
                Text(gun.hasInfiniteAmmo ? "∞ AMMO" : "\(gun.magSize) SHELLS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(gun.hasInfiniteAmmo ? .cyan : .white.opacity(0.6))
            }
            ZStack {
                // Lamp pool on the bench.
                Ellipse()
                    .fill(Color(red: 1.0, green: 0.82, blue: 0.55).opacity(0.10))
                    .frame(width: 220, height: 70)
                    .offset(y: -14)
                Image(uiImage: PixelHeroArt.gunImage(gun))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 74)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 4)
                // Wooden bench plank the gun rests on.
                VStack {
                    Spacer()
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color(red: 0.23, green: 0.16, blue: 0.09))
                            .frame(height: 16)
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 3)
                        // Plank grooves.
                        HStack(spacing: 0) {
                            ForEach(0..<6, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.black.opacity(0.45))
                                    .frame(width: 2, height: 16)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, minHeight: 108)
            .background(.black.opacity(0.65))
            .clipShape(shape)
            .overlay(shape.stroke(.yellow.opacity(0.7), lineWidth: 2))
            .shadow(color: .yellow.opacity(0.2), radius: 8)
            Text(gun.name.uppercased())
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white)
            Text(gun.blurb)
                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
            StatPips(label: "DMG", value: Int(gun.damage), maxValue: Int(HeroWeapon.maxDamage), color: .red)
            StatPips(label: "RNG", value: Int(gun.maxRange), maxValue: Int(HeroWeapon.maxRangeValue), color: .green)
            RofPips(rate: gun.fireRate)
            Text("TAP A RACK TILE TO FILL THIS SLOT")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, 2)
        }
        .padding(14)
        .background(Color(red: 0.07, green: 0.08, blue: 0.115).opacity(0.92))
        .clipShape(shape)
        .overlay(shape.stroke(.yellow.opacity(0.35), lineWidth: 2))
    }
}

/// Scrollable rack: every gun as a compact tile (index, portrait, mini
/// stats, footer action slot). Roster order (by unlock), adaptive columns.
/// Slotted guns wear the yellow tag instead of a single active marker.
private struct RackGrid: View {
    let slotted: [HeroWeapon]
    let deniedRaw: Int?
    let onTap: (HeroWeapon) -> Void
    let onBuy: (HeroWeapon) -> Void

    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(HeroWeapon.rosterOrder.enumerated()), id: \.element) { index, gun in
                GunTile(index: index + 1,
                        gun: gun,
                        selected: slotted.contains(gun),
                        denied: deniedRaw == gun.rawValue,
                        onBuy: { onBuy(gun) })
                    .onTapGesture { onTap(gun) }
            }
        }
        .padding(.bottom, 8)
    }
}

/// Empty slot showcase: points back at the rack.
private struct EmptyShowcaseCard: View {
    let slot: Int
    private let shape = ShopPixelShape(cut: 8)

    var body: some View {
        VStack(spacing: 8) {
            Text("SLOT \(slot + 1) · EMPTY")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))
            Text("PICK A GUN FROM THE RACK")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.cyan)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(.black.opacity(0.55))
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.2), lineWidth: 2))
    }
}

/// Compact rack tile: portrait pad, name, mini stat blocks, footer slot.
/// Slotted tiles glow yellow; locked tiles veil + carry LVL/buyout.
private struct GunTile: View {
    let index: Int
    let gun: HeroWeapon
    let selected: Bool
    let denied: Bool
    let onBuy: () -> Void

    private var locked: Bool { !GunLocker.isUnlocked(gun) }
    private let shape = ShopPixelShape(cut: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(String(format: "%02d", index))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
                Spacer()
                if selected {
                    Text("SLOTTED")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.yellow)
                }
            }
            ZStack {
                Image(uiImage: PixelHeroArt.gunImage(gun))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 44)
                    .saturation(locked ? 0 : 1)
                    .opacity(locked ? 0.4 : 1)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 3)
                if locked {
                    Color.black.opacity(0.45)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.black.opacity(0.7))
            .clipShape(shape)
            .overlay(shape.stroke(selected ? .yellow : .white.opacity(locked ? 0.15 : 0.22),
                                  lineWidth: selected ? 2 : 1))
            .shadow(color: selected ? .yellow.opacity(0.4) : .clear, radius: 6)
            Text(gun.name.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(selected ? .yellow : locked ? .white.opacity(0.45) : .white)
                .lineLimit(1)
            HStack(spacing: 6) {
                MiniStat(label: "D", value: Int(gun.damage), maxValue: Int(HeroWeapon.maxDamage), color: .red)
                MiniStat(label: "R", value: Int(gun.maxRange), maxValue: Int(HeroWeapon.maxRangeValue), color: .green)
                MiniStat(label: "S", value: Int((gun.fireRate * 10).rounded()),
                         maxValue: Int((HeroWeapon.maxFireRate * 10).rounded()), color: .cyan)
            }
            // Footer action slot: diamond buyout for locked guns.
            GunTileFooter(gun: gun, locked: locked, onBuy: onBuy)
        }
        .padding(10)
        .background(Color(red: 0.075, green: 0.085, blue: 0.12).opacity(0.94))
        .clipShape(shape)
        .overlay(shape.stroke(selected ? .yellow.opacity(0.7) : .white.opacity(0.10),
                              lineWidth: selected ? 2 : 1))
        .overlay(alignment: .top) {
            // Peg hook the tile hangs from.
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.32))
                .frame(width: 26, height: 6)
                .offset(y: -3)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
        }
        .offset(x: denied ? -6 : 0)
        .animation(denied ? .easeInOut(duration: 0.06).repeatCount(3, autoreverses: true)
                          : .default,
                   value: denied)
    }
}

/// Tile footer: LVL chip + diamond buyout for locked guns, ammo line
/// for the rest. Affordable buyouts are tappable cyan; broke ones read
/// dim and shake on tap.
private struct GunTileFooter: View {
    let gun: HeroWeapon
    let locked: Bool
    let onBuy: () -> Void

    private var affordable: Bool { WalletStore.shared.canAfford(gun.diamondCost) }

    var body: some View {
        HStack {
            if locked {
                Text("LVL \(gun.unlockLevel)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.cyan)
                Spacer()
                if gun.diamondCost > 0 {
                    Button(action: onBuy) {
                        HStack(spacing: 3) {
                            DiamondChip()
                            Text("\(gun.diamondCost)")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(affordable ? .black : .gray)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(affordable ? .cyan : .white.opacity(0.08))
                        .clipShape(ShopPixelShape(cut: 3))
                        .overlay(ShopPixelShape(cut: 3).stroke(
                            affordable ? .white.opacity(0.6) : .gray.opacity(0.4), lineWidth: 1))
                    }
                    .disabled(!affordable)
                }
            } else {
                Text(gun.hasInfiniteAmmo ? "∞ AMMO" : "\(gun.magSize) SHELLS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(gun.hasInfiniteAmmo ? .cyan : .white.opacity(0.55))
                Spacer()
            }
        }
    }
}

/// Fire-rate meter: label + 6-block meter + shots/sec readout.
/// Same pip language as StatPips, relative to the roster max.
private struct RofPips: View {
    let rate: Double

    private var lit: Int {
        min(6, max(1, Int((rate / HeroWeapon.maxFireRate * 6).rounded())))
    }

    var body: some View {
        HStack(spacing: 3) {
            Text("ROF")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 26, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(i < lit ? .cyan : .white.opacity(0.15))
                        .frame(width: 9, height: 7)
                }
            }
            Text(String(format: "%.1f/S", rate))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

/// Mini stat: label + 6-block meter. Compact enough for rack tiles.
/// D = damage, R = range, S = fire-rate speed — all relative to the
/// full roster so tiles read progressively (Blaster ~1 pip, Oblivion full).
private struct MiniStat: View {
    let label: String
    let value: Int
    let maxValue: Int
    let color: Color

    private var lit: Int {
        guard maxValue > 0 else { return 0 }
        return min(6, max(1, Int((Double(value) / Double(maxValue) * 6).rounded())))
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 1.5) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(i < lit ? color : .white.opacity(0.14))
                        .frame(width: 5, height: 7)
                }
            }
        }
    }
}

/// Small rotated-square diamond chip for the header balance.
private struct DiamondChip: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.cyan)
                .frame(width: 9, height: 9)
                .rotationEffect(.degrees(45))
            Rectangle()
                .fill(.white)
                .frame(width: 3, height: 3)
                .rotationEffect(.degrees(45))
                .offset(x: -1.5, y: -1.5)
        }
        .frame(width: 12, height: 12)
        .shadow(color: .cyan.opacity(0.5), radius: 2)
    }
}

#Preview {
    NavigationStack {
        GunArmoryView()
    }
}
