import Combine
import SpriteKit
import SwiftUI
import UIKit // UIImage portraits from UnitPixelArt

/// GameView — hosts the Level 1 SpriteKit battlefield + movement HUD.
/// Joystick (bottom-left) runs the hero; push the stick up to jump.
/// Tap/drag the right side to aim + shoot (handled in GameScene).
struct GameView: View {
    let level: LevelDef
    /// Deploying hero. Mutable so the Level 8 milestone modal can hand
    /// the player their newly-claimed hero mid-battle.
    @State private var hero: HeroDef
    /// Campaign path. Continue swaps the finished battle for the next
    /// briefing (releasing the scene); Map buttons pop back to the map.
    @Binding var path: NavigationPath

    @Environment(\.dismiss) private var dismiss

    /// Builds the scene pinned to this level's battlefield layout (width,
    /// towers, theme) before anything reads Balance. The hero deploys with
    /// the level-screen gun pick (clamped to unlocked inside the scene).
    init(level: LevelDef, hero: HeroDef, path: Binding<NavigationPath>) {
        self.level = level
        _hero = State(initialValue: hero)
        _path = path
        Balance.active = Balance.layout(for: level.id)
        let gun = GunLocker.selectedGun
        _scene = State(initialValue: GameScene(size: CGSize(width: 1334,
                                                            height: Balance.viewHeight),
                                               levelId: level.id,
                                               weapon: gun,
                                               heroId: hero.id))
        _weapon = State(initialValue: gun)
    }

