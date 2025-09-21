import Foundation
import AppKit
import SQLite3
import SystemConfiguration
import Security

struct AppSettingsRecord: Decodable {
    let httpHost: String?
    let httpPort: Int?
    let socksHost: String?
    let socksPort: Int?

    enum CodingKeys: String, CodingKey {
        case httpHost = "httpHost"
        case httpPort = "httpPort"
        case socksHost = "socksHost"
        case socksPort = "socksPort"
    }
}

final class SystemProxyManager {
    private static func scErrorString(_ code: Int32) -> String {
        let ptr = SCErrorString(code)
        return String(cString: ptr)
    }
    // MARK: - DB
    private static func settingsDBPath() -> String? {
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let bundleId = Bundle.main.bundleIdentifier ?? "v2rayMui"
            let dir = appSupport.appendingPathComponent(bundleId, isDirectory: true)
            return dir.appendingPathComponent("app.db").path
        } catch { return nil }
    }

    static func loadSettings() -> AppSettingsRecord? {
        guard let dbPath = settingsDBPath() else { return nil }
        var db: OpaquePointer? = nil
        defer { if db != nil { sqlite3_close(db) } }
        if sqlite3_open(dbPath, &db) != SQLITE_OK { return nil }
        let sql = "SELECT value FROM items WHERE type='settings' AND id='settings' LIMIT 1"
        var stmt: OpaquePointer? = nil
        defer { if stmt != nil { sqlite3_finalize(stmt) } }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK { return nil }
        if sqlite3_step(stmt) == SQLITE_ROW {
            if let cstr = sqlite3_column_text(stmt, 0) {
                let json = String(cString: cstr)
                if let data = json.data(using: .utf8) {
                    return try? JSONDecoder().decode(AppSettingsRecord.self, from: data)
                }
            }
        }
        return nil
    }

    // MARK: - Shell helpers
    private static func run(_ launchPath: String, _ args: [String]) -> (status: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do { try task.run() } catch { return (-1, error.localizedDescription) }
        task.waitUntilExit()
        let data = try? pipe.fileHandleForReading.readToEnd()
        let out = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return (task.terminationStatus, out.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func runAsAdmin(_ cmd: String) -> (status: Int32, output: String) {
        // cmd 已包含完整可执行与参数；为安全起见不要插入用户输入
        let script = "do shell script \"\(cmd.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        let res = run("/usr/bin/osascript", ["-e", script])
        return res
    }

    private static func shQuote(_ s: String) -> String { return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    // MARK: - Public API
    // MARK: - New approach: SystemConfiguration (with Authorization)
    private static func withAuthorizedPreferences(_ body: (SCPreferences) -> Bool) -> Bool {
        var auth: AuthorizationRef? = nil
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        let status = AuthorizationCreate(nil, nil, flags, &auth)
        if status != errAuthorizationSuccess { NSLog("[Proxy] AuthorizationCreate failed: \(status)"); return false }
        guard let authRef = auth else { return false }
        defer { AuthorizationFree(authRef, []) }
        guard let prefs = SCPreferencesCreateWithAuthorization(nil, "v2rayMui" as CFString, nil, authRef) else {
            NSLog("[Proxy] SCPreferencesCreateWithAuthorization failed")
            return false
        }
        let locked = SCPreferencesLock(prefs, true)
        if locked == false {
            let err = SCError()
            NSLog("[Proxy][SC] lock failed: \(err) \(scErrorString(err))")
        }
        let changed = body(prefs)
        var committed = true
        var applied = true
        if changed {
            committed = SCPreferencesCommitChanges(prefs)
            if committed == false {
                let err = SCError()
                NSLog("[Proxy][SC] commit failed: \(err) \(scErrorString(err))")
            }
            applied = SCPreferencesApplyChanges(prefs)
            if applied == false {
                let err = SCError()
                NSLog("[Proxy][SC] apply failed: \(err) \(scErrorString(err))")
            }
        }
        if locked { _ = SCPreferencesUnlock(prefs) }
        return changed && committed && applied
    }

    private static func foreachProxiesProtocol(prefs: SCPreferences, _ body: (SCNetworkProtocol, String) -> Bool) -> Bool {
        guard let set = SCNetworkSetCopyCurrent(prefs) else { NSLog("[Proxy] SCNetworkSetCopyCurrent nil"); return false }
        guard let services = SCNetworkSetCopyServices(set) as? [SCNetworkService] else { return false }
        var any = false
        for svc in services {
            guard let name = SCNetworkServiceGetName(svc) as String? else { continue }
            if let proto = SCNetworkServiceCopyProtocol(svc, kSCNetworkProtocolTypeProxies) {
                if body(proto, name) { any = true }
            }
        }
        return any
    }

    private static func setUsingSystemConfiguration(httpHost: String, httpPort: Int, socksHost: String, socksPort: Int) -> Bool {
        return withAuthorizedPreferences { prefs in
            let applied = foreachProxiesProtocol(prefs: prefs) { proto, name in
                var dict = (SCNetworkProtocolGetConfiguration(proto) as? [String: Any]) ?? [:]
                dict[kSCPropNetProxiesHTTPEnable as String] = 1
                dict[kSCPropNetProxiesHTTPProxy as String] = httpHost
                dict[kSCPropNetProxiesHTTPPort as String] = httpPort
                dict[kSCPropNetProxiesHTTPSEnable as String] = 1
                dict[kSCPropNetProxiesHTTPSProxy as String] = httpHost
                dict[kSCPropNetProxiesHTTPSPort as String] = httpPort
                dict[kSCPropNetProxiesSOCKSEnable as String] = 1
                dict[kSCPropNetProxiesSOCKSProxy as String] = socksHost
                dict[kSCPropNetProxiesSOCKSPort as String] = socksPort
                // 关闭自动代理/自动发现，确保手动代理生效
                dict[kSCPropNetProxiesProxyAutoConfigEnable as String] = 0
                dict[kSCPropNetProxiesProxyAutoDiscoveryEnable as String] = 0
                let ok = SCNetworkProtocolSetConfiguration(proto, dict as CFDictionary)
                NSLog("[Proxy][SC] set for %@ -> %d", name, ok)
                return ok
            }
            return applied
        }
    }

    private static func clearUsingSystemConfiguration() -> Bool {
        return withAuthorizedPreferences { prefs in
            let applied = foreachProxiesProtocol(prefs: prefs) { proto, name in
                var dict = (SCNetworkProtocolGetConfiguration(proto) as? [String: Any]) ?? [:]
                dict[kSCPropNetProxiesHTTPEnable as String] = 0
                dict[kSCPropNetProxiesHTTPSEnable as String] = 0
                dict[kSCPropNetProxiesSOCKSEnable as String] = 0
                dict[kSCPropNetProxiesProxyAutoConfigEnable as String] = 0
                dict[kSCPropNetProxiesProxyAutoDiscoveryEnable as String] = 0
                let ok = SCNetworkProtocolSetConfiguration(proto, dict as CFDictionary)
                NSLog("[Proxy][SC] clear for %@ -> %d", name, ok)
                return ok
            }
            return applied
        }
    }

    // MARK: - Dynamic Store immediate apply (best-effort)
    private static func applyToDynamicStore(httpHost: String, httpPort: Int, socksHost: String, socksPort: Int) {
        if let store = SCDynamicStoreCreate(nil, "v2rayMui" as CFString, nil, nil) {
            let key = "State:/Network/Global/Proxies" as CFString
            var dict = (SCDynamicStoreCopyValue(store, key) as? [String: Any]) ?? [:]
            dict[kSCPropNetProxiesHTTPEnable as String] = 1
            dict[kSCPropNetProxiesHTTPProxy as String] = httpHost
            dict[kSCPropNetProxiesHTTPPort as String] = httpPort
            dict[kSCPropNetProxiesHTTPSEnable as String] = 1
            dict[kSCPropNetProxiesHTTPSProxy as String] = httpHost
            dict[kSCPropNetProxiesHTTPSPort as String] = httpPort
            dict[kSCPropNetProxiesSOCKSEnable as String] = 1
            dict[kSCPropNetProxiesSOCKSProxy as String] = socksHost
            dict[kSCPropNetProxiesSOCKSPort as String] = socksPort
            dict[kSCPropNetProxiesProxyAutoConfigEnable as String] = 0
            dict[kSCPropNetProxiesProxyAutoDiscoveryEnable as String] = 0
            let ok = SCDynamicStoreSetValue(store, key, dict as CFDictionary)
            NSLog("[Proxy][DS] set global proxies -> %d", ok)
        }
    }

    private static func clearDynamicStore() {
        if let store = SCDynamicStoreCreate(nil, "v2rayMui" as CFString, nil, nil) {
            let key = "State:/Network/Global/Proxies" as CFString
            var dict = (SCDynamicStoreCopyValue(store, key) as? [String: Any]) ?? [:]
            dict[kSCPropNetProxiesHTTPEnable as String] = 0
            dict[kSCPropNetProxiesHTTPSEnable as String] = 0
            dict[kSCPropNetProxiesSOCKSEnable as String] = 0
            let ok = SCDynamicStoreSetValue(store, key, dict as CFDictionary)
            NSLog("[Proxy][DS] clear global proxies -> %d", ok)
        }
    }

    static func setSystemProxyFromDB() {
        guard let s = loadSettings(), let httpHost = s.httpHost, let httpPort = s.httpPort, let socksHost = s.socksHost, let socksPort = s.socksPort else {
            NSLog("[Proxy] settings missing; skip set proxy")
            return
        }
        let ok = setUsingSystemConfiguration(httpHost: httpHost, httpPort: httpPort, socksHost: socksHost, socksPort: socksPort)
        if ok {
            NSLog("[Proxy][SC] applied")
            applyToDynamicStore(httpHost: httpHost, httpPort: httpPort, socksHost: socksHost, socksPort: socksPort)
        } else {
            NSLog("[Proxy][SC] apply failed")
        }
    }

    static func clearSystemProxy() {
        let ok = clearUsingSystemConfiguration()
        if ok {
            NSLog("[Proxy][SC] cleared")
            clearDynamicStore()
        } else {
            NSLog("[Proxy][SC] clear failed")
        }
    }
}


