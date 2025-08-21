//
//  ConfigManager.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import Foundation
import Combine
#if canImport(AppKit)
import AppKit
#endif

// MARK: - 配置管理器
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var configs: [V2RayConfig] = []
    @Published var selectedConfig: V2RayConfig?
    
    private let userDefaults = UserDefaults.standard
    private let configsKey = "V2RayConfigs"
    private let selectedConfigKey = "SelectedV2RayConfig"
    private let linesFileName = "lines_config.json"
    
    private init() {
        loadConfigs()
    }
    
    // MARK: - 配置管理方法
    
    /// 添加新配置
    func addConfig(_ config: V2RayConfig) {
        var newConfig = config
        if configs.contains(where: { $0.id == newConfig.id }) {
            newConfig.id = UUID()
        }
        configs.append(newConfig)
        saveConfigs()
    }
    
    /// 更新配置
    func updateConfig(_ config: V2RayConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
            if selectedConfig?.id == config.id {
                selectedConfig = config
            }
            saveConfigs()
        }
    }
    
    /// 删除配置
    func deleteConfig(_ config: V2RayConfig) {
        configs.removeAll { $0.id == config.id }
        if selectedConfig?.id == config.id {
            selectedConfig = configs.first
        }
        saveConfigs()
    }
    
    /// 选择配置并更新 config.json
    func selectConfig(_ config: V2RayConfig?) {
        selectedConfig = config
        saveSelectedConfig()
        
        // 当选择配置时，立即更新 V2Ray 的 config.json
        if let selectedConfig = config {
            updateV2RayConfig(with: selectedConfig)
        }

        // 广播选择变化，便于自动连接逻辑响应
        NotificationCenter.default.post(name: .selectedConfigChanged, object: config)
    }
    
    /// 更新 V2Ray 的 config.json 文件
    private func updateV2RayConfig(with config: V2RayConfig) {
        do {
            try V2RayManager.shared.generateConfigFile(from: config)
            LogManager.shared.addLog("已更新 V2Ray config.json 为配置: \(config.name)", level: .info, source: .app)
        } catch {
            LogManager.shared.addLog("更新 V2Ray config.json 失败: \(error)", level: .error, source: .app)
        }
    }
    
    /// 获取配置by ID
    func getConfig(by id: UUID) -> V2RayConfig? {
        return configs.first { $0.id == id }
    }
    
    /// 复制配置
    func duplicateConfig(_ config: V2RayConfig) {
        var newConfig = config
        newConfig.name = "\(config.name) 副本"
        newConfig.id = UUID()
        addConfig(newConfig)
    }

    // MARK: - 导入
    /// 从剪贴板导入配置，支持 vless:// vmess:// trojan:// shadowsocks:// 或 JSON 文本
    func importFromClipboard() {
        #if canImport(AppKit)
        guard let pasteboardString = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !pasteboardString.isEmpty else {
            ToastManager.shared.show("剪贴板为空或无文本", style: .warning)
            return
        }
        #else
        ToastManager.shared.show("当前平台不支持剪贴板导入", style: .warning)
        return
        #endif

        if importFromURLScheme(pasteboardString) { return }
        if importFromJSON(pasteboardString) { return }
        ToastManager.shared.show("未识别的剪贴板内容", style: .warning)
    }

    /// 解析 URL scheme 类型的分享链接
    private func importFromURLScheme(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.hasPrefix("vmess://") {
            return importVMessLink(text)
        } else if lower.hasPrefix("vless://") {
            return importVLessLink(text)
        } else if lower.hasPrefix("trojan://") {
            return importTrojanLink(text)
        } else if lower.hasPrefix("ss://") || lower.hasPrefix("shadowsocks://") {
            return importShadowsocksLink(text)
        }
        return false
    }

    /// 尝试将纯 JSON 文本导入为配置（期望是 V2Ray 出站配置的一部分）
    private func importFromJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        do {
            // 兼容使用我们的 V2RayConfig 结构
            let decoder = JSONDecoder()
            if let cfg = try? decoder.decode(V2RayConfig.self, from: data) {
                var cfg2 = cfg
                if cfg2.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000") || configs.contains(where: { $0.id == cfg2.id }) {
                    cfg2.id = UUID()
                }
                addConfig(cfg2)
                ToastManager.shared.show("已从JSON导入: \(cfg2.name)", style: .success)
                return true
            }
        }
        return false
    }

    // MARK: - 各协议导入解析（最小可用实现）
    private func importVMessLink(_ raw: String) -> Bool {
        // vmess 常见为 base64 的 JSON
        let prefix = "vmess://"
        let rest = String(raw.dropFirst(prefix.count))
        let decodedString = rest.removingPercentEncoding ?? rest
        guard let data = Data(base64Encoded: decodedString) ?? decodedString.data(using: .utf8) else { return false }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        var cfg = V2RayConfig()
        cfg.protocolType = "vmess"
        cfg.name = (obj["ps"] as? String) ?? "vmess"
        cfg.serverAddress = (obj["add"] as? String) ?? ""
        cfg.serverPort = Int((obj["port"] as? String) ?? "443") ?? 443
        cfg.userId = (obj["id"] as? String) ?? ""
        cfg.alterId = Int((obj["aid"] as? String) ?? "0") ?? 0
        cfg.security = (obj["scy"] as? String) ?? "auto"
        cfg.network = (obj["net"] as? String) ?? "tcp"
        if cfg.network == "http" { cfg.network = "xhttp" }
        // 预设默认 xhttp path 如果存在自定义语义
        cfg.path = (obj["path"] as? String)
        cfg.host = (obj["host"] as? String)
        cfg.tls = ((obj["tls"] as? String).flatMap { $0.isEmpty ? nil : $0 })
        addConfig(cfg)
        ToastManager.shared.show("已导入 vmess: \(cfg.name)", style: .success)
        return true
    }

    private func importVLessLink(_ raw: String) -> Bool {
        // vless://<uuid>@host:port?encryption=none&security=tls&type=ws&path=/xxx#name
        guard let url = URL(string: raw) else { return false }
        var cfg = V2RayConfig()
        cfg.protocolType = "vless"
        cfg.name = url.fragment?.removingPercentEncoding ?? "vless"
        cfg.serverAddress = url.host ?? ""
        cfg.serverPort = url.port ?? 443
        cfg.userId = url.user ?? ""
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        let map = Dictionary(uniqueKeysWithValues: (q ?? []).map { ($0.name, $0.value ?? "") })
        cfg.network = map["type"] ?? "tcp"
        if cfg.network == "http" { cfg.network = "xhttp" }
        cfg.path = map["path"]
        cfg.host = map["sni"] ?? map["host"]
        cfg.tls = map["security"].flatMap { $0.isEmpty ? nil : $0 }
        addConfig(cfg)
        ToastManager.shared.show("已导入 vless: \(cfg.name)", style: .success)
        return true
    }

    private func importTrojanLink(_ raw: String) -> Bool {
        // trojan://password@host:port?security=tls#name
        guard let url = URL(string: raw) else { return false }
        var cfg = V2RayConfig()
        cfg.protocolType = "trojan"
        cfg.name = url.fragment?.removingPercentEncoding ?? "trojan"
        cfg.serverAddress = url.host ?? ""
        cfg.serverPort = url.port ?? 443
        cfg.password = url.user
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        let map = Dictionary(uniqueKeysWithValues: (q ?? []).map { ($0.name, $0.value ?? "") })
        cfg.tls = map["security"].flatMap { $0.isEmpty ? nil : $0 }
        addConfig(cfg)
        ToastManager.shared.show("已导入 trojan: \(cfg.name)", style: .success)
        return true
    }

    private func importShadowsocksLink(_ raw: String) -> Bool {
        // ss://method:password@host:port#name 或 base64 格式
        let lower = raw.lowercased()
        var work = raw
        if lower.hasPrefix("shadowsocks://") { work = "ss://" + raw.dropFirst("shadowsocks://".count) }
        guard let url = URL(string: work) else { return false }
        var cfg = V2RayConfig()
        cfg.protocolType = "shadowsocks"
        cfg.name = url.fragment?.removingPercentEncoding ?? "shadowsocks"
        cfg.serverAddress = url.host ?? ""
        cfg.serverPort = url.port ?? 8388
        let userInfo = url.user ?? ""
        if userInfo.contains(":") {
            let parts = userInfo.split(separator: ":", maxSplits: 1).map(String.init)
            cfg.method = parts.first
            cfg.password = parts.count > 1 ? parts[1] : nil
        }
        addConfig(cfg)
        ToastManager.shared.show("已导入 shadowsocks: \(cfg.name)", style: .success)
        return true
    }
    
    // MARK: - 数据持久化
    
    /// 保存配置到UserDefaults
    private func saveConfigs() {
        ensureUniqueConfigIds()
        do {
            let data = try JSONEncoder().encode(configs)
            userDefaults.set(data, forKey: configsKey)
        } catch {
            print("保存配置失败: \(error)")
        }

        // 同步保存到 lines_config.json（与 settings.json 同目录）
        saveLinesConfigs()
    }
    
    /// 从UserDefaults加载配置
    private func loadConfigs() {
        guard let data = userDefaults.data(forKey: configsKey) else {
            // 如果没有保存的配置，创建一个示例配置
            createSampleConfig()
            return
        }
        
        do {
            configs = try JSONDecoder().decode([V2RayConfig].self, from: data)
            ensureUniqueConfigIds()
            saveConfigs() // 将修正后的ID回写存储
            loadSelectedConfig()
        } catch {
            print("加载配置失败: \(error)")
            createSampleConfig()
        }
    }

    /// 确保configs数组中的ID唯一
    private func ensureUniqueConfigIds() {
        var seen = Set<UUID>()
        for index in configs.indices {
            var currentId = configs[index].id
            if seen.contains(currentId) {
                // 生成新的不重复的UUID
                var newId = UUID()
                while seen.contains(newId) {
                    newId = UUID()
                }
                configs[index].id = newId
                currentId = newId
            }
            seen.insert(currentId)
        }
    }

    // MARK: - 将所有配置保存为 lines_config.json
    /// 获取与 settings.json 同目录的路径
    private func getSettingsDirectoryURL() -> URL? {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        var appDirURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "v2rayMui")
        if AppEnvironment.isRunningInXcode {
            appDirURL.appendPathComponent("dev")
        }
        return appDirURL
    }

    /// 保存所有配置到 lines_config.json，格式为 [{ id, line, created }]
    private func saveLinesConfigs() {
        struct LinesConfigItem: Codable {
            let id: UUID
            let line: V2RayConfig
            let created: Date
        }

        let items: [LinesConfigItem] = configs.map { cfg in
            LinesConfigItem(id: cfg.id, line: cfg, created: Date())
        }

        guard let dirURL = getSettingsDirectoryURL() else { return }
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("创建设置目录失败: \(error)")
        }

        let fileURL = dirURL.appendingPathComponent(linesFileName)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: fileURL)
        } catch {
            print("保存lines_config.json失败: \(error)")
        }
    }
    
    /// 保存选中的配置
    private func saveSelectedConfig() {
        if let selectedConfig = selectedConfig {
            userDefaults.set(selectedConfig.id.uuidString, forKey: selectedConfigKey)
        } else {
            userDefaults.removeObject(forKey: selectedConfigKey)
        }
    }
    
    /// 加载选中的配置
    private func loadSelectedConfig() {
        guard let selectedIdString = userDefaults.string(forKey: selectedConfigKey),
              let selectedId = UUID(uuidString: selectedIdString) else {
            selectedConfig = configs.first
            return
        }
        
        selectedConfig = configs.first { $0.id == selectedId } ?? configs.first
    }
    
    /// 创建示例配置
    private func createSampleConfig() {
        let sampleConfig = V2RayConfig(
            name: "示例配置",
            serverAddress: "example.com",
            serverPort: 443,
            userId: "12345678-1234-1234-1234-123456789abc",
            alterId: 0,
            security: "auto",
            network: "tcp",
            tls: "tls"
        )
        configs = [sampleConfig]
        selectedConfig = sampleConfig
        saveConfigs()
        saveSelectedConfig()
    }
    
    // MARK: - 配置验证
    
    /// 验证配置是否有效
    func validateConfig(_ config: V2RayConfig) -> [String] {
        var errors: [String] = []
        
        // 基本验证
        if config.name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("配置名称不能为空")
        }
        
        if config.serverAddress.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("服务器地址不能为空")
        }
        
        if config.serverPort < 1 || config.serverPort > 65535 {
            errors.append("端口号必须在1-65535之间")
        }
        
        // 根据协议类型进行特定验证
        switch config.protocolType {
        case "vmess", "vless":
            if config.userId.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append("用户ID不能为空")
            } else if UUID(uuidString: config.userId) == nil {
                errors.append("用户ID格式不正确，请输入有效的UUID")
            }
            
        case "trojan":
            if let password = config.password {
                if password.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("Trojan密码不能为空")
                }
            } else {
                errors.append("Trojan密码不能为空")
            }
            
        case "shadowsocks":
            if let password = config.password {
                if password.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("Shadowsocks密码不能为空")
                }
            } else {
                errors.append("Shadowsocks密码不能为空")
            }
            
            if let method = config.method {
                if method.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("Shadowsocks加密方法不能为空")
                }
            } else {
                errors.append("Shadowsocks加密方法不能为空")
            }
            
        default:
            errors.append("不支持的协议类型")
        }
        
        // REALITY 特定验证
        if config.tls == "reality" {
            if let publicKey = config.publicKey, publicKey.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append("REALITY公钥不能为空")
            }
            if config.publicKey == nil {
                errors.append("REALITY公钥不能为空")
            }
        }
        
        return errors
    }
    
    /// 检查配置名称是否重复
    func isConfigNameDuplicate(_ name: String, excludingId: UUID? = nil) -> Bool {
        return configs.contains { config in
            config.name == name && config.id != excludingId
        }
    }
}

extension Notification.Name {
    static let selectedConfigChanged = Notification.Name("selectedConfigChanged")
}