    @State private var scene: GameScene
    @State private var showMenu = false
    @State private var showWin = false
    @State private var winStars = 0
    @State private var winTime: Double = 0
    /// Last victory's diamond split (shown on the win card).
    @State private var winClearDiamonds = 0
    @State private var winLeftoverDiamonds = 0
    @State private var winWasRepeat = false
    /// Animated diamond count-up (flight starts when it lands).
    @State private var winDiamondsShown = 0
    @State private var winCountDone = false
    /// Diamond flight to the HUD wallet (buttons unlock when it lands).
    @State private var winFlyT: Double = 0
    @State private var flyingDiamonds = false
    @State private var flyCount = 5
    @State private var winFlyDone = false
    /// HUD wallet pop when the flight lands and fills it.
    @State private var hudPop = false
    /// When the winning blow landed (wall clock). The card waits 2s while
    /// the battle keeps raging behind it.
    @State private var winDetectedAt: Date?
    /// When the losing blow landed (wall clock). The card waits 1s while
    /// the battlefield settles, then rises.
    @State private var defeatDetectedAt: Date?
    @State private var showDefeat = false
    /// One revive per run (ad or diamonds — player's choice, then gone).
    @State private var revivedThisRun = false
    /// Simulated-ad overlay while the stub ad "plays".
    @State private var showAdOverlay = false
    @State private var adProgress: Double = 0
    @ObservedObject private var wallet = WalletStore.shared
    /// New-unit intel card: levels that debut a unit pause 1s after entry
    /// and brief the player (stats + portrait) until dismissed.
    @State private var showUnitIntro = false
    /// Level 11 fortress-line intel: introduces the fourth tower that now
    /// anchors each base. Freezes the field until the player dismisses it.
    @State private var showTowerIntro = false
    /// Level 5 grant sequence: 1 = free gun slot, 2 = Scatter gun.
    /// Shown one modal after another on battle entry; each CLAIM grants.
    @State private var grantStep: Int?
    @State private var weapon: HeroWeapon = .blaster
    /// Why the last deploy tap was refused (toast). Nil = none.
    @State private var deployRefusal: String?
    /// Milestone hero unlocked by this level's briefing (shown once, then
    /// claimed + auto-equipped). Nil when nothing new or already owned.
    @State private var heroUnlock: HeroDef?
    @State private var minimap = MinimapSnapshot(levelWidth: Balance.levelWidth, heroX: Balance.heroSpawnX,
                                                 cameraX: 0, viewWidth: 1334,
                                                 playerBaseX: Balance.playerBaseX,
                                                  playerTowerXs: Balance.playerTowerXs,
                                                  enemyTowerXs: Balance.enemyTowerXs,
                                                 enemyBaseX: Balance.enemyBaseX,
                                                 heroHP: Balance.heroHP, heroMaxHP: Balance.heroHP,
                                                 money: Balance.startingGold)
    /// Polls the scene for HUD/minimap state at ~7Hz.
    private let debugTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            // Bottom controls sit BELOW the HUD so HUD buttons always win
            // hit-testing (this layer previously covered them and ate taps).
            // Joystick (bottom-left) runs the hero; push up to jump.
            HStack(alignment: .bottom) {
                JoystickView(onMove: { scene.heroInputX = $0 },
                            onJump: { scene.heroJumpHeld = $0 })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Top command strip with the army tabs tucked directly beneath
            // it. Keeping the tabs off the bottom edge avoids the iPhone
            // home-gesture zone entirely. Compact minimap wins on narrow
            // screens via ViewThatFits.
            VStack(spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    commandBar(minimapWidth: 230)
                    commandBar(minimapWidth: 160)
                }
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        // Locked units aren't shown at all (Heavy arrives L2+).
                        ForEach(ArmyKind.allCases.filter { ArmyKind.isUnlocked($0, levelId: level.id) }) { kind in
                            ArmyCardButton(kind: kind, money: minimap.money,
                                           cooldownFrac: cooldownFraction(for: kind),
                                           armyFull: minimap.allyCount >= minimap.allyCap) {
                                if !scene.summonAlly(kind: kind) {
                                    deployRefusal = scene.summonRefusal(for: kind)
                                    // Auto-clear the toast so it never sticks.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                        deployRefusal = nil
                                    }
                                } else {
                                    deployRefusal = nil
                                }
                            }
                        }
                        Spacer()
                    }
                    // Refusal toast: explains WHY a deploy didn't happen
                    // (army full / not enough gold / still recharging).
                    if let refusal = deployRefusal {
                        Text(refusal)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.red.opacity(0.9))
                            .clipShape(PixelPanelShape(cut: 5))
                            .overlay(PixelPanelShape(cut: 5).stroke(.white.opacity(0.6), lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.5), radius: 6)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                HStack {
                    Spacer(minLength: 0)
                    PerformanceOverlay(scene: scene)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 14)
                .padding(.trailing, 36)
                Spacer()
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .top)

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
                VStack(spacing: 12) {
                    Text("PAUSED")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(.white)
                    // Pixel divider: line — diamond — line.
                    HStack(spacing: 6) {
                        Rectangle().fill(.cyan.opacity(0.6)).frame(width: 52, height: 2)
                        Rectangle().fill(.cyan).frame(width: 8, height: 8)
                        Rectangle().fill(.cyan.opacity(0.6)).frame(width: 52, height: 2)
                    }
                    PixelMenuButton(title: "Resume", style: .primary) {
                        SoundEngine.shared.uiTap()
                        showMenu = false
                        scene.isPaused = false
                    }
                    PixelMenuButton(title: "Restart Level", style: .ghost) {
                        SoundEngine.shared.uiTap()
                        scene.resetLevel()
                        scene.heroInputX = 0
                        scene.heroJumpHeld = false
                        weapon = scene.heroWeapon
                        showMenu = false
                        showDefeat = false
                    }
                    PixelMenuButton(title: "Quit to Menu", style: .danger) {
                        SoundEngine.shared.uiTap()
                        path = NavigationPath()
                    }
                    Text("TAP OUTSIDE TO RESUME")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 2)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
                .background(.black.opacity(0.88))
                .clipShape(PixelPanelShape(cut: 10))
                .overlay(PixelPanelShape(cut: 10).stroke(.cyan.opacity(0.55), lineWidth: 3))
                .shadow(color: .cyan.opacity(0.15), radius: 16)
            }

            // Victory card: enemy HQ destroyed. Congrats, clear time, stars.
            if showWin {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    Text("VICTORY")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(.yellow)
                    Text(level.name.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        Rectangle().fill(.yellow.opacity(0.6)).frame(width: 52, height: 2)
                        Rectangle().fill(.yellow).frame(width: 8, height: 8)
                        Rectangle().fill(.yellow.opacity(0.6)).frame(width: 52, height: 2)
                    }
                    // Pixel stars earned for this clear.
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            PixelStarView(lit: i < winStars)
                        }
                    }
                    // Clear time.
                    HStack(spacing: 6) {
                        Text("TIME")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.55))
                        Text(formatTime(winTime))
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 2)
                    // Diamond payout: clear reward + converted leftover gold.
                    // Counts up with coin ticks, then flies up to the HUD
                    // wallet; buttons unlock when the flight lands.
                    HStack(spacing: 6) {
                        PixelDiamondView()
                            .scaleEffect(winCountDone ? 1.0 : 1.25)
                            .animation(.easeInOut(duration: 0.3), value: winCountDone)
                        Text("+\(winDiamondsShown) DIAMONDS")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(1)
                            .monospacedDigit()
                            .foregroundStyle(.cyan)
                    }
                    .anchorPreference(key: WinDiamondsAnchorKey.self, value: .center) { $0 }
                    .padding(.top, 2)
                    Text("CLEAR \(winClearDiamonds) · GOLD \(winLeftoverDiamonds)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                    PixelMenuButton(title: "Play Again", style: .ghost) {
                        SoundEngine.shared.uiTap()
                        resetWinState()
                        scene.resetLevel()
                        scene.heroInputX = 0
                        scene.heroJumpHeld = false
                        weapon = scene.heroWeapon
                        showWin = false
                        winDetectedAt = nil
                        revivedThisRun = false
                        scene.isPaused = false
                    }
                    .disabled(!winFlyDone)
                    .opacity(winFlyDone ? 1 : 0.4)
                    if nextLevel != nil {
                        PixelMenuButton(title: "Continue", style: .primary) {
                            SoundEngine.shared.uiTap()
                            continueToNextLevel()
                        }
                        .disabled(!winFlyDone)
                        .opacity(winFlyDone ? 1 : 0.4)
                    } else {
                        // Final level: Continue heads back to the map.
                        PixelMenuButton(title: "Continue", style: .primary) {
                            SoundEngine.shared.uiTap()
                            popToMap()
                        }
                        .disabled(!winFlyDone)
                        .opacity(winFlyDone ? 1 : 0.4)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
                .background(.black.opacity(0.9))
                .clipShape(PixelPanelShape(cut: 10))
                .overlay(PixelPanelShape(cut: 10).stroke(.yellow.opacity(0.6), lineWidth: 3))
                .shadow(color: .yellow.opacity(0.2), radius: 18)
            }

            // Defeat card: last heart lost. Compact by design — landscape
            // phones are short, so tight spacing, small type, and Retry /
            // Map share a row. Retry restores all 3 hearts.
            if showDefeat {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                VStack(spacing: 6) {
                    Text("MISSION FAILED")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.red)
                    Text(level.name.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        Rectangle().fill(.red.opacity(0.6)).frame(width: 36, height: 2)
                        Rectangle().fill(.red).frame(width: 8, height: 8)
                        Rectangle().fill(.red.opacity(0.6)).frame(width: 36, height: 2)
                    }
                    // Spent hearts: all dimmed — the reason the run ended.
                    HStack(spacing: 6) {
                        ForEach(0..<minimap.heroMaxLives, id: \.self) { _ in
                            PixelHeartView(color: .gray)
                                .saturation(0)
                                .opacity(0.25)
                        }
                    }
                    // One revive per battle (ad or diamonds). Hidden once
                    // spent — or when the HQ itself is rubble (reviving the
                    // hero then would still be a defeat).
                    if !revivedThisRun, scene.playerBaseAlive {
                        Text("REVIVE — ONE PER BATTLE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.yellow)
                            .padding(.top, 2)
                        PixelMenuButton(title: "Revive · Watch Ad", style: .primary) {
                            SoundEngine.shared.uiTap()
                            startAdRevive()
                        }
                        ReviveDiamondButton(cost: Economy.reviveDiamondCost(levelId: level.id),
                                            balance: wallet.diamonds) {
                            if WalletStore.shared.spend(Economy.reviveDiamondCost(levelId: level.id)) {
                                SoundEngine.shared.uiTap()
                                doRevive()
                            }
                        }
                        HStack(spacing: 5) {
                            PixelDiamondView()
                            Text("BALANCE \(wallet.diamonds)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .monospacedDigit()
                                .foregroundStyle(.cyan)
                        }
                    } else {
                        Text("ALL HEARTS LOST")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    HStack(spacing: 8) {
                        PixelMenuButton(title: "Retry", style: .primary, width: 140) {
                            SoundEngine.shared.uiTap()
                            scene.resetLevel()
                            scene.heroInputX = 0
                            scene.heroJumpHeld = false
                            weapon = scene.heroWeapon
                            showDefeat = false
                            revivedThisRun = false
                            scene.isPaused = false
                        }
                        PixelMenuButton(title: "Map", style: .ghost, width: 140) {
                            SoundEngine.shared.uiTap()
                            popToMap()
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .background(.black.opacity(0.9))
                .clipShape(PixelPanelShape(cut: 10))
                .overlay(PixelPanelShape(cut: 10).stroke(.red.opacity(0.6), lineWidth: 3))
                .shadow(color: .red.opacity(0.2), radius: 18)
            }

            // Simulated rewarded ad: pixel progress bar over 3s, then the
            // revive lands. No cancel — the stub always grants, and the
            // real SDK will own this screen later.
            if showAdOverlay {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("SPONSORED MESSAGE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.6))
                    PixelDiamondView()
                        .scaleEffect(2.0)
                        .padding(.vertical, 8)
                        .opacity(0.5 + 0.5 * adProgress)
                    Text("REVIVE INCOMING…")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.yellow)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(.white.opacity(0.12))
                                .frame(height: 10)
                            Rectangle()
                                .fill(.cyan)
                                .frame(width: geo.size.width * min(1, max(0, adProgress)),
                                       height: 10)
                        }
                    }
                    .frame(width: 220, height: 10)
                    .overlay(Rectangle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
                .background(.black.opacity(0.9))
                .clipShape(PixelPanelShape(cut: 10))
                .overlay(PixelPanelShape(cut: 10).stroke(.cyan.opacity(0.5), lineWidth: 3))
            }

            // New-unit intel: debut unit for THIS level (portrait + stats).
            // Close button or tap outside dismisses and resumes the sim.
            if showUnitIntro, let debut = debutUnit {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeUnitIntro() }
                VStack(spacing: 10) {
                    Text("NEW UNIT")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(.yellow)
                    Image(uiImage: UnitPixelArt.portraitImage(for: debut.pixelKind))
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 80)
                        .background(.black.opacity(0.6))
                        .clipShape(PixelPanelShape(cut: 8))
                        .overlay(PixelPanelShape(cut: 8).stroke(.yellow, lineWidth: 2))
                        .shadow(color: .yellow.opacity(0.4), radius: 10)
                    Text(debut.name.uppercased())
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white)
                    Text(debut.blurb)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(spacing: 14) {
                        UnitStatChip(label: "HP", value: "\(Int(debut.hp))")
                        UnitStatChip(label: "DMG", value: "\(Int(debut.damage))")
                        UnitStatChip(label: "SPD", value: "\(Int(debut.speed))")
                        UnitStatChip(label: "COST", value: "\(debut.cost)")
                    }
                    PixelMenuButton(title: "Close", style: .primary) {
                        SoundEngine.shared.uiTap()
                        closeUnitIntro()
                    }
                    Text("TAP OUTSIDE TO RESUME")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .background(.black.opacity(0.9))
                .clipShape(PixelPanelShape(cut: 10))
                .overlay(PixelPanelShape(cut: 10).stroke(.yellow.opacity(0.6), lineWidth: 3))
                .shadow(color: .yellow.opacity(0.2), radius: 18)
            }

            // Level 11 fortress-line intel: announces the fourth tower that
            // now anchors each base. Close/tap outside resumes the sim.
            if showTowerIntro {
                Color.black.opacity(0.68)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeTowerIntro() }

                // Fits as-is on normal screens; on very short viewports the
                // fallback scrolls so the whole card stays reachable.
                ViewThatFits(in: .vertical) {
                    towerIntroCard
                    ScrollView(.vertical, showsIndicators: false) {
                        towerIntroCard
                    }
                    .frame(maxWidth: 330)
                }
                .padding(.vertical, 12)
            }

            // Milestone hero unlock (Level 8 = Vanguard): portrait + stats, then
            // CLAIM persists the unlock, auto-equips, and resumes.
            if let fresh = heroUnlock {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    Text("NEW HERO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(.orange)
                    Image(uiImage: HeroPixelArt.portraitImage(for: fresh.pixelKind))
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 90)
                        .background(.black.opacity(0.6))
                        .clipShape(PixelPanelShape(cut: 8))
                        .overlay(PixelPanelShape(cut: 8).stroke(.orange, lineWidth: 2))
                        .shadow(color: .orange.opacity(0.4), radius: 10)
                    Text(fresh.displayName.uppercased())
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white)
                    Text(fresh.trait.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.orange)
                    Text(fresh.blurb)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(spacing: 14) {
                        UnitStatChip(label: "HP", value: "\(fresh.maxHealth)")
                        UnitStatChip(label: "DMG", value: "\(fresh.baseDamage)")
                        UnitStatChip(label: "SPD", value: "\(Int(fresh.speed))")
                    }
                    PixelMenuButton(title: "Deploy \(fresh.displayName)", style: .primary) {
                        SoundEngine.shared.uiTap()
                        claimHeroUnlock()
                    }
                    PixelMenuButton(title: "Keep Current Hero", style: .ghost) {
                        SoundEngine.shared.uiTap()
                        dismissHeroUnlock()
                    }
                    Text("AUTO-EQUIPPED FOR THIS RUN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .background(.black.opacity(0.9))
                .clipShape(PixelPanelShape(cut: 10))
                .overlay(PixelPanelShape(cut: 10).stroke(.orange.opacity(0.6), lineWidth: 3))
                .shadow(color: .orange.opacity(0.2), radius: 18)
            }

            // Level 5 grants: modal 1 = free gun slot, modal 2 = Scatter.
            // One after another; each CLAIM grants immediately. Paused sim.
            if let step = grantStep {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    Text(step == 1 ? "EXTRA GUN SLOT" : "NEW GUN")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(.cyan)
                    if step == 1 {
                        Text("SLOT 2 — FREE")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white)
                        Text("HQ expanded your loadout. Carry two guns into battle — swap anytime with the HUD button.")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    } else {
                        Image(uiImage: PixelHeroArt.gunImage(.scatter))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 70)
                            .background(.black.opacity(0.6))
                            .clipShape(PixelPanelShape(cut: 8))
                            .overlay(PixelPanelShape(cut: 8).stroke(.yellow, lineWidth: 2))
                            .shadow(color: .yellow.opacity(0.4), radius: 10)
                        Text(HeroWeapon.scatter.name.uppercased())
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white)
                        Text(HeroWeapon.scatter.blurb)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                        HStack(spacing: 14) {
                            UnitStatChip(label: "DMG", value: "\(Int(HeroWeapon.scatter.damage))×\(HeroWeapon.scatter.pelletCount)")
                            UnitStatChip(label: "MAG", value: "\(HeroWeapon.scatter.magSize)")
                            UnitStatChip(label: "SLOT", value: "2")
                        }
                    }
                    PixelMenuButton(title: step == 1 ? "Claim Slot" : "Claim Scatter", style: .primary) {
                        SoundEngine.shared.uiTap()
                        claimGrantStep()
                    }
                    Text("STEP \(step) OF 2")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .background(.black.opacity(0.9))
                .clipShape(PixelPanelShape(cut: 10))
                .overlay(PixelPanelShape(cut: 10).stroke(.cyan.opacity(0.6), lineWidth: 3))
                .shadow(color: .cyan.opacity(0.2), radius: 18)
            }

            // Diamond flight layer: after the win-card count-up, gems arc
            // from the card to the HUD wallet (which fills as they land).
            // Anchors bridge the two spots; nothing renders when idle.
            Color.clear
                .allowsHitTesting(false)
                .overlayPreferenceValue(HudDiamondsAnchorKey.self) { hud in
                    Color.clear
                        .overlayPreferenceValue(WinDiamondsAnchorKey.self) { card in
                            GeometryReader { geo in
                                if flyingDiamonds, let from = card, let to = hud {
                                    let start = geo[from]
                                    let end = geo[to]
                                    ForEach(0..<flyCount, id: \.self) { i in
                                        // Staggered takeoffs along the same arc.
                                        let t = min(1, max(0, winFlyT * 1.5 - Double(i) * 0.07))
                                        let eased = t * t * (3 - 2 * t)
                                        let pos = CGPoint(
                                            x: start.x + (end.x - start.x) * eased,
                                            y: start.y + (end.y - start.y) * eased
                                                - sin(eased * .pi) * 40)
                                        PixelDiamondView()
                                            .position(pos)
                                            .scaleEffect(1.1 - 0.5 * eased)
                                            .opacity(t >= 1 ? 0 : 1)
                                    }
                                }
                            }
                        }
                }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(debugTimer) { _ in
            let snapshot = scene.minimap
            if snapshot != minimap { minimap = snapshot }
            // Auto-switches in the scene change the active gun behind our
            // back — mirror it so the HUD portrait stays honest.
            if weapon != scene.heroWeapon { weapon = scene.heroWeapon }
            // Enemy HQ down -> let the win breathe 2s with the sim still
            // running, then freeze the frame, bank it, raise the card.
            if minimap.won, !showWin, !showDefeat {
                if winDetectedAt == nil {
                    winDetectedAt = Date()
                } else if Date().timeIntervalSince(winDetectedAt!) >= 2 {
                    winDetectedAt = nil
                    showWin = true
                    showMenu = false
                    scene.isPaused = true
                    winTime = minimap.winTime
                    winStars = starsFor(time: minimap.winTime)
                    // Diamond payout: clear reward (diminished on repeats) +
                    // leftover war gold auto-converts (gold resets per run).
                    // Repeat-ness reads BEFORE banking the stars.
                    winWasRepeat = CampaignData.stars(for: level.id) > 0
                    winClearDiamonds = Economy.clearReward(levelId: level.id, stars: winStars,
                                                          isRepeat: winWasRepeat)
                    winLeftoverDiamonds = Economy.leftoverReward(gold: minimap.money)
                    CampaignData.awardStars(winStars, for: level.id)
                    resetWinState()
                    startDiamondCountUp(total: winClearDiamonds + winLeftoverDiamonds)
                    SoundEngine.shared.stopBattleMusic()
                    SoundEngine.shared.victory()
                }
            } else if !minimap.won {
                winDetectedAt = nil
            }
            // Last heart lost -> let the dust settle 1s with the sim still
            // running, then freeze the frame and raise the defeat card.
            if minimap.lost, !showDefeat {
                if defeatDetectedAt == nil {
                    defeatDetectedAt = Date()
                } else if Date().timeIntervalSince(defeatDetectedAt!) >= 1 {
                    defeatDetectedAt = nil
                    showDefeat = true
                    showMenu = false
                    showWin = false
                    scene.isPaused = true
                    SoundEngine.shared.stopBattleMusic()
                }
            } else if !minimap.lost {
                defeatDetectedAt = nil
            }
        }
        .onAppear {
            scene.heroInputX = 0
            scene.heroJumpHeld = false
            weapon = scene.heroWeapon
            revivedThisRun = false
            // New-unit briefing: let the battle breathe 1s, then freeze and brief.
            // Level 11 sequences this AFTER the fortress-line card instead.
            if debutUnit != nil, level.id != 11 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    guard debutUnit != nil, !showUnitIntro,
                          !minimap.won, !minimap.lost else { return }
                    showUnitIntro = true
                    showMenu = false
                    scene.isPaused = true
                }
            }
            // Level 11 fortress-line briefing: let the field settle, then
            // freeze it and announce the fourth tower at each base.
            if level.id == 11 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    guard !showTowerIntro, !showUnitIntro, grantStep == nil,
                          heroUnlock == nil, !minimap.won, !minimap.lost else { return }
                    showTowerIntro = true
                    showMenu = false
                    scene.isPaused = true
                }
            }
            // Level 5 grants: free slot 2, then the Scatter — one modal
            // after another, 1.2s after entry so the field reads first.
            // Grants persist, so replays skip whatever is already owned.
            if level.id == 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    guard grantStep == nil, !showUnitIntro,
                          !minimap.won, !minimap.lost else { return }
                    if LoadoutStore.slotCount < 2 {
                        grantStep = 1
                    } else if !UnlockStore.owns(.scatter) {
                        grantStep = 2
                    } else { return }
                    showMenu = false
                    scene.isPaused = true
                }
            }
            // Hero milestone unlock: freeze the field and hand the player their
            // new hero, then deploy them for the rest of this run.
            if let fresh = milestoneHero {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    guard heroUnlock == nil, !showUnitIntro, grantStep == nil,
                          !minimap.won, !minimap.lost else { return }
                    heroUnlock = fresh
                    showMenu = false
                    scene.isPaused = true
                }
            }
        }
        .onDisappear {
            SoundEngine.shared.stopBattleMusic()
            // Hand the global layout back to the menu/briefing dioramas.
            Balance.battleOwnsLayout = false
        }
    }

    /// Victory stars from clear time: fast clears earn the full row.
    private func starsFor(time: Double) -> Int {
        if time <= 180 { return 3 }
        if time <= 300 { return 2 }
        return 1
    }

    /// Next campaign level, if any (Continue hides on the final level).
    private var nextLevel: LevelDef? {
        CampaignData.levels.first(where: { $0.id == level.id + 1 })
    }

    /// Continue: pops the finished battle + its deployment screen + the
    /// old briefing (its scene is released) and pushes the next briefing in
    /// a single path update — BACK from that briefing lands on the map.
    private func continueToNextLevel() {
        var p = path
        while p.count > 1 { p.removeLast() }
        p.append(Route.detail(levelId: level.id + 1))
        path = p
    }

    /// Pops battle + deployment + briefing back to the map.
    private func popToMap() {
        var p = path
        while p.count > 1 { p.removeLast() }
        path = p
    }

    /// Diamond count-up: ticks 0 → total over ~1.2s with coin ticks, then
    /// launches the HUD flight (the wallet fills when it lands).
    private func startDiamondCountUp(total: Int) {
        guard total > 0 else {
            winDiamondsShown = 0
            winCountDone = true
            startDiamondFlight(total: 0)
            return
        }
        Task {
            let steps = min(max(total, 1), 24)
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: 50_000_000)
                await MainActor.run {
                    winDiamondsShown = Int((Double(total) * Double(i) / Double(steps)).rounded())
                    if i % 4 == 0 { SoundEngine.shared.pickup() }
                }
            }
            await MainActor.run {
                winDiamondsShown = total
                winCountDone = true
                startDiamondFlight(total: total)
            }
        }
    }

    /// Diamond flight: gems arc from the win card up to the HUD wallet.
    /// The wallet fills (with a pop) exactly when they land — that's also
    /// when the win-card buttons unlock.
    private func startDiamondFlight(total: Int) {
        flyCount = min(9, max(4, total / 4))
        winFlyT = 0
        flyingDiamonds = total > 0
        guard total > 0 else {
            winFlyDone = true
            return
        }
        withAnimation(.easeInOut(duration: 0.9)) { winFlyT = 1 }
        Task {
            try? await Task.sleep(nanoseconds: 950_000_000)
            await MainActor.run {
                WalletStore.shared.earn(total)
                SoundEngine.shared.pickup()
                flyingDiamonds = false
                winFlyDone = true
                hudPop = true
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            await MainActor.run { hudPop = false }
        }
    }

    /// Clears all win-card animation state (fresh count on every victory).
    private func resetWinState() {
        winDiamondsShown = 0
        winCountDone = false
        winFlyT = 0
        flyingDiamonds = false
        flyCount = 5
        winFlyDone = false
        hudPop = false
    }

    /// Level 11 card: the enemy's red tower rendered in the same procedural
    /// pixel art as the battlefield, with the new four-tower line called out.
    private var towerIntroCard: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(.orange.opacity(0.45))
                    .frame(width: 22, height: 1)
                Text("NEW FORTIFICATION")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(.orange)
                Rectangle()
                    .fill(.orange.opacity(0.45))
                    .frame(width: 22, height: 1)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [.red.opacity(0.20),
                                                 .black.opacity(0.78)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 172, height: 132)
                Rectangle()
                    .fill(.red.opacity(0.24))
                    .frame(width: 172, height: 1)
                    .offset(y: 46)
                Image(uiImage: TowerNode.previewImage(for: .enemy))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 118)
                    .shadow(color: .red.opacity(0.55), radius: 14)
            }
            .frame(width: 172, height: 132)
            .clipShape(PixelPanelShape(cut: 8))
            .overlay(PixelPanelShape(cut: 8).stroke(.red.opacity(0.8), lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                Text("×4")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(.red)
                    .padding(6)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(.red)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(7)
            }

            Text("FORTRESS LINE")
                .font(.system(size: 19, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white)
            Text("BOTH BASES: 4 TOWERS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.red)
            Text("A fourth gun emplacement now anchors each base. The red tower below is the enemy's new fortification — another three-bolt volley between you and their HQ.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: 280)
            HStack(spacing: 10) {
                UnitStatChip(label: "TOWERS", value: "4 / SIDE")
                UnitStatChip(label: "TOWER HP", value: "\(Int(Balance.enemyTowerHealth(forLevel: level.id)))")
                UnitStatChip(label: "RANGE", value: "\(Int(Balance.towerRange))")
            }
            Text("TAP OUTSIDE TO RESUME")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.black.opacity(0.92))
        .clipShape(PixelPanelShape(cut: 10))
        .overlay(PixelPanelShape(cut: 10).stroke(.red.opacity(0.65), lineWidth: 3))
        .shadow(color: .red.opacity(0.25), radius: 20)
    }

    /// Unit debuting on this level, if any (Ranger on Level 2, Heavy on
    /// Level 3). Nil keeps entry instant — no modal, no pause.
    private var debutUnit: ArmyKind? {
        ArmyKind.allCases.first(where: { $0.unlockLevel == level.id })
    }

    /// Deploy-cooldown veil fraction for a summon tile (0 = ready).
    /// Reads the SCENE's clock so the card can never claim "ready" while
    /// the scene still refuses the deploy.
    private func cooldownFraction(for kind: ArmyKind) -> Double {
        let remaining = minimap.summonCooldowns[kind] ?? 0
        guard remaining > 0, kind.cooldown > 0 else { return 0 }
        return min(1, remaining / kind.cooldown)
    }

    /// Hero this level unlocks (Vanguard at Level 8), only while it is
    /// still unclaimed. Already-owned milestones never re-modal.
    private var milestoneHero: HeroDef? {
        HeroRoster.heroes.first { $0.unlockLevel == level.id && !HeroRoster.isUnlocked($0) }
    }

    /// CLAIM the milestone hero: persist the unlock, auto-equip it for the
    /// rest of this run, and resume the battle.
    private func claimHeroUnlock() {
        guard let fresh = heroUnlock else { return }
        HeroRosterClaims.claim(fresh)
        hero = fresh
        scene.setHero(fresh.id)
        SoundEngine.shared.pickup()
        heroUnlock = nil
        scene.isPaused = false
    }

    /// Decline the milestone hero: it still unlocks for the armory (no
    /// claim is spent), the current hero keeps deploying this run.
    private func dismissHeroUnlock() {
        if let fresh = heroUnlock {
            HeroRosterClaims.record(fresh)
        }
        heroUnlock = nil
        scene.isPaused = false
    }

    private func closeUnitIntro() {
        showUnitIntro = false
        scene.isPaused = false
    }

    /// Dismiss the Level 11 fortress-line intel, then hand off to the
    /// Bombard's NEW UNIT card (both debut on this level).
    private func closeTowerIntro() {
        showTowerIntro = false
        if level.id == 11, debutUnit != nil, !minimap.won, !minimap.lost {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard !showUnitIntro, !showTowerIntro,
                      !minimap.won, !minimap.lost else { return }
                showUnitIntro = true
                scene.isPaused = true
            }
        } else {
            scene.isPaused = false
        }
    }

    /// Level 5 grant CLAIM: step 1 grants the free slot (if still missing)
    /// then advances to step 2; step 2 grants + slots the Scatter, then
    /// resumes. Grants persist so replays never re-offer them.
    private func claimGrantStep() {
        guard let step = grantStep else { return }
        if step == 1 {
            if LoadoutStore.slotCount < 2 { LoadoutStore.grantSlot() }
            SoundEngine.shared.pickup()
            grantStep = UnlockStore.owns(.scatter) ? nil : 2
        } else {
            UnlockStore.grant(.scatter)
            if LoadoutStore.slotCount >= 2 {
                _ = LoadoutStore.assign(.scatter, to: 1)
            }
            SoundEngine.shared.pickup()
            grantStep = nil
        }
        if grantStep == nil { scene.isPaused = false }
    }

    /// Ad revive: raises the overlay, plays the stub ad with a 3s pixel
    /// progress bar, then revives on grant. One per run — the flag is set
    /// inside doRevive().
    private func startAdRevive() {
        showAdOverlay = true
        adProgress = 0
        withAnimation(.linear(duration: 3.0)) { adProgress = 1 }
        Task {
            let reward = await StubAdService.shared.showRewarded()
            await MainActor.run {
                showAdOverlay = false
                adProgress = 0
                if reward == .granted {
                    SoundEngine.shared.uiTap()
                    doRevive()
                }
            }
        }
    }

    /// Applies the revive: one more heart + standard respawn drop, music
    /// back on, defeat card down. The run continues where it fell.
    private func doRevive() {
        revivedThisRun = true
        scene.reviveHero()
        scene.heroInputX = 0
        scene.heroJumpHeld = false
        weapon = scene.heroWeapon
        showDefeat = false
        scene.isPaused = false
        SoundEngine.shared.startBattleMusic()
    }

    private func formatTime(_ t: Double) -> String {
        let total = max(0, Int(t))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Single structured menu bar holding every top control:
    /// weapon switch | treasury | vitals | minimap | pause.
    /// Minimap width is parameterized so narrow screens get a compact strip.
    @ViewBuilder
    private func commandBar(minimapWidth: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 6) {
            // Weapon switch: tap to rotate through the LOADOUT slots.
            // Single-gun loadouts show a static chip: nothing to switch to.
            Button { weapon = scene.cycleWeapon() } label: {
                HStack(spacing: 5) {
                    // Little square with the actual pixel gun of the active
                    // weapon — oversized so it breaks out of the frame.
                    ZStack {
                        Rectangle()
                            .fill(.cyan.opacity(0.14))
                            .frame(width: 28, height: 28)
                            .overlay(Rectangle().stroke(.cyan.opacity(0.5), lineWidth: 1))
                        Image(uiImage: PixelHeroArt.gunImage(weapon))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 38, height: 21)
                            .offset(x: 3, y: -5)
                            .allowsHitTesting(false)
                    }
                    .frame(width: 28, height: 28)
                    .padding(.trailing, 6)
                    Text(minimap.ammoText)
                        .monospacedDigit()
                        .foregroundStyle(minimap.ammoMag == 0 ? .red
                            : minimap.reloading ? .gray : .white.opacity(0.85))
                    if LoadoutStore.loadout.count > 1 {
                        Image(systemName: "arrow.2.circlepath")
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(.cyan.opacity(0.12))
                .overlay(Rectangle().stroke(.cyan.opacity(0.45), lineWidth: 1))
            }
            .disabled(LoadoutStore.loadout.count < 2)

            HUDDivider()

            // Treasury.
            HStack(spacing: 5) {
                PixelCoinView()
                Text("\(minimap.money)")
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.yellow)

            HUDDivider()

            // Diamond wallet (live balance for revives / buyouts later).
            HStack(spacing: 5) {
                PixelDiamondView()
                Text("\(wallet.diamonds)")
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.cyan)
            .scaleEffect(hudPop ? 1.35 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: hudPop)
            .anchorPreference(key: HudDiamondsAnchorKey.self, value: .center) { $0 }

            HUDDivider()

            // Hero vitals: 3 life-hearts + HP bar + live numbers.
            HeroVitalsView(lives: minimap.heroLives, maxLives: minimap.heroMaxLives,
                           hp: minimap.heroHP, maxHP: minimap.heroMaxHP,
                           shield: minimap.shieldHP, shieldMax: minimap.shieldMax)
                .allowsHitTesting(false)

            // Health pack (booster add-on): one HUD-tapped heal per run.
            // Lit green while armed + hurt, dim otherwise.
            Button {
                _ = scene.useHealthPack()
            } label: {
                HStack(spacing: 4) {
                    PixelMedkitView()
                    Text("+\(minimap.packAmount)")
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(minimap.packReady ? .green : .gray)
                .padding(.horizontal, 7).padding(.vertical, 5)
                .background(minimap.packReady ? .green.opacity(0.16) : .white.opacity(0.06))
                .overlay(Rectangle().stroke(minimap.packReady
                    ? .green.opacity(0.6) : .white.opacity(0.15), lineWidth: 1))
            }
            .disabled(!minimap.packReady)

            Spacer(minLength: 2)
                .allowsHitTesting(false)

            MinimapView(snap: minimap, stripWidth: minimapWidth)
                .allowsHitTesting(false)

            HUDDivider()

            // Pause button: auto-pauses the sim and opens the menu.
            Button {
                SoundEngine.shared.uiTap()
                scene.isPaused = true
                showMenu = true
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.10))
                    .overlay(Rectangle().stroke(.white.opacity(0.22), lineWidth: 1))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.72))
        .clipShape(PixelTopBarShape(cut: 6))
        .overlay(PixelTopBarShape(cut: 6).stroke(.white.opacity(0.16), lineWidth: 2))
    }
}

