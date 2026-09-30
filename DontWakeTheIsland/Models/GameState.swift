import Foundation

enum GamePhase: Equatable, Sendable {
    case sleeping
    case waking
    case chase
    case gameOver
}

enum NoiseRules {
    static let tap: Double = 2
    static let doubleTap: Double = 5
    static let rapid: Double = 8
    static let swipe: Double = 3
    static let bigBonus: Double = 10
    static let dangerThreshold: Double = 65
    static let rearmThreshold: Double = 50
    static let rapidWindow: TimeInterval = 1.0
    static let rapidCount = 4
    /// Actions close to the island are louder.
    static func proximityFactor(_ closeness: Double) -> Double { 1 + closeness * 0.6 }
}

struct ScoreBreakdown: Equatable, Sendable {
    var coinPoints = 0
    var survival: Double = 0
    var bonusPoints = 0

    var survivalPoints: Int { Int(survival) }
    var total: Int { coinPoints + survivalPoints + bonusPoints }
}

struct GameState: Equatable, Sendable {
    var phase: GamePhase = .sleeping
    var noiseLevel: Double = 0
    var difficulty: Double = 1
    var elapsed: TimeInterval = 0
    var coinsCollected = 0
    var combo = 0
    var bestCombo = 0
    var multiplierRemaining: TimeInterval = 0
    var breakdown = ScoreBreakdown()

    var score: Int { breakdown.total }
    var level: Int { Int(difficulty) }
    var noisePercent: Int { Int(noiseLevel.rounded()) }
    var comboMultiplier: Double { 1 + Double(min(combo, 20)) * 0.1 }
    var difficultyMultiplier: Double { 1 + (difficulty - 1) * 0.25 }

    var mood: IslandMood {
        switch phase {
        case .sleeping:
            if noiseLevel < 15 { .sleeping } else if noiseLevel < NoiseRules.dangerThreshold { .calm } else { .danger }
        case .waking: .awake
        case .chase: .chase
        case .gameOver: .gameOver
        }
    }
}

struct GameResult: Equatable, Sendable {
    var score: Int
    var coins: Int
    var duration: TimeInterval
    var level: Int
    var bestCombo: Int
    var breakdown: ScoreBreakdown
}
