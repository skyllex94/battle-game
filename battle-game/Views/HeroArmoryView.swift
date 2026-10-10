import SwiftUI

/// HeroArmory — pro single-screen hero command bay. No scrolling anywhere:
/// the hero showcase stands on the LEFT, upgrades run down the RIGHT.
/// Stage arrows step through the available heroes; the small SWITCH button
/// opens the full choosing screen. Unlocked heroes DEPLOY instantly
/// (persists immediately), locked ones preview with their unlock level
/// and deny with a shake.
struct HeroArmoryView: View {
    @Environment(\.dismiss) private var dismiss
    /// Deployed hero (persisted).
    @State private var selectedId: String = HeroRoster.selectedHeroId
    /// Hero under inspection (may be locked — preview only).
    @State private var previewId: String = HeroRoster.selectedHeroId
    @State private var deniedId: String?
    @State private var showRoster = false
    /// Upgrade purchase awaiting confirmation. Lives at the top level
    /// so the modal covers the whole screen.
    @State private var pendingBuy: PendingBuy?
    @ObservedObject private var wallet = WalletStore.shared

    private var unlockedCount: Int { HeroRoster.unlockedHeroes.count }
    private var previewHero: HeroDef {
        HeroRoster.heroes.first(where: { $0.id == previewId }) ?? HeroRoster.selectedHero
    }
    private var previewUnlocked: Bool { HeroRoster.isUnlocked(previewHero) }
    private var previewIsActive: Bool { previewId == selectedId }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 700
            let tight = geo.size.height < 430
            ZStack {
                // Cryo-bay ready room: teal pod wall, glowing capsules, slow
                // scan band, blinking status lights, floor grid. One Canvas.
                TimelineView(.animation(minimumInterval: 1 / 8)) { tl in
                    Canvas { ctx, size in
                        HeroBayBackdrop.draw(ctx: &ctx, size: size,
                                             t: tl.date.timeIntervalSinceReferenceDate)
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: tight ? 6 : 8) {
                    ArmoryHeader(unlockedCount: unlockedCount,
                                 diamonds: wallet.diamonds) {
                        SoundEngine.shared.uiTap()
                        dismiss()
                    }
                    if wide {
                        // Landscape command split: hero LEFT, upgrades +
                        // add-ons stacked RIGHT.
                        HStack(alignment: .top, spacing: 12) {
                            ShowcaseColumn(hero: previewHero,
                                           isActive: previewIsActive,
                                           locked: !previewUnlocked,
                                           tight: tight,
                                           onPrev: stepPreview(-1),
                                           onNext: stepPreview(1),
                                           onSwitch: {
                                               SoundEngine.shared.uiTap()
                                               withAnimation { showRoster = true }
                                           })
                                .frame(width: 300)
                            VStack(spacing: tight ? 6 : 8) {
                                UpgradeColumn(hero: previewHero,
                                              locked: !previewUnlocked,
                                              tight: tight) { buy in
                                    SoundEngine.shared.uiTap()
                                    pendingBuy = buy
                                }
                                .frame(maxHeight: .infinity)
                                AddonsPanel(hero: previewHero,
                                            locked: !previewUnlocked,
                                            tight: tight) { buy in
                                    SoundEngine.shared.uiTap()
                                    pendingBuy = buy
                                }
                                .frame(maxHeight: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        // Narrow: same blocks, stacked compact — still
                        // no scrolling, just tighter staging.
                        ShowcaseColumn(hero: previewHero,
                                       isActive: previewIsActive,
                                       locked: !previewUnlocked,
                                       tight: true,
                                       onPrev: stepPreview(-1),
                                       onNext: stepPreview(1),
                                       onSwitch: {
                                           SoundEngine.shared.uiTap()
                                           withAnimation { showRoster = true }
                                       })
                        UpgradeColumn(hero: previewHero,
                                      locked: !previewUnlocked,
                                      tight: true) { buy in
                            SoundEngine.shared.uiTap()
                            pendingBuy = buy
                        }
                        AddonsPanel(hero: previewHero,
                                    locked: !previewUnlocked,
                                    tight: true) { buy in
                            SoundEngine.shared.uiTap()
                            pendingBuy = buy
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, tight ? 6 : 10)
                .padding(.bottom, tight ? 8 : 12)

                // Choosing screen slides over the bay.
                if showRoster {
                    RosterScreen(selectedId: selectedId,
                                 previewId: previewId,
                                 deniedId: deniedId,
                                 onPick: pick,
                                 onBack: {
                                     SoundEngine.shared.uiTap()
                                     withAnimation { showRoster = false }
                                 })
                        .transition(.move(edge: .trailing))
                }

                // Buy confirmation over the WHOLE screen: dims everything
                // and asks for the diamond price before anything is spent.
                if let buy = pendingBuy, let cost = buyCost(buy) {
                    ZStack {
                        Color.black.opacity(0.65)
                            .ignoresSafeArea()
                            .onTapGesture {
                                SoundEngine.shared.uiTap()
                                pendingBuy = nil
                            }
                        BuyConfirmCard(icon: buyIcon(buy),
                                       itemTitle: buyTitle(buy),
                                       effectLine: buyEffect(buy),
                                       itemKind: buyKind(buy),
                                       cost: cost,
                                       onConfirm: {
                                           if buyPerform(buy) {
                                               SoundEngine.shared.pickup()
                                           }
                                           pendingBuy = nil
                                       },
                                       onCancel: {
                                           SoundEngine.shared.uiTap()
                                           pendingBuy = nil
                                       })
                            .frame(maxWidth: 340)
                            .padding(.horizontal, 24)
                    }
                    .transition(.opacity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Roster tap: unlocked heroes deploy on the spot and the choosing
    /// screen closes; locked ones deny with a shake and stay open.
    private func pick(_ hero: HeroDef) {
        if HeroRoster.isUnlocked(hero) {
            SoundEngine.shared.uiTap()
            previewId = hero.id
            selectedId = hero.id
            HeroRoster.selectedHeroId = hero.id
            withAnimation { showRoster = false }
        } else {
            deniedId = hero.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if deniedId == hero.id { deniedId = nil }
            }
        }
    }

    /// Stage arrows: step through the AVAILABLE (unlocked) heroes — and
    /// whatever lands on screen IS deployed (no separate deploy step).
    private func stepPreview(_ dir: Int) -> () -> Void {
        {
            let available = HeroRoster.heroes.filter(HeroRoster.isUnlocked)
            guard !available.isEmpty else { return }
            let idx = available.firstIndex(where: { $0.id == previewId }) ?? 0
            let next = available[(idx + dir + available.count) % available.count]
            SoundEngine.shared.uiTap()
            previewId = next.id
            selectedId = next.id
            HeroRoster.selectedHeroId = next.id
        }
    }

    // MARK: - Pending purchase resolution (confirm card content + effect)

    /// Price for a pending buy, nil when it can't be bought (maxed/owned).
    /// The confirm card only appears while a price exists.
    private func buyCost(_ buy: PendingBuy) -> Int? {
        switch buy {
        case .track(let track):
            return HeroUpgrades.nextCost(heroId: previewId, track: track)
        case .booster:
            return HeroAddons.boosterCost(heroId: previewId)
        case .heart:
            return HeroAddons.heartCost(heroId: previewId)
        }
    }

    private func buyTitle(_ buy: PendingBuy) -> String {
        let name = previewHero.displayName.uppercased()
        switch buy {
        case .track(let track):
            let tier = HeroUpgrades.tier(heroId: previewId, track: track) + 1
            return "\(name) — \(track.label) \(roman(tier))"
        case .booster:
            let tier = HeroAddons.boosterTier(heroId: previewId) + 1
            return "\(name) — HEALTH BOOSTER \(roman(tier))"
        case .heart:
            return "\(name) — SECOND HEART"
        }
    }

    private func buyEffect(_ buy: PendingBuy) -> String {
        switch buy {
        case .track(let track):
            let tier = HeroUpgrades.tier(heroId: previewId, track: track) + 1
            return track.effect(tier: tier)
        case .booster:
            let tier = HeroAddons.boosterTier(heroId: previewId) + 1
            return HeroAddons.boosterEffect(tier: tier)
        case .heart:
            return "+1 LIFE EVERY RUN"
        }
    }

    private func buyKind(_ buy: PendingBuy) -> String {
        switch buy {
        case .track: return "upgrade"
        case .booster, .heart: return "add-on"
        }
    }

    /// Pixel icon for the confirm card's hero slot.
    private func buyIcon(_ buy: PendingBuy) -> AddonIconKind {
        switch buy {
        case .track(let track):
            switch track {
            case .hp: return .hp
            case .speed: return .speed
            case .shield: return .shield
            case .damage: return .damage
            }
        case .booster: return .booster
        case .heart: return .heart
        }
    }

    /// Executes the buy. Returns false when broke (balance untouched).
    private func buyPerform(_ buy: PendingBuy) -> Bool {
        switch buy {
        case .track(let track):
            return HeroUpgrades.buy(heroId: previewId, track: track)
        case .booster:
            return HeroAddons.buyBooster(heroId: previewId)
        case .heart:
            return HeroAddons.buyHeart(heroId: previewId)
        }
    }
}

// MARK: - Pending purchase

/// Anything the confirm card can sell: an upgrade track tier, a booster
/// tier, or the one-time second heart.
private enum PendingBuy {
    case track(HeroUpgradeTrack)
    case booster
    case heart
}

private func roman(_ tier: Int) -> String {
    ["", "I", "II", "III"][min(max(tier, 0), 3)]
}

// MARK: - Header

/// Slim command bar: title + readiness + diamond balance + DONE.
private struct ArmoryHeader: View {
    let unlockedCount: Int
    let diamonds: Int
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("HERO ARMORY")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white)
            Text("\(unlockedCount)/\(HeroRoster.heroes.count) READY")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.cyan)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.black.opacity(0.6))
                .overlay(Rectangle().stroke(.cyan.opacity(0.45), lineWidth: 1))
            Spacer()
            HStack(spacing: 4) {
                Text("◆")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.cyan)
                Text("\(diamonds)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.6))
            .overlay(Rectangle().stroke(.cyan.opacity(0.45), lineWidth: 1))
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

// MARK: - Right: upgrades + add-ons

/// Upgrade bay (RIGHT column, top): HEALTH / SPEED / DAMAGE tracks.
/// Shield lives in ADD-ONS below. Fixed compact rows — never scrolls.
private struct UpgradeColumn: View {
    let hero: HeroDef
    let locked: Bool
    let tight: Bool
    /// Price-button tap bubbles up — the top level confirms full-screen.
    let onBuyRequest: (PendingBuy) -> Void
    private let shape = ShopPixelShape(cut: 6)

    /// Core combat tracks (shield is an add-on now).
    private var tracks: [HeroUpgradeTrack] { [.hp, .speed, .damage] }

    /// One-line live combat summary for the inspected hero.
    private var summary: String {
        let hp = Int(HeroUpgrades.maxHP(heroId: hero.id))
        let spd = Int(HeroUpgrades.speedValue(heroId: hero.id))
        let sh = Int(HeroUpgrades.shieldMax(heroId: hero.id))
        let dmg = Int(HeroUpgrades.damageBonus(heroId: hero.id))
        return "HP \(hp) · SPD \(spd) · SH \(sh) · DMG +\(dmg)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: tight ? 4 : 6) {
            HStack(spacing: 6) {
                Text("UPGRADES")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.yellow)
                Spacer()
                Text(summary)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.cyan.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
                ForEach(tracks, id: \.self) { track in
                    UpgradeRow(heroId: hero.id, track: track, locked: locked, tight: tight) {
                        onBuyRequest(.track(track))
                    }
                    .frame(maxHeight: .infinity)
                }
            if locked {
                Text("UNLOCK LVL \(hero.unlockLevel) TO UPGRADE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(tight ? 8 : 10)
        .background(Color(red: 0.05, green: 0.10, blue: 0.13).opacity(0.92))
        .clipShape(shape)
        .overlay(shape.stroke(.cyan.opacity(0.35), lineWidth: 2))
    }
}

private struct UpgradeRow: View {
    let heroId: String
    let track: HeroUpgradeTrack
    let locked: Bool
    let tight: Bool
    /// Called when the price button (or icon) is tapped — confirms first.
    let onBuy: () -> Void

    private var tier: Int { HeroUpgrades.tier(heroId: heroId, track: track) }
    private var cost: Int? { HeroUpgrades.nextCost(heroId: heroId, track: track) }

    private var icon: AddonIconKind {
        switch track {
        case .hp: return .hp
        case .speed: return .speed
        case .shield: return .shield
        case .damage: return .damage
        }
    }

    var body: some View {
        AddonTierRow(icon: icon,
                     label: track.label,
                     tier: tier,
                     maxTier: HeroUpgradeTrack.maxTier,
                     effect: track.effect(tier: tier),
                     cost: cost,
                     locked: locked,
                     tight: tight,
                     onBuy: onBuy)
    }
}

/// ADD-ONS panel (RIGHT column, bottom): hero perks outside the core
/// tracks — AEGIS SHIELD (tiered energy shield), HEALTH BOOSTER (tiered
/// cheat-death medkits per run), SECOND HEART (one-time +1 life).
/// Every price routes through the same full-screen confirmation.
private struct AddonsPanel: View {
    let hero: HeroDef
    let locked: Bool
    let tight: Bool
    let requestBuy: (PendingBuy) -> Void
    private let shape = ShopPixelShape(cut: 6)

    /// Live add-on summary for the inspected hero.
    private var summary: String {
        let sh = Int(HeroUpgrades.shieldMax(heroId: hero.id))
        let bst = HeroAddons.boosterTier(heroId: hero.id)
        let hearts = HeroAddons.maxLives(heroId: hero.id)
        return "SH \(sh) · BST ×\(bst) · ♥\(hearts)"
    }

    private var shieldTier: Int { HeroUpgrades.tier(heroId: hero.id, track: .shield) }
    private var boosterTier: Int { HeroAddons.boosterTier(heroId: hero.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: tight ? 4 : 6) {
            HStack(spacing: 6) {
                Text("ADD-ONS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.yellow)
                Spacer()
                Text(summary)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.cyan.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            AddonTierRow(icon: .shield,
                         label: HeroUpgradeTrack.shield.label,
                         tier: shieldTier,
                         maxTier: HeroUpgradeTrack.maxTier,
                         effect: HeroUpgradeTrack.shield.effect(tier: shieldTier),
                         cost: HeroUpgrades.nextCost(heroId: hero.id, track: .shield),
                         locked: locked,
                         tight: tight) {
                requestBuy(.track(.shield))
            }
            .frame(maxHeight: .infinity)
            AddonTierRow(icon: .booster,
                         label: "BOOSTER",
                         tier: boosterTier,
                         maxTier: HeroAddons.boosterMax,
                         effect: HeroAddons.boosterEffect(tier: boosterTier),
                         cost: HeroAddons.boosterCost(heroId: hero.id),
                         locked: locked,
                         tight: tight) {
                requestBuy(.booster)
            }
            .frame(maxHeight: .infinity)
            AddonHeartRow(hero: hero, locked: locked, tight: tight) {
                requestBuy(.heart)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(tight ? 8 : 10)
        .background(Color(red: 0.05, green: 0.10, blue: 0.13).opacity(0.92))
        .clipShape(shape)
        .overlay(shape.stroke(.cyan.opacity(0.35), lineWidth: 2))
    }
}

/// Generic tiered add-on row: pixel icon slot + pips + effect + price.
/// Tapping the icon opens the same buy confirmation as the price button
/// (finished tracks just tap). Locked heroes show a dash, never a price.
private struct AddonTierRow: View {
    let icon: AddonIconKind
    let label: String
    let tier: Int
    let maxTier: Int
    let effect: String
    let cost: Int?
    let locked: Bool
    let tight: Bool
    let onBuy: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            AddonIconSlot(kind: icon, buyable: !locked && cost != nil) {
                if !locked, cost != nil {
                    onBuy()
                } else {
                    SoundEngine.shared.uiTap()
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white)
                HStack(spacing: 3) {
                    ForEach(0..<maxTier, id: \.self) { i in
                        Rectangle()
                            .fill(i < tier ? .yellow : .white.opacity(0.15))
                            .frame(width: 13, height: tight ? 7 : 8)
                    }
                }
                Text(effect)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 2)
            if locked {
                Text("—")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 8).padding(.vertical, 4)
            } else if let cost {
                PriceButton(cost: cost, action: onBuy)
            } else {
                OwnedTag(text: "MAX")
            }
        }
    }
}

/// Second-heart row: pixel heart slot + one-time buyout, OWNED forever.
/// The slot tap confirms just like the price button.
private struct AddonHeartRow: View {
    let hero: HeroDef
    let locked: Bool
    let tight: Bool
    let onBuy: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            AddonIconSlot(kind: .heart, buyable: !locked && HeroAddons.heartCost(heroId: hero.id) != nil) {
                if !locked, HeroAddons.heartCost(heroId: hero.id) != nil {
                    onBuy()
                } else {
                    SoundEngine.shared.uiTap()
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("2ND HEART")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white)
                Text(HeroAddons.hasHeart(heroId: hero.id) ? "♥♥♥♥ EVERY RUN" : "+1 LIFE EVERY RUN")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 2)
            if locked {
                Text("—")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 8).padding(.vertical, 4)
            } else if let cost = HeroAddons.heartCost(heroId: hero.id) {
                PriceButton(cost: cost, action: onBuy)
            } else {
                OwnedTag(text: "OWNED")
            }
        }
    }
}

/// Which pixel sprite fills a perk's placeholder slot.
private enum AddonIconKind {
    case hp, speed, shield, damage, booster, heart
}

/// Placeholder slot for an add-on: dark pixel-framed box with the perk's
/// pixel sprite inside. Tapping it opens the buy confirmation (same as
/// the price button); finished tracks just tap. Bright border while
/// buyable, dimmed once maxed/owned.
private struct AddonIconSlot: View {
    let kind: AddonIconKind
    let buyable: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .overlay(Rectangle().stroke(.cyan.opacity(buyable ? 0.6 : 0.22),
                                                lineWidth: 2))
                AddonPixelSprite(kind: kind)
            }
            .frame(width: 44, height: 44)
            .shadow(color: buyable ? .cyan.opacity(0.3) : .clear, radius: 5)
        }
        .opacity(buyable ? 1 : 0.7)
    }
}

/// Crisp pixel perk sprites: health heart (green), speed bolt (gold),
/// aegis shield (cyan + glint), damage slug (hot tip, steel case),
/// booster medkit (white case, red cross), second heart (red + glint).
/// Vector rects, same language as the HUD coin/diamond/heart.
private struct AddonPixelSprite: View {
    let kind: AddonIconKind
    var pixel: CGFloat = 2.25

    private var grid: [String] {
        switch kind {
        case .hp, .heart:
            return [
                "..OO.OO..",
                ".OrrOrrO.",
                "OrrLrrrrO",
                "OrrrrrrrO",
                "OrrrrrrrO",
                ".OrrrrrO.",
                "..OrrrO..",
                "...OOO...",
            ]
        case .speed:
            return [
                "....OOO.",
                "...OYYO.",
                "..OYYO..",
                ".OYYYYO.",
                "...OYYO.",
                "..OYYO..",
                ".OYYO...",
                ".OOO....",
            ]
        case .shield:
            return [
                ".OOOOO.",
                "OCWCCCO",
                "OCCCCCO",
                "OCCCCCO",
                ".OCCCO.",
                ".OCCCO.",
                "..OCO..",
                "..OOO..",
            ]
        case .damage:
            return [
                "...OO...",
                "..OYYO..",
                "..OYYO..",
                ".OYYYYO.",
                ".OYYYYO.",
                ".OggggO.",
                ".OggggO.",
                "..OOOO..",
            ]
        case .booster:
            return [
                "..OOOOOO..",
                ".OwwwwwwO.",
                ".OwRRRRwO.",
                "OwwRRRRwwO",
                "OwRRRRRRwO",
                "OwwRRRRwwO",
                ".OwRRRRwO.",
                ".OwwwwwwO.",
                "..OOOOOO..",
            ]
        }
    }

    private var palette: [Character: Color] {
        switch kind {
        case .hp:
            return [
                "O": Color(white: 0.08),
                "r": Color(red: 0.25, green: 0.95, blue: 0.45),
                "L": .white,
            ]
        case .speed:
            return [
                "O": Color(white: 0.08),
                "Y": Color(red: 1.0, green: 0.82, blue: 0.2),
            ]
        case .shield:
            return [
                "O": Color(white: 0.08),
                "C": .cyan,
                "W": .white,
            ]
        case .damage:
            return [
                "O": Color(white: 0.08),
                "Y": Color(red: 1.0, green: 0.55, blue: 0.15),
                "g": Color(red: 0.55, green: 0.58, blue: 0.65),
            ]
        case .booster:
            return [
                "O": Color(white: 0.08),
                "w": Color(red: 0.92, green: 0.94, blue: 0.96),
                "R": Color(red: 1.0, green: 0.25, blue: 0.3),
            ]
        case .heart:
            return [
                "O": Color(white: 0.08),
                "r": Color(red: 1.0, green: 0.25, blue: 0.3),
                "L": .white,
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(grid.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(Array(grid[r]).indices, id: \.self) { c in
                        let ch = Array(grid[r])[c]
                        if ch == "." {
                            Color.clear.frame(width: pixel, height: pixel)
                        } else {
                            (palette[ch] ?? .white)
                                .frame(width: pixel, height: pixel)
                        }
                    }
                }
            }
        }
    }
}

/// Shared diamond price button: big and thumb-friendly, cyan when
/// affordable, dim + disabled when broke. Tapping only ever opens the
/// confirmation — never spends.
private struct PriceButton: View {
    let cost: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(cost) ◆")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(WalletStore.shared.canAfford(cost) ? .black : .gray)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(WalletStore.shared.canAfford(cost) ? .cyan : .white.opacity(0.08))
                .clipShape(ShopPixelShape(cut: 4))
                .overlay(ShopPixelShape(cut: 4).stroke(
                    WalletStore.shared.canAfford(cost) ? .white.opacity(0.6) : .clear,
                    lineWidth: 1))
        }
        .disabled(!WalletStore.shared.canAfford(cost))
    }
}

/// Shared MAX / OWNED tag for finished tracks and buyouts.
private struct OwnedTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .tracking(1)
            .foregroundStyle(.black)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.yellow)
            .clipShape(ShopPixelShape(cut: 4))
    }
}