#Preview {
    NavigationStack {
        GameView(level: CampaignData.levels[0], hero: HeroRoster.selectedHero,
                 path: .constant(NavigationPath()))
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

/// Pixel panel: all four corners chamfered — the dialog/card shape.
/// Hard stepped edges read as retro pixel UI (no smooth rounds).
struct PixelPanelShape: Shape {
    var cut: CGFloat = 10
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

/// Pixel pause-menu button: chamfered hard corners, chunky border,
/// uppercase monospaced label. Primary = cyan fill, ghost = dark with
/// light border, danger = dark with red border + red text.
private struct PixelMenuButton: View {
    enum Style { case primary, ghost, danger }
    let title: String
    let style: Style
    var width: CGFloat = 220
    let onTap: () -> Void
    private let shape = PixelPanelShape(cut: 6)

    var body: some View {
        Button(action: onTap) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(fg)
                .frame(width: width, height: 42)
                .background(bg)
                .clipShape(shape)
                .overlay(shape.stroke(border, lineWidth: 2))
        }
    }

    private var bg: Color {
        switch style {
        case .primary: return .cyan
        case .ghost: return .white.opacity(0.08)
        case .danger: return .red.opacity(0.10)
        }
    }

    private var border: Color {
        switch style {
        case .primary: return .white.opacity(0.65)
        case .ghost: return .white.opacity(0.35)
        case .danger: return .red.opacity(0.7)
        }
    }

    private var fg: Color {
        switch style {
        case .primary: return .black
        case .ghost: return .white
        case .danger: return .red
        }
    }
}

/// Bottom army tab: pixel-menu styling — floating island with chamfered
/// Compact summon tile: chamfered octagon-rectangle portrait with the
/// gold cost riding a strip along the bottom inside the tile. No name
/// label — keeps each tile narrow so more units fit the bar later.
/// While deploying cools down, a dark veil drains top -> bottom with a
/// cyan sweep line + seconds readout. Locked units never reach this tile
/// (the bar only lists fieldable kinds).
private struct ArmyCardButton: View {
    let kind: ArmyKind
    let money: Int
    /// 0 = ready, 1 = just deployed (veil covers the tile, drains down).
    let cooldownFrac: Double
    /// True when the on-field army hit the cap — the card shows FULL and
    /// the deploy toast explains it instead of silently refusing.
    let armyFull: Bool
    let onTap: () -> Void

    private var affordable: Bool { money >= kind.cost }
    private var cooling: Bool { cooldownFrac > 0 }
    private let tileShape = PixelPanelShape(cut: 10)
    private let tileW: CGFloat = 78
    private let tileH: CGFloat = 56

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                // Tint wash behind the sprite.
                Rectangle()
                    .fill(affordable ? .cyan.opacity(0.18) : .white.opacity(0.08))
                // Top edge catch-light for a raised-panel read.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.white.opacity(0.14))
                        .frame(height: 2)
                    Spacer(minLength: 0)
                }
                // Live portrait: the real pixel sprite, torso-up with its
                // gun raised.
                Image(uiImage: UnitPixelArt.portraitImage(for: kind.pixelKind))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 68, height: 32)
                    .offset(y: -10)
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    .saturation(affordable ? 1 : 0)
                    .opacity(affordable ? 1 : 0.6)
                    .allowsHitTesting(false)
                // Cost strip pinned to the bottom inside the tile.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(affordable ? .cyan.opacity(0.5) : .white.opacity(0.15))
                        .frame(height: 1)
                    HStack(spacing: 3) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(kind.cost)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                    }
                    .foregroundStyle(affordable ? .yellow : .gray)
                    .frame(maxWidth: .infinity, minHeight: 17)
                    .background(.black.opacity(0.72))
                }
            }
            .frame(width: tileW, height: tileH)
            .background(.black.opacity(affordable ? 0.78 : 0.55))
            .clipShape(tileShape)
            .overlay {
                // Cooldown sweep: dark veil draining top -> bottom with a
                // cyan sweep line riding its leading edge. Clipped to the
                // octagon so the fill never spikes past the card outline.
                if cooling {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(.black.opacity(0.68))
                            .frame(height: tileH * CGFloat(min(1, cooldownFrac)))
                        Rectangle()
                            .fill(.cyan)
                            .frame(height: 2)
                    }
                    .clipShape(tileShape)
                }
            }
            .overlay(tileShape.stroke(affordable && !cooling ? Color.cyan : Color.gray.opacity(0.5),
                                     lineWidth: 2.5))
            .overlay(alignment: .top) {
                // Army at the cap: say so instead of silently refusing.
                if armyFull {
                    Text("FULL")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.red)
                }
            }
            .opacity(affordable ? 1.0 : 0.6)
        }
    }
}

