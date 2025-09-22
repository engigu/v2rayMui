import SwiftUI
import AppKit

struct StatusMenuView: View {
    @StateObject private var vm = StatusViewModel()
    @State private var openBinError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
       
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .foregroundColor(vm.goServerRunning ? .green : .red)
                    .font(.system(size: 8))
                    .frame(width: 14, alignment: .center)
                Text(vm.goServerRunning ? "Go服务：运行中" : "Go服务：未运行")
                    .font(.subheadline)
            }

     HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .foregroundColor(vm.connected ? .green : .red)
                    .font(.system(size: 8))
                    .frame(width: 14, alignment: .center)
                Text("xray服务: " + (vm.connected ? "已连接" : "未连接") )
                    .font(.subheadline)
                Spacer(minLength: 8)
                if vm.isLoading {
                    ProgressView().controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .foregroundColor(.secondary)
                    .frame(width: 14, alignment: .center)
                if let name = vm.selectedName {
                    Text("当前服务器：\(name)")
                        .font(.subheadline)
                } else {
                    Text("未选择服务器")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button(vm.connected ? "断开" : "连接") {
                    Task { await vm.toggleConnection() }
                }
                .keyboardShortcut(.defaultAction)
                Button("打开配置页面") {
                    openConfigPage()
                }
                Button("打开二进制目录") {
                    openResourcesFolder()
                }
                Button("打开数据目录") {
                    openSupportFolder()
                }
                Button("刷新") {
                    Task { await vm.fetchStatus() }
                }
            }

            Divider()

            Button("退出应用", role: .destructive) {
                // 优先请求 Go 服务优雅退出
                let mgr = GoServerManager()
                mgr.requestGoServerExit(wait: 0.6)
                NSApp.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 180)
        .alert("无法打开目录", isPresented: Binding(get: { openBinError != nil }, set: { v in if !v { openBinError = nil } })) {
            Button("确定", role: .cancel) { openBinError = nil }
        } message: {
            Text(openBinError ?? "")
        }
    }

    private func openResourcesFolder() {
        if let nestedResources = Bundle.main.url(forResource: "Resources", withExtension: nil) {
            NSWorkspace.shared.open(nestedResources)
            return
        }
        if let resourcesRoot = Bundle.main.resourceURL {
            NSWorkspace.shared.open(resourcesRoot)
            return
        }
        openBinError = "未找到包内资源目录"
    }

    private func openSupportFolder() {
        let fm = FileManager.default
        do {
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let bundleId = Bundle.main.bundleIdentifier ?? "v2rayMui"
            let dir = appSupport.appendingPathComponent(bundleId, isDirectory: true)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            NSWorkspace.shared.open(dir)
        } catch {
            openBinError = error.localizedDescription
        }
    }

    private func openConfigPage() {
        if let url = URL(string: "http://\(AppConfig.serverAddress):\(AppConfig.serverPort)/") {
            NSWorkspace.shared.open(url)
        } else {
            openBinError = "无法构建配置页面地址"
        }
    }
}

#Preview {
    StatusMenuView()
}


