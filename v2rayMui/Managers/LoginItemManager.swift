//
//  LoginItemManager.swift
//  v2rayMui
//
//  Best-effort Login Item via LaunchAgent (fallback if helper not present)
//

import Foundation
import AppKit

class LoginItemManager {
    static let shared = LoginItemManager()
    private init() {}

    private let fileManager = FileManager.default

    private var agentPlistURL: URL? {
        guard let home = fileManager.homeDirectoryForCurrentUser as URL? else { return nil }
        let launchAgents = home.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let baseId = Bundle.main.bundleIdentifier ?? "gg.v2rayMui"
        let bundleId = AppEnvironment.isRunningInXcode ? baseId + ".dev" : baseId
        return launchAgents.appendingPathComponent("\(bundleId).plist")
    }

    /// Enable/disable start at login. Returns true when operation appears successful.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            return installAndLoad()
        } else {
            return unload()
        }
    }

    /// Ensure the LaunchAgent matches the current app location and is loaded (when setting is on)
    func ensureInstalledIfNeeded() {
        guard SettingsManager.shared.settings.startAtLogin else { return }
        _ = installAndLoad()
    }

    private func installAndLoad() -> Bool {
        guard let plistURL = agentPlistURL else { return false }
        do {
            try ensureParentDir(plistURL)
            let data = try buildPlist()
            try data.write(to: plistURL)
            LogManager.shared.addLog("写入启动项: \(plistURL.path)", level: .info, source: .app)
        } catch {
            LogManager.shared.addLog("写入启动项失败: \(error.localizedDescription)", level: .error, source: .app)
            return false
        }

        // Try modern bootstrapping
        _ = runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        if runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path]) {
            LogManager.shared.addLog("已启用开机自启 (launchctl bootstrap)", level: .info, source: .app)
            return true
        }
        // Fallback (legacy)
        if runLaunchctl(["load", "-w", plistURL.path]) {
            LogManager.shared.addLog("已启用开机自启 (launchctl load)", level: .info, source: .app)
            return true
        }

        LogManager.shared.addLog("启用开机自启失败：可能因沙盒权限限制，需手动允许或使用带Helper的方案", level: .warning, source: .app)
        return false
    }

    private func unload() -> Bool {
        guard let plistURL = agentPlistURL else { return false }
        var ok = false
        if runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path]) { ok = true }
        if runLaunchctl(["unload", "-w", plistURL.path]) { ok = true }
        if ok {
            LogManager.shared.addLog("已关闭开机自启", level: .info, source: .app)
        } else {
            LogManager.shared.addLog("关闭开机自启失败（可能已未加载）", level: .warning, source: .app)
        }
        return ok
    }

    private func ensureParentDir(_ url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func buildPlist() throws -> Data {
        let bundlePath = Bundle.main.bundlePath
        let execName = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? "v2rayMui"
        let execPath = (bundlePath as NSString).appendingPathComponent("Contents/MacOS/\(execName)")
        var dict: [String: Any] = [:]
        let baseId = Bundle.main.bundleIdentifier ?? "gg.v2rayMui"
        let label = AppEnvironment.isRunningInXcode ? baseId + ".dev" : baseId
        dict["Label"] = label
        dict["RunAtLoad"] = true
        dict["KeepAlive"] = false
        dict["ProcessType"] = "Interactive"
        dict["Program"] = execPath
        dict["ProgramArguments"] = [execPath]
        dict["StandardOutPath"] = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Logs/v2rayMui.launchd.out.log")
        dict["StandardErrorPath"] = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Logs/v2rayMui.launchd.err.log")
        return try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    @discardableResult
    private func runLaunchctl(_ args: [String]) -> Bool {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = args
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            LogManager.shared.addLog("调用 launchctl 失败: \(error.localizedDescription)", level: .warning, source: .app)
            return false
        }
    }
}

//
//  LoginItemManager.swift
//  v2rayMui
//
//  管理开机自启（用户态 LaunchAgent）
//

import Foundation
import AppKit

// (Older alternative implementation removed to avoid duplicate declarations)