/// Compact label + value chip for the unit intel card.
private struct UnitStatChip: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.cyan)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(minWidth: 52)
        .padding(.vertical, 6)
        .background(.white.opacity(0.06))
        .overlay(Rectangle().stroke(.white.opacity(0.18), lineWidth: 1))
    }
}

/// Anchor bridges for the diamond flight: win-card row → HUD wallet.
private struct WinDiamondsAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGPoint>?
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = nextValue() ?? value
    }
}

private struct HudDiamondsAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGPoint>?
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = nextValue() ?? value
    }
}

/// Thin vertical separator between command-bar sections.
private struct HUDDivider: View {    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.14))
            .frame(width: 1, height: 20)
            .allowsHitTesting(false)
    }
}

/// Hero vitals: life-hearts + HP bar + live numbers (e.g. 78/100) +
/// shield bar when the hero runs a shield. Each death costs one heart —
/// spent hearts render desaturated and almost transparent so the remaining
/// attempts read at a glance. The HP bar tracks the current life
/// (green -> red). Bare (no pill background) — it lives inside the
/// command bar.
private struct HeroVitalsView: View {
    let lives: Int
    let maxLives: Int
    let hp: CGFloat
    let maxHP: CGFloat
    var shield: CGFloat = 0
    var shieldMax: CGFloat = 0

