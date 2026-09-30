import SpriteKit
import UIKit

/// Everything the scene needs from the game logic for one frame.
struct SceneTuning: Sendable {
    var phase: GamePhase = .sleeping
    var difficulty: Double = 1
    var coinSpawnInterval: TimeInterval = 1.2
    var coinLifetimeScale: Double = 1
    var maxCoins = 7
    var obstacleSpawnInterval: TimeInterval?
    var obstacleSpeed: CGFloat = 200
    var creatureSpeed: CGFloat = 120
    var creatureSlowed = false
    var playerFrozen = false
    var shieldActive = false
    var invulnerable = false
    var chargeProgress: CGFloat?
}

@MainActor
protocol GameSceneDelegate: AnyObject {
    func sceneTick(_ dt: TimeInterval) -> SceneTuning
    func sceneRequests(_ action: PlayerAction, closeness: CGFloat) -> Bool
    func sceneDidCollect(_ kind: CoinKind, closeness: CGFloat)
    func scenePlayerWasHit(byCreature: Bool) -> HitResult
}

/// Renders the play field and turns raw touches into game actions.
/// Rules (noise, score, difficulty) live in `GameViewModel`.
final class GameScene: SKScene {
    weak var gameDelegate: (any GameSceneDelegate)?

    /// Distance from the top of the screen to the island's center, provided by the SwiftUI layout.
    var islandOffsetFromTop: CGFloat = 30

    private let world = SKNode()
    private let player = PlayerNode()
    private var creature: CreatureNode?
    private var coins: [CoinNode] = []
    private var obstacles: [ObstacleNode] = []
    private var backgroundDots: [SKSpriteNode] = []

    private var lastUpdate: TimeInterval = 0
    private var now: TimeInterval = 0
    private var coinTimer: TimeInterval = 0.5
    private var obstacleTimer: TimeInterval = 1.2
    private var zzzTimer: TimeInterval = 0
    private var phase: GamePhase = .sleeping
    private var tuning = SceneTuning()

    private var touchStartPoint: CGPoint?
    private var touchStartTime: TimeInterval = 0
    private var touchMoved = false
    private var isCharging = false
    private var lastTapTime: TimeInterval = -1
    private var lastTapPoint: CGPoint = .zero

    private enum Gesture {
        static let moveTolerance: CGFloat = 14
        static let swipeDistance: CGFloat = 40
        static let longPressDelay: TimeInterval = 0.32
        static let doubleTapDelay: TimeInterval = 0.3
        static let doubleTapDistance: CGFloat = 70
    }

    var islandPosition: CGPoint {
        CGPoint(x: size.width / 2, y: size.height - islandOffsetFromTop)
    }

    private var playArea: CGRect {
        let top = size.height - islandOffsetFromTop - 110
        return CGRect(x: 28, y: 110, width: max(size.width - 56, 1), height: max(top - 110, 1))
    }

