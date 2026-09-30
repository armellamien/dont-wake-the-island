import Foundation
import SwiftData

@Model
final class PlayerStats {
    var bestScore: Int = 0
    var gamesPlayed: Int = 0
    var totalCoins: Int = 0
    var bestTime: Double = 0
    var maxLevel: Int = 1
    var bestCombo: Int = 0

    init() {}
}

@Model
final class ScoreEntry {
    var score: Int
    var coins: Int
    var duration: Double
    var level: Int
    var date: Date

    init(score: Int, coins: Int, duration: Double, level: Int, date: Date = .now) {
        self.score = score
        self.coins = coins
        self.duration = duration
        self.level = level
        self.date = date
    }
}
