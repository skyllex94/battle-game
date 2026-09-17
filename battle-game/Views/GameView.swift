import Combine
import SpriteKit
import SwiftUI
import UIKit // UIImage portraits from UnitPixelArt

/// GameView — hosts the Level 1 SpriteKit battlefield + movement HUD.
/// Joystick (bottom-left) runs the hero; push the stick up to jump.
/// Tap/drag the right side to aim + shoot (handled in GameScene).
struct GameView: View {
    let level: LevelDef
    let hero: HeroDef

    @Environment(\.dismiss) private var dismiss

    @State private var scene: GameScene = GameScene(size: CGSize(width: 1334,
                                                                 height: Balance.viewHeight))
    @State private var moveX: CGFloat = 0
    @State private var jumpHeld = false
    @State private var showMenu = false
    @State private var weapon: HeroWeapon = .blaster
    @State private var minimap = MinimapSnapshot(levelWidth: Balance.levelWidth, heroX: Balance.heroSpawnX,
                                                 cameraX: 0, viewWidth: 1334,
                                                 playerBaseX: Balance.playerBaseX,
                                                 playerTowerX: Balance.playerTowerX,
                                                 enemyTowerX: Balance.enemyTowerX,
                                                 enemyBaseX: Balance.enemyBaseX,
                                                 heroHP: Balance.heroHP, heroMaxHP: Balance.heroHP,
                                                 money: Balance.startingGold)
    private let debugTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            // Bottom controls sit BELOW the HUD so HUD buttons always win
            // hit-testing (this layer previously covered them and ate taps).
            // Joystick (bottom-left) runs the hero; push up to jump.
            HStack(alignment: .bottom) {
                JoystickView(moveX: $moveX, jumpHeld: $jumpHeld)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Top command strip, glued to the screen edge like the army tabs
            // are glued to the bottom. Compact minimap wins on narrow
            // screens via ViewThatFits.
            VStack(spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    commandBar(minimapWidth: 300)
                    commandBar(minimapWidth: 210)
                }
                Spacer()
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .top)

            // Bottom army tabs: flush with the screen edge so the battlefield
            // stays fully visible. Tap to summon when you can afford it.
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(ArmyKind.allCases) { kind in
                        ArmyCardButton(kind: kind, money: minimap.money) {
                            scene.summonAlly(kind: kind)
                        }
                    }
                    Spacer()
                }
                .padding(.leading, 10)
            }
            .ignoresSafeArea(edges: .bottom)

            // Pause menu overlay (sim is frozen while this is up).
            // Tap outside the card to resume automatically.
            if showMenu {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showMenu = false
                        scene.isPaused = false
                    }
                VStack(spacing: 14) {
                    Text("Paused")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Button("Resume") {
                        showMenu = false
                        scene.isPaused = false
                    }
                    .font(.headline)
                    .padding(.horizontal, 40).padding(.vertical, 10)
                    .background(.cyan)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
                    Button("Restart Level") {
                        scene.resetLevel()
                        scene.heroInputX = moveX
                        scene.heroJumpHeld = jumpHeld
                        weapon = scene.heroWeapon
                        showMenu = false
                    }
                    .font(.headline)
                    .padding(.horizontal, 40).padding(.vertical, 10)
                    .background(.white.opacity(0.15))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    Button("Quit to Menu") {
                        dismiss()
                    }
                    .font(.headline)
                    .padding(.horizontal, 40).padding(.vertical, 10)
                    .background(.white.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
                }
                .padding(30)
                .background(.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: moveX) { scene.heroInputX = $0 }
        .onChange(of: jumpHeld) { scene.heroJumpHeld = $0 }
        .onReceive(debugTimer) { _ in
            minimap = scene.minimap
        }
        .onAppear {
            scene.heroInputX = moveX
            scene.heroJumpHeld = jumpHeld
            weapon = scene.heroWeapon
        }
    }

    /// Single structured menu bar holding every top control:
    /// weapon switch | treasury | vitals | minimap | pause.
    /// Minimap width is parameterized so narrow screens get a compact strip.
    @ViewBuilder
    private func commandBar(minimapWidth: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 8) {
            // Weapon switch: tap to rotate Blaster -> Scatter -> Cannon.
            // Live mag/reserve readout (3/30); REL while reloading, red when dry.
            Button { weapon = scene.cycleWeapon() } label: {
                HStack(spacing: 6) {
                    // Little square with the actual pixel gun of the active
                    // weapon — oversized so it breaks out of the frame.
                    ZStack {
                        Rectangle()
                            .fill(.cyan.opacity(0.18))
                            .frame(width: 30, height: 30)
                            .overlay(Rectangle().stroke(.cyan.opacity(0.6), lineWidth: 2))
                        Image(uiImage: PixelHeroArt.gunImage(weapon))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 42, height: 23)
                            .offset(x: 3, y: -5)
                            .allowsHitTesting(false)
                    }
                    .frame(width: 30, height: 30)
                    .padding(.trailing, 8)
                    Text(minimap.ammoText)
                        .monospacedDigit()
                        .foregroundStyle(minimap.ammoMag == 0 ? .red
                            : minimap.reloading ? .gray : .white.opacity(0.85))
                    Image(systemName: "arrow.2.circlepath")
                        .foregroundStyle(.white.opacity(0.55))
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.cyan.opacity(0.16))
                .overlay(Rectangle().stroke(.cyan.opacity(0.6), lineWidth: 2))
            }

            HUDDivider()

            // Treasury.
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                Text("\(minimap.money)")
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.yellow)

            HUDDivider()

            // Hero vitals.
            HeroHealthBar(hp: minimap.heroHP, maxHP: minimap.heroMaxHP)
                .allowsHitTesting(false)

            Spacer(minLength: 4)
                .allowsHitTesting(false)

            MinimapView(snap: minimap, stripWidth: minimapWidth)
                .allowsHitTesting(false)

            Spacer(minLength: 4)
                .allowsHitTesting(false)

            HUDDivider()

            // Pause button: auto-pauses the sim and opens the menu.
            Button {
                scene.isPaused = true
                showMenu = true
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.12))
                    .overlay(Rectangle().stroke(.white.opacity(0.25), lineWidth: 2))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.78))
        .clipShape(PixelTopBarShape(cut: 7))
        .overlay(PixelTopBarShape(cut: 7).stroke(.white.opacity(0.2), lineWidth: 3))
    }
}

