import SpriteKit
import UIKit

extension UIColor {
    static var neonCyan: UIColor { UIColor(red: 0.35, green: 0.95, blue: 1.00, alpha: 1) }
    static var neonPink: UIColor { UIColor(red: 1.00, green: 0.30, blue: 0.65, alpha: 1) }
    static var neonGold: UIColor { UIColor(red: 1.00, green: 0.82, blue: 0.30, alpha: 1) }
    static var neonRed: UIColor { UIColor(red: 1.00, green: 0.27, blue: 0.30, alpha: 1) }
    static var neonLavender: UIColor { UIColor(red: 0.70, green: 0.65, blue: 1.00, alpha: 1) }
    static var gameBackground: UIColor { UIColor(red: 0.03, green: 0.035, blue: 0.06, alpha: 1) }
}

/// Renders every texture once and caches it: sprites are much cheaper than SKShapeNodes with glow.
@MainActor
enum TextureFactory {
    private static var cache: [String: SKTexture] = [:]

    static func glow(radius: CGFloat, color: UIColor, key: String) -> SKTexture {
        let id = "glow-\(key)-\(radius)"
        if let cached = cache[id] { return cached }

        let side = radius * 4
        let size = CGSize(width: side, height: side)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let center = CGPoint(x: side / 2, y: side / 2)
            let colors = [color.withAlphaComponent(0.5).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawRadialGradient(gradient, startCenter: center, startRadius: radius * 0.8, endCenter: center, endRadius: side / 2, options: [])
            }
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            let inner = radius * 0.45
            cg.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
        }
        return store(SKTexture(image: image), id: id)
    }

    static func emoji(_ symbol: String, size: CGFloat) -> SKTexture {
        let id = "emoji-\(symbol)-\(size)"
        if let cached = cache[id] { return cached }

        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size)]
        let text = symbol as NSString
        let bounds = text.size(withAttributes: attributes)
        let image = UIGraphicsImageRenderer(size: bounds).image { _ in
            text.draw(at: .zero, withAttributes: attributes)
        }
        return store(SKTexture(image: image), id: id)
    }

    static func texture(for kind: CoinKind) -> SKTexture {
        switch kind {
        case .coin: glow(radius: 9, color: .neonGold, key: "coin")
        case .gem: emoji("💎", size: 24)
        case .star: emoji("⭐️", size: 24)
        case .moon: emoji("🌙", size: 24)
        }
    }

    private static func store(_ texture: SKTexture, id: String) -> SKTexture {
        cache[id] = texture
        return texture
    }
}

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    func distance(to other: CGPoint) -> CGFloat {
        hypot(other.x - x, other.y - y)
    }

    func vector(to other: CGPoint) -> CGVector {
        CGVector(dx: other.x - x, dy: other.y - y)
    }
}

extension CGVector {
    var length: CGFloat { hypot(dx, dy) }

    var normalized: CGVector {
        let length = length
        return length > 0 ? CGVector(dx: dx / length, dy: dy / length) : .zero
    }

    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }

    static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }
}
