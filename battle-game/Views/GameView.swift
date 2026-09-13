import Combine
import SpriteKit
import SwiftUI

/// GameView — hosts the Level 1 SpriteKit battlefield + movement HUD.
/// Joystick (bottom-left) runs the hero; push the stick up to jump.
/// The right side is reserved for attack buttons in the combat stage.
struct GameView: View {
    let level: LevelDef
    let hero: HeroDef

    @State private var scene: GameScene = GameScene(size: CGSize(width: 1334,
                                                                 height: Balance.viewHeight))
    @State private var moveX: CGFloat = 0
    @State private var jumpHeld = false
    @State private var debugText = ""
    private let debugTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            VStack {
                HStack {
                    Label("Lv \(level.id) · \(level.name)", systemImage: "flag.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.black.opacity(0.55))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    // Temporary input/physics readout while tuning movement.
                    Text(debugText)
                        .font(.caption2.monospaced())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.black.opacity(0.55))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                    Spacer()
                    Label(hero.displayName, systemImage: "person.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.black.opacity(0.55))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
            .allowsHitTesting(false) // tags never steal touches from the controls

            // Bottom controls: joystick left (right side reserved for attack buttons).
            HStack(alignment: .bottom) {
                JoystickView(moveX: $moveX, jumpHeld: $jumpHeld)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Battle")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: moveX) { scene.heroInputX = $0 }
        .onChange(of: jumpHeld) { scene.heroJumpHeld = $0 }
        .onReceive(debugTimer) { _ in debugText = scene.debugLine }
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
