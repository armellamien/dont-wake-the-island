import Foundation
import SwiftData

@Model
final class GameSettings {
    var soundEnabled: Bool = true
    var musicEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var liveActivityEnabled: Bool = true

    init() {}
}