    private var frac: CGFloat {
        guard maxHP > 0 else { return 0 }
        return min(1, max(0, hp / maxHP))
    }

    private var shieldFrac: CGFloat {
        guard shieldMax > 0 else { return 0 }
        return min(1, max(0, shield / shieldMax))
    }

    private var color: Color {
        if frac > 0.5 { return .green }
        if frac > 0.25 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                ForEach(0..<max(1, maxLives), id: \.self) { i in
                    if i < lives {
                        PixelHeartView(color: color)
                    } else {
                        // Spent life: dimmed to near-ghost.
                        PixelHeartView(color: .gray)
                            .saturation(0)
                            .opacity(0.25)
                    }
                }
            }
            VStack(spacing: 2) {
                PixelHPBarView(frac: frac, color: color)
                if shieldMax > 0 {
                    PixelShieldBarView(frac: shieldFrac)
                }
            }
            Text("\(Int(hp))/\(Int(maxHP))")
                .font(.caption2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(.white)
        }
    }
}

/// Thin cyan shield bar under the HP bar: chunky twin of the HP meter.
private struct PixelShieldBarView: View {
    let frac: CGFloat
    private let chunks = 10
    private let chunkW: CGFloat = 6
    private let chunkH: CGFloat = 4
    private let gap: CGFloat = 1
    private let pad: CGFloat = 2

