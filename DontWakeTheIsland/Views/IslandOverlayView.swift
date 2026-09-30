import SwiftUI

/// Where the in-app island sits. On Dynamic Island iPhones it is drawn exactly around the
/// hardware cutout so the real island appears to come alive; elsewhere it is a classic pill.
struct IslandLayout: Equatable {
    static let hardwareWidth: CGFloat = 126
    static let wingWidth: CGFloat = 70

    let hasDynamicIsland: Bool
    let screenWidth: CGFloat
    let safeTop: CGFloat

    init(safeTop: CGFloat, screenWidth: CGFloat) {
        self.safeTop = safeTop
        self.screenWidth = screenWidth
        // Dynamic Island iPhones report a top inset of 59pt or more; notched ones 47–50pt.
        hasDynamicIsland = safeTop >= 55
    }

    var top: CGFloat { hasDynamicIsland ? max(safeTop - 48.5, 8) : safeTop + 8 }
    var compactHeight: CGFloat { hasDynamicIsland ? 38 : 36 }
    var compactWidth: CGFloat { hasDynamicIsland ? Self.hardwareWidth + Self.wingWidth * 2 : 200 }
    var expandedWidth: CGFloat { min(screenWidth - 20, 380) }
    var expandedHeight: CGFloat { hasDynamicIsland ? 108 : 76 }
    var centerFromTop: CGFloat { top + compactHeight / 2 }
    var bottom: CGFloat { top + compactHeight }
}

struct IslandOverlayView: View {
    let island: DynamicIslandViewModel
    let layout: IslandLayout

    var body: some View {
        let content = island.content
        let expanded = island.isExpanded
        let tint = content.mood.tint
        let glow = content.mood == .sleeping ? 0.15 : 0.25 + Double(content.noise) / 100 * 0.6

        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: expanded ? 40 : layout.compactHeight / 2, style: .continuous)
                .fill(.black)
                .overlay {
                    RoundedRectangle(cornerRadius: expanded ? 40 : layout.compactHeight / 2, style: .continuous)
                        .stroke(tint.opacity(glow), lineWidth: 1)
                }
                .shadow(color: tint.opacity(glow * 0.6), radius: 12)

            if expanded {
                expandedContent(content)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            } else {
                compactContent(content)
                    .transition(.opacity)
            }
        }
        .frame(
            width: expanded ? layout.expandedWidth : layout.compactWidth,
            height: expanded ? layout.expandedHeight : layout.compactHeight
        )
        .keyframeAnimator(initialValue: CGFloat(0), trigger: island.shakeTrigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-7, duration: 0.05)
                LinearKeyframe(7, duration: 0.06)
                LinearKeyframe(-5, duration: 0.06)
                LinearKeyframe(4, duration: 0.06)
                LinearKeyframe(0, duration: 0.05)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.72), value: expanded)
        .animation(.easeInOut(duration: 0.25), value: content.mood)
        .padding(.top, layout.top)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.headline)
    }

    private func compactContent(_ content: IslandAttributes.ContentState) -> some View {
        HStack(spacing: 0) {
            CreatureFace(mood: content.mood)
                .font(.system(size: 19))
            Spacer(minLength: layout.hasDynamicIsland ? IslandLayout.hardwareWidth : 8)
            Text(content.compactText)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(content.mood.tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.horizontal, 14)
        .frame(height: layout.compactHeight)
    }

    private func expandedContent(_ content: IslandAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            CreatureFace(mood: content.mood)
                .font(.system(size: 38))
            VStack(alignment: .leading, spacing: 4) {
                Text(island.banner ?? content.headline)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(content.mood.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("SCORE \(content.score.spaced)")
                    .font(Theme.mono(12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        // Keep clear of the camera on Dynamic Island devices.
        .padding(.top, layout.hasDynamicIsland ? 44 : 14)
    }
}

/// The sleeping creature: breathes slowly while asleep, trembles when it is about to wake.
struct CreatureFace: View {
    let mood: IslandMood

    var body: some View {
        Text(mood.emoji)
            .id(mood)
            .transition(.scale.combined(with: .opacity))
            .phaseAnimator([false, true]) { view, phase in
                view
                    .scaleEffect(scale(phase))
                    .rotationEffect(.degrees(rotation(phase)))
            } animation: { _ in
                switch mood {
                case .danger, .awake: .easeInOut(duration: 0.09)
                case .chase: .easeInOut(duration: 0.3)
                default: .easeInOut(duration: 1.4)
                }
            }
    }

    private func scale(_ phase: Bool) -> CGFloat {
        switch mood {
        case .sleeping, .calm: phase ? 1.1 : 0.92
        case .chase: phase ? 1.12 : 1
        default: 1
        }
    }

    private func rotation(_ phase: Bool) -> Double {
        switch mood {
        case .danger, .awake: phase ? 8 : -8
        default: 0
        }
    }
}
