import Foundation
import Network
import PocketInputKit

@MainActor
@Observable
final class HostServer {
    enum Phase: Equatable {
        case idle
        case listening
        case waitingAccept(deviceName: String)
        case connected(deviceName: String)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var hostDisplayName: String

    private var listener: NWListener?
    private var connection: NWConnection?
    private let lineBuffer = LineBuffer()
    private let injector = InputInjector()
    private var pendingDeviceName: String?

    var onInputEvent: ((InputEvent) -> Void)?

    init() {
        hostDisplayName = Host.current().localizedName ?? "Mac"
    }

    func start() {
        stop()
        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(
                name: hostDisplayName,
                type: ProtocolConstants.bonjourServiceType
            )
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleListenerState(state)
                }
            }
            listener.newConnectionHandler = { [weak self] newConnection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(newConnection)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
            phase = .listening
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func stop() {
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        pendingDeviceName = nil
        lineBuffer.reset()
        phase = .idle
    }

    func acceptPending() {
        guard case .waitingAccept(let name) = phase else { return }
        send(.control(.accepted, deviceName: hostDisplayName))
        phase = .connected(deviceName: name)
    }

    func rejectPending() {
        guard case .waitingAccept = phase else { return }
        send(.control(.rejected, deviceName: hostDisplayName))
        connection?.cancel()
        connection = nil
        pendingDeviceName = nil
        phase = .listening
    }

    func disconnectClient() {
        connection?.cancel()
        connection = nil
        pendingDeviceName = nil
        phase = listener == nil ? .idle : .listening
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            if connection == nil {
                phase = .listening
            }
        case .failed(let error):
            phase = .failed(error.localizedDescription)
        case .cancelled:
            if connection == nil {
                phase = .idle
            }
        default:
            break
        }
    }

    private func handleNewConnection(_ newConnection: NWConnection) {
        // Single-client MVP: reject extra connections.
        if connection != nil {
            newConnection.cancel()
            return
        }
        connection = newConnection
        pendingDeviceName = nil
        newConnection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleConnectionState(state)
            }
        }
        newConnection.start(queue: .main)
        receiveLoop(on: newConnection)
        send(.control(.hello, deviceName: hostDisplayName))
        send(.control(.acceptRequest, deviceName: hostDisplayName))
        phase = .waitingAccept(deviceName: "控制器")
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .failed(let error):
            connection = nil
            pendingDeviceName = nil
            phase = .failed(error.localizedDescription)
            // Recover to listening if listener still up.
            if listener != nil {
                phase = .listening
            }
        case .cancelled:
            connection = nil
            pendingDeviceName = nil
            if listener != nil {
                phase = .listening
            } else {
                phase = .idle
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
                        self.pendingDeviceName = nil
                        if self.listener != nil {
                            self.phase = .listening
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
            switch control {
            case .hello, .acceptRequest:
                if let deviceName, !deviceName.isEmpty {
                    pendingDeviceName = deviceName
                    if case .waitingAccept = phase {
                        phase = .waitingAccept(deviceName: deviceName)
                    }
                }
            case .ping:
                send(.control(.ping, deviceName: hostDisplayName))
            case .accepted, .rejected:
                break
            }
        case .input(let event):
            guard case .connected = phase else { return }
            injector.inject(event)
            onInputEvent?(event)
        }
    }

    private func send(_ message: WireMessage) {
        guard let connection, let data = try? WireCodec.encodeLine(message) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
}
