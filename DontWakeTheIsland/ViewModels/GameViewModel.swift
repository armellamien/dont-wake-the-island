import CoreGraphics
import Foundation
import Observation

/// Values the HUD displays. Published only when one of them changes, so SwiftUI
/// does not re-render at the scene's frame rate.
struct HUDSnapshot: Equatable {
    var score = 0
    var coins = 0
    var noise = 0
    var level = 1
    var combo = 0
    var phase: GamePhase = .sleeping
    var multiplierActive = false
    var magnetReady = true
    var shieldActive = false
    var elapsedSeconds = 0
}

struct GameToast: Equatable, Identifiable {
    enum Style: Equatable { case info, bonus, danger }

    let id = UUID()
    let text: String
    let style: Style
}

@Observable
@MainActor
final class GameViewModel: Identifiable {
    nonisolated let id = UUID()

    private(set) var hud = HUDSnapshot()
    private(set) var isPaused = false
    private(set) var isGameOverPresented = false
    private(set) var result: GameResult?
    private(set) var isNewBest = false
    private(set) var bestScore = 0
    private(set) var toast: GameToast?

    let island: DynamicIslandViewModel
    let scene: GameScene

    @ObservationIgnored private let storage: GameStorageService
    @ObservationIgnored private let haptics: HapticService
    @ObservationIgnored private let audio: AudioService

    @ObservationIgnored private var state = GameState()
    @ObservationIgnored private var player = Player()
    @ObservationIgnored private var creature = Creature()
    @ObservationIgnored private var clock: TimeInterval = 0
    @ObservationIgnored private var recentActions: [TimeInterval] = []
    @ObservationIgnored private var lastCollectTime: TimeInterval = -.infinity
    @ObservationIgnored private var wakeCountdown: TimeInterval = 0
    @ObservationIgnored private var dashCooldown: TimeInterval = 0
    @ObservationIgnored private var dangerArmed = true
    @ObservationIgnored private var lastLevel = 1
    @ObservationIgnored private var hasStarted = false

    init(dependencies: AppDependencies) {
        storage = dependencies.storage
        haptics = dependencies.haptics
        audio = dependencies.audio
        island = dependencies.island
        scene = GameScene(size: CGSize(width: 393, height: 852))
        bestScore = storage.stats().bestScore
        scene.gameDelegate = self
    }

    // MARK: Lifecycle

    func configure(islandCenterFromTop: CGFloat) {
        scene.islandOffsetFromTop = islandCenterFromTop
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        resetRun()
    }

    func restart() {
        resetRun()
    }

    func pause() {
        guard !isPaused, state.phase != .gameOver else { return }
        isPaused = true
        audio.pauseMusic()
        island.sync(islandContent(), force: true)
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        audio.resumeMusic()
        island.sync(islandContent(), force: true)
    }

    func quit() {
        isPaused = false
        island.cancel()
        audio.playMusic(.lullaby)
    }

    private func resetRun() {
        state = GameState()
        player = Player()
        creature = Creature()
        clock = 0
        recentActions.removeAll()
        lastCollectTime = -.infinity
        wakeCountdown = 0
        dashCooldown = 0
        dangerArmed = true
        lastLevel = 1

        isPaused = false
        isGameOverPresented = false
        result = nil
        isNewBest = false
        toast = nil
        bestScore = storage.stats().bestScore

        scene.reset()
        audio.playMusic(.lullaby)
        island.begin(with: islandContent())
        publish()
    }

    // MARK: Rules

    private func tickSleeping(_ dt: TimeInterval) {
        state.elapsed += dt
        state.difficulty = 1 + state.elapsed / 25
        state.breakdown.survival += dt * 2 * state.difficulty

        // Holding still hums a lullaby; otherwise the island slowly calms down,
        // until difficulty makes it restless on its own.
        let drift = player.isCharging
            ? -max(6, 14 - (state.difficulty - 1) * 1.5)
            : min(2.5, -3.2 + (state.difficulty - 1) * 0.5)
        changeNoise(by: drift * dt)
    }

    private func tickWaking(_ dt: TimeInterval) {
        state.elapsed += dt
        wakeCountdown -= dt
        guard wakeCountdown <= 0 else { return }
        state.phase = .chase
        audio.play(.chase)
        audio.playMusic(.chase)
        haptics.play(.danger)
    }

    private func tickChase(_ dt: TimeInterval) {
        state.elapsed += dt
        state.difficulty += dt / 9
        state.breakdown.survival += dt * 12 * state.difficulty
    }