/// Buy confirmation card: names the item, its next tier + effect, and
/// asks for the diamond price before anything is spent.
/// Works for both upgrades and add-ons (kind word switches the ask).
private struct BuyConfirmCard: View {
    let icon: AddonIconKind
    let itemTitle: String
    let effectLine: String
    let itemKind: String
    let cost: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    private let shape = ShopPixelShape(cut: 6)

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 64, height: 64)
                    .overlay(Rectangle().stroke(.yellow.opacity(0.7), lineWidth: 2))
                AddonPixelSprite(kind: icon, pixel: 3)
            }
            .frame(width: 64, height: 64)
            .shadow(color: .yellow.opacity(0.3), radius: 8)
            Text(itemKind == "add-on" ? "CONFIRM ADD-ON" : "CONFIRM UPGRADE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.yellow)
            Text(itemTitle)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(effectLine)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
            Text("Buy this \(itemKind) for \(cost) diamonds?")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("CANCEL")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 32)
                        .background(.white.opacity(0.10))
                        .clipShape(ShopPixelShape(cut: 4))
                        .overlay(ShopPixelShape(cut: 4).stroke(.white.opacity(0.35), lineWidth: 1))
                }
                Button(action: onConfirm) {
                    Text("\(cost) ◆ BUY")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.black)
                        .frame(width: 100, height: 32)
                        .background(.cyan)
                        .clipShape(ShopPixelShape(cut: 4))
                        .overlay(ShopPixelShape(cut: 4).stroke(.white.opacity(0.6), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(red: 0.04, green: 0.08, blue: 0.11).opacity(0.98))
        .clipShape(shape)
        .overlay(shape.stroke(.yellow.opacity(0.6), lineWidth: 2))
        .shadow(color: .yellow.opacity(0.25), radius: 12)
    }
}

