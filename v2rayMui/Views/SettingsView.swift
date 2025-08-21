//
//  SettingsView.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @StateObject private var logManager = LogManager.shared
    @StateObject private var v2rayManager = V2RayManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    @State private var v2rayVersion: String = "正在获取..."
    
    var body: some View {
        Form {
            // 连接设置
            Section("连接设置") {
                Toggle("自动连接", isOn: Binding<Bool>(
                    get: { settingsManager.settings.autoConnect },
                    set: { newValue in
                        settingsManager.updateAutoConnect(newValue)
                    }
                ))
                .help("启动应用时自动连接到选中的配置")
            }
            
            Section("SOCKS本地代理设置") {
                HStack {
                    Text("SOCKS主机")
                    Spacer()
                    TextField("", text: Binding<String>(
                        get: { settingsManager.settings.socksHost },
                        set: { newValue in
                            settingsManager.updateSocksHost(newValue)
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                }
                .help("SOCKS5代理监听地址，默认为127.0.0.1")
                
                HStack {
                    Text("SOCKS端口")
                    Spacer()
                    TextField("", value: Binding<Int>(
                        get: { settingsManager.settings.socksLocalPort },
                        set: { newValue in
                            // 限制端口范围在1-65535之间
                            let validPort = max(1, min(65535, newValue))
                            settingsManager.updateSocksLocalPort(validPort)
                        }
                    ), format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                }
                .help("SOCKS5代理监听端口 (1-65535)")
                
                HStack {
                    Text("SOCKS UDP支持")
                    Spacer()
                    Toggle("", isOn: Binding<Bool>(
                        get: { settingsManager.settings.socksUdpEnabled },
                        set: { newValue in
                            settingsManager.updateSocksUdpEnabled(newValue)
                        }
                    ))
                }
                .help("启用SOCKS代理的UDP转发支持")
            }
            
            Section("HTTP本地代理设置") {
                HStack {
                    Text("HTTP主机")
                    Spacer()
                    TextField("", text: Binding<String>(
                        get: { settingsManager.settings.httpHost },
                        set: { newValue in
                            settingsManager.updateHttpHost(newValue)
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                }
                .help("HTTP代理监听地址，默认为127.0.0.1")
                
                HStack {
                    Text("HTTP端口")
                    Spacer()
                    TextField("", value: Binding<Int>(
                        get: { settingsManager.settings.httpPort },
                        set: { newValue in
                            // 限制端口范围在1-65535之间
                            let validPort = max(1, min(65535, newValue))
                            settingsManager.updateHttpPort(validPort)
                        }
                    ), format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                }
                .help("HTTP代理监听端口 (1-65535)")
            }
            
            // 应用设置
            Section("应用设置") {
                Toggle("开机启动", isOn: Binding<Bool>(
                    get: { settingsManager.settings.startAtLogin },
                    set: { newValue in
                        settingsManager.updateStartAtLogin(newValue)
                    }
                ))
                .help("系统启动时自动启动应用")
                
                Toggle("显示在Dock", isOn: Binding<Bool>(
                    get: { settingsManager.settings.showInDock },
                    set: { newValue in
                        settingsManager.updateShowInDock(newValue)
                    }
                ))
                .help("在Dock中显示应用图标")
            }
            
            // 高级设置
            Section("高级设置") {
                Picker("日志级别", selection: Binding<String>(
                    get: { settingsManager.settings.logLevel },
                    set: { newValue in
                        settingsManager.updateLogLevel(newValue)
                    }
                )) {
                    Text("Debug").tag("debug")
                    Text("Info").tag("info")
                    Text("Warning").tag("warning")
                    Text("Error").tag("error")
                    Text("None").tag("none")
                }
                .help("V2Ray核心日志输出级别")
                
                HStack {
                    Text("日志文件大小限制")
                    Spacer()
                    TextField("大小", value: Binding<Int>(
                        get: { settingsManager.settings.maxLogFileSizeMB },
                        set: { value in
                            let validValue = max(1, value) // 确保不小于最小值1MB
                            settingsManager.updateMaxLogFileSizeMB(validValue)
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    Text("MB")
                        .foregroundColor(.secondary)
                }
                .help("日志文件的最大大小，单位为MB，最小值为1MB")
                
                HStack(spacing: 12) {
                    Button("查看日志文件") {
                        openLogFile()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("清除日志") {
                        clearLogs()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // V2Ray核心
            Section("V2Ray核心") {
                HStack {
                    Text("核心状态")
                    Spacer()
                    Text(v2rayStatus)
                        .foregroundColor(v2rayStatusColor)
                        .font(.system(.body, design: .monospaced))
                }
                HStack {
                    Text("外置路径")
                    Spacer()
                    Text(externalV2rayPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Button(action: {
                        openExternalPathInFinder()
                    }) {
                        Image(systemName: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("在Finder中显示外置路径")
                }
                
                HStack {
                    Text("内置路径")
                    Spacer()
                    Text(v2rayPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if V2RayBinaryManager.shared.binaryPath != nil {
                        Button(action: {
                            openInFinder()
                        }) {
                            Image(systemName: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("在Finder中显示")
                    }
                }
                
                HStack {
                    Text("核心版本")
                    Spacer()
                    Text(v2rayVersion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .onAppear {
                            fetchV2RayVersion()
                        }
                }
                
                HStack {
                    Text("二进制状态")
                    Spacer()
                    Text(binaryStatus)
                        .font(.caption)
                        .foregroundColor(binaryStatusColor)
                }
                
                HStack(spacing: 12) {
                    Button("检查更新") {
                        checkV2RayUpdate()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("重新安装核心") {
                        reinstallV2Ray()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // 网络测试
            Section("网络测试") {
                HStack(spacing: 12) {
                    Button("测试连接") {
                        testConnection()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("测试延迟") {
                        testLatency()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("检查IP地址") {
                        checkIPAddress()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // 数据管理
            Section("数据管理") {
                // 设置文件路径
                HStack {
                    Text("设置文件")
                    Spacer()
                    Text(settingsManager.settingsFilePath ?? "未找到")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if settingsManager.settingsFilePath != nil {
                        Button(action: {
                            openSettingsInFinder()
                        }) {
                            Image(systemName: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("在Finder中显示settings.json")
                    }
                }
                
                HStack(spacing: 12) {
                    Button("导出配置") {
                        exportConfigs()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("导入配置") {
                        importConfigs()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("重置所有设置") {
                    resetAllSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            
            // 关于
            Section("关于") {
                HStack {
                    Text("应用版本")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
                
                HStack(spacing: 12) {
                    Link("GitHub项目", destination: URL(string: "https://github.com/XTLS/Xray-core")!)
                        .buttonStyle(.bordered)
                    
                    Link("官方网站", destination: URL(string: "https://www.v2ray.com")!)
                        .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }
    
    // MARK: - 计算属性
    
    private var v2rayStatus: String {
        switch v2rayManager.connectionStatus {
        case .connected:
            return "运行中"
        case .connecting:
            return "启动中"
        case .disconnected:
            return "未运行"
        case .error:
            return "错误"
        }
    }
    
    private var v2rayStatusColor: Color {
        switch v2rayManager.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var v2rayPath: String {
        if let path = V2RayBinaryManager.shared.binaryPath {
            return path
        }
        return "未找到"
    }
    
    private var externalV2rayPath: String {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        if let libraryPath = libraryPath {
            let bundleId = Bundle.main.bundleIdentifier ?? ""
            let externalPath = libraryPath.appendingPathComponent("Application Support/\(bundleId)/V2ray").path
            return externalPath
        }
        return "未找到"
    }
    
    private var binaryStatus: String {
        if V2RayBinaryManager.shared.binaryPath != nil {
            if V2RayBinaryManager.shared.isBinaryExecutable() {
                return "已就绪"
            } else {
                return "权限错误"
            }
        } else {
            return "未找到"
        }
    }
    
    private var binaryStatusColor: Color {
        if V2RayBinaryManager.shared.binaryPath != nil {
            if V2RayBinaryManager.shared.isBinaryExecutable() {
                return .green
            } else {
                return .orange
            }
        } else {
            return .red
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    // MARK: - 方法
    
    private func fetchV2RayVersion() {
        DispatchQueue.global(qos: .userInitiated).async {
            let version = V2RayBinaryManager.shared.getVersion() ?? "未知版本"
            DispatchQueue.main.async {
                self.v2rayVersion = version
            }
        }
    }
    
    private func openLogFile() {
        // 打开日志文件
        let logURL = getLogFileURL()
        NSWorkspace.shared.open(logURL)
    }
    
    private func clearLogs() {
        // 清除日志文件
        let logURL = getLogFileURL()
        try? FileManager.default.removeItem(at: logURL)
    }
    
    private func getLogFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirURL = appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "v2rayMui")
        let v2rayDirURL = appDirURL.appendingPathComponent("V2ray")
        return v2rayDirURL.appendingPathComponent("v2ray_logs.json")
    }
    
    private func checkV2RayUpdate() {
        // 检查V2Ray核心更新
        // 这里应该实现实际的更新检查逻辑
        print("检查V2Ray更新")
    }
    
    private func reinstallV2Ray() {
        // 重新安装V2Ray核心
        // 这里应该实现实际的安装逻辑
        print("重新安装V2Ray核心")
    }
    
    private func testConnection() {
        // 测试网络连接
        print("测试连接")
    }
    
    private func testLatency() {
        // 测试延迟
        print("测试延迟")
    }
    
    private func checkIPAddress() {
        // 检查IP地址
        print("检查IP地址")
    }
    
    private func exportConfigs() {
        // 导出配置
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "v2ray-configs.json"
        
        if panel.runModal() == .OK {
            // 导出配置到选择的文件
            print("导出配置到: \(panel.url?.path ?? "")")
        }
    }
    
    private func importConfigs() {
        // 导入配置
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            // 从选择的文件导入配置
            print("从文件导入配置: \(panel.url?.path ?? "")")
        }
    }
    
    private func resetAllSettings() {
        // 重置所有设置
        settingsManager.resetAllSettings()
        
        // 清除所有配置
        DispatchQueue.main.async {
            ConfigManager.shared.configs.removeAll()
            ConfigManager.shared.selectedConfig = nil
        }
    }
    
    private func openInFinder() {
        guard let binaryPath = V2RayBinaryManager.shared.binaryPath else {
            print("v2ray二进制文件路径不存在")
            return
        }
        
        let url = URL(fileURLWithPath: binaryPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func openExternalPathInFinder() {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        if let libraryPath = libraryPath {
            let externalURL = libraryPath.appendingPathComponent("Application Support/gg.v2rayMui/V2ray")
            
            // 如果目录不存在，先创建它
            if !FileManager.default.fileExists(atPath: externalURL.path) {
                try? FileManager.default.createDirectory(at: externalURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            NSWorkspace.shared.open(externalURL)
        }
    }
    
    private func openSettingsInFinder() {
        if let settingsPath = settingsManager.settingsFilePath {
            let url = URL(fileURLWithPath: settingsPath).deletingLastPathComponent()
            NSWorkspace.shared.open(url)
        }
    }
    
    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "settings.json"
        panel.title = "导出设置"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try settingsManager.exportSettings(to: url)
                print("设置导出成功: \(url.path)")
            } catch {
                print("导出设置失败: \(error)")
            }
        }
    }
    
    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "导入设置"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try settingsManager.importSettings(from: url)
                print("设置导入成功: \(url.path)")
            } catch {
                print("导入设置失败: \(error)")
            }
        }
    }
}

#Preview {
    SettingsView()
}