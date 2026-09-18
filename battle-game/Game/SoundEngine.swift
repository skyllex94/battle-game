import AVFoundation
import UIKit

/// Procedural sound engine — zero audio assets, everything is synthesized
/// once into PCM buffers (retro dusk-arcade voice: zaps, booms, clicks).
///
/// Usage: `SoundEngine.shared.heroShot(.blaster)`, `.explosionBig()`, etc.
/// Respects the Settings SFX toggle (`settings.sfx`, same key as
/// `SettingsStore`) and rate-limits each voice so scatter fans and tower
/// volleys can't stack into clipping.
final class SoundEngine {

    static let shared = SoundEngine()

    // MARK: - Settings

    private let sfxKey = "settings.sfx"
    var sfxEnabled: Bool {
        // Default ON until the user flips it in Settings.
        if UserDefaults.standard.object(forKey: sfxKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: sfxKey)
    }

    // MARK: - Engine

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var cursor = 0
    private var buffers: [Voice: AVAudioPCMBuffer] = [:]
    private var lastPlay: [Voice: Double] = [:]
    private var built = false
    private let lock = NSLock()

    private let sampleRate = 22050.0

    // MARK: - Positional audio (proximity to the hero)

    /// World x of the listener (the hero — the scene writes this every
    /// frame). Every voice with a world position attenuates with distance
    /// and pans in stereo, so far-off battles rumble quietly and swell as
    /// the hero closes in.
    var listenerX: CGFloat = 0
    /// Inside this range a voice stays full volume.
    private let fullRange: CGFloat = 350
    /// Past this range a voice sits at the audibility floor (never 0, so
    /// distant battles still rumble faintly).
    private let hearRange: CGFloat = 1500
    private let floorGain: Float = 0.12
    /// Render format for every voice buffer AND every player-node connection,
    /// so scheduleBuffer can never hit a channel-count mismatch against the
    /// (stereo) mixer — the engine inserts the mono->stereo converter.
    private var renderFormat: AVAudioFormat? {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    }

    private init() {}

    // MARK: - Public voices

    func heroShot(_ weapon: HeroWeapon, at x: CGFloat) {
        switch weapon {
        case .blaster: play(.blaster, volume: 0.50, at: x)
        case .scatter: play(.scatter, volume: 0.55, at: x)
        case .cannon: play(.cannon, volume: 0.85, at: x)
        }
    }

    func towerFire(at x: CGFloat) { play(.tower, volume: 0.42, at: x) }
    func baseFire(at x: CGFloat) { play(.baseFan, volume: 0.60, at: x) }
    func enemyFire(at x: CGFloat) { play(.enemy, volume: 0.28, at: x) }
    func allyFire(at x: CGFloat) { play(.ally, volume: 0.32, at: x) }
    func dryFire() { play(.dry, volume: 0.40) }

    func reloadStart() { play(.reloadStart, volume: 0.50) }
    func reloadDone() { play(.reloadDone, volume: 0.55) }

    func impact(at x: CGFloat) { play(.impact, volume: 0.30, at: x) }
    func enemyDown(at x: CGFloat) { play(.enemyDown, volume: 0.55, at: x) }
    func troopDown(at x: CGFloat) { play(.enemyDown, volume: 0.40, at: x) }

    func heroHurt() { play(.heroHurt, volume: 0.60) }
    func heroDeath() {
        play(.heroDeath, volume: 0.70)
        Haptics.heroDeath()
    }

    /// Tower or HQ destroyed — big boom + heavy destruction haptics.
    /// Positioned at the structure so across-the-map kills rumble quietly.
    func structureDestroyed(playerOwned: Bool, at x: CGFloat) {
        play(.bigBoom, volume: 0.90, at: x)
        Haptics.structureDestroyed(playerOwned: playerOwned)
    }
    func explosionBig(at x: CGFloat) { play(.bigBoom, volume: 0.80, at: x) }

