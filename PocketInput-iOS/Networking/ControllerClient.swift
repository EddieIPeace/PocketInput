import Foundation
import Network
import PocketInputKit
import UIKit

@MainActor
@Observable
final class ControllerClient {
    enum Phase: Equatable {
        case disconnected
        case connecting
        case waitingAccept
        case connected
        case rejected
        case failed(String)
    }

    private(set) var phase: Phase = .disconnected
    private(set) var remoteName: String?

    private var connection: NWConnection?
    private let lineBuffer = LineBuffer()
    private let deviceName: String

    init() {
        deviceName = UIDevice.current.name
    }

    func connect(to host: DiscoveredHost) {
        disconnect()
        remoteName = host.name
        phase = .connecting

        let connection = NWConnection(to: host.endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleState(state)
            }
        }
        connection.start(queue: .main)
        self.connection = connection
        receiveLoop(on: connection)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        lineBuffer.reset()
        remoteName = nil
        phase = .disconnected
    }

    func send(_ event: InputEvent) {
        guard case .connected = phase else { return }
        sendMessage(.input(event))
    }

    private func handleState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            sendMessage(.control(.hello, deviceName: deviceName))
            if phase == .connecting {
                phase = .waitingAccept
            }
        case .failed(let error):
            connection = nil
            phase = .failed(error.localizedDescription)
        case .cancelled:
            connection = nil
            if phase != .rejected {
                phase = .disconnected
            }
        default:
            break
        }
    }

    private func receiveLoop(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data, !data.isEmpty {
                    for line in self.lineBuffer.append(data) {
                        self.handleLine(line)
                    }
                }
                if isComplete || error != nil {
                    if self.connection === connection {
                        self.connection = nil
                        if self.phase != .rejected {
                            self.phase = .disconnected
                        }
                    }
                    return
                }
                self.receiveLoop(on: connection)
            }
        }
    }

    private func handleLine(_ line: Data) {
        guard let message = try? WireCodec.decodeLine(line) else { return }
        switch message {
        case .control(let control, let deviceName):
            if let deviceName, !deviceName.isEmpty {
                remoteName = deviceName
            }
            switch control {
            case .hello, .acceptRequest, .ping:
                break
            case .accepted:
                phase = .connected
            case .rejected:
                phase = .rejected
                connection?.cancel()
                connection = nil
            }
        case .input:
            break
        }
    }

    private func sendMessage(_ message: WireMessage) {
        guard let connection, let data = try? WireCodec.encodeLine(message) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
}
