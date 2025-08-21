//
//  StatusBarPopoverView.swift
//  test11
//
//  Created by SayHeya on 2025/3/13.
//

import SwiftUI

// MARK: - 状态栏弹出窗口视图
struct StatusBarPopoverView: View {
    @ObservedObject private var v2rayManager = V2RayManager.shared
    @ObservedObject private var configManager = ConfigManager.shared
    
    var body: some View {
        VStack(spacing: 18) {
            // 标题栏
            HStack {
                Text("V2Ray客户端")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    // 打开主窗口
                    openMainWindow()
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("打开主窗口")
            }
            
            // 分隔线
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
            
            // 连接状态显示（紧凑版）
            CompactConnectionStatusView()
            
            // 当前配置信息
            if let currentConfig = configManager.selectedConfig {
                CompactCurrentConfigView(config: currentConfig)
            } else {
                CompactNoConfigView()
            }
            
            // 连接控制按钮
            CompactConnectionControlView()
            
            // 分隔线
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
            
            // 快速操作
            HStack(spacing: 8) {
                Button("配置") {
                    openMainWindow(selectedTab: .configs)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(.caption, design: .rounded, weight: .medium))
                
                Button("日志") {
                    openMainWindow(selectedTab: .logs)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(.caption, design: .rounded, weight: .medium))
                
                Button("设置") {
                    openMainWindow(selectedTab: .settings)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(.caption, design: .rounded, weight: .medium))
            }
        }
        .padding(18)
        .frame(width: 260) // 减少宽度，使其更紧凑
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(NSColor.windowBackgroundColor))
        )
    }
    
    private func openMainWindow(selectedTab: SidebarItem? = nil) {
        // 先发送通知切换标签页
        if let tab = selectedTab {
            NotificationCenter.default.post(name: .switchToTab, object: tab)
        }
        
        // 然后显示主窗口
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        
        // 最后关闭弹出窗口
        StatusBarManager.shared.popover?.performClose(nil)
    }
}

// MARK: - 紧凑连接状态视图
struct CompactConnectionStatusView: View {
    @ObservedObject private var v2rayManager = V2RayManager.shared
    
    var body: some View {
        HStack(spacing: 14) {
            // 状态指示器
            ZStack {
                // 外层背景圆
                Circle()
                    .fill(statusColor.opacity(0.08))
                    .frame(width: 40, height: 40)
                
                // 中层圆环
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 1)
                    .frame(width: 40, height: 40)
                
                // 内层活跃圆
                Circle()
                    .fill(statusColor)
                    .frame(width: 18, height: 18)
                    .scaleEffect(v2rayManager.connectionStatus == .connecting ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: v2rayManager.connectionStatus == .connecting)
            }
            .shadow(color: statusColor.opacity(0.1), radius: 3, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(v2rayManager.connectionStatus.description)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                Text(statusSubtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 连接时长（如果已连接）
            if v2rayManager.connectionStatus.isConnected {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                        Text("已连接")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.green)
                    }
                    // Text(connectionDuration)
                    //     .font(.system(.caption2, design: .monospaced, weight: .medium))
                    //     .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
    }
    
    private var statusColor: Color {
        switch v2rayManager.connectionStatus {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusSubtitle: String {
        switch v2rayManager.connectionStatus {
        case .disconnected:
            return "点击连接按钮开始"
        case .connecting:
            return "正在建立连接..."
        case .connected:
            return "连接正常运行"
        case .error:
            return "连接出现错误"
        }
    }
    
    private var connectionDuration: String {
        // 这里应该计算实际的连接时长
        return "00:15:32"
    }
}

// MARK: - 紧凑当前配置视图
struct CompactCurrentConfigView: View {
    let config: V2RayConfig
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部区域
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("当前配置")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 协议标签
                Text(config.network.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                    )
            }
            .padding(.bottom, 8)
            
            // 主要内容区域
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(config.name)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(config.serverAddress):\(config.serverPort)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // TLS标签
                if let tls = config.tls, tls == "tls" {
                    HStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 7, weight: .bold))
                        Text("TLS")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green)
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 0.5)
        )
    }
}

// MARK: - 紧凑无配置视图
struct CompactNoConfigView: View {
    var body: some View {
        VStack(spacing: 12) {
            // 图标区域
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 50, height: 50)
                
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    .frame(width: 50, height: 50)
                
                Image(systemName: "gear.badge.questionmark")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
            }
            .shadow(color: Color.orange.opacity(0.1), radius: 3, x: 0, y: 1)
            
            VStack(spacing: 6) {
                Text("未选择配置")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("请在配置页面添加或选择一个配置")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - 紧凑连接控制视图
struct CompactConnectionControlView: View {
    @ObservedObject private var v2rayManager = V2RayManager.shared
    @ObservedObject private var configManager = ConfigManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 连接/断开按钮
            Button(action: toggleConnection) {
                HStack(spacing: 8) {
                    Image(systemName: connectionButtonIcon)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(connectionButtonText)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(configManager.selectedConfig == nil && !v2rayManager.connectionStatus.isConnected)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.accentColor.opacity(0.15), radius: 3, x: 0, y: 1)
        }
    }
    
    private var connectionButtonText: String {
        switch v2rayManager.connectionStatus {
        case .disconnected:
            return "连接"
        case .connecting:
            return "连接中..."
        case .connected:
            return "断开"
        case .error:
            return "连接"
        }
    }
    
    private var connectionButtonIcon: String {
        switch v2rayManager.connectionStatus {
        case .disconnected:
            return "play.fill"
        case .connecting:
            return "stop.fill"
        case .connected:
            return "stop.fill"
        case .error:
            return "arrow.clockwise"
        }
    }
    
    private func toggleConnection() {
        if v2rayManager.connectionStatus.isConnected {
            v2rayManager.disconnect()
        } else {
            guard let config = configManager.selectedConfig else { return }
            v2rayManager.connect(with: config)
        }
    }
}

// MARK: - 预览
#Preview {
    StatusBarPopoverView()
        .frame(width: 280)
}