// MARK: - Right: showcase

/// Hero showcase (LEFT column): glow-pad stage with step arrows, name +
/// trait, dossier blurb and stat pips. Whatever hero is displayed IS the
/// deployed one — arrows and the choosing screen deploy on the spot, so
/// there is no separate deploy control. The status chip (ACTIVE / READY /
/// LVL) doubles as the SWITCH button into the choosing screen.
/// Everything fixed-height so the column never pushes the screen.
private struct ShowcaseColumn: View {
    let hero: HeroDef
    let isActive: Bool
    let locked: Bool
    let tight: Bool
    let onPrev: () -> Void
    let onNext: () -> Void
    let onSwitch: () -> Void
    private let shape = ShopPixelShape(cut: 8)

    var body: some View {
        VStack(spacing: tight ? 6 : 8) {
            // Stage: the roster portrait (same pixel image as the hero
            // selection) on a glow pad, arrows on the flanks, trait +
            // status chip pinned bottom.
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.4, green: 0.95, blue: 1).opacity(0.10))
                    .frame(width: 200, height: 54)
                    .offset(y: tight ? 40 : 50)
                Image(uiImage: HeroPixelArt.portraitImage(for: hero.pixelKind))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: tight ? 104 : 128)
                    .shadow(color: .cyan.opacity(0.35), radius: 14)
                    .saturation(locked ? 0.4 : 1)
                    .opacity(locked ? 0.75 : 1)
                HStack {
                    StageArrow(system: "chevron.left", action: onPrev)
                    Spacer()
                    StageArrow(system: "chevron.right", action: onNext)
                }
                .padding(.horizontal, 10)
                VStack {
                    Spacer()
                    HStack {
                        Text(hero.trait)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.cyan)
                        Spacer()
                        statusChip
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, minHeight: tight ? 148 : 178)
            .background(.black.opacity(0.6))
            .clipShape(shape)
            .overlay(shape.stroke(.cyan.opacity(0.5), lineWidth: 2))

            // Dossier group: big name + blurb, then the four combat stats
            // stacked tall — HP over SPD over SHIELD over DAMAGE.
            VStack(alignment: .leading, spacing: 5) {
                Text(hero.displayName.uppercased())
                    .font(.system(size: tight ? 19 : 22, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(hero.blurb)
                    .font(.system(size: tight ? 12 : 13))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: tight ? 32 : 34)
                Rectangle()
                    .fill(.cyan.opacity(0.25))
                    .frame(height: 1)
                DossierStatRow(icon: .hp, label: "HEALTH",
                               value: "\(Int(HeroUpgrades.maxHP(heroId: hero.id)))",
                               lit: pips(Int(HeroUpgrades.maxHP(heroId: hero.id)), 780),
                               color: .green)
                DossierStatRow(icon: .speed, label: "SPEED",
                               value: "\(Int(HeroUpgrades.speedValue(heroId: hero.id)))",
                               lit: pips(Int(HeroUpgrades.speedValue(heroId: hero.id)), 23),
                               color: .cyan)
                DossierStatRow(icon: .shield, label: "SHIELD",
                               value: "\(Int(HeroUpgrades.shieldMax(heroId: hero.id)))",
                               lit: HeroUpgrades.tier(heroId: hero.id, track: .shield) * 2,
                               color: .cyan)
                DossierStatRow(icon: .damage, label: "DAMAGE",
                               value: "+\(Int(HeroUpgrades.damageBonus(heroId: hero.id)))",
                               lit: pips(Int(HeroUpgrades.damageBonus(heroId: hero.id)), 30),
                               color: .orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(red: 0.05, green: 0.10, blue: 0.13).opacity(0.92))
            .clipShape(shape)
            .overlay(shape.stroke(.cyan.opacity(0.35), lineWidth: 2))
        }
    }

    /// 0-6 pip fill for a raw value against its ceiling.
    private func pips(_ value: Int, _ maxValue: Int) -> Int {
        min(6, max(0, Int(round(Double(value) / Double(maxValue) * 6))))
    }

    /// Status chip that doubles as the SWITCH button: ACTIVE on the
    /// deployed hero, READY on a spare unlocked fighter, LVL on a locked
    /// one. Any tap opens the choosing screen.
    @ViewBuilder
    private var statusChip: some View {
        Button(action: onSwitch) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.2.circlepath")
                    .font(.system(size: 8, weight: .black))
                Text(chipText)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(chipColor)
        }
    }

    private var chipText: String {
        if isActive { return "ACTIVE" }
        if locked { return "LVL \(hero.unlockLevel)" }
        return "SWITCH"
    }

    private var chipColor: Color {
        if isActive { return .yellow }
        if locked { return .gray }
        return .green
    }
}