    private var lit: Int { Int((min(1, max(0, frac)) * CGFloat(chunks)).rounded()) }

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<chunks, id: \.self) { i in
                Rectangle()
                    .fill(i < lit ? .cyan : .white.opacity(0.12))
                    .frame(width: chunkW, height: chunkH)
            }
        }
        .padding(.horizontal, pad)
        .background(.black.opacity(0.65))
        .overlay(Rectangle().stroke(.cyan.opacity(0.35), lineWidth: 1))
    }
}

/// Chunky pixel HP bar: dark padded frame + hairline border + discrete
/// block segments that wink out one by one (10 chunks), with a faint top
/// shine. Same language as the in-world tower/HQ bars.
private struct PixelHPBarView: View {
    let frac: CGFloat
    let color: Color
    private let chunks = 10
    private let chunkW: CGFloat = 6
    private let chunkH: CGFloat = 8
    private let gap: CGFloat = 1
    private let pad: CGFloat = 3

    private var lit: Int { Int((min(1, max(0, frac)) * CGFloat(chunks)).rounded()) }

    var body: some View {
        ZStack(alignment: .leading) {
            // Dark padded frame.
            Rectangle()
                .fill(.black.opacity(0.65))
                .frame(width: frameW, height: chunkH + pad * 2)
            // Block segments.
            HStack(spacing: gap) {
                ForEach(0..<chunks, id: \.self) { i in
                    Rectangle()
                        .fill(i < lit ? color : .white.opacity(0.12))
                        .frame(width: chunkW, height: chunkH)
                }
            }
            .padding(.horizontal, pad)
            // Top shine across the frame.
            VStack {
                Rectangle()
                    .fill(.white.opacity(0.14))
                    .frame(width: frameW, height: 2)
                Spacer(minLength: 0)
            }
            .frame(width: frameW, height: chunkH + pad * 2)
        }
        .frame(width: frameW, height: chunkH + pad * 2)
        .overlay(Rectangle().stroke(.white.opacity(0.25), lineWidth: 1))
    }

