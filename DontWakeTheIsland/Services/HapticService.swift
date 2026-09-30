import CoreHaptics
import Foundation

@MainActor
final class HapticService {
    enum Event: CaseIterable {
        case coin
        case bonus
        case danger
        case wake
        case gameOver
        case dash
        case shield
    }

    var isEnabled = true

    private var engine: CHHapticEngine?
    private var patterns: [Event: CHHapticPattern] = [:]
    private var needsRestart = false

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            // CoreHaptics calls these handlers on a private queue.
            engine.resetHandler = { @Sendable [weak self] in
                guard let self else { return }
                Task { @MainActor in self.restart() }
            }
            engine.stoppedHandler = { @Sendable [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.needsRestart = true }
            }
            try engine.start()
            self.engine = engine
            for event in Event.allCases {
                patterns[event] = try? Self.makePattern(for: event)
            }
        } catch {
            engine = nil
        }
    }

    func play(_ event: Event) {
        guard isEnabled, let engine, let pattern = patterns[event] else { return }
        do {
            if needsRestart { try restartEngine(engine) }
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            needsRestart = true
        }
    }

    private func restart() {
        guard let engine else { return }
        try? restartEngine(engine)
    }

    private func restartEngine(_ engine: CHHapticEngine) throws {
        try engine.start()
        needsRestart = false
    }

    private static func makePattern(for event: Event) throws -> CHHapticPattern {
        switch event {
        case .coin:
            return try CHHapticPattern(events: [transient(0, intensity: 0.45, sharpness: 0.8)], parameters: [])
        case .bonus:
            return try CHHapticPattern(events: [
                transient(0, intensity: 0.7, sharpness: 0.6),
                transient(0.09, intensity: 0.85, sharpness: 0.8),
            ], parameters: [])
        case .danger:
            return try CHHapticPattern(events: [
                transient(0, intensity: 1, sharpness: 0.3),
                continuous(0.02, duration: 0.18, intensity: 0.8, sharpness: 0.2),
            ], parameters: [])
        case .wake:
            let fade = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 1),
                    .init(relativeTime: 0.8, value: 0.15),
                ],
                relativeTime: 0
            )
            return try CHHapticPattern(events: [
                transient(0, intensity: 1, sharpness: 1),
                continuous(0, duration: 0.8, intensity: 1, sharpness: 0.1),
                transient(0.25, intensity: 1, sharpness: 0.5),
                transient(0.5, intensity: 1, sharpness: 0.3),
            ], parameterCurves: [fade])
        case .gameOver:
            return try CHHapticPattern(events: [
                transient(0, intensity: 1, sharpness: 0.4),
                transient(0.16, intensity: 0.75, sharpness: 0.4),
                transient(0.34, intensity: 0.5, sharpness: 0.4),
                continuous(0.5, duration: 0.6, intensity: 0.5, sharpness: 0.1),
            ], parameters: [])
        case .dash:
            return try CHHapticPattern(events: [transient(0, intensity: 0.55, sharpness: 1)], parameters: [])
        case .shield:
            return try CHHapticPattern(events: [continuous(0, duration: 0.25, intensity: 0.6, sharpness: 0.9)], parameters: [])
        }
    }

    private static func transient(_ time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private static func continuous(_ time: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time,
            duration: duration
        )
    }
}