    func summon(at x: CGFloat) { play(.summon, volume: 0.45, at: x) }
    func pickup() { play(.pickup, volume: 0.50) }
    func uiTap() { play(.ui, volume: 0.40) }
    func weaponSwitch() { play(.weaponSwitch, volume: 0.45) }

    // MARK: - Playback core

    private enum Voice: String, CaseIterable {
        case blaster, scatter, cannon
        case tower, baseFan, enemy, ally
        case dry, reloadStart, reloadDone
        case impact, enemyDown, heroHurt, heroDeath, bigBoom
        case summon, pickup, ui, weaponSwitch

        /// Minimum seconds between re-triggers of the same voice.
        var minInterval: Double {
            switch self {
            case .blaster: return 0.05
            case .scatter: return 0.08
            case .cannon: return 0.15
            case .tower: return 0.09
            case .baseFan: return 0.20
            case .enemy, .ally: return 0.09
            case .dry: return 0.25
            case .reloadStart, .reloadDone: return 0.20
            case .impact: return 0.03
            case .enemyDown: return 0.08
            case .heroHurt: return 0.15
            case .heroDeath: return 0.30
            case .bigBoom: return 0.30
            case .summon: return 0.20
            case .pickup: return 0.10
            case .ui: return 0.05
            case .weaponSwitch: return 0.08
            }
        }
    }

    private func play(_ voice: Voice, volume: Float, at x: CGFloat? = nil) {
        guard sfxEnabled else { return }
        lock.lock()
        let now = CFAbsoluteTimeGetCurrent()
        if let last = lastPlay[voice], now - last < voice.minInterval {
            lock.unlock()
            return
        }
        lastPlay[voice] = now
        let lx = listenerX
        lock.unlock()

        // Proximity: quadratic falloff past fullRange down to the floor,
        // plus stereo pan by side. Listener-centered voices (reload, UI,
        // hero) skip attenuation entirely.
        var gain: Float = 1
        var pan: Float = 0
        if let x {
            let dist = abs(x - lx)
            let t = min(1, max(0, (dist - fullRange) / (hearRange - fullRange)))
            let att = 1 - t
            let attF = Float(att)
            gain = floorGain + (1 - floorGain) * attF * attF
            pan = min(1, max(-1, Float((x - lx) / 700)))
        }

        ensureStarted()
        guard let buffer = buffer(for: voice) else { return }
        // Near-identical repeats: real firearms don't wander in pitch, so
        // keep the wander tiny on guns (rate also stretches time) and let
        // impacts vary a touch more.
        let wobble: Float
        switch voice {
        case .impact: wobble = 0.04
        case .blaster, .scatter, .cannon, .tower, .baseFan, .enemy, .ally,
             .bigBoom, .enemyDown, .heroDeath:
            wobble = 0.01
        default: wobble = 0.02
        }
        let rate = 1.0 + Float.random(in: -wobble...wobble)

        lock.lock()
        guard !players.isEmpty else { lock.unlock(); return }
        let node = players[cursor]
        cursor = (cursor + 1) % players.count
        lock.unlock()

        node.volume = volume * gain
        node.pan = pan
        node.scheduleBuffer(buffer, at: nil, options: [])
        // Per-play pitch via a fresh rate each trigger.
        node.rate = rate
        if !node.isPlaying { node.play() }
    }

    // MARK: - Startup

