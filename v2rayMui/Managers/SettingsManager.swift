//
//  SettingsManager.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import Foundation
import SwiftUI

/// 路由模式枚举
enum RoutingMode: String, CaseIterable, Codable, Hashable {
    case global = "global"      // 全局代理
    case passcn = "passcn"           // PassCN模式
    case direct = "direct"     // 直连模式
    
    var displayName: String {
        switch self {
        case .global:
            return "全局代理"
        case .passcn:
            return "绕过大陆"
        case .direct:
            return "直连模式"
        }
    }
}

/// 设置数据模型
struct AppSettings: Codable {
    var autoConnect: Bool = false
    var startAtLogin: Bool = false
    var showInDock: Bool = true
    var socksLocalPort: Int = 1088
    var socksHost: String = "127.0.0.1"
    var httpPort: Int = 1087
    var httpHost: String = "127.0.0.1"
    var socksUdpEnabled: Bool = true
    var logLevel: String = "warning"
    var maxLogFileSizeMB: Int = 10
    var routingMode: RoutingMode = .global
    var passcnFileURL: String? = nil  // PassCN文件路径（可选）
    // 路由高级设置
    var domainStrategy: String = "IPIfNonMatch" // 可选: AsIs, IPIfNonMatch, IPOnDemand
    var customProxyRules: String = ""   // 多行，域名或IP/CIDR，每行一条
    var customDirectRules: String = ""
    var customBlockRules: String = ""
    
    // 可以添加更多设置项
    var lastUpdated: Date = Date()
}

/// 设置管理器
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings = AppSettings()
    
    private let fileManager = FileManager.default
    private var settingsFileURL: URL?
    
    private init() {
        setupSettingsDirectory()
        loadSettings()
        
        // 添加应用终止通知监听以确保保存设置
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, 
                                               object: nil, 
                                               queue: .main) { [weak self] _ in
            self?.applicationWillTerminate()
        }
    }
    
    deinit {
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 应用终止时的清理操作
    private func applicationWillTerminate() {
        saveSettings()
    }
    
    // MARK: - 文件管理
    
    /// 设置设置文件目录
    private func setupSettingsDirectory() {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            LogManager.shared.addLog("无法获取Application Support目录", level: .error, source: .app)
            return
        }
        
        let appDirURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "v2rayMui")
        settingsFileURL = appDirURL.appendingPathComponent("settings.json")
        
        // 创建目录（如果不存在）
        do {
            try fileManager.createDirectory(at: appDirURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            LogManager.shared.addLog("创建设置目录失败: \(error)", level: .error, source: .app)
        }
    }
    
    // MARK: - 设置管理
    
    /// 从settings.json加载设置
    func loadSettings() {
        guard let settingsFileURL = settingsFileURL else { return }
        
        do {
            let data = try Data(contentsOf: settingsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedSettings = try decoder.decode(AppSettings.self, from: data)
            
            DispatchQueue.main.async {
                self.settings = loadedSettings
            }
            
            // 同步到UserDefaults（保持兼容性）
            syncToUserDefaults()
            
            LogManager.shared.addLog("设置加载成功: \(settingsFileURL.path)", level: .info, source: .app)
        } catch {
            LogManager.shared.addLog("加载设置失败: \(error)", level: .error, source: .app)
            // 如果加载失败，从UserDefaults加载现有设置
            loadFromUserDefaults()
            saveSettings() // 保存到JSON文件
        }
    }
    
    /// 保存设置到settings.json
    func saveSettings() {
        guard let settingsFileURL = settingsFileURL else { return }
        
        settings.lastUpdated = Date()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys // 使用sortedKeys优化JSON输出
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(settings)
            try data.write(to: settingsFileURL)
            
            // 同步到UserDefaults（保持兼容性）
            syncToUserDefaults()
            
            LogManager.shared.addLog("设置保存成功: \(settingsFileURL.path)", level: .info, source: .app)
        } catch {
            LogManager.shared.addLog("保存设置失败: \(error)", level: .error, source: .app)
        }
    }
    
    /// 从UserDefaults加载现有设置
    private func loadFromUserDefaults() {
        let userDefaults = UserDefaults.standard
        
        settings.autoConnect = userDefaults.bool(forKey: "autoConnect")
        settings.startAtLogin = userDefaults.bool(forKey: "startAtLogin")
        settings.showInDock = userDefaults.object(forKey: "showInDock") as? Bool ?? true
        settings.socksLocalPort = userDefaults.object(forKey: "localPort") as? Int ?? 1080
        settings.logLevel = userDefaults.string(forKey: "logLevel") ?? "warning"
        
        // 加载路由模式
        if let routingModeString = userDefaults.string(forKey: "routingMode"),
           let routingMode = RoutingMode(rawValue: routingModeString) {
            settings.routingMode = routingMode
        }
        settings.domainStrategy = userDefaults.string(forKey: "domainStrategy") ?? settings.domainStrategy
        settings.customProxyRules = userDefaults.string(forKey: "customProxyRules") ?? settings.customProxyRules
        settings.customDirectRules = userDefaults.string(forKey: "customDirectRules") ?? settings.customDirectRules
        settings.customBlockRules = userDefaults.string(forKey: "customBlockRules") ?? settings.customBlockRules
        
        // 加载PassCN文件URL
        settings.passcnFileURL = userDefaults.string(forKey: "passcnFileURL")
        
        // 从LogManager获取日志文件大小设置
        settings.maxLogFileSizeMB = LogManager.shared.maxLogFileSizeMB
    }
    
    /// 同步设置到UserDefaults（保持兼容性）
    private func syncToUserDefaults() {
        let userDefaults = UserDefaults.standard
        
        userDefaults.set(settings.autoConnect, forKey: "autoConnect")
        userDefaults.set(settings.startAtLogin, forKey: "startAtLogin")
        userDefaults.set(settings.showInDock, forKey: "showInDock")
        userDefaults.set(settings.socksLocalPort, forKey: "localPort")
        userDefaults.set(settings.logLevel, forKey: "logLevel")
        userDefaults.set(settings.routingMode.rawValue, forKey: "routingMode")
        userDefaults.set(settings.passcnFileURL, forKey: "passcnFileURL")
        userDefaults.set(settings.domainStrategy, forKey: "domainStrategy")
        userDefaults.set(settings.customProxyRules, forKey: "customProxyRules")
        userDefaults.set(settings.customDirectRules, forKey: "customDirectRules")
        userDefaults.set(settings.customBlockRules, forKey: "customBlockRules")
        
        // 同步到LogManager
        LogManager.shared.maxLogFileSizeMB = settings.maxLogFileSizeMB
    }
    
    // MARK: - 设置更新方法
    
    func updateAutoConnect(_ value: Bool) {
        objectWillChange.send()
        settings.autoConnect = value
        saveSettings()
    }
    
    func updateStartAtLogin(_ value: Bool) {
        objectWillChange.send()
        settings.startAtLogin = value
        saveSettings()
    }
    
    func updateShowInDock(_ value: Bool) {
        objectWillChange.send()
        settings.showInDock = value
        saveSettings()
    }
    
    func updateSocksLocalPort(_ value: Int) {
        objectWillChange.send()
        settings.socksLocalPort = value
        saveSettings()
    }
    
    func updateRoutingMode(_ value: RoutingMode) {
        objectWillChange.send()
        settings.routingMode = value
        saveSettings()
    }

    func updateDomainStrategy(_ value: String) {
        objectWillChange.send()
        settings.domainStrategy = value
        saveSettings()
    }

    func updateCustomProxyRules(_ value: String) {
        objectWillChange.send()
        settings.customProxyRules = value
        saveSettings()
    }

    func updateCustomDirectRules(_ value: String) {
        objectWillChange.send()
        settings.customDirectRules = value
        saveSettings()
    }

    func updateCustomBlockRules(_ value: String) {
        objectWillChange.send()
        settings.customBlockRules = value
        saveSettings()
    }
    
    func updatePasscnFileURL(_ value: String?) {
        objectWillChange.send()
        settings.passcnFileURL = value
        saveSettings()
        
        // 如果当前是PassCN模式且V2Ray正在运行，重新连接以应用新的PassCN设置
        let v2rayManager = V2RayManager.shared
        if settings.routingMode == .passcn && v2rayManager.connectionStatus == .connected {
            v2rayManager.reconnect()
        }
    }
    
