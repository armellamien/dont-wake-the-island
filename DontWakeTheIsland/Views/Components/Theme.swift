import SwiftUI

enum Theme {
    static let background = Color(red: 0.03, green: 0.035, blue: 0.06)
    static let surface = Color.white.opacity(0.06)
    static let elevated = Color(red: 0.07, green: 0.075, blue: 0.11)
    static let cyan = Color(red: 0.35, green: 0.95, blue: 1.00)
    static let pink = Color(red: 1.00, green: 0.30, blue: 0.65)
    static let gold = Color(red: 1.00, green: 0.82, blue: 0.30)
    static let danger = Color(red: 1.00, green: 0.27, blue: 0.30)
    static let lavender = Color(red: 0.70, green: 0.65, blue: 1.00)

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}

struct NeonButtonStyle: ButtonStyle {
    var tint: Color = Theme.cyan
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(prominent ? Color.black : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.08)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(tint.opacity(prominent ? 0 : 0.45), lineWidth: 1)
            }
            .shadow(color: tint.opacity(prominent ? 0.45 : 0), radius: 16)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension TimeInterval {
    /// "1:05"
    var clockString: String {
        let seconds = Int(self)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
