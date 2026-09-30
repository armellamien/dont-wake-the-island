import CoreGraphics
import Foundation

struct Creature: Sendable {
    var slowRemaining: TimeInterval = 0

    var isSlowed: Bool { slowRemaining > 0 }

    static let slowDuration: TimeInterval = 3
    static let wakeDuration: TimeInterval = 1.8

    func speed(difficulty: Double) -> CGFloat {
        let base = min(110 + CGFloat(difficulty - 1) * 26, 330)
        return isSlowed ? base * 0.45 : base
    }
}
