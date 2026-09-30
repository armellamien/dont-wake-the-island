import SpriteKit

final class CreatureNode: SKNode {
    static let radius: CGFloat = 22

    var velocity = CGVector.zero

    private let aura = SKSpriteNode(texture: TextureFactory.glow(radius: CreatureNode.radius, color: .neonRed, key: "creature"))
    private let face = SKSpriteNode(texture: TextureFactory.emoji("😡", size: 34))
    private var isSlowed = false

    override init() {
        super.init()
        zPosition = 8
        aura.alpha = 0.75
        addChild(aura)
        addChild(face)
        aura.run(.repeatForever(.sequence([
            .scale(to: 1.15, duration: 0.35),
            .scale(to: 0.95, duration: 0.35),
        ])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func emerge() {
        setScale(0.2)
        alpha = 0
        let grow = SKAction.scale(to: 1, duration: 0.45)
        grow.timingMode = .easeOut
        run(.group([grow, .fadeIn(withDuration: 0.2)]))
    }

    func setSlowed(_ slowed: Bool) {
        guard slowed != isSlowed else { return }
        isSlowed = slowed
        face.texture = TextureFactory.emoji(slowed ? "😵‍💫" : "😡", size: 34)
        aura.alpha = slowed ? 0.35 : 0.75
    }

    func knockBack(from point: CGPoint) {
        velocity = point.vector(to: position).normalized * 650
    }

    func celebrate() {
        velocity = .zero
        face.texture = TextureFactory.emoji("😈", size: 34)
        run(.repeatForever(.sequence([
            .scale(to: 1.25, duration: 0.2),
            .scale(to: 1.0, duration: 0.2),
        ])))
    }
}
