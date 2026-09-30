import Observation
import SwiftData

/// Long-lived services shared by every screen.
@Observable
@MainActor
final class AppDependencies {
    let storage: GameStorageService
    let haptics: HapticService
    let audio: AudioService
    let island: DynamicIslandViewModel
    let settings: SettingsViewModel

    init(context: ModelContext) {
        storage = GameStorageService(context: context)
        haptics = HapticService()
        audio = AudioService()
        island = DynamicIslandViewModel()
        settings = SettingsViewModel(storage: storage, audio: audio, haptics: haptics, island: island)
    }
}
