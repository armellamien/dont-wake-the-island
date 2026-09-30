import AVFoundation

/// Every sound is synthesized at launch, so the game ships without audio assets.
/// Drop real files into Resources/Sounds and swap the buffers if you want recorded sounds.
@MainActor
final class AudioService {
    enum Effect: CaseIterable {
        case coin
        case bonus
        case warning
        case wake
        case chase
        case gameOver
        case dash
        case magnet
        case shield
        case calm
    }

    enum Track {
        case lullaby
        case chase
    }

    var sfxEnabled = true

    var musicEnabled = true {
        didSet {
            guard oldValue != musicEnabled else { return }
            if musicEnabled, let requestedTrack {
                startTrack(requestedTrack)
            } else {
                musicPlayer.stop()
                playingTrack = nil
            }
        }
    }

    private let engine = AVAudioEngine()
    private let musicPlayer = AVAudioPlayerNode()
    private var sfxPlayers: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0
    private let format: AVAudioFormat
    private let sampleRate: Double = 44_100
    private var effects: [Effect: AVAudioPCMBuffer] = [:]
    private var tracks: [Track: AVAudioPCMBuffer] = [:]
    private var requestedTrack: Track?
    private var playingTrack: Track?

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)

        engine.attach(musicPlayer)
        engine.connect(musicPlayer, to: engine.mainMixerNode, format: format)
        musicPlayer.volume = 0.32

        for _ in 0..<6 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            sfxPlayers.append(player)
        }

        buildEffects()
        buildTracks()

        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleConfigurationChange() }
        }

        startEngineIfNeeded()
    }

    // MARK: Playback

    func play(_ effect: Effect) {
        guard sfxEnabled, let buffer = effects[effect], startEngineIfNeeded() else { return }
        let player = sfxPlayers[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % sfxPlayers.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    func playMusic(_ track: Track) {
        requestedTrack = track
        guard musicEnabled else { return }
        if playingTrack == track, musicPlayer.isPlaying { return }
        startTrack(track)
    }

    func pauseMusic() {
        musicPlayer.pause()
    }

    func resumeMusic() {
        guard musicEnabled, playingTrack != nil, startEngineIfNeeded() else { return }
        musicPlayer.play()
    }

    func stopMusic() {
        musicPlayer.stop()
        playingTrack = nil
        requestedTrack = nil
    }

    private func startTrack(_ track: Track) {
        guard let buffer = tracks[track], startEngineIfNeeded() else { return }
        musicPlayer.stop()
        musicPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        musicPlayer.play()
        playingTrack = track
    }

    @discardableResult
    private func startEngineIfNeeded() -> Bool {
        if engine.isRunning { return true }
        engine.prepare()
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func handleConfigurationChange() {
        guard startEngineIfNeeded(), let playingTrack else { return }
        startTrack(playingTrack)
    }

    // MARK: Synthesis

    private func buildEffects() {
        effects[.coin] = render(duration: 0.24, [
            Tone(start: 0, duration: 0.07, frequency: note(83), volume: 0.16, wave: .square),
            Tone(start: 0.06, duration: 0.17, frequency: note(88), volume: 0.16, wave: .square),
        ])
        effects[.bonus] = render(duration: 0.45, [72, 76, 79, 84].enumerated().map { index, midi in
            Tone(start: Double(index) * 0.06, duration: 0.16, frequency: note(midi), volume: 0.35, wave: .triangle)
        })
        effects[.warning] = render(duration: 0.34, [
            Tone(start: 0, duration: 0.12, frequency: 440, volume: 0.18, wave: .square),
            Tone(start: 0.18, duration: 0.12, frequency: 440, volume: 0.18, wave: .square),
        ])
        effects[.wake] = render(duration: 0.9, [
            Tone(start: 0, duration: 0.75, frequency: 110, endFrequency: 520, volume: 0.22, wave: .square, decay: 1),
            Tone(start: 0, duration: 0.5, frequency: 0, volume: 0.22, wave: .noise),
            Tone(start: 0, duration: 0.85, frequency: 55, volume: 0.5, wave: .sine),
        ])
        effects[.chase] = render(duration: 0.4, [
            Tone(start: 0, duration: 0.35, frequency: 900, endFrequency: 300, volume: 0.3, wave: .triangle),
        ])
        effects[.gameOver] = render(duration: 1.4, [67, 64, 60, 55].enumerated().map { index, midi in
            Tone(start: Double(index) * 0.18, duration: 0.22, frequency: note(midi), volume: 0.2, wave: .square)
        } + [Tone(start: 0.72, duration: 0.65, frequency: note(43), volume: 0.4, wave: .triangle)])
        effects[.dash] = render(duration: 0.16, [
            Tone(start: 0, duration: 0.14, frequency: 0, volume: 0.14, wave: .noise),
            Tone(start: 0, duration: 0.14, frequency: 600, endFrequency: 200, volume: 0.14, wave: .sine),
        ])
        effects[.magnet] = render(duration: 0.3, [
            Tone(start: 0, duration: 0.28, frequency: 1200, endFrequency: 380, volume: 0.22, wave: .sine),
        ])
        effects[.shield] = render(duration: 0.36, [
            Tone(start: 0, duration: 0.3, frequency: 300, endFrequency: 900, volume: 0.3, wave: .sine),
            Tone(start: 0.05, duration: 0.3, frequency: 450, endFrequency: 1350, volume: 0.12, wave: .triangle),
        ])
        effects[.calm] = render(duration: 0.65, [
            Tone(start: 0, duration: 0.5, frequency: note(76), volume: 0.22, wave: .sine),
            Tone(start: 0.12, duration: 0.5, frequency: note(83), volume: 0.18, wave: .sine),
        ])
    }

    private func buildTracks() {
        let step = 0.45
        let melody = [72, 76, 79, 76, 74, 72, 69, 72, 72, 76, 79, 81, 79, 76, 74, 72]
        var lullaby = melody.enumerated().map { index, midi in
            Tone(start: Double(index) * step, duration: 0.8, frequency: note(midi), volume: 0.1, wave: .triangle)
        }
        lullaby += [48, 45, 41, 43].enumerated().map { index, midi in
            Tone(start: Double(index) * step * 4, duration: 1.8, frequency: note(midi), volume: 0.16, wave: .sine)
        }
        tracks[.lullaby] = render(duration: step * Double(melody.count), lullaby)

        let sixteenth = 0.125
        let roots = [45, 45, 41, 43]
        var chase: [Tone] = []
        for index in 0..<32 {
            let time = Double(index) * sixteenth
            let root = roots[index / 8]
            if index % 2 == 0 {
                let midi = (index / 2) % 2 == 0 ? root : root + 12
                chase.append(Tone(start: time, duration: 0.11, frequency: note(midi), volume: 0.11, wave: .square))
            } else {
                chase.append(Tone(start: time, duration: 0.03, frequency: 0, volume: 0.05, wave: .noise))
            }
            if index % 4 == 0 {
                chase.append(Tone(start: time, duration: 0.15, frequency: 120, endFrequency: 40, volume: 0.5, wave: .sine))
            }
            if index % 8 == 0 {
                chase.append(Tone(start: time, duration: 0.25, frequency: note(root + 24), volume: 0.07, wave: .triangle))
            }
        }
        tracks[.chase] = render(duration: sixteenth * 32, chase)
    }

    private func note(_ midi: Int) -> Double {
        440 * pow(2, Double(midi - 69) / 12)
    }

    private func render(duration: Double, _ tones: [Tone]) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
            let data = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frameCount
        let count = Int(frameCount)
        data.initialize(repeating: 0, count: count)
        for tone in tones {
            tone.render(into: data, frameCount: count, sampleRate: sampleRate)
        }
        for index in 0..<count {
            data[index] = Float(tanh(Double(data[index])))
        }
        return buffer
    }
}

private struct Tone {
    enum Wave { case sine, triangle, square, noise }

    var start: Double
    var duration: Double
    var frequency: Double
    var endFrequency: Double?
    var volume: Double
    var wave: Wave
    /// Exponent of the release curve: 2 = percussive, 1 = linear.
    var decay: Double = 2

    func render(into data: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
        let startFrame = Int(start * sampleRate)
        let length = Int(duration * sampleRate)
        let attack = 0.005
        var phase = 0.0
        var seed: UInt32 = 0x9E37_79B9
        for n in 0..<length {
            let index = startFrame + n
            guard index < frameCount else { break }
            let time = Double(n) / sampleRate
            let progress = Double(n) / Double(length)
            let currentFrequency = frequency + ((endFrequency ?? frequency) - frequency) * progress
            phase += currentFrequency / sampleRate
            phase -= floor(phase)

            let sample: Double
            switch wave {
            case .sine:
                sample = sin(2 * .pi * phase)
            case .triangle:
                sample = 4 * abs(phase - 0.5) - 1
            case .square:
                sample = phase < 0.5 ? 0.6 : -0.6
            case .noise:
                seed = seed &* 1_664_525 &+ 1_013_904_223
                sample = Double(seed) / Double(UInt32.max) * 2 - 1
            }

            let envelope = min(1, time / attack) * pow(1 - progress, decay)
            data[index] += Float(sample * envelope * volume)
        }
    }
}
