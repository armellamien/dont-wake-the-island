import SwiftData
import SwiftUI

struct ScoreView: View {
    @Query private var stats: [PlayerStats]
    @Query(sort: \ScoreEntry.score, order: .reverse) private var entries: [ScoreEntry]

    var body: some View {
        let current = stats.first
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("BEST SCORE")
                        .font(Theme.label(12))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text((current?.bestScore ?? 0).spaced)
                        .font(Theme.mono(44, weight: .heavy))
                        .foregroundStyle(Theme.gold)
                        .shadow(color: Theme.gold.opacity(0.4), radius: 12)
                }
                .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(title: "Parties", value: "\(current?.gamesPlayed ?? 0)")
                    StatTile(title: "Pièces", value: (current?.totalCoins ?? 0).spaced)
                    StatTile(title: "Meilleur temps", value: (current?.bestTime ?? 0).clockString)
                    StatTile(title: "Niveau max", value: "\(current?.maxLevel ?? 1)")
                    StatTile(title: "Combo max", value: "x\(current?.bestCombo ?? 0)")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("TOP 20")
                        .font(Theme.label(12))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))

                    if entries.isEmpty {
                        Text("Aucune partie pour l'instant. La créature attend…")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }

                    ForEach(Array(entries.prefix(20).enumerated()), id: \.element.persistentModelID) { index, entry in
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(Theme.mono(13))
                                .foregroundStyle(index == 0 ? Theme.gold : .white.opacity(0.5))
                                .frame(width: 36, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.score.spaced)
                                    .font(Theme.mono(17, weight: .heavy))
                                    .foregroundStyle(.white)
                                Text("🪙 \(entry.coins) · LV \(entry.level) · \(entry.duration.clockString)")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Text(entry.date, format: .dateTime.day().month(.abbreviated))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Scores")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Theme.label(10))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(Theme.mono(20, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
    }
}
