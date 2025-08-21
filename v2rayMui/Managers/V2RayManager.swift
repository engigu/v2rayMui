//
//  V2RayManager.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import Foundation
import Combine
import AppKit

// MARK: - V2Ray连接管理器
class V2RayManager: ObservableObject {
    static let shared = V2RayManager()
    
    @Published var connectionStatus: V2RayConnectionStatus = .disconnected
    @Published var currentConfig: V2RayConfig?
    @Published var isAutoConnect: Bool = false
    
    private var v2rayProcess: Process?
    private var configFileURL: URL?
    private let fileManager = FileManager.default
    
    private init() {
        setupConfigDirectory()
        // 初始化v2ray二进制文件
        _ = V2RayBinaryManager.shared.initializeBinary()
        // 开始日志记录
        LogManager.shared.startLogging()
        
        // 添加应用终止通知监听以确保清理资源
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, 
                                               object: nil, 
                                               queue: .main) { [weak self] _ in
            self?.applicationWillTerminate()
        }
    }
    
    deinit {
        disconnect()
        // 清理所有资源
        cleanupResources()
        
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 应用终止时的清理操作
    private func applicationWillTerminate() {
        disconnect()
    }
    
    /// 清理资源
    private func cleanupResources() {
        v2rayProcess = nil
        configFileURL = nil
    }
    
    // MARK: - 连接管理
    
    /// 连接到V2Ray服务器
    func connect(with config: V2RayConfig) {
        guard connectionStatus != .connecting else { return }
        
        connectionStatus = .connecting
        currentConfig = config
        
        LogManager.shared.addLog("开始连接到服务器: \(config.serverAddress):\(config.serverPort)", level: .info, source: .app)
        
        do {
            // 确保配置目录已设置
            setupConfigDirectory()
            
            // 生成配置文件
            try generateConfigFile(from: config)
            
            // 启动V2Ray进程
            try startV2RayProcess()
            
            // 模拟连接过程（实际应用中需要检查进程状态）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.v2rayProcess?.isRunning == true {
                    self.connectionStatus = .connected
                    LogManager.shared.addLog("连接成功", level: .info, source: .app)
                    // 启用系统代理
                    ProxyManager.shared.enableProxies()
                } else {
                    self.connectionStatus = .error("连接失败")
                    LogManager.shared.addLog("连接失败：进程未运行", level: .error, source: .app)
                }
            }
            
        } catch {
            connectionStatus = .error(error.localizedDescription)
            LogManager.shared.addLog("连接失败: \(error.localizedDescription)", level: .error, source: .app)
        }
    }
    
    /// 断开连接
    func disconnect() {
        LogManager.shared.addLog("断开连接", level: .info, source: .app)
        // // 先关闭系统代理
        // ProxyManager.shared.disableProxies()
        stopV2RayProcess()
        connectionStatus = .disconnected
        currentConfig = nil
        // 清理所有资源
        cleanupResources()
    }
    
    /// 重新连接
    func reconnect() {
        guard let config = currentConfig else { return }
        let configToReconnect = config // 保存配置引用
        disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 重新设置配置目录，因为disconnect时被清空了
            self.setupConfigDirectory()
            self.connect(with: configToReconnect)
        }
    }
    
    // MARK: - V2Ray进程管理
    
    /// 启动V2Ray进程
    private func startV2RayProcess() throws {
        guard let configFileURL = configFileURL else {
            throw V2RayError.configFileNotFound
        }
        
        // 检查v2ray可执行文件是否存在
        let v2rayPath = getV2RayExecutablePath()
        guard fileManager.fileExists(atPath: v2rayPath) else {
            throw V2RayError.executableNotFound
        }
        
        v2rayProcess = Process()
        v2rayProcess?.executableURL = URL(fileURLWithPath: v2rayPath)
        v2rayProcess?.arguments = ["-config", configFileURL.path]
        
        // 设置输出重定向并处理日志
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        v2rayProcess?.standardOutput = outputPipe
        v2rayProcess?.standardError = errorPipe
        
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        // 监听输出（使用弱引用避免循环引用）
        outputHandle.readabilityHandler = { [weak self] handle in
            guard self != nil else { return }
            let data = handle.availableData
            if !data.isEmpty {
                LogManager.shared.handleV2RayOutput(data)
            }
        }
        
        // 监听错误输出（使用弱引用避免循环引用）
        errorHandle.readabilityHandler = { [weak self] handle in
            guard self != nil else { return }
            let data = handle.availableData
            if !data.isEmpty {
                LogManager.shared.handleV2RayOutput(data)
            }
        }
        
        // 进程终止时的处理
        v2rayProcess?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                LogManager.shared.addLog("V2Ray进程已终止，退出码: \(process.terminationStatus)", level: .info, source: .v2ray)
                
                // 若进程异常退出且当前显示为已连接，则回退状态并关闭系统代理
                if let strongSelf = self, strongSelf.connectionStatus.isConnected {
                    ProxyManager.shared.disableProxies()
                    strongSelf.connectionStatus = .disconnected
                    strongSelf.currentConfig = nil
                }
            }
            
            // 清理文件句柄
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil
            
            // 关闭文件句柄
            try? outputHandle.close()
            try? errorHandle.close()
            
            DispatchQueue.main.async {
                self?.v2rayProcess = nil
            }
        }
        
        LogManager.shared.addLog("启动V2Ray进程: \(v2rayPath)", level: .info, source: .app)
        // LogManager.shared.addLog("使用配置文件: \(configFileURL.path)", level: .info, source: .app)
        LogManager.shared.addLog("进程参数: \(v2rayProcess?.arguments?.joined(separator: " ") ?? "无")", level: .info, source: .app)
        
        // 检查配置文件是否存在
        if fileManager.fileExists(atPath: configFileURL.path) {
            LogManager.shared.addLog("配置文件存在，大小: \(String(describing: try? fileManager.attributesOfItem(atPath: configFileURL.path)[.size] ?? 0)) bytes", level: .info, source: .app)
        } else {
            LogManager.shared.addLog("警告：配置文件不存在！", level: .warning, source: .app)
        }
        
        try v2rayProcess?.run()
    }
    
    /// 停止V2Ray进程
    private func stopV2RayProcess() {
        guard let process = v2rayProcess else { return }
        
        // 清理文件句柄
        if let outputPipe = process.standardOutput as? Pipe {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            try? outputPipe.fileHandleForReading.close()
        }
        
        if let errorPipe = process.standardError as? Pipe {
            errorPipe.fileHandleForReading.readabilityHandler = nil
            try? errorPipe.fileHandleForReading.close()
        }
        
        // 终止进程
        process.terminate()
        
        // 等待进程结束，但设置超时
        DispatchQueue.global(qos: .background).async { [weak process] in
            guard let process = process else { return }
            let semaphore = DispatchSemaphore(value: 0)
            
            DispatchQueue.global(qos: .background).async {
                process.waitUntilExit()
                semaphore.signal()
            }
            
            // 等待最多3秒
            if semaphore.wait(timeout: .now() + 3) == .timedOut {
                // 强制杀死进程
                kill(process.processIdentifier, SIGKILL)
            }
        }
        
        v2rayProcess = nil
    }
    
    /// 获取V2Ray可执行文件路径
    private func getV2RayExecutablePath() -> String {
        // 优先使用应用包内的v2ray二进制文件
        if let bundlePath = V2RayBinaryManager.shared.binaryPath {
            return bundlePath
        }
        
        // 如果应用包内没有，则检查系统路径
        let systemPaths = [
            "/usr/local/bin/v2ray",
            "/opt/homebrew/bin/v2ray",
            "/usr/bin/v2ray"
        ]
        
        for path in systemPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        
        // 默认返回系统路径
        return "/usr/local/bin/v2ray"
    }
    
    // MARK: - 配置文件管理
    
    /// 设置配置目录
    private func setupConfigDirectory() {
        // 使用Application Support目录，这个目录具有读写权限
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            LogManager.shared.addLog("无法获取Application Support目录", level: .error, source: .app)
            return
        }
        
        let appDirURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "v2rayMui")
        let v2rayDirURL = appDirURL.appendingPathComponent("V2ray")
        configFileURL = v2rayDirURL.appendingPathComponent("config.json")
        
        LogManager.shared.addLog("配置文件路径设置为: \(configFileURL?.path ?? "未知")", level: .info, source: .app)
        
        // 创建应用目录和V2ray目录（如果不存在）
        do {
            // 设置目录权限属性，确保可读可写
            let attributes: [FileAttributeKey: Any] = [
                .posixPermissions: 0o755  // 所有者读写执行，组和其他用户读执行
            ]
            
            // 创建应用目录
            try fileManager.createDirectory(at: appDirURL, withIntermediateDirectories: true, attributes: attributes)
            
            // 创建V2ray目录
            try fileManager.createDirectory(at: v2rayDirURL, withIntermediateDirectories: true, attributes: attributes)
            
            LogManager.shared.addLog("V2ray目录创建成功: \(v2rayDirURL.path)", level: .info, source: .app)
        } catch {
            LogManager.shared.addLog("创建V2ray目录失败: \(error.localizedDescription)", level: .error, source: .app)
        }
        
        // 检查V2ray目录权限
        let v2rayPath = v2rayDirURL.path
        if fileManager.isWritableFile(atPath: v2rayPath) {
            LogManager.shared.addLog("V2ray目录可写", level: .info, source: .app)
        } else {
            LogManager.shared.addLog("警告：V2ray目录不可写，可能会导致配置文件保存失败", level: .warning, source: .app)
            
            // 尝试修改权限
            do {
                let attributes: [FileAttributeKey: Any] = [
                    .posixPermissions: 0o755
                ]
                try fileManager.setAttributes(attributes, ofItemAtPath: v2rayPath)
                LogManager.shared.addLog("已尝试修改V2ray目录权限", level: .info, source: .app)
            } catch {
                LogManager.shared.addLog("修改V2ray目录权限失败: \(error.localizedDescription)", level: .error, source: .app)
            }
        }
    }
    
    /// 生成V2Ray配置文件
    func generateConfigFile(from config: V2RayConfig) throws {
        guard let configFileURL = configFileURL else {
            throw V2RayError.configFileNotFound
        }
        
        LogManager.shared.addLog("生成配置文件到: \(configFileURL.path)", level: .info, source: .app)
        
        let v2rayConfig = generateV2RayJSON(from: config)
        let jsonData = try JSONSerialization.data(withJSONObject: v2rayConfig, options: [.sortedKeys, .prettyPrinted])
        
        // 记录配置文件内容（仅用于调试）
        if let configString = String(data: jsonData, encoding: .utf8) {
            LogManager.shared.addLog("配置文件内容:\n\(configString)", level: .debug, source: .app)
        }
        
        try jsonData.write(to: configFileURL)
        LogManager.shared.addLog("配置文件写入成功，大小: \(jsonData.count) bytes", level: .info, source: .app)
    }
    
    /// 生成V2Ray JSON配置
    private func generateV2RayJSON(from config: V2RayConfig) -> [String: Any] {
        // 从SettingsManager获取设置
        let settingsManager = SettingsManager.shared
        let logLevel = settingsManager.settings.logLevel
        let routingMode = settingsManager.settings.routingMode
        
        // 生成代理outbound配置
        let proxyOutbound = generateProxyOutbound(from: config)
        
        // 直连outbound
        let directOutbound: [String: Any] = [
            "tag": "direct",
            "protocol": "freedom",
            "settings": [:]
        ]
        
        // 阻止outbound
        let blockOutbound: [String: Any] = [
            "tag": "block",
            "protocol": "blackhole",
            "settings": [:]
        ]
        
        // 根据路由模式生成routing配置
        var routing: [String: Any] = [:]
        var outbounds: [[String: Any]] = []
        
        switch routingMode {
        case .global:
            // 全局代理模式：所有流量都走代理
            outbounds = [proxyOutbound, directOutbound, blockOutbound]
            routing = buildRouting(domainStrategy: settingsManager.settings.domainStrategy,
                                   proxyRules: settingsManager.settings.customProxyRules,
                                   directRules: settingsManager.settings.customDirectRules,
                                   blockRules: settingsManager.settings.customBlockRules,
                                   base: .global)
            
        case .direct:
            // 直连模式：所有流量都直连
            outbounds = [directOutbound, proxyOutbound, blockOutbound]
            routing = buildRouting(domainStrategy: settingsManager.settings.domainStrategy,
                                   proxyRules: settingsManager.settings.customProxyRules,
                                   directRules: settingsManager.settings.customDirectRules,
                                   blockRules: settingsManager.settings.customBlockRules,
                                   base: .direct)
            
        case .passcn:
            // PAC模式：绕过中国大陆地址，其他流量走代理
            outbounds = [proxyOutbound, directOutbound, blockOutbound]
            routing = buildRouting(domainStrategy: settingsManager.settings.domainStrategy,
                                   proxyRules: settingsManager.settings.customProxyRules,
                                   directRules: settingsManager.settings.customDirectRules,
                                   blockRules: settingsManager.settings.customBlockRules,
                                   base: .passcn)
        }
        
        var v2rayConfig: [String: Any] = [
            "log": [
                "level": logLevel
            ],
            "inbounds": [
                [
                    "listen": SettingsManager.shared.settings.socksHost,
                    "port": SettingsManager.shared.settings.socksLocalPort,
                    "protocol": "socks",
                    "settings": [
                        "auth": "noauth",
                        "udp": SettingsManager.shared.settings.socksUdpEnabled
                    ]
                ],
                [
                    "listen": SettingsManager.shared.settings.httpHost,
                    "port": SettingsManager.shared.settings.httpPort,
                    "protocol": "http",
                    "settings": [     "auth": "noauth"]
                ]
            ],
            "outbounds": outbounds
        ]
        
        // 只有在非直连模式下才添加routing配置
        if routingMode != .direct {
            v2rayConfig["routing"] = routing
        }
        
        return v2rayConfig
    }

    private enum BaseRouting: String { case global, direct, passcn }

    private func buildRouting(domainStrategy: String,
                              proxyRules: String,
                              directRules: String,
                              blockRules: String,
                              base: BaseRouting) -> [String: Any] {
        var rules: [[String: Any]] = []
        // 基础规则
        switch base {
        case .global:
            // 仅私有IP直连，其他默认走代理
            rules.append([
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "direct"
            ])
        case .direct:
            // 无默认规则
            break
        case .passcn:
            // 私有IP/CN直连，广告阻止
            rules.append(contentsOf: [
                ["type": "field", "ip": ["geoip:private"], "outboundTag": "direct"],
                ["type": "field", "ip": ["geoip:cn"], "outboundTag": "direct"],
                ["type": "field", "domain": ["geosite:cn"], "outboundTag": "direct"],
                ["type": "field", "domain": ["geosite:category-ads-all"], "outboundTag": "block"]
            ])
        }
        // 自定义规则（多行，按空白分割）
        func parseLines(_ text: String) -> [String] {
            text.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        let proxyList = parseLines(proxyRules)
        if !proxyList.isEmpty {
            rules.append(["type": "field", "domain": proxyList, "outboundTag": "proxy"])
        }
        let directList = parseLines(directRules)
        if !directList.isEmpty {
            rules.append(["type": "field", "domain": directList, "outboundTag": "direct"])
        }
        let blockList = parseLines(blockRules)
        if !blockList.isEmpty {
            rules.append(["type": "field", "domain": blockList, "outboundTag": "block"])
        }
        return [
            "domainStrategy": domainStrategy,
            "rules": rules
        ]
    }
    
    /// 根据协议类型生成代理outbound配置
    private func generateProxyOutbound(from config: V2RayConfig) -> [String: Any] {
        switch config.protocolType {
        case "vmess":
            return generateVMessOutbound(from: config)
        case "vless":
            return generateVLessOutbound(from: config)
        case "trojan":
            return generateTrojanOutbound(from: config)
        case "shadowsocks":
            return generateShadowsocksOutbound(from: config)
        default:
            return generateVMessOutbound(from: config) // 默认使用VMess
        }
    }
    
    /// 生成VMess outbound配置
    private func generateVMessOutbound(from config: V2RayConfig) -> [String: Any] {
        let streamSettings = generateStreamSettings(from: config)
        
        return [
            "tag": "proxy",
            "protocol": "vmess",
            "settings": [
                "vnext": [[
                    "address": config.serverAddress,
                    "port": config.serverPort,
                    "users": [[
                        "id": config.userId,
                        "alterId": config.alterId,
                        "security": config.security
                    ]]
                ]]
            ],
            "streamSettings": streamSettings
        ]
    }
    
    /// 生成VLESS outbound配置
    private func generateVLessOutbound(from config: V2RayConfig) -> [String: Any] {
        let streamSettings = generateStreamSettings(from: config)
        
        return [
            "tag": "proxy",
            "protocol": "vless",
            "settings": [
                "vnext": [[
                    "address": config.serverAddress,
                    "port": config.serverPort,
                    "users": [[
                        "id": config.userId,
                        "encryption": "none"
                    ]]
                ]]
            ],
            "streamSettings": streamSettings
        ]
    }
    
    /// 生成Trojan outbound配置
    private func generateTrojanOutbound(from config: V2RayConfig) -> [String: Any] {
        let streamSettings = generateStreamSettings(from: config)
        
        return [
            "tag": "proxy",
            "protocol": "trojan",
            "settings": [
                "servers": [[
                    "address": config.serverAddress,
                    "port": config.serverPort,
                    "password": config.password ?? ""
                ]]
            ],
            "streamSettings": streamSettings
        ]
    }
    
    /// 生成Shadowsocks outbound配置
    private func generateShadowsocksOutbound(from config: V2RayConfig) -> [String: Any] {
        return [
            "tag": "proxy",
            "protocol": "shadowsocks",
            "settings": [
                "servers": [[
                    "address": config.serverAddress,
                    "port": config.serverPort,
                    "method": config.method ?? "aes-256-gcm",
                    "password": config.password ?? ""
                ]]
            ]
        ]
    }
    
    /// 生成流设置配置
    private func generateStreamSettings(from config: V2RayConfig) -> [String: Any] {
        var streamSettings: [String: Any] = [
            "network": config.network
        ]
        
        // 根据网络类型添加特定设置
        switch config.network {
        case "ws":
            if let path = config.path, !path.isEmpty {
                streamSettings["wsSettings"] = ["path": path]
            }
        case "h2":
            if let path = config.path, !path.isEmpty {
                streamSettings["httpSettings"] = ["path": path]
            }
        case "grpc":
            if let path = config.path, !path.isEmpty {
                streamSettings["grpcSettings"] = ["serviceName": path]
            }
        case "xhttp":
            // xHTTP: 始终输出 xhttpSettings，包含 mode 与 path（path 默认t）
            let modeValue: String = (config.xhttpMode ?? "")
            let pathValue: String = {
                if let p = config.path, !p.isEmpty { return p }
                return ""
            }()
            streamSettings["xhttpSettings"] = [
                "mode": modeValue,
                "path": pathValue
            ]
        default:
            break
        }
        
        // TLS/XTLS/REALITY设置
        if let tls = config.tls, !tls.isEmpty {
            streamSettings["security"] = tls
            
            switch tls {
            case "tls":
                // 期望格式：
                // "tlsSettings": { "fingerprint": "", "alpn": [], "serverName": "", "allowInsecure": true }
                var tlsSettings: [String: Any] = [
                    "fingerprint": config.fingerprint ?? "",
                    "alpn": [],
                    "serverName": config.host ?? "",
                    "allowInsecure": config.allowInsecure ?? false
                ]
                streamSettings["tlsSettings"] = tlsSettings
                
            case "xtls":
                var xtlsSettings: [String: Any] = [:]
                if let host = config.host, !host.isEmpty {
                    xtlsSettings["serverName"] = host
                }
                streamSettings["xtlsSettings"] = xtlsSettings
                
            case "reality":
                var realitySettings: [String: Any] = [:]
                if let host = config.host, !host.isEmpty {
                    realitySettings["serverName"] = host
                }
                if let publicKey = config.publicKey, !publicKey.isEmpty {
                    realitySettings["publicKey"] = publicKey
                }
                if let shortId = config.shortId, !shortId.isEmpty {
                    realitySettings["shortId"] = shortId
                }
                if let spiderX = config.spiderX, !spiderX.isEmpty {
                    realitySettings["spiderX"] = spiderX
                }
                if let fingerprint = config.fingerprint, !fingerprint.isEmpty {
                    realitySettings["fingerprint"] = fingerprint
                }
                streamSettings["realitySettings"] = realitySettings
                
            default:
                break
            }
        }
        
        return streamSettings
    }
}

// MARK: - V2Ray错误类型
enum V2RayError: LocalizedError {
    case configFileNotFound
    case executableNotFound
    case connectionFailed
    case invalidConfig
    
    var errorDescription: String? {
        switch self {
        case .configFileNotFound:
            return "配置文件未找到"
        case .executableNotFound:
            return "V2Ray可执行文件未找到，请确保已安装V2Ray"
        case .connectionFailed:
            return "连接失败"
        case .invalidConfig:
            return "配置无效"
        }
    }
}
