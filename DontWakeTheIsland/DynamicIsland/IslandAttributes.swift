import ActivityKit
import SwiftUI

// Shared between the app and the widget extension.

enum IslandMood: String, Codable, Hashable, Sendable {
    case sleeping
    case calm
    case danger
    case awake
    case chase
    case gameOver

    var emoji: String {
        switch self {
        case .sleeping, .calm: "😴"
        case .danger: "⚠️"
        case .awake: "😡"
        case .chase: "👾"
        case .gameOver: "💀"
        }
    }

    var tint: Color {
        switch self {
        case .sleeping: Color(red: 0.70, green: 0.65, blue: 1.00)
        case .calm: Color(red: 0.35, green: 0.95, blue: 1.00)
        case .danger: Color(red: 1.00, green: 0.72, blue: 0.25)
        case .awake, .chase: Color(red: 1.00, green: 0.27, blue: 0.30)
        case .gameOver: Color(white: 0.85)
        }
    }
}

struct IslandAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var mood: IslandMood
        var noise: Int
        var score: Int
        var coins: Int
        var level: Int
        var isPaused: Bool

        static let idle = ContentState(mood: .sleeping, noise: 0, score: 0, coins: 0, level: 1, isPaused: false)
    }

    var startedAt: Date
}

extension IslandAttributes.ContentState {
    /// Text shown next to the creature in the compact presentation.
    var compactText: String {
        switch mood {
        case .sleeping: "Zzz..."
        case .calm, .danger: "\(noise)%"
        case .awake: "!!!"
        case .chase: score.spaced
        case .gameOver: "GAME OVER"
        }
    }

    var headline: String {
        if isPaused { return "En pause — touche pour reprendre" }
        return switch mood {
        case .sleeping: "L'île dort profondément…"
        case .calm: "Elle remue dans son sommeil"
        case .danger: "Chut ! Elle va se réveiller"
        case .awake: "WHO WOKE ME UP?!"
        case .chase: "Elle te poursuit !"
        case .gameOver: "GAME OVER"
        }
    }
}

extension Int {
    /// "12 450"
    var spaced: String {
        formatted(.number.grouping(.automatic).locale(Locale(identifier: "fr_FR")))
    }
}
