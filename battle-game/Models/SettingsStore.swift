import Combine
import Foundation
import SwiftUI

/// Settings ported from Unity's settings/pause buttons. Persisted in UserDefaults.
final class SettingsStore: ObservableObject {
    @AppStorage("settings.music") var musicEnabled = true
    @AppStorage("settings.sfx") var sfxEnabled = true
    /// 0.5 ... 1.5 multiplier applied to joystick look/turn speed in stage 2.
    @AppStorage("settings.sensitivity") var sensitivity = 1.0

    func resetCampaign() {
        CampaignData.reset()
        objectWillChange.send()
    }
}
