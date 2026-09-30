import SpriteKit

final class CoinNode: SKNode {
    let kind: CoinKind
    let radius: CGFloat
    var expiry: TimeInterval = 0
    var isAttracted = false
    private(set) var isBlinking = false

    private let sprite: SKSpriteNode

    init(kind: CoinKind) {
        self.kind = kind
        radius = kind == .coin ? 10 : 14
        sprite = SKSpriteNode(texture: TextureFactory.texture(for: kind))
        super.init()
        zPosition = 5
        addChild(sprite)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func appear() {
        setScale(0)
        run(.sequence([.scale(to: 1.15, duration: 0.14), .scale(to: 1, duration: 0.08)]))
        let bob = SKAction.moveBy(x: 0, y: 3, duration: 0.7)
        bob.timingMode = .easeInEaseOut
        sprite.run(.repeatForever(.sequence([bob, bob.reversed()])))
    }

    func startBlinking() {
        isBlinking = true
        run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: 0.12),
            .fadeAlpha(to: 1, duration: 0.12),
        ])), withKey: "blink")
    }

    func collect() {
        removeAllActions()
        run(.sequence([
            .group([.scale(to: 1.8, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent(),
        ]))
    }

    func expire() {
        removeAllActions()
        run(.sequence([
            .group([.scale(to: 0, duration: 0.2), .fadeOut(withDuration: 0.2)]),
            .removeFromParent(),
        ]))
    }
}
