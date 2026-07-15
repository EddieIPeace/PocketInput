import Foundation

public enum ControlMessage: String, Codable, Sendable {
    case hello
    case acceptRequest
    case accepted
    case rejected
    case ping
}

public enum WireMessage: Codable, Sendable, Equatable {
    case control(ControlMessage, deviceName: String?)
    case input(InputEvent)

    private enum CodingKeys: String, CodingKey {
        case v
        case kind
        case control
        case deviceName
        case event
    }

    private enum Kind: String, Codable {
        case control
        case input
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .v)
        guard version == ProtocolConstants.protocolVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .v,
                in: container,
                debugDescription: "Unsupported protocol version \(version)"
            )
        }
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .control:
            let control = try container.decode(ControlMessage.self, forKey: .control)
            let deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
            self = .control(control, deviceName: deviceName)
        case .input:
            let event = try container.decode(InputEvent.self, forKey: .event)
            self = .input(event)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ProtocolConstants.protocolVersion, forKey: .v)
        switch self {
        case .control(let control, let deviceName):
            try container.encode(Kind.control, forKey: .kind)
            try container.encode(control, forKey: .control)
            try container.encodeIfPresent(deviceName, forKey: .deviceName)
        case .input(let event):
            try container.encode(Kind.input, forKey: .kind)
            try container.encode(event, forKey: .event)
        }
    }
}

public enum WireCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    public static func encodeLine(_ message: WireMessage) throws -> Data {
        var data = try encoder.encode(message)
        data.append(ProtocolConstants.lineDelimiter)
        return data
    }

    public static func decodeLine(_ data: Data) throws -> WireMessage {
        try decoder.decode(WireMessage.self, from: data)
    }
}

/// Accumulates TCP bytes and yields complete NDJSON lines.
public final class LineBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    public init() {}

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll(keepingCapacity: false)
    }

    public func append(_ data: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
        var lines: [Data] = []
        while let index = buffer.firstIndex(of: ProtocolConstants.lineDelimiter) {
            let line = buffer.subdata(in: buffer.startIndex..<index)
            buffer.removeSubrange(buffer.startIndex...index)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}
