import Combine
import SpriteKit
import SwiftUI
import UIKit // UIImage portraits from UnitPixelArt

/// One card in the level-entry intel queue. Each debut on a level gets its
/// own modal so nothing is ever skipped: structural cards (tower / citadel
/// HQ / bomber / Mk-III siege) first, then one card per new enemy unit,
/// then one per new army unit.
private enum LevelIntroStep: Identifiable, Hashable {
    case foe(EnemyKind)
    case unit(ArmyKind)
    case tower
    case base
    case bomber
    case towerMkIII
    case coreFinale

    var id: String {
        switch self {
        case .foe(let kind): return "foe-\(kind.rawValue)"
        case .unit(let kind): return "unit-\(kind.rawValue)"
        case .tower: return "tower"
        case .base: return "base"
        case .bomber: return "bomber"
        case .towerMkIII: return "towerMkIII"
        case .coreFinale: return "coreFinale"
        }
    }
}

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
        // Seed the HUD wallet with this level's starting gold (playground
        // pays the fat dev stack); the ~7Hz scene poll corrects it live.
        _minimap = State(initialValue: MinimapSnapshot(levelWidth: Balance.levelWidth, heroX: Balance.heroSpawnX,
                                                 cameraX: 0, viewWidth: 1334,
                                                 playerBaseX: Balance.playerBaseX,
                                                  playerTowerXs: Balance.playerTowerXs,
                                                  enemyTowerXs: Balance.enemyTowerXs,
                                                 enemyBaseX: Balance.enemyBaseX,
                                                 heroHP: Balance.heroHP, heroMaxHP: Balance.heroHP,
                                                 money: Balance.startingGold(for: level.id)))
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
    /// Ordered level-entry intel queue: every debut on this level gets its
    /// own modal, shown one after another (tower/base/bomber structural
    /// cards first, then each new hostile, then each new army unit).
    /// Fixes levels that debut two things at once (L3 Heavy+Brute, L6
    /// Truck+Skitter, L15 Missile Truck+Bulwark, L11 Bombard+towers):
    /// previously the two 1s timers raced and the loser never showed.
    @State private var introQueue: [LevelIntroStep] = []
    @State private var currentIntro: LevelIntroStep? = nil
    /// Frozen card count for the "INTEL i OF N" header (queue drains live).
    @State private var introTotalCount: Int = 0
    /// Level 5 grant sequence: 1 = free gun slot, 2 = Scatter gun.
    /// Shown one modal after another on battle entry; each CLAIM grants.
    @State private var grantStep: Int?
    @State private var weapon: HeroWeapon = .blaster
    /// Milestone hero unlocked by this level's briefing (shown once, then
    /// claimed + auto-equipped). Nil when nothing new or already owned.
    @State private var heroUnlock: HeroDef?
    @State private var showDiagnostics = false
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
                                           armyFull: minimap.allyCount >= minimap.allyCap,
                                           hqDown: !minimap.playerHQAlive) {
                                scene.summonAlly(kind: kind)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                // Bomber zone-select banner: confirms targeting mode + how
                // to back out (tap STRIKE again). No hit-testing: taps pass
                // through to the field so the zone lands where aimed.
                if minimap.bomberTargeting {
                    Text("TAP THE FIELD TO CALL THE STRIKE — STRIKE AGAIN TO CANCEL")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.black.opacity(0.65))
                        .overlay(Rectangle().stroke(.orange.opacity(0.6), lineWidth: 1))
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                }
                Spacer()
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if showDiagnostics {
                    PerformanceOverlay(scene: scene) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                            showDiagnostics = false
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                            showDiagnostics = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.path.ecg")
                            Text("DIAG")
                            Image(systemName: "chevron.up")
                        }
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
            .animation(.spring(response: 0.28, dampingFraction: 0.92), value: showDiagnostics)

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
                        showMenu = false
                        popToMap()
                    }
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

            // Queued level-entry intel: each debut on this level gets its
            // own modal, one after another (NEXT steps through the queue).
            // Close button or tap outside advances and resumes when drained.
            if let step = currentIntro, case .unit(let debut) = step {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { advanceIntro() }
                VStack(spacing: 10) {
                    introProgressHeader(total: introTotal, index: introIndex)
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
                    PixelMenuButton(title: introNextTitle, style: .primary) {
                        SoundEngine.shared.uiTap()
                        advanceIntro()
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .background(.black.opacity(0.9))
                .clipShape(PixelPanelShape(cut: 10))
                .overlay(PixelPanelShape(cut: 10).stroke(.yellow.opacity(0.6), lineWidth: 3))
                .shadow(color: .yellow.opacity(0.2), radius: 18)
            }

            // New-hostile intel: each enemy debut for THIS level gets its
            // own modal (portrait + stats + threat read), same as the new
            // army-unit cards — every entry, no buttons. Tap outside the
            // card to step through the queue.
            if let step = currentIntro, case .foe(let foe) = step {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { advanceIntro() }
                VStack(spacing: 10) {
                    introProgressHeader(total: introTotal, index: introIndex)
                    Text("NEW HOSTILE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(.red)
                    Image(uiImage: UnitPixelArt.portraitImage(for: foe.pixelKind))
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 80)
                        .background(.black.opacity(0.6))
                        .clipShape(PixelPanelShape(cut: 8))
                        .overlay(PixelPanelShape(cut: 8).stroke(.red, lineWidth: 2))
                        .shadow(color: .red.opacity(0.4), radius: 10)
                    Text(foe.displayName.uppercased())
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white)
                    Text(foe.threatBlurb)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                    if let note = foe.debutNote {
                        Text(note)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.cyan)
                            .frame(maxWidth: 290)
                    }
                    HStack(spacing: 14) {
                        UnitStatChip(label: "HP", value: "\(Int(foe.hp))")
                        UnitStatChip(label: "DMG", value: "\(Int(foe.attackDamage))")
                        UnitStatChip(label: "SPD", value: "\(Int(foe.moveSpeed))")
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .background(.black.opacity(0.9))
                .clipShape(PixelPanelShape(cut: 10))
                .overlay(PixelPanelShape(cut: 10).stroke(.red.opacity(0.6), lineWidth: 3))
                .shadow(color: .red.opacity(0.2), radius: 18)
            }

            // Fortress-line intel: announces the new tower count anchoring
            // each base (4 on Level 11, 5 on Level 23). Part of the queue.
            if currentIntro == .tower {
                Color.black.opacity(0.68)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { advanceIntro() }

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

            // Level 20 HQ refit intel: announces the Mk-II citadel HQs and
            // their 4-missile rooftop volley on both sides.
            if currentIntro == .base {
                Color.black.opacity(0.68)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { advanceIntro() }

                ViewThatFits(in: .vertical) {
                    baseIntroCard
                    ScrollView(.vertical, showsIndicators: false) {
                        baseIntroCard
                    }
                    .frame(maxWidth: 360)
                }
                .padding(.vertical, 12)
            }

            // Level 31 siege-tower intel: announces the Mk-III refit and
            // its 4-missile volley on both sides. Part of the queue.
            if currentIntro == .towerMkIII {
                Color.black.opacity(0.68)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { advanceIntro() }

                ViewThatFits(in: .vertical) {
                    towerMkIIIIntroCard
                    ScrollView(.vertical, showsIndicators: false) {
                        towerMkIIIIntroCard
                    }
                    .frame(maxWidth: 360)
                }
                .padding(.vertical, 12)
            }

            // Level 35 finale intel: the huge enemy core-fortress vs our
            // same Mk-II citadel. Part of the queue, shown first.
            if currentIntro == .coreFinale {
                Color.black.opacity(0.68)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { advanceIntro() }

                ViewThatFits(in: .vertical) {
                    coreFinaleIntroCard
                    ScrollView(.vertical, showsIndicators: false) {
                        coreFinaleIntroCard
                    }
                    .frame(maxWidth: 360)
                }
                .padding(.vertical, 12)
            }

            // Level 25 air-support intel: announces the bomber strike
            // button + tap-the-field zone select. Part of the queue.
            if currentIntro == .bomber {
                Color.black.opacity(0.68)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { advanceIntro() }

                ViewThatFits(in: .vertical) {
                    bomberIntroCard
                    ScrollView(.vertical, showsIndicators: false) {
                        bomberIntroCard
                    }
                    .frame(maxWidth: 360)
                }
                .padding(.vertical, 12)
            }

            // Milestone hero unlock (Vanguard on Level 8, Bulwark on 15,
            // Ranger on 21): portrait + stats, then CLAIM persists the
            // unlock, auto-equips, and resumes.
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
                    if level.id != Balance.playgroundLevelId {
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
                    }
                    SoundEngine.shared.stopAllBattleAudio()
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
                    SoundEngine.shared.stopAllBattleAudio()
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
            // Queued level-entry intel: let the battle breathe ~1s, then
            // freeze and step through every debut on this level — one
            // modal per new enemy unit (plus tower/base/bomber/army cards).
            // Grants + milestone hero follow after the queue drains.
            let queue = buildIntroQueue()
            if !queue.isEmpty || level.id == 5 || milestoneHero != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    guard currentIntro == nil, grantStep == nil, heroUnlock == nil,
                          !minimap.won, !minimap.lost else { return }
                    introQueue = buildIntroQueue()
                    introTotalCount = introQueue.count
                    if !introQueue.isEmpty {
                        currentIntro = introQueue.removeFirst()
                        showMenu = false
                        scene.isPaused = true
                    } else {
                        presentPostIntelModalIfNeeded()
                    }
                }
            }
        }
        .onDisappear {
            // Leaving the level (quit, map, continue, pop): hard-stop
            // music + every SFX tail so nothing leaks into the menu or
            // the next scene.
            SoundEngine.shared.stopAllBattleAudio()
            // Hand the global layout back to the menu/briefing dioramas.
            Balance.battleOwnsLayout = false
        }
    }

    /// Victory stars from clear time: fast clears earn the full row.
    /// The time targets scale with the campaign tier — later levels are
    /// legitimately longer fights (mech walls, missile trucks, the tower
    /// refit), so a slow-but-solid run there never drops to the floor.
    private func starsFor(time: Double) -> Int {
        let budget = starTimeBudget(for: level.id)
        if time <= budget { return 3 }
        if time <= budget * 5 / 3 { return 2 }
        return 1
    }

    /// 3-star clear target per tier (seconds): L1-5 ≈ 2.5 min skirmishes,
    /// L6-9 ≈ 3.5, L10-14 ≈ 5, L15-17 ≈ 6, L18+ (the refit levels and
    /// beyond) ≈ 9+. A 2-star run gets 1.67x that; everything under
    /// beats one star.
    private func starTimeBudget(for levelId: Int) -> TimeInterval {
        switch levelId {
        case 1...5: return 150
        case 6...9: return 210
        case 10...14: return 300
        case 15...17: return 360
        default: return 540
        }
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

    /// Fortress-line card: the enemy's red tower in battlefield pixel art,
    /// calling out the new tower line — 4 per side on Level 11, 5 per side
    /// on Level 23 (the standard from 23 on).
    private var towerIntroCount: Int { level.id == 23 ? 5 : 4 }
    /// Body copy for the fortress-line card (4th vs 5th tower wording).
    private var towerIntroBody: String {
        if towerIntroCount >= 5 {
            return "A fifth gun emplacement now anchors each base, closing the middle gap. Five towers a side from here on — another three-bolt volley between you and their HQ."
        }
        return "A fourth gun emplacement now anchors each base. The red tower below is the enemy's new fortification — another three-bolt volley between you and their HQ."
    }
    private var towerIntroCard: some View {
        VStack(spacing: 9) {
            introProgressHeader(total: introTotal, index: introIndex)
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
                Image(uiImage: TowerNode.previewImage(for: .enemy,
                                                      upgraded: level.id >= Balance.upgradedTowerLevel))
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
                Text("×\(towerIntroCount)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(.red)
                    .padding(6)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 3) {
                    ForEach(0..<towerIntroCount, id: \.self) { _ in
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
            Text("BOTH BASES: \(towerIntroCount) TOWERS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.red)
            Text(towerIntroBody)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: 280)
            HStack(spacing: 10) {
                UnitStatChip(label: "TOWERS", value: "\(towerIntroCount) / SIDE")
                UnitStatChip(label: "TOWER HP", value: "\(Int(Balance.enemyTowerHealth(forLevel: level.id)))")
                UnitStatChip(label: "RANGE", value: "\(Int(Balance.towerRange))")
            }
            PixelMenuButton(title: introNextTitle, style: .primary) {
                SoundEngine.shared.uiTap()
                advanceIntro()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.black.opacity(0.92))
        .clipShape(PixelPanelShape(cut: 10))
        .overlay(PixelPanelShape(cut: 10).stroke(.red.opacity(0.65), lineWidth: 3))
        .shadow(color: .red.opacity(0.25), radius: 20)
    }

    /// Level 20 card: both HQs rendered in the new Mk-II citadel pixel art,
    /// calling out the bigger fortified structure and 4-missile rooftop volley.
    private var baseIntroCard: some View {
        VStack(spacing: 9) {
            introProgressHeader(total: introTotal, index: introIndex)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [.red.opacity(0.22),
                                                 .black.opacity(0.80)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 244, height: 136)
                Rectangle()
                    .fill(.red.opacity(0.26))
                    .frame(width: 244, height: 1)
                    .offset(y: 48)
                HStack(spacing: 14) {
                    Image(uiImage: BaseNode.previewImage(for: .player, upgraded: true))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 98, height: 104)
                        .shadow(color: .cyan.opacity(0.45), radius: 10)
                    Image(uiImage: BaseNode.previewImage(for: .enemy, upgraded: true))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 98, height: 104)
                        .shadow(color: .red.opacity(0.55), radius: 12)
                }
            }
            .frame(width: 244, height: 136)
            .clipShape(PixelPanelShape(cut: 8))
            .overlay(PixelPanelShape(cut: 8).stroke(.orange.opacity(0.8), lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                Text("MK-II")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.orange)
                    .padding(6)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 3) {
                    ForEach(0..<Balance.baseMissileCount, id: \.self) { _ in
                        Rectangle()
                            .fill(.orange)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }

            Text("MK-II CITADEL HQ")
                .font(.system(size: 19, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white)
            Text("UPGRADED HQS · 4-MISSILE VOLLEY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.orange)
            Text("Both main HQs have been refitted into heavy Mk-II citadels with reinforced casemates and a rooftop quad-missile battery that fires a 4-rocket salvo.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: 290)
            HStack(spacing: 10) {
                UnitStatChip(label: "SALVO", value: "4 MISSILES")
                UnitStatChip(label: "ENEMY HQ", value: "\(Int(Balance.enemyBaseHealth(forLevel: level.id).rounded()))")
                UnitStatChip(label: "RANGE", value: "\(Int(Balance.baseRange))")
            }
            PixelMenuButton(title: introNextTitle, style: .primary) {
                SoundEngine.shared.uiTap()
                advanceIntro()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.black.opacity(0.92))
        .clipShape(PixelPanelShape(cut: 10))
        .overlay(PixelPanelShape(cut: 10).stroke(.orange.opacity(0.65), lineWidth: 3))
        .shadow(color: .orange.opacity(0.25), radius: 20)
    }

    /// Level 31 card: both teams' towers rendered in the new Mk-III siege
    /// pixel art — taller, bulkier shells with a quad-missile pod turret,
    /// calling out the 4-missile volley on both sides of the lane.
    private var towerMkIIIIntroCard: some View {
        VStack(spacing: 9) {
            introProgressHeader(total: introTotal, index: introIndex)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [.red.opacity(0.22),
                                                 .black.opacity(0.80)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 244, height: 152)
                Rectangle()
                    .fill(.red.opacity(0.26))
                    .frame(width: 244, height: 1)
                    .offset(y: 56)
                HStack(spacing: 14) {
                    Image(uiImage: TowerNode.previewImage(for: .player, upgraded: true, mkIII: true))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 98, height: 122)
                        .shadow(color: .cyan.opacity(0.45), radius: 10)
                    Image(uiImage: TowerNode.previewImage(for: .enemy, upgraded: true, mkIII: true))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 98, height: 122)
                        .shadow(color: .red.opacity(0.55), radius: 12)
                }
            }
            .frame(width: 244, height: 152)
            .clipShape(PixelPanelShape(cut: 8))
            .overlay(PixelPanelShape(cut: 8).stroke(.red.opacity(0.8), lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                Text("MK-III")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.red)
                    .padding(6)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 3) {
                    ForEach(0..<Balance.towerMissileCountMkIII, id: \.self) { _ in
                        Rectangle()
                            .fill(.red)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }

            Text("MK-III SIEGE TOWER")
                .font(.system(size: 19, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white)
            Text("UPGRADED TOWERS · 4-MISSILE VOLLEY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.red)
            Text("Both tower lines have been refitted into taller, bulkier Mk-III siege towers with twin barrels and quad missile pods — every tower on the lane now answers with a 4-rocket salvo.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: 290)
            HStack(spacing: 10) {
                UnitStatChip(label: "SALVO", value: "4 MISSILES")
                UnitStatChip(label: "TOWER HP", value: "\(Int(Balance.enemyTowerHealth(forLevel: level.id)))")
                UnitStatChip(label: "RANGE", value: "\(Int(Balance.towerRange))")
            }
            PixelMenuButton(title: introNextTitle, style: .primary) {
                SoundEngine.shared.uiTap()
                advanceIntro()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.black.opacity(0.92))
        .clipShape(PixelPanelShape(cut: 10))
        .overlay(PixelPanelShape(cut: 10).stroke(.red.opacity(0.65), lineWidth: 3))
        .shadow(color: .red.opacity(0.25), radius: 20)
    }

    /// Level 35 finale intel: the enemy's huge Mordor-style main-main
    /// building — the Embral Core core-fortress with its Burning Eye and a
    /// 5-missile rooftop salvo — against our same Mk-II citadel HQ.
    private var coreFinaleIntroCard: some View {
        VStack(spacing: 9) {
            introProgressHeader(total: introTotal, index: introIndex)
            Text("FINAL BATTLE")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.black)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(.yellow)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [.red.opacity(0.28),
                                                 .black.opacity(0.85)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 264, height: 168)
                Rectangle()
                    .fill(.red.opacity(0.26))
                    .frame(width: 264, height: 1)
                    .offset(y: 62)
                HStack(spacing: 10) {
                    VStack(spacing: 2) {
                        Image(uiImage: BaseNode.previewImage(for: .player, upgraded: true))
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 84, height: 104)
                            .shadow(color: .cyan.opacity(0.45), radius: 10)
                        Text("OURS · MK-II")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                    Text("VS")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    VStack(spacing: 2) {
                        Image(uiImage: BaseNode.previewImage(for: .enemy, upgraded: true, finale: true))
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 104, height: 128)
                            .shadow(color: .red.opacity(0.6), radius: 14)
                        Text("THEIRS · CORE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(width: 264, height: 168)
            .clipShape(PixelPanelShape(cut: 8))
            .overlay(PixelPanelShape(cut: 8).stroke(.yellow.opacity(0.85), lineWidth: 2))
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 3) {
                    ForEach(0..<Balance.baseMissileCountFinale, id: \.self) { _ in
                        Rectangle()
                            .fill(.red)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }

            Text("EMBRAL CORE")
                .font(.system(size: 19, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white)
            Text("FINALE HQ · 5-MISSILE SALVO")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.yellow)
            Text("This is it — the heart of the enemy on Emra. Their HQ rises as a huge core-fortress crowned by the Burning Eye.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(4)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: 300)
            HStack(spacing: 10) {
                UnitStatChip(label: "SALVO", value: "5 MISSILES")
                UnitStatChip(label: "ENEMY HQ", value: "\(Int(Balance.enemyBaseHealth(forLevel: level.id).rounded()))")
                UnitStatChip(label: "RANGE", value: "\(Int(Balance.baseRange))")
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.black.opacity(0.92))
        .clipShape(PixelPanelShape(cut: 10))
        .overlay(PixelPanelShape(cut: 10).stroke(.yellow.opacity(0.65), lineWidth: 3))
        .shadow(color: .yellow.opacity(0.25), radius: 20)
    }

    /// Level 25 air-support intel: announces the bomber strike button
    /// (next to the health pack) + tap-the-field zone select.
    private var bomberIntroCard: some View {
        VStack(spacing: 9) {
            introProgressHeader(total: introTotal, index: introIndex)
            Text("AIR SUPPORT")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.black)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(.orange)
            PixelBomberView(pixel: 4)
                .background(.black.opacity(0.6))
                .clipShape(PixelPanelShape(cut: 8))
                .overlay(PixelPanelShape(cut: 8).stroke(.orange, lineWidth: 2))
                .shadow(color: .orange.opacity(0.4), radius: 10)
            Text("BOMBER STRIKE")
                .font(.system(size: 19, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white)
            Text("NEW HUD ABILITY · TAP STRIKE, TAP THE FIELD")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.orange)
            Text("HQ loans you a heavy bomber. Tap STRIKE next to the health pack, then tap the field to pick the zone — the bomber strings a stick of bombs across it. Recharges after every run.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(4)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: 290)
            HStack(spacing: 10) {
                UnitStatChip(label: "BOMBS", value: "\(Balance.bomberBombCount)")
                UnitStatChip(label: "DMG", value: "\(Int(Balance.bomberBombDamage))")
                UnitStatChip(label: "RECHARGE", value: "\(Int(Balance.bomberCooldown))S")
            }
            PixelMenuButton(title: introNextTitle, style: .primary) {
                SoundEngine.shared.uiTap()
                advanceIntro()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.black.opacity(0.92))
        .clipShape(PixelPanelShape(cut: 10))
        .overlay(PixelPanelShape(cut: 10).stroke(.orange.opacity(0.65), lineWidth: 3))
        .shadow(color: .orange.opacity(0.25), radius: 20)
    }

    /// Every army unit debuting on this level (usually one — array so a
    /// future level can field two at once and each gets its own modal).
    private var debutUnits: [ArmyKind] {
        ArmyKind.allCases.filter { $0.unlockLevel == level.id }
    }

    /// Every hostile debuting on this level (usually one — array so a
    /// future level can field two at once and each gets its own modal).
    /// Mirrors the army debuts: shows on every entry, replays included.
    private var foeDebuts: [EnemyKind] {
        EnemyKind.allCases.filter { $0.unlockLevel == level.id }
    }

    /// Total intel cards in the current run (for the "1 OF N" header).
    private var introTotal: Int {
        max(1, introTotalCount)
    }

    /// 1-based index of the card on screen (for the "1 OF N" header).
    private var introIndex: Int {
        max(1, introTotal - introQueue.count)
    }

    /// NEXT on every card but the last, CLOSE on the last one.
    private var introNextTitle: String {
        introQueue.isEmpty ? "Close" : "Next"
    }

    /// Small "INTEL 1 OF N" strip above each queued card.
    @ViewBuilder
    private func introProgressHeader(total: Int, index: Int) -> some View {
        if total > 1 {
            Text("INTEL \(index) OF \(total)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    /// Builds the ordered intel queue for this level: structural cards
    /// first (finale core / tower line / citadel HQ / bomber / Mk-III
    /// siege), then each new hostile, then each new army unit. Empty =
    /// instant entry, no pause.
    private func buildIntroQueue() -> [LevelIntroStep] {
        var q: [LevelIntroStep] = []
        if level.id == Balance.finaleBaseLevel { q.append(.coreFinale) }
        if level.id == 11 || level.id == 23 { q.append(.tower) }
        if level.id == Balance.upgradedBaseLevel { q.append(.base) }
        if level.id == Balance.bomberUnlockLevel { q.append(.bomber) }
        if level.id == Balance.megaUpgradedTowerLevel { q.append(.towerMkIII) }
        for foe in foeDebuts { q.append(.foe(foe)) }
        for unit in debutUnits { q.append(.unit(unit)) }
        return q
    }

    /// Shows the next queued intel card (pausing the sim). When the queue
    /// drains, hands off to the Level 5 grants / milestone hero if pending,
    /// otherwise resumes the battle.
    private func advanceIntro() {
        if introQueue.isEmpty {
            currentIntro = nil
            introTotalCount = 0
            presentPostIntelModalIfNeeded()
        } else {
            currentIntro = introQueue.removeFirst()
            showMenu = false
            scene.isPaused = true
        }
    }

    /// After the intel queue drains: Level 5 grants first, then the
    /// milestone hero. Either pauses the sim on its own modal.
    private func presentPostIntelModalIfNeeded() {
        if minimap.won || minimap.lost { scene.isPaused = false; return }
        if level.id == 5 {
            if LoadoutStore.slotCount < 2 {
                grantStep = 1
                showMenu = false
                scene.isPaused = true
                return
            } else if !UnlockStore.owns(.scatter) {
                grantStep = 2
                showMenu = false
                scene.isPaused = true
                return
            }
        }
        if let fresh = milestoneHero {
            heroUnlock = fresh
            showMenu = false
            scene.isPaused = true
            return
        }
        scene.isPaused = false
    }

    /// Deploy-cooldown veil fraction for a summon tile (0 = ready).
    /// Reads the SCENE's clock so the card can never claim "ready" while
    /// the scene still refuses the deploy.
    private func cooldownFraction(for kind: ArmyKind) -> Double {
        let remaining = minimap.summonCooldowns[kind] ?? 0
        guard remaining > 0, kind.cooldown > 0 else { return 0 }
        return min(1, remaining / kind.cooldown)
    }

    /// Hero this level unlocks (Vanguard on 8, Bulwark on 15, Ranger on
    /// 21), only while it is still unclaimed. Already-owned milestones
    /// never re-modal.
    private var milestoneHero: HeroDef? {
        HeroRoster.heroes.first { $0.unlockLevel == level.id && !HeroRoster.isUnlocked($0) }
    }

    /// Bomber HUD readout: cancel hint while aiming, strike call when
    /// ready, blank while the sideways sweep shows the recharge.
    private var bomberLabel: String {
        if minimap.bomberTargeting { return "CANCEL" }
        if minimap.bomberReady { return "STRIKE" }
        return ""
    }

    /// True while the strike is recharging (veil sweep visible).
    private var bomberCooling: Bool {
        !minimap.bomberLocked && !minimap.bomberReady && !minimap.bomberTargeting
    }

    /// Recharge left as a 0...1 fraction (1 = just spent, drains to 0).
    private var bomberCooldownFrac: Double {
        min(1, max(0, minimap.bomberCooldown / Balance.bomberCooldown))
    }

    private var bomberColor: Color {
        if minimap.bomberTargeting { return .red }
        if minimap.bomberReady { return .orange }
        return .gray
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

    /// Level 5 grant CLAIM: step 1 grants the free slot (if still missing)
    /// then advances to step 2; step 2 grants + slots the Scatter, then
    /// hands off to the milestone hero if pending, else resumes.
    /// Grants persist so replays never re-offer them.
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
        if grantStep == nil {
            if let fresh = milestoneHero, heroUnlock == nil {
                heroUnlock = fresh
                showMenu = false
                scene.isPaused = true
            } else {
                scene.isPaused = false
            }
        }
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
            // Pixel-cut panel with the gun name + mag count — wide enough
            // that 2-digit mags never reflow the bar.
            Button { weapon = scene.cycleWeapon() } label: {
                HStack(spacing: 8) {
                    // Pixel gun cell: dark backdrop + hard border, gun sprite
                    // oversized so it breaks out of the frame.
                    ZStack {
                        Rectangle()
                            .fill(.black.opacity(0.55))
                            .frame(width: 34, height: 30)
                            .overlay(Rectangle().stroke(.cyan.opacity(0.5), lineWidth: 1))
                        Image(uiImage: PixelHeroArt.gunImage(weapon))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 42, height: 23)
                            .offset(x: 3, y: -5)
                            .allowsHitTesting(false)
                    }
                    .frame(width: 34, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(weapon.name.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.cyan.opacity(0.85))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(minimap.ammoText)
                                .monospacedDigit()
                                .frame(width: 32, alignment: .leading)
                                .lineLimit(1)
                                .foregroundStyle(minimap.reloading || minimap.ammoMag == 0 ? .red
                                    : .white.opacity(0.9))
                            Text("MAG")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            if LoadoutStore.loadout.count > 1 {
                                Image(systemName: "arrow.2.circlepath")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(minWidth: 122, alignment: .leading)
                .background(ShopPixelShape(cut: 5).fill(.cyan.opacity(0.12)))
                .overlay(ShopPixelShape(cut: 5).stroke(.cyan.opacity(0.45), lineWidth: 1))
            }
            .disabled(LoadoutStore.loadout.count < 2)

            HUDDivider()

            // Treasury. The digit box is width-pinned so growing balances
            // (4+ digits) never reflow the bar and squeeze the gun ammo.
            HStack(spacing: 5) {
                PixelCoinView()
                Text("\(minimap.money)")
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 34, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.yellow)

            HUDDivider()

            // Diamond wallet (live balance for revives / buyouts later).
            HStack(spacing: 5) {
                PixelDiamondView()
                Text("\(wallet.diamonds)")
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 26, alignment: .trailing)
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

            // Bomber strike (Level 25+ ability): tap to arm zone-select,
            // tap the field to call the run. Recharge reads like the unit
            // cards — a dark veil draining sideways with an orange sweep
            // line riding its leading edge.
            if !minimap.bomberLocked {
                Button {
                    if minimap.bomberTargeting {
                        scene.cancelBomberTargeting()
                    } else {
                        _ = scene.startBomberTargeting()
                    }
                } label: {
                    HStack(spacing: 4) {
                        PixelBomberView()
                        Text(bomberLabel)
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(bomberColor)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(bomberColor.opacity(minimap.bomberReady || minimap.bomberTargeting ? 0.16 : 0.06))
                    .overlay {
                        // Recharge sweep: dark veil draining left -> right
                        // with an orange line riding its leading edge.
                        if bomberCooling {
                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(.black.opacity(0.68))
                                        .frame(width: geo.size.width * bomberCooldownFrac)
                                    Rectangle()
                                        .fill(.orange)
                                        .frame(width: 2)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                    .overlay(Rectangle().stroke(bomberColor.opacity(minimap.bomberReady || minimap.bomberTargeting ? 0.6 : 0.15), lineWidth: 1))
                }
                .disabled(!minimap.bomberReady && !minimap.bomberTargeting)
            }

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
    /// True when the on-field army hit the cap.
    let armyFull: Bool
    /// True while your own HQ smoulders — nothing deploys without it.
    let hqDown: Bool
    /// Deploy attempt; the scene refuses on its own — the card does not
    /// need the result, its chip reflects the live block reason instead.
    let onDeploy: () -> Bool

    private var affordable: Bool { money >= kind.cost }
    private var cooling: Bool { cooldownFrac > 0 }
    private let tileShape = PixelPanelShape(cut: 10)
    private let tileW: CGFloat = 78
    private let tileH: CGFloat = 56

    /// Status chip pinned inside the card top (same language as FULL):
    /// HQ down > army at the cap. Recharging needs no label — the
    /// cooldown veil's drain animation says it — and being broke needs
    /// no label either: the dimmed cost strip already says NO GOLD.
    private var statusChip: (label: String, color: Color)? {
        if hqDown { return ("HQ DOWN", Color.red) }
        if armyFull { return ("FULL", Color.red) }
        return nil
    }

    var body: some View {
        Button(action: { _ = onDeploy() }) {
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
                // Status chip pinned inside the top of the tile: why this
                // unit can't deploy right now (army at cap, cooling, broke).
                if let chip = statusChip {
                    Text(chip.label)
                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                        .tracking(0.5)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(chip.color)
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

    private var columns: Int {
        grid.map(\.count).max() ?? 0
    }

    var body: some View {
        Canvas { ctx, _ in
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    guard let color = palette[ch] else { continue }
                    let rect = CGRect(x: CGFloat(c) * pixel,
                                      y: CGFloat(r) * pixel,
                                      width: pixel, height: pixel)
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(columns) * pixel,
               height: CGFloat(grid.count) * pixel)
        .allowsHitTesting(false)
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
private struct PixelMedkitView: View {    private let grid = [
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

/// Pixel-art bomber for the strike button: side-view heavy bomber —
/// blue fuselage, glass cockpit, tail fin — in player blue war paint.
private struct PixelBomberView: View {
    var pixel: CGFloat = 1.75
    private let grid = [
        "......OO....",
        ".....OggO...",
        ".O..OggggOO.",
        "OOOOOOOOOOOO",
        ".OOOoooooOO.",
        "....O.OO.O..",
        "....OO..OO..",
    ]
    var body: some View {
        PixelSpriteView(grid: grid, palette: [
            "O": Color(red: 0.30, green: 0.60, blue: 1.0),
            "o": Color(red: 0.12, green: 0.28, blue: 0.62),
            "g": Color(red: 0.75, green: 0.95, blue: 1.0),
        ], pixel: pixel)
        .shadow(color: .blue.opacity(0.45), radius: 2)
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
