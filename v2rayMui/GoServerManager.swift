import Foundation
import AppKit
import Darwin

final class GoServerManager {
    private var process: Process?

    // MARK: - Diagnostics
    private func debugLog(_ message: String) {
        NSLog("[GoServerManager][Diag] %@", message)
        // 同步写入本地诊断日志文件，便于在 Console 以外查看
        writeDiagLogToFile(message)
    }

    private func listItems(at url: URL) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: url.path) else { return [] }
        return items
    }

    private func diagLogFileURL() -> URL? {
        let fm = FileManager.default
        do {
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let bundleId = Bundle.main.bundleIdentifier ?? "v2rayMui"
            let dir = appSupport.appendingPathComponent(bundleId, isDirectory: true)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir.appendingPathComponent("diag.log", isDirectory: false)
        } catch {
            return nil
        }
    }

    private let loggerQueue = DispatchQueue(label: "GoServerManager.Logger")

    private func writeDiagLogToFile(_ message: String) {
        guard let fileURL = diagLogFileURL() else { return }
        let line = "[" + ISO8601DateFormatter().string(from: Date()) + "] " + message + "\n"
        loggerQueue.async {
            if FileManager.default.fileExists(atPath: fileURL.path) == false {
                _ = try? line.data(using: .utf8)?.write(to: fileURL)
                return
            }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                do {
                    try handle.seekToEnd()
                    if let data = line.data(using: .utf8) {
                        try handle.write(contentsOf: data)
                    }
                } catch {
                    // ignore file write error
                }
            }
        }
    }

    // MARK: - Quarantine Handling
    @discardableResult
    private func removeQuarantine(at url: URL) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-dr", "com.apple.quarantine", url.path]
        do {
            try task.run()
            task.waitUntilExit()
            let ok = (task.terminationStatus == 0)
            debugLog("dequarantine \(url.path) -> status=\(task.terminationStatus)")
            return ok
        } catch {
            debugLog("dequarantine failed for \(url.path): \(error.localizedDescription)")
            return false
        }
    }

    /// 调用 Go 服务退出接口，给予短暂时间优雅退出（默认 0.3s）
    func requestGoServerExit(wait seconds: TimeInterval = 0.3) {
        guard let url = URL(string: "http://\(AppConfig.serverAddress):\(AppConfig.serverPort)/api/v1/exit") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: req) { _, _, _ in }
        task.resume()
        if seconds > 0 {
            Thread.sleep(forTimeInterval: seconds)
        }
    }

    private func waitForServerReady(timeoutSec: TimeInterval = 3.0) {
        guard let url = URL(string: "http://\(AppConfig.serverAddress):\(AppConfig.serverPort)/api/v1/status") else { return }
        let deadline = Date().addingTimeInterval(timeoutSec)
        let session = URLSession(configuration: .ephemeral)
        var attempt = 0
        while Date() < deadline {
            attempt += 1
            let sem = DispatchSemaphore(value: 1)
            sem.wait()
            var ok = false
            let task = session.dataTask(with: url) { _, resp, err in
                defer { sem.signal() }
                if let http = resp as? HTTPURLResponse {
                    self.debugLog("health attempt #\(attempt) -> status=\(http.statusCode)")
                    ok = (200...299).contains(http.statusCode)
                } else if let err = err {
                    self.debugLog("health attempt #\(attempt) error=\(err.localizedDescription)")
                } else {
                    self.debugLog("health attempt #\(attempt) no response")
                }
            }
            task.resume()
            _ = sem.wait(timeout: .now() + 0.7)
            if ok { self.debugLog("health OK"); return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        self.debugLog("health timeout after \(attempt) attempts")
    }

    func startServerIfNeeded() {
        // If already running, do nothing
        if process?.isRunning == true { return }

        guard let execURL = resolveServerExecutableURL() else {
            NSLog("[GoServerManager] Failed to locate v2rayMuiGoServer in bundle resources")
            if let res = Bundle.main.resourceURL {
                debugLog("Bundle.resourceURL=\(res.path)")
                debugLog("Bundle.resourceURL items=\(listItems(at: res))")
                let bin = res.appendingPathComponent("bin", isDirectory: true)
                debugLog("Resources/bin items=\(listItems(at: bin))")
            }
            if let res2 = Bundle.main.url(forResource: "Resources", withExtension: nil) {
                debugLog("Bundle.Resources ref=\(res2.path)")
                debugLog("Bundle.Resources items=\(listItems(at: res2))")
                let bin2 = res2.appendingPathComponent("bin", isDirectory: true)
                debugLog("Bundle.Resources/bin items=\(listItems(at: bin2))")
            }
            return
        }

        // Ensure executable bit & remove quarantine
        _ = try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: execURL.path)
        debugLog("Using execURL=\(execURL.path)")
        removeQuarantine(at: execURL)

        do {
            // 在启动新进程前先尝试调用退出接口，清理遗留 Go 进程
            requestGoServerExit(wait: 0.3)

            let (dataPath, binPath) = try computeRuntimePaths()
            debugLog("dataPath=\(dataPath.path)")
            debugLog("binPath=\(binPath.path)")
            debugLog("binPath items=\(listItems(at: binPath))")

            // 确保 xray 与 bin 目录去隔离并赋权
            removeQuarantine(at: binPath)
            let xrayURL = binPath.appendingPathComponent("xray")
            if FileManager.default.fileExists(atPath: xrayURL.path) {
                _ = try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: xrayURL.path)
                removeQuarantine(at: xrayURL)
            }
            let xrayPath = xrayURL.path
            debugLog("xrayExists=\(FileManager.default.fileExists(atPath: xrayPath)) at \(xrayPath)")

            let p = Process()
            p.executableURL = execURL
            p.arguments = [
                "-datapath", dataPath.path,
                "-binpath", binPath.path,
                "-port", String(AppConfig.serverPort)
            ]
            debugLog("launch args=\(p.arguments ?? [])")

            // Capture output for debugging
            let outPipe = Pipe()
            let errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                if let str = String(data: handle.availableData, encoding: .utf8), !str.isEmpty {
                    let line = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    NSLog("[GoServer] %@", line)
                    self.debugLog("stdout: \(line)")
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                if let str = String(data: handle.availableData, encoding: .utf8), !str.isEmpty {
                    let line = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    NSLog("[GoServer][ERR] %@", line)
                    self.debugLog("stderr: \(line)")
                }
            }

            try p.run()
            debugLog("spawned pid=\(p.processIdentifier)")
            p.terminationHandler = { proc in
                NSLog("[GoServerManager] go server exited with code %d", proc.terminationStatus)
                self.debugLog("go server exited code=\(proc.terminationStatus)")
            }

            process = p
            NSLog("[GoServerManager] v2rayMuiGoServer started at port %d (dataPath=%@, binPath=%@)", AppConfig.serverPort, dataPath.path, binPath.path)
            debugLog("started OK, begin health checks")
            // 健康检查，确认 HTTP 监听已就绪
            waitForServerReady(timeoutSec: 4.0)
        } catch {
            NSLog("[GoServerManager] Failed to start server: %@", error.localizedDescription)
            debugLog("spawn error: \(error.localizedDescription)")
            if let res = Bundle.main.resourceURL {
                debugLog("Bundle.resourceURL=\(res.path)")
                debugLog("Resources items=\(listItems(at: res))")
                let bin = res.appendingPathComponent("bin", isDirectory: true)
                debugLog("Resources/bin items=\(listItems(at: bin))")
            }
        }
    }

    func stopServerIfRunning() {
        guard let p = process else { return }
        if p.isRunning {
            p.terminate()
            p.waitUntilExit()
            NSLog("[GoServerManager] v2rayMuiGoServer terminated")
            debugLog("terminated pid=\(p.processIdentifier)")
        }
        process = nil
    }

    // MARK: - Helpers

    private func resolveServerExecutableURL() -> URL? {
        let fm = FileManager.default
        // Search order:
        // 1) Bundle/Resources/bin/v2rayMuiGoServer (when embedded under bin)
        // 2) Bundle/Resources/v2rayMuiGoServer (when placed at resources root via nested folder)
        // 3) Bundle resource root /v2rayMuiGoServer
        if let resRoot = Bundle.main.url(forResource: "Resources", withExtension: nil) {
            let binExec = resRoot.appendingPathComponent("bin").appendingPathComponent("v2rayMuiGoServer")
            if fm.fileExists(atPath: binExec.path) { return binExec }
            let nested = resRoot.appendingPathComponent("v2rayMuiGoServer")
            if fm.fileExists(atPath: nested.path) { return nested }
        }
        if let root = Bundle.main.resourceURL {
            let binExec = root.appendingPathComponent("bin").appendingPathComponent("v2rayMuiGoServer")
            if fm.fileExists(atPath: binExec.path) { return binExec }
            let direct = root.appendingPathComponent("v2rayMuiGoServer")
            if fm.fileExists(atPath: direct.path) { return direct }
        }
        return nil
    }

    private func computeRuntimePaths() throws -> (dataPath: URL, binPath: URL) {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let bundleId = Bundle.main.bundleIdentifier ?? "v2rayMui"
        let dataPath = appSupport.appendingPathComponent(bundleId, isDirectory: true)
        if !fm.fileExists(atPath: dataPath.path) {
            try fm.createDirectory(at: dataPath, withIntermediateDirectories: true)
        }

        // binPath = directory that contains xray; prefer Resources/bin, fallback to resources root
        if let resRoot = Bundle.main.url(forResource: "Resources", withExtension: nil) {
            let binDir = resRoot.appendingPathComponent("bin", isDirectory: true)
            if fm.fileExists(atPath: binDir.path, isDirectory: nil) {
                return (dataPath, binDir)
            }
            return (dataPath, resRoot)
        }
        if let root = Bundle.main.resourceURL {
            let binDir = root.appendingPathComponent("bin", isDirectory: true)
            if fm.fileExists(atPath: binDir.path, isDirectory: nil) {
                return (dataPath, binDir)
            }
            return (dataPath, root)
        }
        throw NSError(domain: "GoServerManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundle resources not found"])
    }


    private func isProcessRunning(pid: String) -> Bool {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-p", pid]
        let out = Pipe()
        ps.standardOutput = out
        do {
            try ps.run(); ps.waitUntilExit()
            let data = try out.fileHandleForReading.readToEnd() ?? Data()
            return (String(data: data, encoding: .utf8) ?? "").contains(pid)
        } catch { return false }
    }

    
}