    private func tickTimers(_ dt: TimeInterval) {
        state.multiplierRemaining = max(0, state.multiplierRemaining - dt)
        player.shieldRemaining = max(0, player.shieldRemaining - dt)
        player.dashInvulnerability = max(0, player.dashInvulnerability - dt)
        player.magnetCooldown = max(0, player.magnetCooldown - dt)
        dashCooldown = max(0, dashCooldown - dt)
        creature.slowRemaining = max(0, creature.slowRemaining - dt)
        if player.isCharging { player.chargeTime += dt }
        if state.combo > 0, clock - lastCollectTime > 1.6 { state.combo = 0 }
    }

    private func changeNoise(by amount: Double) {
        guard state.phase == .sleeping else { return }
        state.noiseLevel = min(100, max(0, state.noiseLevel + amount))

        if state.noiseLevel >= NoiseRules.dangerThreshold, dangerArmed {
            dangerArmed = false
            haptics.play(.danger)
            audio.play(.warning)
            showToast("CHUT !", style: .danger)
        } else if state.noiseLevel < NoiseRules.rearmThreshold {
            dangerArmed = true
        }

        if state.noiseLevel >= 100 { wake() }
    }

    private func registerNoise(_ base: Double, closeness: CGFloat) {
        recentActions.append(clock)
        recentActions.removeAll { clock - $0 > NoiseRules.rapidWindow }
        let isRapid = recentActions.count >= NoiseRules.rapidCount
        let amount = (isRapid ? max(base, NoiseRules.rapid) : base) * NoiseRules.proximityFactor(Double(closeness))
        changeNoise(by: amount)
    }

    private func wake() {
        state.phase = .waking
        state.noiseLevel = 100
        wakeCountdown = Creature.wakeDuration
        player.isCharging = false
        haptics.play(.wake)
        audio.stopMusic()
        audio.play(.wake)
        island.sync(islandContent())
        island.announce("WHO WOKE ME UP?!", duration: Creature.wakeDuration)
    }

    private func endGame() {
        guard state.phase != .gameOver else { return }
        state.phase = .gameOver
        player.isCharging = false
        haptics.play(.gameOver)
        audio.stopMusic()
        audio.play(.gameOver)

        let result = GameResult(
            score: state.score,
            coins: state.coinsCollected,
            duration: state.elapsed,
            level: state.level,
            bestCombo: state.bestCombo,
            breakdown: state.breakdown
        )
        self.result = result
        isNewBest = storage.record(result)
        bestScore = storage.stats().bestScore
        publish()
        island.finish(with: islandContent())

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, self.result == result else { return }
            self.isGameOverPresented = true
        }
    }

    private func checkLevelUp() {
        guard state.level > lastLevel else { return }
        lastLevel = state.level
        showToast("NIVEAU \(state.level)", style: .info)
    }

    private func showToast(_ text: String, style: GameToast.Style) {
        let toast = GameToast(text: text, style: style)
        self.toast = toast
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.1))
            guard let self, self.toast?.id == toast.id else { return }
            self.toast = nil
        }
    }

    // MARK: Output

    private func publish() {
        let snapshot = HUDSnapshot(
            score: state.score,
            coins: state.coinsCollected,
            noise: state.noisePercent,
            level: state.level,
            combo: state.combo,
            phase: state.phase,
            multiplierActive: state.multiplierRemaining > 0,
            magnetReady: player.magnetCooldown <= 0,
            shieldActive: player.isShielded,
            elapsedSeconds: Int(state.elapsed)
        )
        if snapshot != hud { hud = snapshot }
        island.sync(islandContent())
    }

    private func islandContent() -> IslandAttributes.ContentState {
        IslandAttributes.ContentState(
            mood: state.mood,
            noise: state.noisePercent,
            score: state.score,
            coins: state.coinsCollected,
            level: state.level,
            isPaused: isPaused
        )
    }

    private func makeTuning() -> SceneTuning {
        var tuning = SceneTuning()
        let difficulty = state.difficulty
        tuning.phase = state.phase
        tuning.difficulty = difficulty

        switch state.phase {
        case .sleeping, .waking:
            tuning.coinSpawnInterval = max(0.55, 1.3 - (difficulty - 1) * 0.12)
            tuning.coinLifetimeScale = max(0.55, 1 - (difficulty - 1) * 0.07)
            tuning.maxCoins = 7
        case .chase, .gameOver:
            tuning.coinSpawnInterval = max(0.3, 0.75 - (difficulty - 1) * 0.06)
            tuning.coinLifetimeScale = max(0.5, 0.8 - (difficulty - 1) * 0.05)
            tuning.maxCoins = 10
            tuning.obstacleSpawnInterval = max(0.35, 1.5 - (difficulty - 1) * 0.14)
            tuning.obstacleSpeed = min(520, 190 + CGFloat(difficulty - 1) * 35)
            tuning.creatureSpeed = creature.speed(difficulty: difficulty)
            tuning.creatureSlowed = creature.isSlowed
        }

        tuning.playerFrozen = player.isCharging
        tuning.shieldActive = player.isShielded
        tuning.invulnerable = player.isInvulnerable
        if player.isCharging {
            tuning.chargeProgress = state.phase == .chase
                ? CGFloat(min(player.chargeTime / Player.shieldChargeTime, 1))
                : CGFloat(player.chargeTime.truncatingRemainder(dividingBy: 1.2) / 1.2)
        }
        return tuning
    }
}

