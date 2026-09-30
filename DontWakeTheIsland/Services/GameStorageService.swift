import Foundation
import SwiftData

@MainActor
final class GameStorageService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func stats() -> PlayerStats {
        if let existing = try? context.fetch(FetchDescriptor<PlayerStats>()).first {
            return existing
        }
        let stats = PlayerStats()
        context.insert(stats)
        save()
        return stats
    }

    func settings() -> GameSettings {
        if let existing = try? context.fetch(FetchDescriptor<GameSettings>()).first {
            return existing
        }
        let settings = GameSettings()
        context.insert(settings)
        save()
        return settings
    }

    /// Returns `true` when the result is a new best score.
    @discardableResult
    func record(_ result: GameResult) -> Bool {
        let stats = stats()
        let isNewBest = result.score > stats.bestScore
        stats.gamesPlayed += 1
        stats.totalCoins += result.coins
        stats.bestScore = max(stats.bestScore, result.score)
        stats.bestTime = max(stats.bestTime, result.duration)
        stats.maxLevel = max(stats.maxLevel, result.level)
        stats.bestCombo = max(stats.bestCombo, result.bestCombo)
        context.insert(ScoreEntry(score: result.score, coins: result.coins, duration: result.duration, level: result.level))
        save()
        return isNewBest
    }

    func resetStats() {
        try? context.delete(model: ScoreEntry.self)
        try? context.delete(model: PlayerStats.self)
        save()
    }

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