//    func updateSocksLocalPort(_ value: Int) {
//        objectWillChange.send()
//        settings.socksLocalPort = value
//        saveSettings()
//    }
    
    func updateLogLevel(_ value: String) {
        objectWillChange.send()
        settings.logLevel = value
        saveSettings()
    }
    
    func updateMaxLogFileSizeMB(_ value: Int) {
        objectWillChange.send()
        settings.maxLogFileSizeMB = value
        saveSettings()
    }
    
    func updateHttpPort(_ value: Int) {
        objectWillChange.send()
        settings.httpPort = value
        saveSettings()
    }
    
    func updateSocksUdpEnabled(_ value: Bool) {
        objectWillChange.send()
        settings.socksUdpEnabled = value
        saveSettings()
    }
    
    func updateSocksHost(_ value: String) {
        objectWillChange.send()
        settings.socksHost = value
        saveSettings()
    }
    
    func updateHttpHost(_ value: String) {
        objectWillChange.send()
        settings.httpHost = value
        saveSettings()
    }
    
    // MARK: - 工具方法
    
    /// 重置所有设置
    func resetAllSettings() {
        settings = AppSettings()
        saveSettings()
    }
    
    /// 导出设置
    func exportSettings(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys // 使用sortedKeys优化JSON输出
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(settings)
        try data.write(to: url)
    }
    
    /// 导入设置
    func importSettings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let importedSettings = try JSONDecoder().decode(AppSettings.self, from: data)
        
        DispatchQueue.main.async {
            self.settings = importedSettings
            self.saveSettings()
        }
    }
    
    /// 获取设置文件路径
    var settingsFilePath: String? {
        return settingsFileURL?.path
    }
}