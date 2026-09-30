import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var soundEnabled: Bool { didSet { persist() } }
    var musicEnabled: Bool { didSet { persist() } }
    var hapticsEnabled: Bool {
        didSet {
            persist()
            if hapticsEnabled { haptics.play(.coin) }
        }
    }
    var liveActivityEnabled: Bool { didSet { persist() } }

    @ObservationIgnored private let storage: GameStorageService
    @ObservationIgnored private let audio: AudioService
    @ObservationIgnored private let haptics: HapticService
    @ObservationIgnored private let island: DynamicIslandViewModel

    var liveActivitiesAuthorized: Bool { island.liveActivitiesAuthorized }

    init(storage: GameStorageService, audio: AudioService, haptics: HapticService, island: DynamicIslandViewModel) {
        self.storage = storage
        self.audio = audio
        self.haptics = haptics
        self.island = island
        let settings = storage.settings()
        soundEnabled = settings.soundEnabled
        musicEnabled = settings.musicEnabled
        hapticsEnabled = settings.hapticsEnabled
        liveActivityEnabled = settings.liveActivityEnabled
        apply()
    }

    func resetStats() {
        storage.resetStats()
    }

    private func persist() {
        let settings = storage.settings()
        settings.soundEnabled = soundEnabled
        settings.musicEnabled = musicEnabled
        settings.hapticsEnabled = hapticsEnabled
        settings.liveActivityEnabled = liveActivityEnabled
        storage.save()
        apply()
    }

    private func apply() {
        audio.sfxEnabled = soundEnabled
        audio.musicEnabled = musicEnabled
        haptics.isEnabled = hapticsEnabled
        island.liveActivitiesEnabled = liveActivityEnabled
    }
}
