//
//  ProxyManager.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import Foundation
import SystemConfiguration
import Security

/// 系统代理管理器（基于 networksetup）
class ProxyManager {
    static let shared = ProxyManager()
    private init() {}

    private let networksetupPath = "/usr/sbin/networksetup"
    private var authorizationRef: AuthorizationRef?

    /// 获取（并缓存）系统偏好写入授权。仅在首次需要时提示一次，后续复用。
    private func getAuthorization() -> AuthorizationRef? {
        if let auth = authorizationRef { return auth }
        var authRef: AuthorizationRef?
        var rightName = "system.preferences.network"
        var item = rightName.withCString { ptr -> AuthorizationItem in
            AuthorizationItem(name: ptr, valueLength: 0, value: nil, flags: 0)
        }
        var rights = AuthorizationRights(count: 1, items: &item)
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        let status = AuthorizationCreate(&rights, nil, flags, &authRef)
        if status == errAuthorizationSuccess, let auth = authRef {
            authorizationRef = auth
            return auth
        } else {
            LogManager.shared.addLog("获取系统网络偏好授权失败: \(status)", level: .warning, source: .app)
            return nil
        }
    }

    /// 启用系统 HTTP/HTTPS/SOCKS 代理
    func enableProxies() {
        let settings = SettingsManager.shared.settings
        let httpHost = settings.httpHost
        let httpPort = settings.httpPort
        let socksHost = settings.socksHost
        let socksPort = settings.socksLocalPort

        if enableProxiesUsingSystemConfiguration(httpHost: httpHost, httpPort: httpPort, socksHost: socksHost, socksPort: socksPort) {
            LogManager.shared.addLog("已通过SystemConfiguration启用系统代理", level: .info, source: .app)
            return
        }

        // 回退方案：使用 networksetup
        let services = listAllNetworkServices()
        guard !services.isEmpty else {
            LogManager.shared.addLog("未找到任何网络服务，无法设置系统代理（SC与networksetup均不可用）", level: .warning, source: .app)
            return
        }
        for service in services {
            _ = runNetworkSetup(["-setwebproxy", service, httpHost, String(httpPort)])
            _ = runNetworkSetup(["-setsecurewebproxy", service, httpHost, String(httpPort)])
            _ = runNetworkSetup(["-setwebproxystate", service, "on"])
            _ = runNetworkSetup(["-setsecurewebproxystate", service, "on"])
            _ = runNetworkSetup(["-setsocksfirewallproxy", service, socksHost, String(socksPort)])
            _ = runNetworkSetup(["-setsocksfirewallproxystate", service, "on"])
            LogManager.shared.addLog("已为网络服务 \(service) 启用 HTTP/HTTPS/SOCKS 代理 (fallback)", level: .info, source: .app)
        }
    }

    /// 关闭系统 HTTP/HTTPS/SOCKS 代理
    func disableProxies() {
        if disableProxiesUsingSystemConfiguration() {
            LogManager.shared.addLog("已通过SystemConfiguration关闭系统代理", level: .info, source: .app)
            return
        }

        let services = listAllNetworkServices()
        guard !services.isEmpty else { return }
        for service in services {
            _ = runNetworkSetup(["-setwebproxystate", service, "off"])
            _ = runNetworkSetup(["-setsecurewebproxystate", service, "off"])
            _ = runNetworkSetup(["-setsocksfirewallproxystate", service, "off"])
            LogManager.shared.addLog("已为网络服务 \(service) 关闭 HTTP/HTTPS/SOCKS 代理 (fallback)", level: .info, source: .app)
        }
    }

    // MARK: - Helpers

    // 优先通过 SystemConfiguration 修改代理（更兼容沙盒）
    private func enableProxiesUsingSystemConfiguration(httpHost: String, httpPort: Int, socksHost: String, socksPort: Int) -> Bool {
        // 使用授权以尽量只弹一次密码（本次会话内复用）
        guard let prefs = (getAuthorization().flatMap { SCPreferencesCreateWithAuthorization(nil, "v2rayMui" as CFString, nil, $0) }) ?? SCPreferencesCreate(nil, "v2rayMui" as CFString, nil),
              let currentSet = SCNetworkSetCopyCurrent(prefs) else {
            return false
        }

        let targetServices = getTargetServices(prefs: prefs, currentSet: currentSet)
        if targetServices.isEmpty { return false }

        var changed = false
        for service in targetServices {
            guard let proxies = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeProxies) else { continue }
            let current = (SCNetworkProtocolGetConfiguration(proxies) as? [String: Any]) ?? [:]

            // 期望配置
            var desired: [String: Any] = current
            desired[kSCPropNetProxiesHTTPEnable as String] = 1
            desired[kSCPropNetProxiesHTTPProxy as String] = httpHost
            desired[kSCPropNetProxiesHTTPPort as String] = httpPort
            desired[kSCPropNetProxiesHTTPSEnable as String] = 1
            desired[kSCPropNetProxiesHTTPSProxy as String] = httpHost
            desired[kSCPropNetProxiesHTTPSPort as String] = httpPort
            desired[kSCPropNetProxiesSOCKSEnable as String] = 1
            desired[kSCPropNetProxiesSOCKSProxy as String] = socksHost
            desired[kSCPropNetProxiesSOCKSPort as String] = socksPort

            // 比较关键字段，避免重复写入引发授权提示
            let keys = [
                kSCPropNetProxiesHTTPEnable as String,
                kSCPropNetProxiesHTTPProxy as String,
                kSCPropNetProxiesHTTPPort as String,
                kSCPropNetProxiesHTTPSEnable as String,
                kSCPropNetProxiesHTTPSProxy as String,
                kSCPropNetProxiesHTTPSPort as String,
                kSCPropNetProxiesSOCKSEnable as String,
                kSCPropNetProxiesSOCKSProxy as String,
                kSCPropNetProxiesSOCKSPort as String
            ]
            var differs = false
            for key in keys {
                let a = (current[key] as AnyObject?)?.description
                let b = (desired[key] as AnyObject?)?.description
                if a != b { differs = true; break }
            }
            if !differs { continue }

            if SCNetworkProtocolSetConfiguration(proxies, desired as CFDictionary) {
                changed = true
            }
        }