/// One large dossier stat line: pixel icon + label on the left, chunky
/// pips + big live value on the right. HP over SPD over SHIELD over DMG.
private struct DossierStatRow: View {
    let icon: AddonIconKind
    let label: String
    let value: String
    let lit: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 30, height: 30)
                    .overlay(Rectangle().stroke(.cyan.opacity(0.35), lineWidth: 1))
                AddonPixelSprite(kind: icon, pixel: 1.5)
            }
            .frame(width: 30, height: 30)
            Text(label)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 4)
            HStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(i < lit ? color : .white.opacity(0.15))
                        .frame(width: 10, height: 9)
                }
            }
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .frame(height: 30)
    }
}

/// Slim chevron for stepping the preview through the roster.
private struct StageArrow: View {
    let system: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.cyan)
                .frame(width: 30, height: 44)
                .background(.black.opacity(0.55))
                .clipShape(ShopPixelShape(cut: 5))
                .overlay(ShopPixelShape(cut: 5).stroke(.cyan.opacity(0.4), lineWidth: 1))
        }
    }
}

// MARK: - Choosing screen

/// Full hero choosing screen: all twelve fighters as cards in a fixed
/// grid (4 columns, no scrolling). Locked cards veil with their unlock
/// level; the deployed card glows yellow. Back chevron returns to the bay.
private struct RosterScreen: View {
    let selectedId: String
    let previewId: String
    let deniedId: String?
    let onPick: (HeroDef) -> Void
    let onBack: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .black))
                        Text("HERO")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(2)
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.black.opacity(0.6))
                    .clipShape(ShopPixelShape(cut: 5))
                    .overlay(ShopPixelShape(cut: 5).stroke(.cyan.opacity(0.5), lineWidth: 2))
                }
                Spacer()
                Text("CHOOSE YOUR FIGHTER")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(HeroRoster.heroes) { hero in
                    RosterMiniCard(hero: hero,
                                   isActive: hero.id == selectedId,
                                   isPreview: hero.id == previewId,
                                   denied: deniedId == hero.id,
                                   tight: false)
                        .onTapGesture { onPick(hero) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.black.opacity(0.45))
    }
}

