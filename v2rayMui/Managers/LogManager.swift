//
//  LogManager.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import Foundation
import Combine
import AppKit

// MARK: - 日志管理器
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    private var logs: [LogEntry] = []
    @Published var isLogging: Bool = false
    
    private let maxLogEntries = 50  // 减少内存中的日志数量从100到50，进一步优化内存使用
    private let logQueue = DispatchQueue(label: "com.v2rayMui.logmanager", qos: .background) // 使用background QoS优化性能
    private var saveTimer: Timer?
    private var pendingSave = false
    
    // 日志文件大小限制设置
    @Published var maxLogFileSizeMB: Int {
        didSet {
            UserDefaults.standard.set(maxLogFileSizeMB, forKey: "maxLogFileSizeMB")
        }
    }
    private let minLogFileSizeMB: Int = 1     // 最小1MB
    
    private var maxLogFileSizeBytes: Int {
        return max(maxLogFileSizeMB, minLogFileSizeMB) * 1024 * 1024
    }
    
    private init() {
        // 从UserDefaults加载设置
        maxLogFileSizeMB = UserDefaults.standard.object(forKey: "maxLogFileSizeMB") as? Int ?? 8
        
        loadStoredLogs()
        
        // 添加应用终止通知监听以执行清理操作
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, 
                                               object: nil, 
                                               queue: .main) { [weak self] _ in
            self?.applicationWillTerminate()
        }
    }
    
    deinit {
        // 清理定时器
        saveTimer?.invalidate()
        saveTimer = nil
        
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 应用终止时的清理操作
    private func applicationWillTerminate() {
        saveLogsToFile()
        saveTimer?.invalidate()
    }
    
    /// 清理旧日志
    private func clearOldLogs() {
        // 清理内存中的过期日志
        cleanupMemoryLogs()
        
        // 保存当前日志到文件
        saveLogsToFile()
    }
    
    /// 清理内存中的过期日志
    private func cleanupMemoryLogs() {
        if self.logs.count > self.maxLogEntries {
            let excessCount = self.logs.count - self.maxLogEntries
            DispatchQueue.main.async {
                self.logs.removeFirst(excessCount)
            }
        }
    }
    
    // MARK: - 日志操作
    
    /// 添加日志条目
    func addLog(_ message: String, level: LogLevel = .info, source: LogSource = .app) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            source: source,
            message: message
        )
        
        DispatchQueue.main.async {
            // 通知UI即将更新，避免偶发不刷新导致日志面板为空
            self.objectWillChange.send()
            self.logs.append(entry)
            
            // 定期清理内存中的日志
            self.cleanupMemoryLogs()
            
            // 延迟保存到磁盘，避免频繁I/O
            self.scheduleSave()
        }
    }
    
    /// 清空日志
    func clearLogs() {
        objectWillChange.send()
        logs.removeAll()
        saveTimer?.invalidate()
        saveTimer = nil
        pendingSave = false
        saveLogsToFile()
    }
    
    /// 开始日志记录
    func startLogging() {
        isLogging = true
        addLog("开始记录日志", level: .info, source: .app)
    }
    
    /// 停止日志记录
    func stopLogging() {
        addLog("停止记录日志", level: .info, source: .app)
        isLogging = false
    }
    
    /// 处理V2Ray进程输出
    func handleV2RayOutput(_ data: Data) {
        guard isLogging else { return }
        
        if let output = String(data: data, encoding: .utf8) {
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedLine.isEmpty {
                    let level = parseLogLevel(from: trimmedLine)
                    addLog(trimmedLine, level: level, source: .v2ray)
                }
            }
        }
    }
    
    /// 获取过滤后的日志
    func getFilteredLogs(level: LogLevel? = nil, source: LogSource? = nil) -> [LogEntry] {
        return logs.filter { entry in
            let levelMatch = level == nil || entry.level == level
            let sourceMatch = source == nil || entry.source == source
            return levelMatch && sourceMatch
        }
    }
    
    // MARK: - 私有方法
    
    /// 解析日志级别
    private func parseLogLevel(from message: String) -> LogLevel {
        let lowercased = message.lowercased()
        
        if lowercased.contains("error") || lowercased.contains("failed") {
            return .error
        } else if lowercased.contains("warning") || lowercased.contains("warn") {
            return .warning
        } else if lowercased.contains("debug") {
            return .debug
        } else {
            return .info
        }
    }
    
    /// 获取日志文件路径
    private func getLogFilePath() -> URL? {
        // 使用与V2RayManager相同的Application Support目录
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        var appDirURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "v2rayMui")
        if AppEnvironment.isRunningInXcode {
            appDirURL.appendPathComponent("dev")
        }
        let v2rayDirURL = appDirURL.appendingPathComponent("V2ray")
        return v2rayDirURL.appendingPathComponent("v2ray_logs.json")
    }
    
    /// 保存日志到文件
    private func saveLogsToFile() {
        guard let logFilePath = getLogFilePath() else { 
            print("无法获取日志文件路径")
            return 
        }
        
        // 创建V2ray目录（如果不存在）
        let parentDir = logFilePath.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("创建V2ray目录失败: \(error.localizedDescription)")
        }
        
        // 检查目录权限
        if !FileManager.default.isWritableFile(atPath: parentDir.path) {
            print("警告：V2ray目录不可写: \(parentDir.path)")
        }
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                // 检查现有文件大小
                self.checkAndRotateLogFile(at: logFilePath)
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(self.logs)
                
                // 检查新数据大小是否超过限制
                if data.count > self.maxLogFileSizeBytes {
                    // 如果新数据本身就超过限制，只保留最新的日志
                    let reducedLogs = self.reduceLogsToFitSize()
                    let reducedData = try encoder.encode(reducedLogs)
                    try reducedData.write(to: logFilePath)
                    
                    DispatchQueue.main.async {
                        self.logs = reducedLogs
                    }
                } else {
                    try data.write(to: logFilePath)
                }
            } catch {
                print("保存日志失败: \(error)")
            }
        }
    }
    
    /// 检查并轮转日志文件
    private func checkAndRotateLogFile(at logFilePath: URL) {
        guard FileManager.default.fileExists(atPath: logFilePath.path) else { return }
        
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: logFilePath.path)
            if let fileSize = fileAttributes[.size] as? Int, fileSize > maxLogFileSizeBytes {
                // 文件超过大小限制，创建备份并清空当前文件
                let backupPath = logFilePath.appendingPathExtension("backup")
                
                // 删除旧备份（如果存在）
                if FileManager.default.fileExists(atPath: backupPath.path) {
                    try FileManager.default.removeItem(at: backupPath)
                }
                
                // 移动当前文件为备份
                try FileManager.default.moveItem(at: logFilePath, to: backupPath)
                print("日志文件超过\(maxLogFileSizeMB)MB限制，已创建备份")
            }
        } catch {
            print("检查日志文件大小失败: \(error)")
        }
    }
    
    /// 减少日志数量以适应文件大小限制
    private func reduceLogsToFitSize() -> [LogEntry] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        var reducedLogs = logs
        let targetSize = Int(Double(maxLogFileSizeBytes) * 0.8) // 保留80%的空间
        
        while reducedLogs.count > 10 { // 至少保留10条日志
            do {
                let data = try encoder.encode(reducedLogs)
                if data.count <= targetSize {
                    break
                }
                // 移除最旧的日志（前面的日志）
                reducedLogs.removeFirst(max(1, reducedLogs.count / 10))
            } catch {
                print("编码日志失败: \(error)")
                break
            }
        }
        
        return reducedLogs
    }
    
    /// 延迟保存机制
    private func scheduleSave() {
        guard !pendingSave else { return }
        
        pendingSave = true
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.saveLogsToFile()
            self?.pendingSave = false
        }
    }
    
    /// 从文件加载日志
    private func loadStoredLogs() {
        guard let logFilePath = getLogFilePath(),
              FileManager.default.fileExists(atPath: logFilePath.path) else {
            return
        }
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try Data(contentsOf: logFilePath)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loadedLogs = try decoder.decode([LogEntry].self, from: data)
                
                DispatchQueue.main.async {
                    // 合并而非覆盖，避免已显示的新日志被异步加载的旧日志覆盖导致“先显示再消失”
                    self.objectWillChange.send()
                    let merged = (loadedLogs + self.logs)
                    self.logs = Array(merged.suffix(self.maxLogEntries))
                }
            } catch {
                print("加载日志失败: \(error)")
            }
        }
    }
}

// MARK: - 日志条目模型
struct LogEntry: Codable, Identifiable {
    var id = UUID()
    let timestamp: Date
    let level: LogLevel
    let source: LogSource
    let message: String
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var levelIcon: String {
        switch level {
        case .debug:
            return "🔍"
        case .info:
            return "ℹ️"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        }
    }
}

// MARK: - 日志级别
enum LogLevel: String, Codable, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - 日志来源
enum LogSource: String, Codable, CaseIterable {
    case app = "APP"
    case v2ray = "V2RAY"
    
    var displayName: String {
        switch self {
        case .app:
            return "应用"
        case .v2ray:
            return "V2Ray"
        }
    }
}