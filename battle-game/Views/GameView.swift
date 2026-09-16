import Combine
import SpriteKit
import SwiftUI

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

            // Unified command bar: weapon | treasury | vitals | minimap | pause.
            // Compact minimap variant wins on narrow screens via ViewThatFits.
            VStack(spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    commandBar(minimapWidth: 300)
                    commandBar(minimapWidth: 210)
                }
                Spacer()
                    .allowsHitTesting(false)
            }

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
            if showMenu {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
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
            Button { weapon = scene.cycleWeapon() } label: {
                HStack(spacing: 6) {
                    Image(systemName: weapon.icon)
                        .foregroundStyle(.cyan)
                    Text(weapon.name)
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.2.circlepath")
                        .foregroundStyle(.white.opacity(0.55))
                }
                .font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.cyan.opacity(0.16))
                .overlay(Capsule().stroke(.cyan.opacity(0.45), lineWidth: 1))
                .clipShape(Capsule())
            }

            HUDDivider()

            // Treasury.
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                Text("\(minimap.money)")
                    .monospacedDigit()
            }
            .font(.caption.bold())
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
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }
}

#Preview {
    NavigationStack {
        GameView(level: CampaignData.levels[0], hero: HeroRoster.heroes[0])
    }
}

/// Bottom army tab: compact horizontal tab with rounded top corners and a
/// flat bottom glued to the screen edge. Same width as before, dimmed +
/// disabled when broke; tap summons the unit at the player base.
private struct ArmyCardButton: View {
    let kind: ArmyKind
    let money: Int
    let onTap: () -> Void

    private var affordable: Bool { money >= kind.cost }
    private var tabShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0,
                               bottomTrailingRadius: 0, topTrailingRadius: 12)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.body.bold())
                    .foregroundStyle(affordable ? .cyan : .gray)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.name)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Label("\(kind.cost)", systemImage: "dollarsign.circle.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(affordable ? .yellow : .gray)
                        .lineLimit(1)
                }
                Text("HP \(Int(kind.hp))\nDMG \(Int(kind.damage))")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .frame(width: 158, height: 50)
            .background(.black.opacity(affordable ? 0.65 : 0.45))
            .clipShape(tabShape)
            .overlay(tabShape.stroke(affordable ? Color.cyan : Color.gray.opacity(0.5), lineWidth: 1.5))
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
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(width: 90, height: 8)
                Capsule()
                    .fill(color)
                    .frame(width: 90 * frac, height: 8)
            }
            Text("\(Int(hp))/\(Int(maxHP))")
                .font(.caption2.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}
