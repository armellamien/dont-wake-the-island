import ActivityKit
import Foundation

/// Thin wrapper around the ActivityKit Live Activity. Callers decide *when* to push;
/// this type only drops redundant updates.
@MainActor
final class IslandActivity {
    private var activity: Activity<IslandAttributes>?
    private var lastSent: IslandAttributes.ContentState?

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isRunning: Bool { activity != nil }

    func start(with state: IslandAttributes.ContentState) {
        guard isAvailable, activity == nil else { return }
        do {
            activity = try Activity.request(
                attributes: IslandAttributes(startedAt: .now),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            lastSent = state
        } catch {
            activity = nil
        }
    }

    func update(_ state: IslandAttributes.ContentState) {
        guard let activity, state != lastSent else { return }
        lastSent = state
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(with state: IslandAttributes.ContentState? = nil, dismissAfter delay: TimeInterval = 0) {
        guard let activity else { return }
        self.activity = nil
        lastSent = nil
        let content = state.map { ActivityContent(state: $0, staleDate: nil) }
        let policy: ActivityUIDismissalPolicy = delay > 0 ? .after(.now + delay) : .immediate
        Task {
            await activity.end(content, dismissalPolicy: policy)
        }
    }

    /// Cleans up activities left over from a previous launch.
    static func endAll() {
        Task {
            for activity in Activity<IslandAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
