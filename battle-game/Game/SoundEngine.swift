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

    /// Victory sting: triumphant major run over a war-drum thump.
    func victory() { play(.victory, volume: 0.70) }

    // MARK: - Battle music (procedural driving rock, zero assets)

    var musicEnabled: Bool {
        if UserDefaults.standard.object(forKey: "settings.music") == nil { return true }
        return UserDefaults.standard.bool(forKey: "settings.music")
    }

    private var musicNode: AVAudioPlayerNode?
    private var musicLoop: AVAudioPCMBuffer?
    private var musicOn = false
    private let musicVolume: Float = 0.30

    /// Starts the battle loop (idempotent while playing). Safe to call on
    /// every level start: a stopped node gets its loop buffer re-scheduled
    /// (`stop()` clears a node's queue, so replaying without rescheduling
    /// would be silence — that's what broke restarts).
    func startBattleMusic() {
        guard musicEnabled else { return }
        lock.lock()
        let on = musicOn
        lock.unlock()
        if on { return }
        ensureStarted()
        lock.lock()
        if musicNode == nil {
            lock.unlock()
            guard let loop = buildBattleLoop() else { return }
            lock.lock()
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: renderFormat)
            node.volume = musicVolume
            musicNode = node
            musicLoop = loop
        }
        let node = musicNode
        let loop = musicLoop
        lock.unlock()
        if let node, let loop {
            node.scheduleBuffer(loop, at: nil, options: .loops)
            node.play()
        }
        lock.lock()
        musicOn = true
        lock.unlock()
    }

    func stopBattleMusic() {
        lock.lock()
        defer { lock.unlock() }
        musicNode?.stop()
        musicOn = false
    }

    /// Poll-friendly toggle sync (the scene calls this ~1/sec): starts the
    /// loop if the user flipped music on mid-battle, stops it if off.
    func syncMusic() {
        if musicEnabled {
            startBattleMusic()
        } else {
            stopBattleMusic()
        }
    }

    /// 4-bar loop, 142 BPM, Em – C – G – D: four-on-the-floor kicks,
    /// backbeat snares, 8th hats, driving root bass, palm-muted power-chord
    /// chugs with a fill into the top. Peak-normalized, click-free seam.
    private func buildBattleLoop() -> AVAudioPCMBuffer? {
        let bpm = 142.0
        let step = 60.0 / bpm / 4 // 16th note
        let bars = 4
        let total = step * 16 * Double(bars)
        guard let (buffer, _) = pcm(total),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var mix = [Double](repeating: 0, count: n)
        let roots = [82.41, 65.41, 98.0, 73.42] // E2 C2 G2 D2
        for bar in 0..<bars {
            let barStart = Double(bar) * 16 * step
            if bar == 0 { addCrash(&mix, at: barStart) }
            for s in 0..<16 {
                let t = barStart + Double(s) * step
                if s % 2 == 0 { addHat(&mix, at: t, open: s == 14) }
                if s % 4 == 0 || (bar == 3 && s == 14) { addKick(&mix, at: t) }
                if s == 4 || s == 12 { addSnare(&mix, at: t, gain: 1.0) }
                if s % 2 == 0 {
                    let root = roots[bar]
                    let f = (s == 10) ? root * 2 : root // octave pop
                    addBass(&mix, at: t, freq: f, dur: step * 2 * 0.92)
                    addChug(&mix, at: t, root: root, dur: step * 2 * 0.9, accent: s % 4 == 0)
                }
            }
            if bar == 3 {
                // Fill into the top: rising snare 16ths (kept clear of the seam).
                for (k, s) in [11, 12, 13, 14].enumerated() {
                    addSnare(&mix, at: barStart + Double(s) * step, gain: 0.5 + 0.18 * Double(k))
                }
            }
        }
        // Seam guard: 12ms fade so the loop never clicks.
        let fade = Int(0.012 * sampleRate)
        for j in 0..<min(fade, n) {
            mix[n - 1 - j] *= Double(j) / Double(fade)
        }
        var peak = 0.0
        for v in mix { peak = max(peak, abs(v)) }
        let norm = peak > 0 ? 0.7 / peak : 1.0
        for i in 0..<n { data[i] = Float(mix[i] * norm) }
        return buffer
    }

    private func addKick(_ mix: inout [Double], at t: Double) {
        let dur = 0.14
        let start = Int(t * sampleRate)
        let count = Int(dur * sampleRate)
        var phase = 0.0
        for j in 0..<count {
            let idx = start + j
            if idx >= mix.count { break }
            let lt = Double(j) / sampleRate
            let freq = 40.0 + 90.0 * exp(-lt * 45.0)
            phase += 2.0 * .pi * freq / sampleRate
            mix[idx] += sin(phase) * exp(-lt * 28.0) * 1.0
                + Double.random(in: -1...1) * exp(-lt * 160.0) * 0.22
        }
    }

    private func addSnare(_ mix: inout [Double], at t: Double, gain: Double) {
        let dur = 0.16
        let start = Int(t * sampleRate)
        let count = Int(dur * sampleRate)
        var phase = 0.0
        var lp = 0.0
        for j in 0..<count {
            let idx = start + j
            if idx >= mix.count { break }
            let lt = Double(j) / sampleRate
            phase += 2.0 * .pi * 190.0 / sampleRate
            let raw = Double.random(in: -1...1)
            lp += 0.45 * (raw - lp)
            mix[idx] += (lp * exp(-lt * 32.0) * 0.9 + sin(phase) * exp(-lt * 40.0) * 0.5) * gain
        }
    }

    private func addHat(_ mix: inout [Double], at t: Double, open: Bool) {
        let dur = open ? 0.11 : 0.035
        let start = Int(t * sampleRate)
        let count = Int(dur * sampleRate)
        var lp = 0.0
        for j in 0..<count {
            let idx = start + j
            if idx >= mix.count { break }
            let lt = Double(j) / sampleRate
            let raw = Double.random(in: -1...1)
            lp += 0.9 * (raw - lp) // very bright: keep the sizzle on top
            mix[idx] += (raw - lp) * exp(-lt * (open ? 30.0 : 140.0)) * (open ? 0.30 : 0.22)
        }
    }

    private func addCrash(_ mix: inout [Double], at t: Double) {
        let dur = 0.7
        let start = Int(t * sampleRate)
        let count = Int(dur * sampleRate)
        var lp = 0.0
        for j in 0..<count {
            let idx = start + j
            if idx >= mix.count { break }
            let lt = Double(j) / sampleRate
            let raw = Double.random(in: -1...1)
            lp += 0.55 * (raw - lp)
            mix[idx] += (raw - lp * 0.5) * exp(-lt * 7.0) * 0.30
        }
    }

    private func addBass(_ mix: inout [Double], at t: Double, freq: Double, dur: Double) {
        let start = Int(t * sampleRate)
        let count = Int(dur * sampleRate)
        var phase = 0.0
        for j in 0..<count {
            let idx = start + j
            if idx >= mix.count { break }
            let lt = Double(j) / sampleRate
            phase += 2.0 * .pi * freq / sampleRate
            // Gated 8th: punchy attack, palm-muted sustain, click-free release.
            let attack = min(1.0, lt / 0.004)
            let rel = min(1.0, (dur - lt) / (dur * 0.2))
            let env = attack * rel * (0.72 + 0.28 * exp(-lt * 18.0))
            let pick = lt < 0.01 ? Double.random(in: -1...1) * 0.3 : 0
            mix[idx] += (tanh(sin(phase) * 2.2) * 0.7 + pick) * env * 0.55
        }
    }

    private func addChug(_ mix: inout [Double], at t: Double, root: Double, dur: Double, accent: Bool) {
        // Power chord an octave above the bass root: root + fifth + octave.
        let r = root * 2
        let freqs = [r, r * 1.5, r * 2]
        let start = Int(t * sampleRate)
        let count = Int(dur * sampleRate)
        var phases = [0.0, 0.0, 0.0]
        let detune = [1.003, 0.997, 1.0]
        var lp = 0.0
        for j in 0..<count {
            let idx = start + j
            if idx >= mix.count { break }
            let lt = Double(j) / sampleRate
            var s = 0.0
            for v in 0..<3 {
                phases[v] += 2.0 * .pi * freqs[v] * detune[v] / sampleRate
                let cyc = phases[v].truncatingRemainder(dividingBy: 2.0 * .pi) / (2.0 * .pi)
                s += cyc * 2.0 - 1.0
            }
            s /= 3.0
            lp += 0.25 * (s - lp) // heavy cab: shave the fizz
            let attack = min(1.0, lt / 0.003)
            let rel = min(1.0, (dur - lt) / (dur * 0.15))
            let env = attack * rel * (0.7 + 0.3 * exp(-lt * 22.0))
            mix[idx] += tanh(lp * 3.0) * env * (accent ? 0.34 : 0.27)
        }
    }

    // MARK: - Playback core

    private enum Voice: String, CaseIterable {
        case blaster, scatter, cannon
        case tower, baseFan, enemy, ally
        case dry, reloadStart, reloadDone
        case impact, enemyDown, heroHurt, heroDeath, bigBoom
        case summon, pickup, ui, weaponSwitch, victory

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
            case .victory: return 1.0
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

    /// Pre-spins the engine off the main thread (session activation +
    /// buffer synthesis + `engine.start()` cost ~100ms+ on first use).
    /// Call from the main menu's `.task` so the first real tap — DEPLOY —
    /// never eats that hitch inside the navigation push.
    func warmUp() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.ensureStarted()
        }
    }

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
        // Realistic firearms: supersonic crack forward, lean body, restrained
        // sub — no bass-drum thump. Distant/suppressed voices get lowpass.
        // Firearms voice: airy "tshsst" crack forward, lean body, restrained
        // sub — snap and hiss, never a bass-drum thump.
        made[.blaster] = actionShot(bodyF0: 280, bodyF1: 110, dur: 0.15, crack: 1.1, sub: 0.25, drive: 1.2, hiss: 1.3, body: 0.55)
        made[.scatter] = actionShot(bodyF0: 190, bodyF1: 65, dur: 0.22, crack: 1.3, sub: 0.45, drive: 1.4, hiss: 1.1, body: 0.7)
        made[.cannon] = plasmaBlast()
        made[.tower] = actionShot(bodyF0: 230, bodyF1: 85, dur: 0.18, crack: 0.9, sub: 0.4, drive: 1.3, hiss: 0.7, body: 0.9)
        made[.baseFan] = actionShot(bodyF0: 160, bodyF1: 52, dur: 0.30, crack: 1.0, sub: 0.6, drive: 1.4, hiss: 0.8, body: 0.9)
        made[.enemy] = actionShot(bodyF0: 360, bodyF1: 140, dur: 0.12, crack: 0.6, sub: 0.25, drive: 1.2, distance: 0.6, hiss: 0.4, body: 0.8)
        made[.ally] = actionShot(bodyF0: 280, bodyF1: 105, dur: 0.14, crack: 0.7, sub: 0.35, drive: 1.2, distance: 0.25, hiss: 0.6, body: 0.8)
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
        made[.victory] = triumph()
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

    /// Realistic gunshot: airy "tshsst" hiss-crack over a lean dropping
    /// body, restrained sub, dark dirt tail, outdoor slapback. `hiss`
    /// sets the sibilant bite; `body` scales the tonal weight; `distance`
    /// darkens far/suppressed shots. No pew sweeps.
    private func actionShot(bodyF0: Double, bodyF1: Double, dur: Double,
                            crack: Double, sub: Double, drive: Double,
                            distance: Double = 0, hiss: Double = 0.5, body: Double = 1.0) -> AVAudioPCMBuffer? {
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var dry = [Double](repeating: 0, count: n)
        var phase = 0.0
        var subPhase = 0.0
        var bodyLP = 0.0
        var tailLP = 0.0
        var hissLP = 0.0
        let nearCrack = crack * (1.0 - distance * 0.4)
        let nearHiss = hiss * (1.0 - distance * 0.55)
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
            // Sibilant "tss": highpassed noise, ~14ms airy tail.
            hissLP += 0.85 * (raw - hissLP)
            let tss = (raw - hissLP) * exp(-t * 70.0) * nearHiss
            bodyLP += bright * (raw - bodyLP)
            let bodyEnv = attack * exp(-t * 30.0)
            tailLP += dark * (raw - tailLP)
            let tailEnv = exp(-t * 10.0)
            let subEnv = attack * exp(-t * 12.0)
            dry[i] = (raw * nearCrack * crackEnv + tss
                + (sin(phase) * 0.6 + bodyLP * 1.4) * bodyEnv * body
                + sin(subPhase) * sub * subEnv
                + tailLP * tailEnv * 0.5) * 0.5
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

    /// Plasma cannon: an 80ms charge whine swelling upward, then a bright
    /// energy discharge — falling sizzle, ringing partials, ionized tail.
    /// The charge is part of the blast itself, so trigger feel stays instant.
    private func plasmaBlast() -> AVAudioPCMBuffer? {
        let charge = 0.08, dur = 0.42
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var chargePhase = 0.0
        var dumpPhase = 0.0
        var ringA = 0.0, ringB = 0.0
        var sizzleLP = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let raw = Double.random(in: -1...1)
            var s = 0.0
            if t < charge {
                // Charge whine: swelling sine sweeping upward + rising hiss.
                let k = t / charge
                let freq = 250.0 + 1150.0 * k * k
                chargePhase += 2.0 * .pi * freq / sampleRate
                let swell = sin(0.5 * .pi * k)
                s += sin(chargePhase) * swell * 0.55
                s += raw * 0.10 * swell
            } else {
                // Discharge.
                let bt = t - charge
                let freq = 180.0 + 1420.0 * exp(-bt * 14.0)
                dumpPhase += 2.0 * .pi * freq / sampleRate
                let cyc = dumpPhase.truncatingRemainder(dividingBy: 2.0 * .pi) / (2.0 * .pi)
                let saw = cyc * 2.0 - 1.0
                // Ionized sizzle: bright noise that falls off fast.
                sizzleLP += 0.7 * (raw - sizzleLP)
                let sizzle = (raw - sizzleLP) * exp(-bt * 30.0)
                // Ringing energy partials.
                ringA += 2.0 * .pi * 2400.0 / sampleRate
                ringB += 2.0 * .pi * 3150.0 / sampleRate
                let rings = (sin(ringA) + sin(ringB) * 0.6) * exp(-bt * 10.0) * 0.35
                let dumpEnv = exp(-bt * 12.0)
                s += (saw * 0.8 + sizzle * 0.9 + rings) * dumpEnv + rings * 0.4
            }
            data[i] = Float(grit(s * 0.6, 1.6) * 0.9)
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

    /// Victory sting: war-drum thump under a rising E-major run
    /// (E–G#–B–E) with a final shimmering octave. Bold, not chirpy.
    private func triumph() -> AVAudioPCMBuffer? {
        let notes = [164.81, 207.65, 246.94, 329.63]
        let noteDur = 0.13
        let dur = noteDur * Double(notes.count) + 0.35
        guard let (buffer, _) = pcm(dur),
              let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var phase = 0.0
        var drumPhase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let idx = min(notes.count - 1, Int(t / noteDur))
            let lt = t - Double(idx) * noteDur
            phase += 2.0 * .pi * notes[idx] / sampleRate
            // Brassy voice: fundamental + octave shimmer, swelling per note.
            let swell = min(1.0, lt / 0.02) * exp(-lt * 6.0)
            var sample = (sin(phase) + sin(phase * 2) * 0.35) * swell * 0.7
            // Final note blooms instead of dying.
            if idx == notes.count - 1 {
                sample = (sin(phase) + sin(phase * 2) * 0.4) * min(1.0, lt / 0.03) * 0.8
            }
            // War-drum heartbeat under the first and last notes.
            if idx == 0 || idx == notes.count - 1 {
                let dt = idx == 0 ? t : lt
                drumPhase += 2.0 * .pi * 65.0 / sampleRate
                sample += sin(drumPhase) * exp(-dt * 14.0) * 0.8
            }
            data[i] = Float(grit(sample * 0.5, 1.5) * 0.85)
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