private struct RosterMiniCard: View {
    let hero: HeroDef
    let isActive: Bool
    let isPreview: Bool
    let denied: Bool
    let tight: Bool

    private var locked: Bool { !HeroRoster.isUnlocked(hero) }
    private let shape = ShopPixelShape(cut: 6)

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Image(uiImage: HeroPixelArt.portraitImage(for: hero.pixelKind))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: tight ? 34 : 40)
                    .saturation(locked ? 0 : 1)
                    .opacity(locked ? 0.45 : 1)
                if locked {
                    Color.black.opacity(0.45)
                    VStack(spacing: 1) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                        Text("LVL \(hero.unlockLevel)")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.cyan)
                    }
                }
                if isActive {
                    VStack {
                        Spacer()
                        Text("ACTIVE")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.yellow)
                    }
                    .padding(.bottom, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: tight ? 52 : 60)
            .background(.black.opacity(0.65))
            .clipShape(shape)
            .overlay(shape.stroke(isActive ? .yellow : isPreview ? .cyan : .cyan.opacity(locked ? 0.12 : 0.3),
                                  lineWidth: isActive || isPreview ? 2 : 1))
            .shadow(color: isActive ? .yellow.opacity(0.5)
                        : isPreview ? .cyan.opacity(0.35) : .clear, radius: 6)
            .offset(x: denied ? -6 : 0)
            .animation(denied ? .easeInOut(duration: 0.06).repeatCount(3, autoreverses: true)
                              : .default,
                       value: denied)
            Text(hero.displayName.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(isActive ? .yellow : locked ? .white.opacity(0.45) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Cryo-bay ready-room backdrop (one cheap Canvas): deep teal wall over a
/// dark deck, glowing pod capsules, a slow vertical scan band, blinking
/// status lights, floor grid sheen, and rising cool motes.
private enum HeroBayBackdrop {
    static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let seamY = h * 0.66
        // Wall + deck base.
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: seamY)),
                 with: .color(Color(red: 0.04, green: 0.09, blue: 0.12)))
        ctx.fill(Path(CGRect(x: 0, y: seamY, width: w, height: h - seamY)),
                 with: .color(Color(red: 0.02, green: 0.03, blue: 0.05)))
        // Wall panel seams.
        let seamColor = Color.white.opacity(0.05)
        var x: CGFloat = 70
        while x < w {
            ctx.fill(Path(CGRect(x: x, y: 0, width: 2, height: seamY)), with: .color(seamColor))
            x += 150
        }
        ctx.fill(Path(CGRect(x: 0, y: seamY - 2, width: w, height: 2)), with: .color(seamColor))
        // Cryo pods: glowing capsules along the wall.
        var px: CGFloat = 50
        var pod = 0
        while px < w {
            let pw: CGFloat = 54, ph = seamY * 0.62
            let py = seamY * 0.2
            let breathe = 0.75 + 0.25 * sin(t * 1.6 + Double(pod) * 1.1)
            ctx.stroke(Path(roundedRect: CGRect(x: px, y: py, width: pw, height: ph),
                            cornerRadius: 16),
                       with: .color(Color(red: 0.3, green: 0.85, blue: 0.9,
                                          opacity: 0.28 * breathe)), lineWidth: 2)
            ctx.fill(Path(roundedRect: CGRect(x: px + 6, y: py + 8, width: pw - 12,
                                              height: ph - 16), cornerRadius: 12),
                     with: .color(Color(red: 0.25, green: 0.75, blue: 0.85,
                                        opacity: 0.10 * breathe)))
            // Pod base + status pip.
            ctx.fill(Path(CGRect(x: px + 4, y: py + ph, width: pw - 8, height: 8)),
                     with: .color(Color(white: 0.1)))
            let pipOn = (Int(t * 1.2) + pod) % 3 != 0
            ctx.fill(Path(CGRect(x: px + pw / 2 - 3, y: py + ph + 2, width: 6, height: 6)),
                     with: .color(pipOn ? Color(red: 0.4, green: 1, blue: 0.6, opacity: 0.9)
                                        : Color(white: 0.2, opacity: 0.6)))
            px += 92
            pod += 1
        }
        // Slow vertical scan band sweeping the bay.
        let scanY = (t * 40).truncatingRemainder(dividingBy: Double(h + 120)) - 60
        ctx.fill(Path(CGRect(x: 0, y: scanY, width: w, height: 26)),
                 with: .color(Color(red: 0.4, green: 0.95, blue: 1, opacity: 0.05)))
        ctx.fill(Path(CGRect(x: 0, y: scanY + 12, width: w, height: 2)),
                 with: .color(Color(red: 0.4, green: 0.95, blue: 1, opacity: 0.18)))
        // Floor grid sheen.
        var gx: CGFloat = 0
        while gx < w {
            ctx.fill(Path(CGRect(x: gx, y: seamY + 8, width: 1.5, height: h - seamY - 8)),
                     with: .color(Color(red: 0.3, green: 0.8, blue: 0.9, opacity: 0.06)))
            gx += 46
        }
        ctx.fill(Path(CGRect(x: 0, y: seamY + 8, width: w, height: 1.5)),
                 with: .color(Color(red: 0.3, green: 0.8, blue: 0.9, opacity: 0.10)))
        // Rising cool motes.
        for i in 0..<36 {
            let mx = Double((i * 173 + Int(t * 18)) % Int(max(1, Int(w) + 40))) - 20
            let my = h - Double((i * 229 + Int(t * 46)) % Int(max(1, Int(h) + 40))) + 20
            let a = 0.2 + 0.3 * (sin(t * 2 + Double(i)) + 1) / 2
            ctx.fill(Path(CGRect(x: mx, y: my, width: 3, height: 3)),
                     with: .color((i % 3 == 0 ? Color.white : Color.cyan).opacity(a)))
        }
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
