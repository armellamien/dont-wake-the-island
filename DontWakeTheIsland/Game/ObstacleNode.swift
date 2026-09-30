import SpriteKit

/// A shockwave the angry island throws at the player.
final class ObstacleNode: SKNode {
    static let radius: CGFloat = 11

    var velocity = CGVector.zero

    private let sprite = SKSpriteNode(texture: TextureFactory.glow(radius: ObstacleNode.radius, color: .neonPink, key: "obstacle"))

    override init() {
        super.init()
        zPosition = 7
        addChild(sprite)
        sprite.run(.repeatForever(.sequence([
            .scale(to: 1.2, duration: 0.18),
            .scale(to: 0.9, duration: 0.18),
        ])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func launch() {
        setScale(0.3)
        run(.scale(to: 1, duration: 0.2))
    }
}
