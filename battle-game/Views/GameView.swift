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

            // Top HUD pinned to the safe-area top: back + level | minimap | hero.
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    HStack(spacing: 6) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.caption.bold())
                                .padding(8)
                                .background(.black.opacity(0.55))
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                        }
                        Label("Lv \(level.id)", systemImage: "flag.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.black.opacity(0.55))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .allowsHitTesting(false)
                        // Gold for the coming unit shop.
                        Label("\(minimap.money)", systemImage: "dollarsign.circle.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.black.opacity(0.55))
                            .foregroundStyle(.yellow)
                            .clipShape(Capsule())
                            .allowsHitTesting(false)
                        // Hero HP bar with live numbers.
                        HeroHealthBar(hp: minimap.heroHP, maxHP: minimap.heroMaxHP)
                            .allowsHitTesting(false)
                    }
                    Spacer()
                        .allowsHitTesting(false)
                    MinimapView(snap: minimap)
                        .allowsHitTesting(false)
                    Spacer()
                        .allowsHitTesting(false)
                    // Pause button: auto-pauses the sim and opens the menu.
                    Button {
                        scene.isPaused = true
                        showMenu = true
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.caption.bold())
                            .padding(10)
                            .background(.black.opacity(0.55))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)
                Spacer()
                    .allowsHitTesting(false)
            }

            // Bottom controls: joystick left (right side reserved for attack buttons).
            HStack(alignment: .bottom) {
                JoystickView(moveX: $moveX, jumpHeld: $jumpHeld)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
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

/// Hero health bar + live numbers (e.g. 78/100). Green -> red as HP drops.
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
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 110, height: 10)
                Capsule()
                    .fill(color)
                    .frame(width: 110 * frac, height: 10)
            }
            Text("\(Int(hp))/\(Int(maxHP))")
                .font(.caption2.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.black.opacity(0.55))
        .clipShape(Capsule())
    }
}
