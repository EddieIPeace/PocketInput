import AppKit
import AppKit
import SwiftUI

struct ContentView: View {
    @State private var server = HostServer()
    @State private var isAccessibilityTrusted = AccessibilityGate.isTrusted

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            accessibilityBanner
            statusCard
            actions
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            isAccessibilityTrusted = AccessibilityGate.ensureTrusted(prompt: true)
            server.start()
        }
        .onDisappear {
            server.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isAccessibilityTrusted = AccessibilityGate.isTrusted
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PocketInput")
                .font(.largeTitle.bold())
            Text("本机：\(server.hostDisplayName)")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var accessibilityBanner: some View {
        if !isAccessibilityTrusted {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 8) {
                    Text("需要辅助功能权限")
                        .font(.headline)
                    Text("未授权时无法注入鼠标事件。请在系统设置中允许 PocketInput-macOS。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("打开系统设置") {
                        AccessibilityGate.openSystemSettings()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("状态")
                .font(.headline)
            Text(statusText)
                .font(.title3)
            if case .waitingAccept(let name) = server.phase {
                Text("来自：\(name)")
                    .foregroundStyle(.secondary)
            }
            if case .connected(let name) = server.phase {
                Text("已连接：\(name)")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var actions: some View {
        switch server.phase {
        case .waitingAccept:
            HStack {
                Button("接受") {
                    server.acceptPending()
                }
                .buttonStyle(.borderedProminent)
                Button("拒绝") {
                    server.rejectPending()
                }
            }
        case .connected:
            Button("断开连接") {
                server.disconnectClient()
            }
        case .idle, .failed:
            Button("开始监听") {
                server.start()
            }
            .buttonStyle(.borderedProminent)
        case .listening:
            Button("停止监听") {
                server.stop()
            }
        }
    }

    private var statusText: String {
        switch server.phase {
        case .idle:
            return "未监听"
        case .listening:
            return "等待 iPhone 连接…"
        case .waitingAccept:
            return "有设备请求连接"
        case .connected:
            return "已连接，可接收输入"
        case .failed(let message):
            return "错误：\(message)"
        }
    }
}

#Preview {
    ContentView()
}
