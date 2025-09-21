import Foundation
import AppKit
import Darwin

final class GoServerManager {
    private var process: Process?

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

    func startServerIfNeeded() {
        // If already running, do nothing
        if process?.isRunning == true { return }

        guard let execURL = resolveServerExecutableURL() else {
            NSLog("[GoServerManager] Failed to locate v2rayMuiGoServer in bundle resources")
            return
        }

        // Ensure executable bit
        _ = try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: execURL.path)

        do {
            // 在启动新进程前先尝试调用退出接口，清理遗留 Go 进程
            requestGoServerExit(wait: 0.3)

            let (dataPath, binPath) = try computeRuntimePaths()

            let p = Process()
            p.executableURL = execURL
            p.arguments = [
                "-datapath", dataPath.path,
                "-binpath", binPath.path,
                "-port", String(AppConfig.serverPort)
            ]
// 

            // Capture output for debugging
            let outPipe = Pipe()
            let errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                if let str = String(data: handle.availableData, encoding: .utf8), !str.isEmpty {
                    NSLog("[GoServer] %@", str.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                if let str = String(data: handle.availableData, encoding: .utf8), !str.isEmpty {
                    NSLog("[GoServer][ERR] %@", str.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }

            try p.run()

            process = p
            NSLog("[GoServerManager] v2rayMuiGoServer started at port %d (dataPath=%@, binPath=%@)", AppConfig.serverPort, dataPath.path, binPath.path)
        } catch {
            NSLog("[GoServerManager] Failed to start server: %@", error.localizedDescription)
        }
    }

    func stopServerIfRunning() {
        guard let p = process else { return }
        if p.isRunning {
            p.terminate()
            p.waitUntilExit()
            NSLog("[GoServerManager] v2rayMuiGoServer terminated")
        }
        // Also clean stale pid file if any
//        do {
//            let (dataPath, _) = try computeRuntimePaths()
////            removePidFile(in: dataPath)
//        } catch { /* ignore */ }
        process = nil
    }

    // MARK: - Helpers

    private func resolveServerExecutableURL() -> URL? {
        // Prefer nested "Resources" folder reference if present
        if let resRoot = Bundle.main.url(forResource: "Resources", withExtension: nil) {
            let nested = resRoot.appendingPathComponent("v2rayMuiGoServer")
            if FileManager.default.fileExists(atPath: nested.path) { return nested }
        }
        // Fallback to resources root
        if let root = Bundle.main.resourceURL {
            let direct = root.appendingPathComponent("v2rayMuiGoServer")
            if FileManager.default.fileExists(atPath: direct.path) { return direct }
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

        // binPath = bundle's resources directory (prefer nested Resources folder)
        if let nested = Bundle.main.url(forResource: "Resources", withExtension: nil) {
            return (dataPath, nested)
        }
        if let root = Bundle.main.resourceURL {
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


