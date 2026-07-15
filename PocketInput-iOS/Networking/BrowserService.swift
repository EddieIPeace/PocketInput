import Foundation
import Network
import PocketInputKit

struct DiscoveredHost: Identifiable, Hashable {
    let id: String
    let name: String
    let endpoint: NWEndpoint
}

@MainActor
@Observable
final class BrowserService {
    private(set) var hosts: [DiscoveredHost] = []
    private(set) var isBrowsing = false
    private(set) var lastError: String?

    private var browser: NWBrowser?

    func start() {
        stop()
        let descriptor = NWBrowser.Descriptor.bonjour(
            type: ProtocolConstants.bonjourServiceType,
            domain: nil
        )
        let browser = NWBrowser(for: descriptor, using: .tcp)
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isBrowsing = true
                    self.lastError = nil
                case .failed(let error):
                    self.isBrowsing = false
                    self.lastError = error.localizedDescription
                case .cancelled:
                    self.isBrowsing = false
                default:
                    break
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.hosts = results.compactMap { result in
                    guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                    return DiscoveredHost(
                        id: "\(result.endpoint)",
                        name: name,
                        endpoint: result.endpoint
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
        isBrowsing = true
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
        hosts = []
    }
}
