import SwiftUI

/// Everything drawn over the SpriteKit scene. Reads `viewModel.hud` itself so the
/// parent view (and its SpriteView) is not invalidated when the score changes.
struct HUDView: View {
    let viewModel: GameViewModel
    let layout: IslandLayout
    let bottomInset: CGFloat

    var body: some View {
        let hud = viewModel.hud

        ZStack(alignment: .top) {
            RadialGradient(
                colors: [Theme.danger.opacity(glowOpacity(hud)), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
            .animation(.easeOut(duration: 0.3), value: glowOpacity(hud))

            VStack(spacing: 0) {
                topBar(hud)
                    .padding(.top, layout.bottom + 12)
                Spacer()
                if hud.phase == .sleeping {
                    NoiseMeter(noise: hud.noise)
                        .padding(.bottom, 14)
                        .transition(.opacity)
                }
                abilityBar(hud)
                if hud.elapsedSeconds < 6, hud.phase == .sleeping {
                    Text("Tap : bouger · 2×Tap : aimant · Glisser : esquive · Maintenir : chut / bouclier")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, max(bottomInset, 12) + 8)
            .animation(.easeInOut(duration: 0.3), value: hud.phase)

            if let toast = viewModel.toast {
                ToastView(toast: toast)
                    .id(toast.id)
                    .padding(.top, layout.bottom + 110)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: viewModel.toast)
        .allowsHitTesting(false)
    }

    private func glowOpacity(_ hud: HUDSnapshot) -> Double {
        switch hud.phase {
        case .sleeping: max(0, Double(hud.noise) - 30) / 70 * 0.35
        case .waking: 0.5
        case .chase: 0.18
        case .gameOver: 0
        }
    }

    private func topBar(_ hud: HUDSnapshot) -> some View {
        HStack(alignment: .top) {
            // Room for the pause button placed by GameView.
            Color.clear.frame(width: 70, height: 1)
            Spacer()
            VStack(spacing: 2) {
                Text("SCORE")
                    .font(Theme.label())
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(hud.score.spaced)
                    .font(Theme.mono(30, weight: .heavy))
                    .foregroundStyle(hud.multiplierActive ? Theme.gold : .white)
                    .contentTransition(.numericText(value: Double(hud.score)))
                if hud.combo >= 2 {
                    Text("COMBO x\(hud.combo)")
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.pink)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: hud.combo >= 2)
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("🪙 \(hud.coins)")
                    .font(Theme.mono(15))
                    .foregroundStyle(Theme.gold)
                Text("LV \(hud.level)")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.cyan)
                if hud.multiplierActive {
                    Text("⭐️ x2")
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.gold)
                }
            }
            .frame(width: 70, alignment: .trailing)
        }
    }

    private func abilityBar(_ hud: HUDSnapshot) -> some View {
        let isChase = hud.phase == .chase
        return HStack(spacing: 10) {
            AbilityChip(symbol: "🧲", caption: "2×TAP", isReady: hud.magnetReady)
            AbilityChip(symbol: "💨", caption: "GLISSER", isReady: true)
            AbilityChip(
                symbol: isChase ? "🛡️" : "🤫",
                caption: "MAINTENIR",
                isReady: !hud.shieldActive,
                isHighlighted: hud.shieldActive
            )
        }
    }
}

struct NoiseMeter: View {
    let noise: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BRUIT")
                    .font(Theme.label())
                    .tracking(2)
                Spacer()
                Text("\(noise)%")
                    .font(Theme.mono(12))
                    .contentTransition(.numericText(value: Double(noise)))
            }
            .foregroundStyle(noise >= Int(NoiseRules.dangerThreshold) ? Theme.danger : .white.opacity(0.6))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    LinearGradient(colors: [Theme.lavender, Theme.gold, Theme.danger], startPoint: .leading, endPoint: .trailing)
                        .mask(alignment: .leading) {
                            Capsule().frame(width: proxy.size.width * CGFloat(noise) / 100)
                        }
                    Rectangle()
                        .fill(.white.opacity(0.35))
                        .frame(width: 1.5)
                        .offset(x: proxy.size.width * CGFloat(NoiseRules.dangerThreshold) / 100)
                }
            }
            .frame(height: 8)
            .animation(.easeOut(duration: 0.2), value: noise)
        }
    }
}

struct AbilityChip: View {
    let symbol: String
    let caption: String
    let isReady: Bool
    var isHighlighted = false

    var body: some View {
        VStack(spacing: 3) {
            Text(symbol).font(.system(size: 20))
            Text(caption)
                .font(Theme.label(9))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isHighlighted ? Theme.cyan.opacity(0.18) : Theme.surface)
        )
        .opacity(isReady || isHighlighted ? 1 : 0.35)
        .animation(.easeInOut(duration: 0.2), value: isReady)
    }
}

struct ToastView: View {
    let toast: GameToast

    var body: some View {
        Text(toast.text)
            .font(Theme.title(22))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.6), radius: 10)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Capsule().fill(.black.opacity(0.55)))
    }

    private var color: Color {
        switch toast.style {
        case .info: Theme.cyan
        case .bonus: Theme.gold
        case .danger: Theme.danger
        }
    }
}