    private var frameW: CGFloat {
        CGFloat(chunks) * chunkW + CGFloat(chunks - 1) * gap + pad * 2
    }
}

/// Crisp pixel-grid sprite renderer: each character is one hard-edged
/// square, "." is transparent. Vector rects so it stays sharp at any size.
private struct PixelSpriteView: View {
    let grid: [String]
    let palette: [Character: Color]
    var pixel: CGFloat = 2

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

/// Pixel-art gold coin for the treasury: dark outline, pale shine,
/// deep inner notch so it reads as a coin, not a dot.
private struct PixelCoinView: View {
    private let grid = [
        "..OOOO..",
        ".OllllO.",
        "OlLGGGGO",
        "OLGGGGGO",
        "OGGGGGGO",
        "OGGDDGGO",
        ".OggggO.",
        "..OOOO..",
    ]
    var body: some View {
        PixelSpriteView(grid: grid, palette: [
            "O": Color(red: 0.25, green: 0.15, blue: 0.05),
            "G": Color(red: 1.0, green: 0.80, blue: 0.20),
            "g": Color(red: 0.75, green: 0.50, blue: 0.10),
            "l": Color(red: 1.0, green: 0.95, blue: 0.70),
            "L": .white,
            "D": Color(red: 0.55, green: 0.32, blue: 0.06),
        ], pixel: 1.75)
        .shadow(color: .yellow.opacity(0.35), radius: 2)
    }
}

/// Diamond revive button: pixel-menu styling matching the defeat card —
/// cyan fill when affordable, dimmed + disabled when broke.
private struct ReviveDiamondButton: View {
    let cost: Int
    let balance: Int
    let onTap: () -> Void
    private let shape = PixelPanelShape(cut: 6)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                PixelDiamondView()
                Text("REVIVE · \(cost) DIAMONDS")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(affordable ? .black : .gray)
            }
            .frame(width: 220, height: 42)
            .background(affordable ? .cyan : .white.opacity(0.08))
            .clipShape(shape)
            .overlay(shape.stroke(affordable ? .white.opacity(0.65) : .gray.opacity(0.4),
                                  lineWidth: 2))
            .opacity(affordable ? 1.0 : 0.6)
        }
        .disabled(!affordable)
    }

    private var affordable: Bool { balance >= cost }
}

