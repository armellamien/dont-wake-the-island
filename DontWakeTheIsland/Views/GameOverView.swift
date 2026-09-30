import SwiftUI

struct GameOverView: View {
    let result: GameResult
    let isNewBest: Bool
    let bestScore: Int
    let onReplay: () -> Void
    let onHome: () -> Void

    @State private var displayedScore = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("💀")
                    .font(.system(size: 52))
                Text("GAME OVER")
                    .font(Theme.title(34))
                    .foregroundStyle(Theme.danger)
                    .shadow(color: Theme.danger.opacity(0.5), radius: 12)

                if isNewBest {
                    Text("NOUVEAU RECORD !")
                        .font(Theme.label(13))
                        .tracking(2)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.gold))
                }

                VStack(spacing: 2) {
                    Text("SCORE")
                        .font(Theme.label())
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(displayedScore.spaced)
                        .font(Theme.mono(44, weight: .heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(displayedScore)))
                    Text("BEST SCORE \(bestScore.spaced)")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.gold)
                }

                VStack(spacing: 8) {
                    StatRow(label: "Pièces", value: result.breakdown.coinPoints.spaced, detail: "🪙 \(result.coins)")
                    StatRow(label: "Survie", value: result.breakdown.survivalPoints.spaced, detail: result.duration.clockString)
                    StatRow(label: "Bonus", value: result.breakdown.bonusPoints.spaced, detail: "combo x\(result.bestCombo)")
                    StatRow(label: "Niveau atteint", value: "\(result.level)", detail: nil)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))

                VStack(spacing: 12) {
                    Button("↻  REJOUER", action: onReplay)
                        .buttonStyle(NeonButtonStyle(tint: Theme.cyan, prominent: true))
                    Button("ACCUEIL", action: onHome)
                        .buttonStyle(NeonButtonStyle(tint: Theme.lavender))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Theme.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Theme.danger.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(20)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.8)) {
                displayedScore = result.score
            }
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    let detail: String?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.6))
            if let detail {
                Text(detail)
                    .foregroundStyle(.white.opacity(0.35))
            }
            Spacer()
            Text(value)
                .foregroundStyle(.white)
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .monospacedDigit()
    }
}
