import Foundation
import Observation

/// Drives both islands:
/// - the in-app island drawn over the hardware Dynamic Island (or a classic pill on other iPhones),
///   updated every frame because it is plain SwiftUI;
/// - the ActivityKit Live Activity, only visible once the player leaves the app, so it is
///   pushed sparingly: on mood changes, pause/resume and game over.
@Observable
@MainActor
final class DynamicIslandViewModel {
    private(set) var content = IslandAttributes.ContentState.idle
    private(set) var banner: String?
    private(set) var isExpanded = false
    /// Incremented to trigger a shake animation.
    private(set) var shakeTrigger = 0

    var liveActivitiesEnabled = true {
        didSet {
            if !liveActivitiesEnabled { activity.end() }
        }
    }

    @ObservationIgnored private let activity = IslandActivity()
    @ObservationIgnored private var bannerToken = 0

    var liveActivitiesAuthorized: Bool { activity.isAvailable }

    func begin(with state: IslandAttributes.ContentState) {
        activity.end()
        content = state
        banner = nil
        isExpanded = false
        if liveActivitiesEnabled { activity.start(with: state) }
    }

    func sync(_ state: IslandAttributes.ContentState, force: Bool = false) {
        let moodChanged = state.mood != content.mood || state.isPaused != content.isPaused
        if state != content { content = state }
        if moodChanged, state.mood == .danger || state.mood == .awake { shakeTrigger += 1 }
        if moodChanged || force { activity.update(state) }
    }

    /// Expands the island with a message, like a system Dynamic Island alert.
    func announce(_ message: String, duration: TimeInterval) {
        bannerToken += 1
        let token = bannerToken
        banner = message
        isExpanded = true
        shakeTrigger += 1
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, self.bannerToken == token else { return }
            self.banner = nil
            self.isExpanded = false
        }
    }

    func finish(with state: IslandAttributes.ContentState) {
        content = state
        announce("💀 GAME OVER", duration: 1.6)
        activity.end(with: state, dismissAfter: 10)
    }

    func cancel() {
        activity.end()
        bannerToken += 1
        banner = nil
        isExpanded = false
        content = .idle
    }
}
