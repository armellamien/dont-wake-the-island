import Foundation

enum CoinKind: CaseIterable, Sendable {
    case coin
    case gem
    case star
    case moon

    var points: Int {
        switch self {
        case .coin: 10
        case .gem: 50
        case .star: 25
        case .moon: 5
        }
    }

    /// Negative values calm the creature down.
    var noise: Double {
        switch self {
        case .coin: 1
        case .gem, .star: NoiseRules.bigBonus
        case .moon: -25
        }
    }

    var lifetime: TimeInterval {
        switch self {
        case .coin: 6
        case .gem: 3.5
        case .star: 4.5
        case .moon: 5
        }
    }

    static func random(phase: GamePhase, difficulty: Double) -> CoinKind {
        let roll = Double.random(in: 0..<1)
        if phase == .chase {
            if roll < 0.08 { return .star }
            if roll < 0.16 { return .gem }
            if roll < 0.22 { return .moon }
            return .coin
        }
        if roll < 0.10 { return .gem }
        if roll < 0.16 { return .star }
        if roll < 0.16 + min(0.08, 0.02 * difficulty) { return .moon }
        return .coin
    }
}
