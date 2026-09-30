import SpriteKit

final class PlayerNode: SKNode {
    static let radius: CGFloat = 14

    var target: CGPoint?

    private let core = SKSpriteNode(texture: TextureFactory.glow(radius: PlayerNode.radius, color: .neonCyan, key: "player"))
    private let shieldRing = SKShapeNode(circleOfRadius: 26)
    private let chargeRing = SKShapeNode()

    override init() {
        super.init()
        zPosition = 10

        addChild(core)
        core.run(.repeatForever(.sequence([
            .scale(to: 1.08, duration: 0.6),
            .scale(to: 0.94, duration: 0.6),
        ])))

        shieldRing.strokeColor = .neonCyan
        shieldRing.fillColor = UIColor.neonCyan.withAlphaComponent(0.08)
        shieldRing.lineWidth = 2.5
        shieldRing.isHidden = true
        addChild(shieldRing)

        chargeRing.lineWidth = 3
        chargeRing.lineCap = .round
        chargeRing.isHidden = true
        addChild(chargeRing)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(shield: Bool, invulnerable: Bool, charge: CGFloat?) {
        if shield == shieldRing.isHidden {
            shieldRing.isHidden = !shield
            if shield {
                shieldRing.setScale(0.4)
                shieldRing.run(.scale(to: 1, duration: 0.15))
            }
        }
        core.alpha = invulnerable && !shield ? 0.5 : 1

        if let charge {
            chargeRing.isHidden = false
            let progress = min(max(charge, 0.02), 1)
            chargeRing.strokeColor = progress >= 1 ? .neonCyan : .neonLavender
            chargeRing.path = UIBezierPath(
                arcCenter: .zero,
                radius: 21,
                startAngle: .pi / 2,
                endAngle: .pi / 2 - 2 * .pi * progress,
                clockwise: false
            ).cgPath
        } else if !chargeRing.isHidden {
            chargeRing.isHidden = true
        }
    }

    func dash(to destination: CGPoint) {
        target = nil
        if let parent {
            let ghost = SKSpriteNode(texture: core.texture)
            ghost.position = position
            ghost.alpha = 0.4
            ghost.zPosition = zPosition - 1
            parent.addChild(ghost)
            ghost.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
        }
        let move = SKAction.move(to: destination, duration: 0.13)
        move.timingMode = .easeOut
        run(move, withKey: "dash")
    }

    func vanish() {
        removeAction(forKey: "dash")
        target = nil
        run(.group([.scale(to: 0.1, duration: 0.25), .fadeOut(withDuration: 0.25)]))
    }

    func reset(at point: CGPoint) {
        removeAllActions()
        position = point
        target = nil
        alpha = 1
        setScale(1)
        apply(shield: false, invulnerable: false, charge: nil)
    }
}