#Preview {
    NavigationStack {
        GameView(level: CampaignData.levels[0], hero: HeroRoster.heroes[0])
    }
}

/// Pixel-corner tab shape: chamfered top corners, flat bottom glued to the
/// screen edge. Hard stepped edges read as retro pixel UI (no smooth rounds).
private struct PixelTabShape: Shape {
    var cut: CGFloat = 7
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        p.addLine(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Pixel top strip: flat top glued to the screen edge, chamfered bottom
/// corners. Mirrors PixelTabShape so the HUD command bar matches the tabs.
private struct PixelTopBarShape: Shape {
    var cut: CGFloat = 7
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        p.closeSubpath()
        return p
    }
}

/// Bottom army tab: pixel-menu styling — chamfered hard corners, chunky
/// 3pt border, uppercase monospaced label + cost. No stats, just pick-and-go.
private struct ArmyCardButton: View {
    let kind: ArmyKind
    let money: Int
    let onTap: () -> Void

    private var affordable: Bool { money >= kind.cost }
    private let tabShape = PixelTabShape(cut: 7)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Live portrait: the real pixel sprite, torso-up with its
                // gun raised — breaking out of the little square on purpose.
                ZStack {
                    Rectangle()
                        .fill(affordable ? .cyan.opacity(0.18) : .white.opacity(0.08))
                        .frame(width: 30, height: 30)
                        .overlay(Rectangle().stroke(affordable ? Color.cyan : Color.gray.opacity(0.5),
                                                    lineWidth: 2))
                    Image(uiImage: UnitPixelArt.portraitImage(for: kind.pixelKind))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 48, height: 32)
                        .offset(x: -2, y: -7)
                        .saturation(affordable ? 1 : 0)
                        .opacity(affordable ? 1 : 0.6)
                        .allowsHitTesting(false)
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.name.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 3) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(kind.cost)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                    }
                    .foregroundStyle(affordable ? .yellow : .gray)
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 158, height: 48)
            .background(.black.opacity(affordable ? 0.78 : 0.55))
            .clipShape(tabShape)
            .overlay(tabShape.stroke(affordable ? Color.cyan : Color.gray.opacity(0.5), lineWidth: 3))
            .opacity(affordable ? 1.0 : 0.6)
        }
        .disabled(!affordable)
    }
}

/// Thin vertical separator between command-bar sections.
private struct HUDDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: 22)
            .allowsHitTesting(false)
    }
}

/// Hero vitals: heart + bar + live numbers (e.g. 78/100). Green -> red as HP
/// drops. Bare (no pill background) — it lives inside the command bar.
private struct HeroHealthBar: View {
    let hp: CGFloat
    let maxHP: CGFloat

    private var frac: CGFloat {
        guard maxHP > 0 else { return 0 }
        return min(1, max(0, hp / maxHP))
    }

    private var color: Color {
        if frac > 0.5 { return .green }
        if frac > 0.25 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(color)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 90, height: 10)
                Rectangle()
                    .fill(color)
                    .frame(width: 90 * frac, height: 10)
            }
            .overlay(Rectangle().stroke(.white.opacity(0.25), lineWidth: 1))
            Text("\(Int(hp))/\(Int(maxHP))")
                .font(.caption2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(.white)
        }
    }
}