    private var defaultPlayerPosition: CGPoint {
        CGPoint(x: size.width / 2, y: playArea.minY + 40)
    }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .gameBackground
        addChild(world)
        world.addChild(player)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        layoutBackground()
        player.reset(at: defaultPlayerPosition)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        layoutBackground()
        player.position = clamped(player.position)
    }

    func reset() {
        coins.forEach { $0.removeFromParent() }
        coins.removeAll()
        obstacles.forEach { $0.removeFromParent() }
        obstacles.removeAll()
        creature?.removeFromParent()
        creature = nil
        world.removeAllActions()
        world.position = .zero

        player.reset(at: defaultPlayerPosition)
        phase = .sleeping
        tuning = SceneTuning()
        coinTimer = 0.5
        obstacleTimer = 1.2
        lastUpdate = 0
        isCharging = false
        touchStartPoint = nil
    }

    // MARK: Game loop

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdate = currentTime }
        guard lastUpdate > 0, let gameDelegate else { return }
        // Clamping also absorbs the jump after a pause.
        let dt = min(currentTime - lastUpdate, 1.0 / 20.0)
        guard dt > 0 else { return }
        now += dt

        checkLongPress()
        tuning = gameDelegate.sceneTick(dt)
        if tuning.phase != phase { transition(to: tuning.phase) }
        guard phase != .gameOver else { return }

        player.apply(shield: tuning.shieldActive, invulnerable: tuning.invulnerable, charge: tuning.chargeProgress)
        movePlayer(dt)
        updateCoins(dt)

        switch phase {
        case .sleeping: emitZzz(dt)
        case .chase:
            updateCreature(dt)
            updateObstacles(dt)
        case .waking, .gameOver: break
        }
    }

    private func transition(to newPhase: GamePhase) {
        phase = newPhase
        switch newPhase {
        case .sleeping:
            break
        case .waking:
            shake(amplitude: 10, duration: 1.2)
            flash(color: .neonRed)
        case .chase:
            let creature = CreatureNode()
            creature.position = islandPosition
            world.addChild(creature)
            creature.emerge()
            self.creature = creature
            obstacleTimer = 1.0
        case .gameOver:
            isCharging = false
            touchStartPoint = nil
            burst(at: player.position, color: .neonCyan, key: "cyan", count: 16)
            player.vanish()
            creature?.celebrate()
            shake(amplitude: 8, duration: 0.4)
        }
    }

    private func movePlayer(_ dt: TimeInterval) {
        guard !tuning.playerFrozen, let target = player.target else { return }
        let delta = player.position.vector(to: target)
        let distance = delta.length
        let step = Player.moveSpeed * CGFloat(dt)
        if distance <= step {
            player.position = target
            player.target = nil
        } else {
            player.position = player.position + delta.normalized * step
        }
    }

    // MARK: Coins

    private func updateCoins(_ dt: TimeInterval) {
        coinTimer -= dt
        if coinTimer <= 0, phase != .waking {
            coinTimer = tuning.coinSpawnInterval * Double.random(in: 0.7...1.3)
            if coins.count < tuning.maxCoins { spawnCoin() }
        }

        var remaining: [CoinNode] = []
        for coin in coins {
            if coin.isAttracted {
                let delta = coin.position.vector(to: player.position)
                let step = 900 * CGFloat(dt)
                coin.position = delta.length <= step ? player.position : coin.position + delta.normalized * step
            }

            if coin.position.distance(to: player.position) < PlayerNode.radius + coin.radius + 6 {
                gameDelegate?.sceneDidCollect(coin.kind, closeness: closeness(of: coin.position))
                coin.collect()
            } else if now >= coin.expiry, !coin.isAttracted {
                coin.expire()
            } else {
                if now >= coin.expiry - 1.2, !coin.isBlinking { coin.startBlinking() }
                remaining.append(coin)
            }
        }
        coins = remaining
    }

    private func spawnCoin() {
        let kind = CoinKind.random(phase: phase, difficulty: tuning.difficulty)
        let area = playArea
        var point = CGPoint.zero
        for _ in 0..<4 {
            // Big bonuses sit close to the sleeping island: more points, more noise.
            let minY = kind == .gem ? area.maxY - area.height * 0.3 : area.minY
            point = CGPoint(x: .random(in: area.minX...area.maxX), y: .random(in: minY...area.maxY))
            if point.distance(to: player.position) > 70 { break }
        }
        let coin = CoinNode(kind: kind)
        coin.position = point
        coin.expiry = now + kind.lifetime * tuning.coinLifetimeScale
        world.addChild(coin)
        coin.appear()
        coins.append(coin)
    }

    // MARK: Chase

    private func updateCreature(_ dt: TimeInterval) {
        guard let creature else { return }
        creature.setSlowed(tuning.creatureSlowed)

        let toPlayer = creature.position.vector(to: player.position)
        let distance = toPlayer.length
        if distance > 1 {
            let desired = toPlayer.normalized * tuning.creatureSpeed
            creature.velocity = creature.velocity + (desired - creature.velocity) * CGFloat(min(1, dt * 2.5))
        }
        let next = creature.position + creature.velocity * CGFloat(dt)
        creature.position = CGPoint(x: min(max(next.x, 0), size.width), y: min(max(next.y, 0), size.height))

        guard distance < PlayerNode.radius + CreatureNode.radius else { return }
        switch gameDelegate?.scenePlayerWasHit(byCreature: true) ?? .ignored {
        case .ignored: break
        case .absorbed:
            creature.knockBack(from: player.position)
            burst(at: player.position, color: .neonCyan, key: "cyan", count: 8)
        case .fatal:
            transition(to: .gameOver)
        }
    }

    private func updateObstacles(_ dt: TimeInterval) {
        if let interval = tuning.obstacleSpawnInterval {
            obstacleTimer -= dt
            if obstacleTimer <= 0 {
                obstacleTimer = interval * Double.random(in: 0.8...1.2)
                spawnVolley()
            }
        }

        let bounds = frame.insetBy(dx: -80, dy: -80)
        var remaining: [ObstacleNode] = []
        for obstacle in obstacles {
            obstacle.position = obstacle.position + obstacle.velocity * CGFloat(dt)
            guard bounds.contains(obstacle.position) else {
                obstacle.removeFromParent()
                continue
            }
            let hit = phase == .chase
                && obstacle.position.distance(to: player.position) < PlayerNode.radius + ObstacleNode.radius - 2
            guard hit else {
                remaining.append(obstacle)
                continue
            }
            switch gameDelegate?.scenePlayerWasHit(byCreature: false) ?? .ignored {
            case .ignored:
                remaining.append(obstacle)
            case .absorbed:
                burst(at: obstacle.position, color: .neonPink, key: "pink", count: 8)
                obstacle.removeFromParent()
            case .fatal:
                burst(at: obstacle.position, color: .neonPink, key: "pink", count: 8)
                obstacle.removeFromParent()
                transition(to: .gameOver)
            }
        }
        obstacles = remaining
    }

    private func spawnVolley() {
        let origin = islandPosition
        let aim = origin.vector(to: player.position)
        let baseAngle = atan2(aim.dy, aim.dx)
        let count = tuning.difficulty >= 4 ? 3 : (tuning.difficulty >= 2.5 ? 2 : 1)
        for index in 0..<count {
            let spread = count == 1 ? 0 : (CGFloat(index) - CGFloat(count - 1) / 2) * 0.32
            let angle = baseAngle + spread + .random(in: -0.12...0.12)
            addObstacle(at: origin, direction: CGVector(dx: cos(angle), dy: sin(angle)))
        }
        if tuning.difficulty >= 3, Double.random(in: 0..<1) < 0.3 {
            let fromLeft = Bool.random()
            let start = CGPoint(x: fromLeft ? -20 : size.width + 20, y: .random(in: playArea.minY...playArea.maxY))
            addObstacle(at: start, direction: CGVector(dx: fromLeft ? 1 : -1, dy: 0))
        }
    }

    private func addObstacle(at point: CGPoint, direction: CGVector) {
        let obstacle = ObstacleNode()
        obstacle.position = point
        obstacle.velocity = direction * tuning.obstacleSpeed
        world.addChild(obstacle)
        obstacle.launch()
        obstacles.append(obstacle)
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, phase != .gameOver else { return }
        touchStartPoint = touch.location(in: self)
        touchStartTime = now
        touchMoved = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = touchStartPoint, let touch = touches.first else { return }
        if start.distance(to: touch.location(in: self)) > Gesture.moveTolerance { touchMoved = true }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = touchStartPoint, let touch = touches.first else { return }
        touchStartPoint = nil
        let end = touch.location(in: self)

        if isCharging {
            isCharging = false
            _ = gameDelegate?.sceneRequests(.chargeReleased, closeness: closeness(of: player.position))
            return
        }

        let delta = start.vector(to: end)
        if delta.length > Gesture.swipeDistance {
            performDash(direction: delta.normalized)
        } else if now - lastTapTime < Gesture.doubleTapDelay, lastTapPoint.distance(to: end) < Gesture.doubleTapDistance {
            lastTapTime = -1
            performMagnet()
        } else {
            lastTapTime = now
            lastTapPoint = end
            performTap(at: end)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartPoint = nil
        if isCharging {
            isCharging = false
            _ = gameDelegate?.sceneRequests(.chargeReleased, closeness: closeness(of: player.position))
        }
    }

    private func checkLongPress() {
        guard touchStartPoint != nil, !touchMoved, !isCharging, now - touchStartTime >= Gesture.longPressDelay else { return }
        if gameDelegate?.sceneRequests(.chargeBegan, closeness: closeness(of: player.position)) == true {
            isCharging = true
            player.target = nil
        } else {
            touchStartPoint = nil
        }
    }

    private func performTap(at point: CGPoint) {
        guard gameDelegate?.sceneRequests(.tap, closeness: closeness(of: point)) == true else { return }
        player.target = clamped(point)
        ripple(at: point, radius: 26, color: .neonCyan)
    }

    private func performDash(direction: CGVector) {
        guard gameDelegate?.sceneRequests(.swipe, closeness: closeness(of: player.position)) == true else { return }
        player.dash(to: clamped(player.position + direction * Player.dashDistance))
        ripple(at: player.position, radius: 40, color: .neonLavender)
    }

    private func performMagnet() {
        guard gameDelegate?.sceneRequests(.doubleTap, closeness: closeness(of: player.position)) == true else { return }
        ripple(at: player.position, radius: Player.magnetRadius, color: .neonPink)
        for coin in coins where coin.position.distance(to: player.position) < Player.magnetRadius {
            coin.isAttracted = true
        }
    }

    // MARK: Effects

    private func emitZzz(_ dt: TimeInterval) {
        zzzTimer -= dt
        guard zzzTimer <= 0 else { return }
        zzzTimer = 1.1
        let label = SKLabelNode(text: "z")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = .random(in: 12...18)
        label.fontColor = UIColor.neonLavender.withAlphaComponent(0.7)
        label.position = CGPoint(x: islandPosition.x + 40, y: islandPosition.y - 24)
        label.zPosition = 2
        world.addChild(label)
        label.run(.sequence([
            .group([
                .moveBy(x: 30, y: -60, duration: 1.8),
                .fadeOut(withDuration: 1.8),
                .scale(to: 1.5, duration: 1.8),
            ]),
            .removeFromParent(),
        ]))
    }

    /// Every action emits a visible "sound wave".
    private func ripple(at point: CGPoint, radius: CGFloat, color: UIColor) {
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.strokeColor = color.withAlphaComponent(0.6)
        ring.lineWidth = 2
        ring.position = point
        ring.zPosition = 3
        world.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: radius / 10, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
    }

    private func burst(at point: CGPoint, color: UIColor, key: String, count: Int) {
        let texture = TextureFactory.glow(radius: 3, color: color, key: "spark-\(key)")
        for index in 0..<count {
            let spark = SKSpriteNode(texture: texture)
            spark.position = point
            spark.zPosition = 20
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi + .random(in: -0.2...0.2)
            let distance = CGFloat.random(in: 30...80)
            let move = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.4)
            move.timingMode = .easeOut
            world.addChild(spark)
            spark.run(.sequence([
                .group([move, .fadeOut(withDuration: 0.4), .scale(to: 0.3, duration: 0.4)]),
                .removeFromParent(),
            ]))
        }
    }

    private func shake(amplitude: CGFloat, duration: TimeInterval) {
        let steps = Int(duration / 0.04)
        var actions: [SKAction] = (0..<steps).map { step in
            let decay = 1 - CGFloat(step) / CGFloat(steps)
            let offset = CGPoint(x: .random(in: -amplitude...amplitude) * decay, y: .random(in: -amplitude...amplitude) * decay)
            return .move(to: offset, duration: 0.04)
        }
        actions.append(.move(to: .zero, duration: 0.04))
        world.run(.sequence(actions), withKey: "shake")
    }

    private func flash(color: UIColor) {
        let overlay = SKSpriteNode(color: color, size: size)
        overlay.anchorPoint = .zero
        overlay.alpha = 0.35
        overlay.zPosition = 50
        addChild(overlay)
        overlay.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    private func layoutBackground() {
        backgroundDots.forEach { $0.removeFromParent() }
        backgroundDots = (0..<45).map { _ in
            let dot = SKSpriteNode(color: .white, size: CGSize(width: 2, height: 2))
            dot.position = CGPoint(x: .random(in: 0...max(size.width, 1)), y: .random(in: 0...max(size.height, 1)))
            dot.alpha = .random(in: 0.05...0.3)
            dot.zPosition = -10
            addChild(dot)
            return dot
        }
    }

    // MARK: Geometry

    /// 0 far from the island, 1 right next to it.
    private func closeness(of point: CGPoint) -> CGFloat {
        let reference = max(size.height * 0.85, 1)
        return min(max(1 - point.distance(to: islandPosition) / reference, 0), 1)
    }

    private func clamped(_ point: CGPoint, margin: CGFloat = 16) -> CGPoint {
        let area = playArea.insetBy(dx: -margin, dy: -margin)
        return CGPoint(x: min(max(point.x, area.minX), area.maxX), y: min(max(point.y, area.minY), area.maxY + 60))
    }
}