        if changed {
            let committed = SCPreferencesCommitChanges(prefs)
            let applied = SCPreferencesApplyChanges(prefs)
            if !committed || !applied {
                LogManager.shared.addLog("SystemConfiguration 提交/应用更改失败 (committed=\(committed), applied=\(applied))", level: .error, source: .app)
            }
            return committed && applied
        }
        return false
    }

    private func disableProxiesUsingSystemConfiguration() -> Bool {
        guard let prefs = (getAuthorization().flatMap { SCPreferencesCreateWithAuthorization(nil, "v2rayMui" as CFString, nil, $0) }) ?? SCPreferencesCreate(nil, "v2rayMui" as CFString, nil),
              let currentSet = SCNetworkSetCopyCurrent(prefs) else {
            return false
        }

        let targetServices = getTargetServices(prefs: prefs, currentSet: currentSet)
        if targetServices.isEmpty { return false }

        var changed = false
        for service in targetServices {
            guard let proxies = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeProxies) else { continue }
            let current = (SCNetworkProtocolGetConfiguration(proxies) as? [String: Any]) ?? [:]
            var desired = current
            desired[kSCPropNetProxiesHTTPEnable as String] = 0
            desired[kSCPropNetProxiesHTTPSEnable as String] = 0
            desired[kSCPropNetProxiesSOCKSEnable as String] = 0

            // 若当前已禁用，则跳过
            let alreadyDisabled = ((current[kSCPropNetProxiesHTTPEnable as String] as? Int) ?? 0) == 0
                && ((current[kSCPropNetProxiesHTTPSEnable as String] as? Int) ?? 0) == 0
                && ((current[kSCPropNetProxiesSOCKSEnable as String] as? Int) ?? 0) == 0
            if alreadyDisabled { continue }

            if SCNetworkProtocolSetConfiguration(proxies, desired as CFDictionary) {
                changed = true
            }
        }

        if changed {
            let committed = SCPreferencesCommitChanges(prefs)
            let applied = SCPreferencesApplyChanges(prefs)
            return committed && applied
        }
        return false
    }

    private func getTargetServices(prefs: SCPreferences, currentSet: SCNetworkSet) -> [SCNetworkService] {
        guard let services = SCNetworkSetCopyServices(currentSet) as? [SCNetworkService] else { return [] }

        // 优先主服务
        if let primaryServiceID = getPrimaryServiceID(),
           let primary = services.first(where: { SCNetworkServiceGetServiceID($0) as String? == primaryServiceID }) {
            return [primary]
        }
        return services
    }

    private func getPrimaryServiceID() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "v2rayMui" as CFString, nil, nil),
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let primary = dict["PrimaryService"] as? String else {
            return nil
        }
        return primary
    }

    /// 列出所有可用网络服务（过滤掉带 * 的禁用项和第一行标题）
    private func listAllNetworkServices() -> [String] {
        guard let output = runNetworkSetup(["-listallnetworkservices"]) else { return [] }
        let lines = output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard lines.count > 1 else { return [] }
        return lines
            .dropFirst() // 第一行是注释/标题
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
    }

    /// 运行 networksetup 命令并返回标准输出
    @discardableResult
    private func runNetworkSetup(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: networksetupPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            LogManager.shared.addLog("执行 networksetup 失败: \(error.localizedDescription)", level: .error, source: .app)
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        if let err = String(data: errData, encoding: .utf8), !err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            LogManager.shared.addLog("networksetup 错误: \(err.trimmingCharacters(in: .whitespacesAndNewlines))", level: .warning, source: .app)
        }
        return String(data: data, encoding: .utf8)
    }
}