/// Pixel-art diamond for the wallet: faceted gem — wide crown, pointed
/// pavilion, white glint on the left facets, deep-cyan shade on the right.
private struct PixelDiamondView: View {
    private let grid = [
        "...OO...",
        "..OaaO..",
        ".OaLLdO.",
        "OaaLLddO",
        "OaLLLddO",
        ".OaaddO.",
        "..OaaO..",
        "...OO...",
        "....O...",
    ]
    var body: some View {
        PixelSpriteView(grid: grid, palette: [
            "O": Color(white: 0.08),
            "a": .cyan,
            "L": .white,
            "d": Color(red: 0.05, green: 0.55, blue: 0.75),
        ], pixel: 1.75)
        .shadow(color: .cyan.opacity(0.35), radius: 2)
    }
}

/// Pixel-art heart for the vitals: dark outline, white glint, body tinted
/// by the same HP color as the bar (green -> orange -> red).
private struct PixelHeartView: View {
    let color: Color
    private let grid = [
        "..OO.OO..",
        ".OrrOrrO.",
        "OrrLrrrrO",
        "OrrrrrrrO",
        "OrrrrrrrO",
        ".OrrrrrO.",
        "..OrrrO..",
        "...OOO...",
    ]
    var body: some View {
        PixelSpriteView(grid: grid, palette: [
            "O": Color(white: 0.08),
            "r": color,
            "L": .white,
        ], pixel: 1.5)
    }
}

/// Pixel-art medkit for the health-pack button: green cross with a
/// white-hot core on a dark pad. Matches the booster add-on icon.
private struct PixelMedkitView: View {
    private let grid = [
        "..OO..",
        ".OGGO.",
        "OGWWGO",
        ".OGGO.",
        "..OO..",
    ]
    var body: some View {
        PixelSpriteView(grid: grid, palette: [
            "O": Color(white: 0.08),
            "G": Color(red: 0.25, green: 0.95, blue: 0.45),
            "W": .white,
        ], pixel: 1.75)
        .shadow(color: .green.opacity(0.35), radius: 2)
    }
}

/// Pixel victory star: lit gold or dim outline grey.
private struct PixelStarView: View {
    let lit: Bool
    private let grid = [
        "....O....",
        "...OOO...",
        "...OOO...",
        "OOOOOOOOO",
        ".OOOOOOO.",
        "..OOOOO..",
        "..OOOOO..",
        ".OOO.OOO.",
        ".OO...OO.",
    ]
    var body: some View {
        PixelSpriteView(grid: grid, palette: [
            "O": lit ? Color(red: 1.0, green: 0.82, blue: 0.2) : Color(white: 0.3),
        ], pixel: 2)
        .shadow(color: lit ? .yellow.opacity(0.5) : .clear, radius: 4)
    }
}