// MARK: - GameSceneDelegate

extension GameViewModel: GameSceneDelegate {
    func sceneTick(_ dt: TimeInterval) -> SceneTuning {
        guard !isPaused, state.phase != .gameOver else { return makeTuning() }
        clock += dt

        switch state.phase {
        case .sleeping: tickSleeping(dt)
        case .waking: tickWaking(dt)
        case .chase: tickChase(dt)
        case .gameOver: break
        }

        tickTimers(dt)
        checkLevelUp()
        publish()
        return makeTuning()
    }

    func sceneRequests(_ action: PlayerAction, closeness: CGFloat) -> Bool {
        guard !isPaused, state.phase != .gameOver else { return false }

        switch action {
        case .tap:
            registerNoise(NoiseRules.tap, closeness: closeness)
            return true

        case .doubleTap:
            guard player.magnetCooldown <= 0 else { return false }
            player.magnetCooldown = Player.magnetCooldownDuration
            registerNoise(NoiseRules.doubleTap, closeness: closeness)
            audio.play(.magnet)
            haptics.play(.dash)
            return true

        case .swipe:
            guard dashCooldown <= 0 else { return false }
            dashCooldown = Player.dashCooldown
            player.dashInvulnerability = Player.dashInvulnerabilityDuration
            registerNoise(NoiseRules.swipe, closeness: closeness)
            audio.play(.dash)
            haptics.play(.dash)
            return true

        case .chargeBegan:
            guard state.phase == .sleeping || state.phase == .chase else { return false }
            player.isCharging = true
            player.chargeTime = 0
            if state.phase == .sleeping { audio.play(.calm) }
            return true

        case .chargeReleased:
            let isCharged = player.isCharging && player.chargeTime >= Player.shieldChargeTime
            player.isCharging = false
            if state.phase == .chase, isCharged {
                player.shieldRemaining = Player.shieldDuration
                audio.play(.shield)
                haptics.play(.shield)
                showToast("🛡️ BOUCLIER", style: .info)
            }
            return true
        }
    }

    func sceneDidCollect(_ kind: CoinKind, closeness: CGFloat) {
        guard state.phase != .gameOver else { return }

        state.coinsCollected += 1
        state.combo = clock - lastCollectTime <= 1.6 ? state.combo + 1 : 1
        lastCollectTime = clock
        state.bestCombo = max(state.bestCombo, state.combo)

        var points = Double(kind.points) * state.comboMultiplier * state.difficultyMultiplier
        if state.multiplierRemaining > 0 { points *= 2 }
        if state.phase == .chase { points *= 1.5 }
        state.breakdown.coinPoints += Int(points.rounded())

        // Risk bonus: grabbing coins while the creature is about to wake up.
        if state.phase == .sleeping, state.noiseLevel >= 70 {
            let bonus = Int((points * 0.5).rounded())
            state.breakdown.bonusPoints += bonus
            showToast("AUDACE +\(bonus)", style: .bonus)
        }

        switch kind {
        case .coin:
            haptics.play(.coin)
            audio.play(.coin)
            changeNoise(by: kind.noise * NoiseRules.proximityFactor(Double(closeness)))
        case .gem:
            state.breakdown.bonusPoints += 25
            haptics.play(.bonus)
            audio.play(.bonus)
            changeNoise(by: kind.noise)
        case .star:
            state.multiplierRemaining = 6
            haptics.play(.bonus)
            audio.play(.bonus)
            showToast("⭐️ SCORE x2", style: .bonus)
            changeNoise(by: kind.noise)
        case .moon:
            haptics.play(.bonus)
            audio.play(.calm)
            if state.phase == .chase {
                creature.slowRemaining = Creature.slowDuration
                showToast("🌙 ELLE RALENTIT", style: .info)
            } else {
                changeNoise(by: kind.noise)
                showToast("🌙 BERCEUSE", style: .info)
            }
        }

        if state.combo >= 5, state.combo % 5 == 0 {
            showToast("COMBO x\(state.combo)", style: .bonus)
        }
    }

    func scenePlayerWasHit(byCreature: Bool) -> HitResult {
        guard state.phase == .chase, !isPaused else { return .ignored }
        if player.dashInvulnerability > 0 { return .ignored }
        if player.isShielded {
            player.shieldRemaining = 0
            haptics.play(.danger)
            audio.play(.shield)
            return .absorbed
        }
        endGame()
        return .fatal
    }
}
