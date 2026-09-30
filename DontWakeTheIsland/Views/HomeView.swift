import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Query private var stats: [PlayerStats]
    @State private var game: GameViewModel?

    private var bestScore: Int { stats.first?.bestScore ?? 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                RadialGradient(colors: [Theme.lavender.opacity(0.18), .clear], center: .top, startRadius: 0, endRadius: 420)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    SleepingIslandBadge()

                    VStack(spacing: 0) {
                        Text("DON'T WAKE")
                            .foregroundStyle(.white)
                        Text("THE ISLAND")
                            .foregroundStyle(Theme.cyan)
                            .shadow(color: Theme.cyan.opacity(0.55), radius: 14)
                    }
                    .font(Theme.title(44))
                    .multilineTextAlignment(.center)

                    Text("BEST SCORE \(bestScore.spaced)")
                        .font(Theme.mono(14))
                        .foregroundStyle(Theme.gold)

                    Spacer()

                    VStack(spacing: 14) {
                        Button("▶  JOUER") {
                            game = GameViewModel(dependencies: dependencies)
                        }
                        .buttonStyle(NeonButtonStyle(tint: Theme.cyan, prominent: true))

                        NavigationLink {
                            ScoreView()
                        } label: {
                            Text("🏆  SCORES")
                        }
                        .buttonStyle(NeonButtonStyle(tint: Theme.gold))

                        NavigationLink {
                            SettingsView()
                        } label: {
                            Text("⚙️  PARAMÈTRES")
                        }
                        .buttonStyle(NeonButtonStyle(tint: Theme.lavender))
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Theme.cyan)
        .onAppear { dependencies.audio.playMusic(.lullaby) }
        .fullScreenCover(item: $game) { game in
            GameView(viewModel: game) { self.game = nil }
        }
    }
}

/// Decorative island on the home screen.
private struct SleepingIslandBadge: View {
    var body: some View {
        HStack(spacing: 12) {
            CreatureFace(mood: .sleeping)
                .font(.system(size: 26))
            Text("Zzz...")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.lavender)
                .phaseAnimator([0.4, 1.0]) { view, opacity in
                    view.opacity(opacity)
                } animation: { _ in .easeInOut(duration: 1.4) }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.black)
                .overlay(Capsule().stroke(Theme.lavender.opacity(0.3), lineWidth: 1))
                .shadow(color: Theme.lavender.opacity(0.35), radius: 18)
        )
    }
}
