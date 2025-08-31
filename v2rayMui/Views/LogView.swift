//
//  LogView.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import SwiftUI

struct LogView: View {
    @ObservedObject private var logManager = LogManager.shared
    @State private var selectedLevel: LogLevel? = nil
    @State private var selectedSource: LogSource? = nil
    @State private var searchText = ""
    @State private var autoScroll = true
    @State private var visibleRange: Range<Int> = 0..<30   // 进一步减少初始加载量
    @State private var isViewVisible = false  // 跟踪视图可见性
    
    var filteredLogs: [LogEntry] {
        var logs = logManager.getFilteredLogs(level: selectedLevel, source: selectedSource)
        
        if !searchText.isEmpty {
            logs = logs.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs
    }
    
    var visibleLogs: [LogEntry] {
        let logs = filteredLogs
        let endIndex = min(visibleRange.upperBound, logs.count)
        let startIndex = max(0, min(visibleRange.lowerBound, endIndex))
        return Array(logs[startIndex..<endIndex])
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                // 过滤器
                Menu("级别: \(selectedLevel?.displayName ?? "全部")") {
                    Button("全部") {
                        selectedLevel = nil
                    }
                    
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button(level.displayName) {
                            selectedLevel = level
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                
                Menu("来源: \(selectedSource?.displayName ?? "全部")") {
                    Button("全部") {
                        selectedSource = nil
                    }
                    
                    ForEach(LogSource.allCases, id: \.self) { source in
                        Button(source.displayName) {
                            selectedSource = source
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                
                Spacer()
                
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜索日志...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 200)
                
                // 自动滚动开关
                Toggle("自动滚动", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                
                // 清空按钮
                Button("清空") {
                    logManager.clearLogs()
                }
                .buttonStyle(.borderless)
                
                // 导出按钮
                Button("导出") {
                    exportLogs()
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 日志列表
            if filteredLogs.isEmpty && logManager.isLogging == false {
                VStack {
                    Spacer()
                    
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("暂无日志")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    Text("连接到服务器后将显示日志信息")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 0) {
                        ForEach(visibleLogs) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                                .onAppear {
                                    // 当接近底部时加载更多
                                    if entry.id == visibleLogs.last?.id {
                                        loadMoreIfNeeded()
                                    }
                                }
                        }
                        
                        // 加载更多指示器
                        if visibleRange.upperBound < filteredLogs.count {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("加载更多...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .onAppear {
                                loadMoreIfNeeded()
                            }
                        }
                        }
                        .onAppear {
                              isViewVisible = true
                              
                              // 直接计算初始可见范围，避免调用可能触发循环的updateVisibleRange()
                              let totalCount = filteredLogs.count
                              if autoScroll {
                                  let startIndex = max(0, totalCount - 30)
                                  visibleRange = startIndex..<totalCount
                              } else {
                                  let newUpperBound = min(visibleRange.upperBound, totalCount)
                                  let newLowerBound = max(0, min(visibleRange.lowerBound, newUpperBound))
                                  visibleRange = newLowerBound..<newUpperBound
                              }
                              
                              // 首次加载时滚动到底部
                              DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                  if autoScroll && totalCount > 0 && isViewVisible {
                                      if let lastLog = filteredLogs.last {
                                          proxy.scrollTo(lastLog.id, anchor: .bottom)
                                      }
                                  }
                              }
                          }
                          .onDisappear {
                              isViewVisible = false
                          }
                          .onChange(of: filteredLogs.count) { newCount in
                              guard isViewVisible else { return }  // 视图不可见时跳过更新
                              
                              // 直接计算新的可见范围，避免调用可能触发循环的updateVisibleRange()
                              let newVisibleRange: Range<Int>
                              if autoScroll {
                                  let startIndex = max(0, newCount - 30)
                                  newVisibleRange = startIndex..<newCount
                              } else {
                                  let newUpperBound = min(visibleRange.upperBound, newCount)
                                  let newLowerBound = max(0, min(visibleRange.lowerBound, newUpperBound))
                                  newVisibleRange = newLowerBound..<newUpperBound
                              }
                              
                              // 只有当范围真正改变时才更新
                              if newVisibleRange != visibleRange {
                                  visibleRange = newVisibleRange
                              }
                              
                              // 确保每次都滚动到最底部
                              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                  if autoScroll && newCount > 0 && isViewVisible {
                                      withAnimation(.easeOut(duration: 0.2)) {
                                          if let lastLog = filteredLogs.last {
                                              proxy.scrollTo(lastLog.id, anchor: .bottom)
                                          }
                                      }
                                  }
                              }
                          }
                    }
                }
                .background(Color.clear)
                .padding(.horizontal, 8)
            }
            
            // 状态栏
            HStack {
                Text("共 \(filteredLogs.count) 条日志")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if logManager.isLogging {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: logManager.isLogging)
                        
                        Text("正在记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle("连接日志")
    }
    
    private func loadMoreIfNeeded() {
        guard isViewVisible else { return }  // 视图不可见时不加载
        
        let currentCount = visibleRange.upperBound
        let totalCount = filteredLogs.count
        
        if currentCount < totalCount {
            let newUpperBound = min(currentCount + 15, totalCount)
            visibleRange = visibleRange.lowerBound..<newUpperBound
        }
    }
    

    
    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "v2ray_logs_\(Date().timeIntervalSince1970).txt"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let logText = filteredLogs.map { entry in
                    "[\(entry.formattedTimestamp)] [\(entry.level.rawValue)] [\(entry.source.rawValue)] \(entry.message)"
                }.joined(separator: "\n")
                
                do {
                    try logText.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("导出日志失败: \(error)")
                }
            }
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    
    var levelColor: Color {
        switch entry.level {
        case .debug:
            return .secondary
        case .info:
            return .primary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
    
    var sourceColor: Color {
        switch entry.source {
        case .app:
            return .blue
        case .v2ray:
            return .purple
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间戳
            Text(entry.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // 级别标签
            Text(entry.level.rawValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(levelColor)
                .frame(width: 60, alignment: .leading)
            
            // 来源标签
            Text(entry.source.rawValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(sourceColor)
                .frame(width: 50, alignment: .leading)
            
            // 消息内容
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contextMenu {
            Button("复制消息") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.message, forType: .string)
            }
            
            Button("复制完整日志") {
                let fullLog = "[\(entry.formattedTimestamp)] [\(entry.level.rawValue)] [\(entry.source.rawValue)] \(entry.message)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fullLog, forType: .string)
            }
        }
    }
}

#Preview {
    LogView()
        .frame(width: 800, height: 600)
}