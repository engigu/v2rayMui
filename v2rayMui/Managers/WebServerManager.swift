//
//  WebServerManager.swift
//  v2rayMui
//
//  Created by Assistant on 2025/9/02.
//

import Foundation
import AppKit

/// 管理本地 Go Web 服务进程（用于承载 shancn-vue 前端和后端 API）
class WebServerManager: ObservableObject {
    static let shared = WebServerManager()

    private var process: Process?
    private var stdout: Pipe?
    private var stderr: Pipe?
    private var isStarting = false

    private init() {}

    /// 服务器监听地址
    var baseURL: URL {
        let host = SettingsManager.shared.settings.webHost
        let port = SettingsManager.shared.settings.webPort
        return URL(string: "http://\(host):\(port)")!
    }

    /// 启动 WebServer 二进制；若未找到则提示构建
    func startIfNeeded() {
        guard process == nil, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        guard let binaryURL = locateBinary() else {
            ToastManager.shared.show("未找到Web服务，请先运行 scripts/build_webserver.sh", style: .warning)
            return
        }

        let host = SettingsManager.shared.settings.webHost
        let port = SettingsManager.shared.settings.webPort

        let p = Process()
        p.executableURL = binaryURL
        p.arguments = ["--host", host, "--port", String(port)]

        let out = Pipe(); let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        self.stdout = out
        self.stderr = err

        out.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let s = String(data: data, encoding: .utf8), !s.isEmpty {
                LogManager.shared.addLog("[web] " + s.trimmingCharacters(in: .whitespacesAndNewlines), level: .debug, source: .app)
            }
        }
        err.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let s = String(data: data, encoding: .utf8), !s.isEmpty {
                LogManager.shared.addLog("[web:err] " + s.trimmingCharacters(in: .whitespacesAndNewlines), level: .warning, source: .app)
            }
        }

        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                LogManager.shared.addLog("Web服务已退出(\(proc.terminationStatus))", level: .info, source: .app)
                self?.cleanup()
            }
        }

        do {
            try p.run()
            self.process = p
            LogManager.shared.addLog("Web服务已启动: \(baseURL.absoluteString)", level: .info, source: .app)
        } catch {
            LogManager.shared.addLog("启动Web服务失败: \(error.localizedDescription)", level: .error, source: .app)
            cleanup()
        }
    }

    /// 关闭 WebServer
    func stop() {
        guard let p = process else { return }
        p.terminate()
        cleanup()
    }

    /// 在默认浏览器打开控制台
    func openDashboard() {
        NSWorkspace.shared.open(baseURL)
    }

    // MARK: - Helpers

    private func cleanup() {
        stdout?.fileHandleForReading.readabilityHandler = nil
        stderr?.fileHandleForReading.readabilityHandler = nil
        stdout = nil
        stderr = nil
        process = nil
    }

    private func locateBinary() -> URL? {
        // 期望路径：App Bundle Resources/webserver/webserver
        guard let bundleURL = Bundle.main.resourceURL else { return nil }
        let candidate = bundleURL.appendingPathComponent("webserver").appendingPathComponent("webserver")
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
        return nil
    }
}


