//
//  V2RayBinaryManager.swift
//  v2rayMui
//
//  Created by Assistant on 2024/01/01.
//

import Foundation

class V2RayBinaryManager {
    static let shared = V2RayBinaryManager()
    
    private init() {}
    
    /// 获取外置v2ray二进制文件路径
    private func getExternalBinaryPath() -> String? {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        guard let libraryPath = libraryPath else {
            LogManager.shared.addLog("无法获取Library目录路径", level: .error, source: .app)
            return nil
        }
        
        // 动态获取应用的Bundle Identifier
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            LogManager.shared.addLog("无法获取应用Bundle Identifier", level: .error, source: .app)
            return nil
        }
        
        var base = libraryPath.appendingPathComponent("Application Support/\(bundleIdentifier)")
        if AppEnvironment.isRunningInXcode {
            base.appendPathComponent("dev")
        }
        let externalPath = base.appendingPathComponent("V2ray/v2ray").path
        return externalPath
    }
    
    /// v2ray二进制文件路径（优先外置路径，其次内置路径）
    lazy var binaryPath: String? = {
        // 1. 优先检查外置路径
        if let externalPath = getExternalBinaryPath() {
            if FileManager.default.fileExists(atPath: externalPath) {
                LogManager.shared.addLog("使用自定义的v2ray二进制文件: \(externalPath)", level: .info, source: .app)
                return externalPath
            }
        }
        
        // 2. 如果外置路径没有，使用内置路径
        guard let bundlePath = Bundle.main.resourcePath else {
            LogManager.shared.addLog("无法获取应用包资源路径", level: .error, source: .app)
            return nil
        }
        
        // 优先 Resources/v2ray-core/v2ray，其次 Resources/v2ray（向下兼容）
        let candidates = [
            bundlePath + "/v2ray-core/v2ray",
            bundlePath + "/v2ray",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                LogManager.shared.addLog("使用内置v2ray二进制文件: \(path)", level: .info, source: .app)
                return path
            }
        }
        LogManager.shared.addLog("未在内置路径找到v2ray二进制文件（尝试: \(candidates.joined(separator: ", "))）", level: .warning, source: .app)
        return nil
    }()
    
    /// 检查v2ray二进制文件是否可执行
    func isBinaryExecutable() -> Bool {
        guard let path = binaryPath else { return false }
        
        return FileManager.default.isExecutableFile(atPath: path)
    }
    
    /// 设置v2ray二进制文件为可执行
    func makeBinaryExecutable() -> Bool {
        guard let path = binaryPath else { return false }
        
        do {
            let attributes = [FileAttributeKey.posixPermissions: 0o755]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: path)
            LogManager.shared.addLog("已设置v2ray二进制文件为可执行", level: .info, source: .app)
            return true
        } catch {
            LogManager.shared.addLog("设置v2ray二进制文件权限失败: \(error)", level: .error, source: .app)
            return false
        }
    }
    
    /// 获取v2ray版本信息
    func getVersion() -> String? {
        guard let path = binaryPath else { return nil }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // 提取版本号
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("V2Ray") {
                    return line.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            LogManager.shared.addLog("获取v2ray版本失败: \(error)", level: .error, source: .app)
            return nil
        }
    }
    
    /// 验证v2ray二进制文件的完整性
    func validateBinary() -> Bool {
        guard let path = binaryPath else {
            LogManager.shared.addLog("v2ray二进制文件路径无效", level: .error, source: .app)
            return false
        }
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: path) else {
            LogManager.shared.addLog("v2ray二进制文件不存在", level: .error, source: .app)
            return false
        }
        
        // 检查文件大小（v2ray二进制文件通常大于1MB）
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? Int64, fileSize < 1024 * 1024 {
                LogManager.shared.addLog("v2ray二进制文件大小异常: \(fileSize) bytes", level: .warning, source: .app)
                return false
            }
        } catch {
            LogManager.shared.addLog("无法获取v2ray二进制文件属性: \(error)", level: .error, source: .app)
            return false
        }
        
        // 尝试获取版本信息来验证文件有效性
        if getVersion() != nil {
            LogManager.shared.addLog("v2ray二进制文件验证成功", level: .info, source: .app)
            return true
        } else {
            LogManager.shared.addLog("v2ray二进制文件验证失败", level: .error, source: .app)
            return false
        }
    }
    
    /// 初始化v2ray二进制文件（设置权限并验证）
    func initializeBinary() -> Bool {
        guard binaryPath != nil else {
            LogManager.shared.addLog("v2ray二进制文件不存在，请确保已将v2ray文件添加到应用包的Resources目录中", level: .error, source: .app)
            return false
        }
        
        // 设置可执行权限
        if !isBinaryExecutable() {
            if !makeBinaryExecutable() {
                return false
            }
        }
        
        // 验证二进制文件
        return validateBinary()
    }
}
