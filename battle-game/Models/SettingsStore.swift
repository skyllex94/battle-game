import Combine
import Foundation

/// Settings ported from Unity's settings/pause buttons. Persisted in UserDefaults.
///
/// `@Published` + explicit saves (rather than `@AppStorage`) so every panel
/// redraws the moment a toggle, slider or quality chip changes. The battle
/// layer reads the same keys through the `GameSettings` accessors below.
final class SettingsStore: ObservableObject {
    @Published var musicEnabled: Bool { didSet { save(musicEnabled, "settings.music") } }
    @Published var musicVolume: Double { didSet { save(musicVolume, "settings.musicVolume") } }
    @Published var sfxEnabled: Bool { didSet { save(sfxEnabled, "settings.sfx") } }
    @Published var sfxVolume: Double { didSet { save(sfxVolume, "settings.sfxVolume") } }
    @Published var hapticsEnabled: Bool { didSet { save(hapticsEnabled, "settings.haptics") } }
    @Published var particlesEnabled: Bool { didSet { save(particlesEnabled, "settings.particles") } }
    @Published var weatherEnabled: Bool { didSet { save(weatherEnabled, "settings.weather") } }
    @Published var muzzleFlashEnabled: Bool { didSet { save(muzzleFlashEnabled, "settings.muzzleFlash") } }
    @Published var effectsQuality: String { didSet { save(effectsQuality, "settings.effectsQuality") } }
    /// 0.5 ... 1.5 multiplier applied to joystick look/turn speed in stage 2.
    @Published var sensitivity: Double { didSet { save(sensitivity, "settings.sensitivity") } }

    init() {
        let defaults = UserDefaults.standard
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        func double(_ key: String, _ fallback: Double) -> Double {
            defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
        }
        musicEnabled = bool("settings.music", true)
        musicVolume = double("settings.musicVolume", 0.7)
        sfxEnabled = bool("settings.sfx", true)
        sfxVolume = double("settings.sfxVolume", 0.8)
        hapticsEnabled = bool("settings.haptics", true)
        particlesEnabled = bool("settings.particles", true)
        weatherEnabled = bool("settings.weather", true)
        muzzleFlashEnabled = bool("settings.muzzleFlash", true)
        effectsQuality = defaults.string(forKey: "settings.effectsQuality")
            ?? GameSettings.EffectsQuality.standard.rawValue
        sensitivity = double("settings.sensitivity", 1.0)
    }

    func resetCampaign() {
        CampaignData.reset()
        objectWillChange.send()
    }

    /// Restore every tunable to its first-run value. Campaign progress is
    /// deliberately untouched.
    func restoreDefaults() {
        musicEnabled = true
        musicVolume = 0.7
        sfxEnabled = true
        sfxVolume = 0.8
        hapticsEnabled = true
        particlesEnabled = true
        weatherEnabled = true
        muzzleFlashEnabled = true
        effectsQuality = GameSettings.EffectsQuality.standard.rawValue
        sensitivity = 1.0
        SoundEngine.shared.applyVolumes()
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

/// Read-only accessors for the values the SpriteKit layer needs every frame
/// or on every particle spawn. UserDefaults keeps this cheap and thread-safe;
/// missing keys fall back to the same defaults the settings screen shows.
enum GameSettings {
    enum EffectsQuality: String, CaseIterable, Identifiable {
        case low, standard, high

        var id: String { rawValue }

        var title: String {
            switch self {
            case .low: return "LOW"
            case .standard: return "STANDARD"
            case .high: return "HIGH"
            }
        }

        /// Fraction of debris / smoke / trail particles to spawn.
        var particleScale: Double {
            switch self {
            case .low: return 0.35
            case .standard: return 0.7
            case .high: return 1.0
            }
        }
    }

    static var particlesEnabled: Bool {
        BoolDefault("settings.particles", fallback: true)
    }

    /// Snowfall overlay on snow levels. Independent from particles so a
    /// player can keep combat FX but clear the snow (visibility + battery).
    static var weatherEnabled: Bool {
        BoolDefault("settings.weather", fallback: true)
    }

    static var hapticsEnabled: Bool {
        BoolDefault("settings.haptics", fallback: true)
    }

    static var muzzleFlashEnabled: Bool {
        BoolDefault("settings.muzzleFlash", fallback: true)
    }

    static var effectsQuality: EffectsQuality {
        let raw = UserDefaults.standard.string(forKey: "settings.effectsQuality")
        return EffectsQuality(rawValue: raw ?? "") ?? .standard
    }

    static var particleScale: Double {
        particlesEnabled ? effectsQuality.particleScale : 0
    }

    private static func BoolDefault(_ key: String, fallback: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return fallback }
        return UserDefaults.standard.bool(forKey: key)
    }
}
