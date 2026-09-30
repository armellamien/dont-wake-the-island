import CoreGraphics
import Foundation

enum PlayerAction: Equatable, Sendable {
    case tap
    case doubleTap
    case swipe
    case chargeBegan
    case chargeReleased
}

enum HitResult: Sendable {
    case ignored
    case absorbed
    case fatal
}

struct Player: Sendable {
    var shieldRemaining: TimeInterval = 0
    var dashInvulnerability: TimeInterval = 0
    var magnetCooldown: TimeInterval = 0
    var isCharging = false
    var chargeTime: TimeInterval = 0

    var isShielded: Bool { shieldRemaining > 0 }
    var isInvulnerable: Bool { isShielded || dashInvulnerability > 0 }

    static let moveSpeed: CGFloat = 520
    static let dashDistance: CGFloat = 150
    static let dashCooldown: TimeInterval = 0.35
    static let dashInvulnerabilityDuration: TimeInterval = 0.3
    static let magnetRadius: CGFloat = 170
    static let magnetCooldownDuration: TimeInterval = 2.5
    static let shieldChargeTime: TimeInterval = 0.9
    static let shieldDuration: TimeInterval = 2.5
}
