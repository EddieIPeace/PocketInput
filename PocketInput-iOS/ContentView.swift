import SwiftUI
import PocketInputKit

struct ContentView: View {
    @State private var browser = BrowserService()
    @State private var client = ControllerClient()

    var body: some View {
        NavigationStack {
            Group {
                switch client.phase {
                case .connected:
                    connectedView
                case .connecting, .waitingAccept:
                    connectingView
                case .rejected:
                    rejectedView
                case .failed(let message):
                    failedView(message)
                case .disconnected:
                    browserView
                }
            }
            .navigationTitle("PocketInput")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            browser.start()
        }
        .onDisappear {
            browser.stop()
            client.disconnect()
        }
    }

    private var browserView: some View {
        List {
            Section {
                if let error = browser.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                }
                if browser.hosts.isEmpty {
                    ContentUnavailableView(
                        "未发现 Mac",
                        systemImage: "laptopcomputer",
                        description: Text("请确认 Mac 端 PocketInput 已打开，且两台设备在同一 Wi‑Fi。")
                    )
                } else {
                    ForEach(browser.hosts) { host in
                        Button {
                            client.connect(to: host)
                        } label: {
                            Label(host.name, systemImage: "desktopcomputer")
                        }
                    }
                }
            } header: {
                Text(browser.isBrowsing ? "附近的 Mac" : "未在搜索")
            }
        }
        .refreshable {
            browser.start()
        }
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(client.phase == .waitingAccept ? "等待 Mac 接受连接…" : "正在连接…")
            if let name = client.remoteName {
                Text(name)
                    .foregroundStyle(.secondary)
            }
            Button("取消") {
                client.disconnect()
            }
        }
        .padding()
    }

    private var connectedView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已连接")
                        .font(.headline)
                    Text(client.remoteName ?? "Mac")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("断开") {
                    client.disconnect()
                }
            }
            .padding()

            TrackpadView(
                onMove: { dx, dy in
                    client.send(.move(dx: dx, dy: dy))
                },
                onLeftTap: {
                    client.send(.click(button: .left, phase: .tap))
                },
                onRightClick: {
                    client.send(.click(button: .right, phase: .tap))
                }
            )
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var rejectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("连接被拒绝")
            Button("返回") {
                client.disconnect()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("连接失败")
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("返回") {
                client.disconnect()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
