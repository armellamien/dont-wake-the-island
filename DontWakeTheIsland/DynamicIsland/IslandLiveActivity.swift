import ActivityKit
import SwiftUI
import WidgetKit

// Widget extension target only.

private let resumeURL = URL(string: "dontwaketheisland://resume")

struct IslandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IslandAttributes.self) { context in
            IslandLockScreenView(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(resumeURL)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(state.mood.emoji)
                        .font(.system(size: 36))
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SCORE")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(state.score.spaced)
                            .font(.system(size: 18, weight: .heavy, design: .monospaced))
                            .contentTransition(.numericText())
                    }
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.headline)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(state.mood.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        if state.mood == .sleeping || state.mood == .calm || state.mood == .danger {
                            NoiseGauge(noise: state.noise, tint: state.mood.tint)
                        } else {
                            Text("🪙 \(state.coins) · LV \(state.level)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        if state.isPaused, let resumeURL {
                            Link(destination: resumeURL) {
                                Text("▶ REPRENDRE")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(state.mood.tint))
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Text(state.mood.emoji)
            } compactTrailing: {
                Text(state.compactText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.mood.tint)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 64)
            } minimal: {
                Text(state.mood.emoji)
            }
            .widgetURL(resumeURL)
            .keylineTint(state.mood.tint)
        }
    }
}

private struct IslandLockScreenView: View {
    let state: IslandAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Text(state.mood.emoji)
                .font(.system(size: 40))
            VStack(alignment: .leading, spacing: 5) {
                Text("DON'T WAKE THE ISLAND")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(state.headline)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(state.mood.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                NoiseGauge(noise: state.noise, tint: state.mood.tint)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(state.score.spaced)
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                Text("🪙 \(state.coins)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

private struct NoiseGauge: View {
    let noise: Int
    let tint: Color

    var body: some View {
        ProgressView(value: Double(min(max(noise, 0), 100)), total: 100)
            .tint(tint)
    }
}
