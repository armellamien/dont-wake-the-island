import SwiftData
import SwiftUI

@main
struct DontWakeTheIslandApp: App {
    private let container: ModelContainer
    @State private var dependencies: AppDependencies

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: PlayerStats.self, ScoreEntry.self, GameSettings.self)
        } catch {
            fatalError("Impossible d'initialiser SwiftData : \(error)")
        }
        self.container = container
        _dependencies = State(initialValue: AppDependencies(context: container.mainContext))
        IslandActivity.endAll()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(dependencies)
                .preferredColorScheme(.dark)
                // Opened from the Live Activity: the paused game is simply brought back to the front.
                .onOpenURL { _ in }
        }
        .modelContainer(container)
    }
}
