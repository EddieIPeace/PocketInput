import Foundation

public enum MouseButton: String, Codable, Sendable {
    case left
    case right
}

public enum ClickPhase: String, Codable, Sendable {
    case down
    case up
    case tap
}

public enum InputEvent: Codable, Sendable, Equatable {
    case move(dx: Double, dy: Double)
    case click(button: MouseButton, phase: ClickPhase)

    private enum CodingKeys: String, CodingKey {
        case type
        case dx
        case dy
        case button
        case phase
    }

    private enum EventType: String, Codable {
        case move
        case click
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EventType.self, forKey: .type)
        switch type {
        case .move:
            let dx = try container.decode(Double.self, forKey: .dx)
            let dy = try container.decode(Double.self, forKey: .dy)
            self = .move(dx: dx, dy: dy)
        case .click:
            let button = try container.decode(MouseButton.self, forKey: .button)
            let phase = try container.decode(ClickPhase.self, forKey: .phase)
            self = .click(button: button, phase: phase)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .move(let dx, let dy):
            try container.encode(EventType.move, forKey: .type)
            try container.encode(dx, forKey: .dx)
            try container.encode(dy, forKey: .dy)
        case .click(let button, let phase):
            try container.encode(EventType.click, forKey: .type)
            try container.encode(button, forKey: .button)
            try container.encode(phase, forKey: .phase)
        }
    }
}
