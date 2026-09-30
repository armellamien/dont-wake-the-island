import SpriteKit
import SwiftUI

struct GameView: View {
    let viewModel: GameViewModel
    let onExit: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            let layout = IslandLayout(safeTop: proxy.safeAreaInsets.top, screenWidth: proxy.size.width)

            ZStack(alignment: .top) {
                SpriteView(
                    scene: viewModel.scene,
                    isPaused: viewModel.isPaused,
                    preferredFramesPerSecond: 120,
                    options: [.ignoresSiblingOrder]
                )

                HUDView(viewModel: viewModel, layout: layout, bottomInset: proxy.safeAreaInsets.bottom)

                IslandOverlayView(island: viewModel.island, layout: layout)

                pauseButton
                    .padding(.top, layout.bottom + 10)
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.isPaused {
                    PauseOverlay(onResume: { viewModel.resume() }, onQuit: { exit() })
                        .transition(.opacity)
                }

                if viewModel.isGameOverPresented, let result = viewModel.result {
                    GameOverView(
                        result: result,
                        isNewBest: viewModel.isNewBest,
                        bestScore: viewModel.bestScore,
                        onReplay: { viewModel.restart() },
                        onHome: { exit() }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.25), value: viewModel.isPaused)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.isGameOverPresented)
            .onAppear {
                viewModel.configure(islandCenterFromTop: layout.centerFromTop)
                viewModel.start()
            }
            .onChange(of: layout) { _, newLayout in
                viewModel.configure(islandCenterFromTop: newLayout.centerFromTop)
            }
        }
        .background(Theme.background)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.pause() }
        }
    }

    private var pauseButton: some View {
        Button {
            viewModel.pause()
        } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.surface))
        }
        .accessibilityLabel("Pause")
        .opacity(viewModel.result == nil ? 1 : 0)
    }

    private func exit() {
        viewModel.quit()
        onExit()
    }
}

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("😴")
                    .font(.system(size: 54))
                Text("PAUSE")
                    .font(Theme.title(34))
                    .foregroundStyle(.white)
                Text("La créature dort encore… pour l'instant.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                VStack(spacing: 12) {
                    Button("▶  REPRENDRE", action: onResume)
                        .buttonStyle(NeonButtonStyle(tint: Theme.cyan, prominent: true))
                    Button("ACCUEIL", action: onQuit)
                        .buttonStyle(NeonButtonStyle(tint: Theme.lavender))
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
    }
}