    private func ensureStarted() {
        lock.lock()
        let needsBuild = !built
        lock.unlock()
        if needsBuild { buildAll() }

        lock.lock()
        let running = engine.isRunning
        lock.unlock()
        guard !running else { return }
        lock.lock()
        defer { lock.unlock() }
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio stays silent; game must never crash over sound.
            return
        }
        #endif
        for _ in 0..<10 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: renderFormat)
            players.append(node)
        }
        do {
            try engine.start()
        } catch {
            // Silent fallback.
        }
    }

    private func buffer(for voice: Voice) -> AVAudioPCMBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return buffers[voice]
    }

    private func buildAll() {
        lock.lock()
        guard !built else { lock.unlock(); return }
        lock.unlock()

        var made: [Voice: AVAudioPCMBuffer] = [:]
        // Action-grade voices: muzzle crack + dropping body + sub weight,
        // soft-clipped for grit. No chirpy pew sweeps, no coin arpeggios.
        // Realistic firearms: supersonic crack + powder body + dirt tail +
        // outdoor slapback. Distant/suppressed voices get extra lowpass.
        made[.blaster] = actionShot(bodyF0: 240, bodyF1: 85, dur: 0.22, crack: 1.0, sub: 0.7, drive: 1.6)
        made[.scatter] = actionShot(bodyF0: 170, bodyF1: 55, dur: 0.30, crack: 1.4, sub: 1.0, drive: 1.8)
        made[.cannon] = actionShot(bodyF0: 120, bodyF1: 30, dur: 0.60, crack: 1.2, sub: 1.4, drive: 1.8)
        made[.tower] = actionShot(bodyF0: 210, bodyF1: 75, dur: 0.22, crack: 0.8, sub: 0.7, drive: 1.6)
        made[.baseFan] = actionShot(bodyF0: 150, bodyF1: 48, dur: 0.35, crack: 1.0, sub: 1.0, drive: 1.7)
        made[.enemy] = actionShot(bodyF0: 320, bodyF1: 120, dur: 0.14, crack: 0.5, sub: 0.35, drive: 1.5, distance: 0.6)
        made[.ally] = actionShot(bodyF0: 260, bodyF1: 95, dur: 0.16, crack: 0.6, sub: 0.55, drive: 1.5, distance: 0.25)
        made[.dry] = metalTick()
        made[.reloadStart] = rackPair(up: false)
        made[.reloadDone] = rackPair(up: true)
        made[.impact] = groundThud()
        made[.enemyDown] = actionShot(bodyF0: 150, bodyF1: 50, dur: 0.30, crack: 0.7, sub: 0.9, drive: 2.2)
        made[.heroHurt] = actionShot(bodyF0: 130, bodyF1: 62, dur: 0.22, crack: 0.6, sub: 1.0, drive: 3.0)
        made[.heroDeath] = actionShot(bodyF0: 200, bodyF1: 34, dur: 0.70, crack: 0.8, sub: 1.3, drive: 2.5)
        made[.bigBoom] = cinematicBoom()
        made[.summon] = radioSquelch()
        made[.pickup] = tacticalConfirm()
        made[.ui] = uiClick()
        made[.weaponSwitch] = rackPair(up: true, light: true)

        lock.lock()
        buffers = made
        built = true
        lock.unlock()
    }

    // MARK: - Synthesis helpers (mono Float32 @ sampleRate)

    // MARK: - Synthesis: action-grade (crack + body + sub + grit)

    private func pcm(_ dur: Double) -> (AVAudioPCMBuffer, AVAudioFormat)? {
        guard let format = renderFormat,
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(dur * sampleRate)) else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity
        return (buffer, format)
    }

    /// Soft clipper: tube-like grit without harsh digital clipping.
    private func grit(_ x: Double, _ drive: Double) -> Double {
        tanh(x * drive) / tanh(drive)
    }

    /// Realistic gunshot: supersonic muzzle-crack (unfiltered noise, ~3ms)
    /// + powder body (mid noise + dropping tone) + sub weight + dark dirt
    /// tail, finished with a single outdoor slapback echo. `distance`
    /// darkens the voice for far/suppressed shots. No pew sweeps.
    private func actionShot(bodyF0: Double, bodyF1: Double, dur: Double,
                            crack: Double, sub: Double, drive: Double,
                            distance: Double = 0) -> AVAudioPCMBuffer? {
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var dry = [Double](repeating: 0, count: n)
        var phase = 0.0
        var subPhase = 0.0
        var bodyLP = 0.0
        var tailLP = 0.0
        let nearCrack = crack * (1.0 - distance * 0.4)
        let bright = max(0.12, 0.35 - distance * 0.18)
        let dark = 0.10 + distance * 0.22
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let k = t / dur
            let freq = bodyF0 + (bodyF1 - bodyF0) * k
            phase += 2.0 * .pi * freq / sampleRate
            subPhase += 2.0 * .pi * freq * 0.5 / sampleRate
            let attack = min(1.0, t / 0.001)
            let raw = Double.random(in: -1...1)
            let crackEnv = exp(-t * 320.0)
            bodyLP += bright * (raw - bodyLP)
            let bodyEnv = attack * exp(-t * 26.0)
            tailLP += dark * (raw - tailLP)
            let tailEnv = exp(-t * 9.0)
            let subEnv = attack * exp(-t * 7.0)
            dry[i] = (raw * nearCrack * crackEnv
                + (sin(phase) * 0.6 + bodyLP * 1.4) * bodyEnv
                + sin(subPhase) * sub * subEnv
                + tailLP * tailEnv * 0.7) * 0.5
        }
        // Outdoor slapback: one 45ms lowpassed echo off the far ridge.
        let delay = Int(0.045 * sampleRate)
        var echoLP = 0.0
        for i in 0..<n {
            var s = dry[i]
            if i >= delay {
                echoLP += 0.2 * (dry[i - delay] - echoLP)
                s += echoLP * 0.22
            }
            data[i] = Float(grit(s, drive) * 0.9)
        }
        return buffer
    }

    /// Dry-fire tick: metallic striker click, no body.
    private func metalTick() -> AVAudioPCMBuffer? {
        let dur = 0.06
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var phase = 0.0
        var lp = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            phase += 2.0 * .pi * 1900.0 / sampleRate
            let env = exp(-t * 140.0)
            let raw = Double.random(in: -1...1)
            lp += 0.6 * (raw - lp)
            data[i] = Float((sin(phase) * 0.5 + (raw - lp) * 0.6) * env * 0.5)
        }
        return buffer
    }

    /// Dirt thud for projectile impacts: low thump + muffled grit.
    private func groundThud() -> AVAudioPCMBuffer? {
        let dur = 0.09
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var phase = 0.0
        var lp = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            phase += 2.0 * .pi * 110.0 / sampleRate
            let env = exp(-t * 55.0)
            let raw = Double.random(in: -1...1)
            lp += 0.25 * (raw - lp)
            data[i] = Float(grit((sin(phase) + lp * 0.8) * env * 0.6, 1.5) * 0.8)
        }
        return buffer
    }

    /// Cinematic structure explosion: sub drop + rolling body + early
    /// crackle, soft-clipped. One full second of weight.
    private func cinematicBoom() -> AVAudioPCMBuffer? {
        let dur = 0.9
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var phase = 0.0
        var lp = 0.0
        var lp2 = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let k = t / dur
            let freq = 90.0 - 62.0 * k
            phase += 2.0 * .pi * freq / sampleRate
            let attack = min(1.0, t / 0.003)
            let env = attack * exp(-t * 4.2)
            let raw = Double.random(in: -1...1)
            lp += 0.25 * (raw - lp)   // crackle
            lp2 += 0.06 * (raw - lp2) // rolling body
            // Early crackle that settles into a rolling boom.
            let crackleMix = max(0.0, 1.0 - k * 2.2)
            let mix = sin(phase) * env * 1.1 + lp * env * crackleMix + lp2 * env * 1.6
            data[i] = Float(grit(mix * 0.5, 2.5) * 0.9)
        }
        return buffer
    }

    /// Radio squelch for summons: filtered noise swell + low confirm blip.
    private func radioSquelch() -> AVAudioPCMBuffer? {
        let dur = 0.24
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var lp = 0.0
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let k = t / dur
            let raw = Double.random(in: -1...1)
            lp += 0.30 * (raw - lp)
            let swell = sin(.pi * k)
            var sample = lp * swell * 0.9
            if t > 0.16 {
                let bt = t - 0.16
                phase += 2.0 * .pi * 240.0 / sampleRate
                sample += sin(phase) * exp(-bt * 30.0) * 0.5
            }
            data[i] = Float(sample * 0.6)
        }
        return buffer
    }

    /// Tactile UI click: short tick + quiet body, no chirp.
    private func uiClick() -> AVAudioPCMBuffer? {
        let dur = 0.045
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            phase += 2.0 * .pi * 900.0 / sampleRate
            let raw = Double.random(in: -1...1)
            let env = exp(-t * 130.0)
            data[i] = Float((sin(phase) * 0.5 + raw * 0.25) * env * 0.5)
        }
        return buffer
    }

    /// Weapon handling: dry metal rack. Full reloads get a second heavier
    /// rack + low confirm thump; weapon swaps stay light and fast.
    private func rackPair(up: Bool, light: Bool = false) -> AVAudioPCMBuffer? {
        let dur = light ? 0.12 : (up ? 0.24 : 0.16)
        let gap = light ? 0.05 : (up ? 0.10 : 0.06)
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            data[i] = Float(clack(at: t, when: 0, heavy: !light) +
                            clack(at: t, when: gap, heavy: up && !light) +
                            confirmThump(at: t, when: up && !light ? 0.16 : -1))
        }
        return buffer
    }

    /// One metal clack: bright strike + low thunk, fast decay.
    private func clack(at t: Double, when: Double, heavy: Bool) -> Double {
        guard t >= when else { return 0 }
        let lt = t - when
        let raw = Double.random(in: -1...1)
        let amp = heavy ? 0.9 : 0.6
        return (raw * exp(-lt * 110.0) * 0.7 + sin(2.0 * .pi * 170.0 * lt) * exp(-lt * 70.0) * 0.5) * amp * 0.5
    }

    /// Low confirm thump at the tail of a finished reload. `when` < 0 skips.
    private func confirmThump(at t: Double, when: Double) -> Double {
        guard when >= 0, t >= when else { return 0 }
        let lt = t - when
        return sin(2.0 * .pi * 140.0 * lt) * exp(-lt * 40.0) * 0.4
    }

    /// Tactical pickup confirm: tick head + two low solid tones.
    /// Deliberately an octave below coin-chime territory.
    private func tacticalConfirm() -> AVAudioPCMBuffer? {
        let notes = [330.0, 495.0]
        let noteDur = 0.07
        let dur = noteDur * Double(notes.count) + 0.06
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let idx = min(notes.count - 1, Int(t / noteDur))
            let lt = t - Double(idx) * noteDur
            phase += 2.0 * .pi * notes[idx] / sampleRate
            var sample = sin(phase) * exp(-lt * 24.0) * 0.8
            if t < 0.015 { sample += Double.random(in: -1...1) * 0.35 }
            data[i] = Float(sample * 0.5)
        }
        return buffer
    }
}

// MARK: - Haptics

/// Destruction-only haptics: towers, HQs, and the hero. Nothing else
/// buzzes — no UI, reload, pickup, or kill ticks.
enum Haptics {
    /// Tower / HQ destroyed: heavy slam + success (enemy fell) or error (we fell).
    static func structureDestroyed(playerOwned: Bool) {
        impact(.heavy)
        dispatch {
            let note = UINotificationFeedbackGenerator()
            note.notificationOccurred(playerOwned ? .error : .success)
        }
    }

    static func heroDeath() {
        impact(.heavy)
        dispatch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        dispatch {
            let gen = UIImpactFeedbackGenerator(style: style)
            gen.impactOccurred()
        }
    }

    private static func dispatch(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
