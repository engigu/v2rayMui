//
//  MainView.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import SwiftUI

struct MainView: View {
    @ObservedObject private var v2rayManager = V2RayManager.shared
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var selectedSidebarItem: SidebarItem? = .configs
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏内容
            SidebarView(selectedItem: $selectedSidebarItem)
        } detail: {
            // 主内容区域
            Group {
                switch selectedSidebarItem {
                case .configs:
                    ConfigView()
                    
                case .logs:
                    LogView()
                    
                case .routing:
                    RoutingView()

                case .settings:
                    SettingsView()
                    
                case .none:
                    HomeContentView()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { notification in
            if let tab = notification.object as? SidebarItem {
                selectedSidebarItem = tab
            }
        }
    }
}

// MARK: - 主页内容视图
struct HomeContentView: View {
    @ObservedObject private var v2rayManager = V2RayManager.shared
    @ObservedObject private var configManager = ConfigManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 连接状态和控制区域
                VStack(spacing: 16) {
                    ConnectionStatusView()
                    ConnectionControlView()
                }
                
                // 配置信息
                if let currentConfig = configManager.selectedConfig {
                    CurrentConfigView(config: currentConfig)
                } else {
                    NoConfigView()
                }
                
                // 快速配置选择
                QuickConfigSelectionView()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle(titleText)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}

// MARK: - 连接状态视图
struct ConnectionStatusView: View {
    @ObservedObject private var v2rayManager = V2RayManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // 状态指示器
            ZStack {
                // 外层背景圆
                Circle()
                    .fill(statusColor.opacity(0.08))
                    .frame(width: 100, height: 100)
                
                // 中层圆环
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 1)
                    .frame(width: 100, height: 100)
                
                // 内层活跃圆
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .scaleEffect(v2rayManager.connectionStatus == .connecting ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: v2rayManager.connectionStatus == .connecting)
                
                // 图标
                Image(systemName: statusIcon)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(statusColor)
            }
            .shadow(color: statusColor.opacity(0.1), radius: 8, x: 0, y: 2)
            
            // 状态文本区域
            VStack(spacing: 8) {
                Text(v2rayManager.connectionStatus.description)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(statusColor)
                
                Text(statusSubtitle)
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 320)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
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
    
    private var statusIcon: String {
        switch v2rayManager.connectionStatus {
        case .disconnected:
            return "power"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .connected:
            return "checkmark.shield"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

private extension HomeContentView {
    var titleText: String {
        AppEnvironment.isRunningInXcode ? "V2Ray 客户端 · dev" : "V2Ray 客户端"
    }
}

// MARK: - 当前配置视图
struct CurrentConfigView: View {
    let config: V2RayConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当前配置")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 状态指示器
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("活跃")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 0) {
                // 配置名称和协议
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.name)
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        HStack(spacing: 0) {
                            Text(config.serverAddress)
                            Text(":")
                            Text(config.serverPort, format: .number.grouping(.never))
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        // 协议标签
                        Text(config.network.uppercased())
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                            )
                        
                        // TLS标签
                        if let tls = config.tls, tls == "tls" {
                            HStack(spacing: 3) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 8, weight: .bold))
                                Text("TLS")
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                            )
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
            )
        }
        .frame(maxWidth: 320) // 限制最大宽度，使其更窄
    }
}

// MARK: - 无配置视图
struct NoConfigView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("无可用配置")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("当前没有选择任何配置")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Text("请在配置管理中添加或选择一个配置")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("添加配置") {
                    // 切换到配置页面
                    NotificationCenter.default.post(name: .switchToTab, object: SidebarItem.configs)
                }
                .font(.callout)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - 连接控制视图
struct ConnectionControlView: View {
    @ObservedObject private var v2rayManager = V2RayManager.shared
    @ObservedObject private var configManager = ConfigManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 连接/断开按钮
            Button(action: toggleConnection) {
                HStack(spacing: 10) {
                    Image(systemName: connectionButtonIcon)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text(connectionButtonText)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(configManager.selectedConfig == nil && !v2rayManager.connectionStatus.isConnected)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.accentColor.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
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
        case .disconnected, .error:
            return "play.fill"
        case .connecting:
            return "stop.fill"
        case .connected:
            return "stop.fill"
        }
    }
    
    private func toggleConnection() {
        switch v2rayManager.connectionStatus {
        case .disconnected, .error:
            if let config = configManager.selectedConfig {
                v2rayManager.connect(with: config)
            }
        case .connecting, .connected:
            v2rayManager.disconnect()
        }
    }
}

// MARK: - 快速配置选择视图
struct QuickConfigSelectionView: View {
    @StateObject private var configManager = ConfigManager.shared
    
    var body: some View {
        if !configManager.configs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("快速选择")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(configManager.configs.count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(configManager.configs) { config in
                            ConfigQuickSelectButton(config: config)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - 配置快速选择按钮
struct ConfigQuickSelectButton: View {
    let config: V2RayConfig
    @ObservedObject private var configManager = ConfigManager.shared
    
    var body: some View {
        let tap = TapGesture().onEnded {
            withAnimation(.easeInOut(duration: 0.12)) {
                configManager.selectConfig(config)
            }
        }
        
        return VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "server.rack")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                    )
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(config.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(config.serverAddress):\(config.serverPort)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(config.network.uppercased())
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .frame(width: 110, height: 75)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .highPriorityGesture(tap)
    }
    
    private var isSelected: Bool {
        configManager.selectedConfig?.id == config.id
    }
}

// MARK: - 侧边栏项目枚举
enum SidebarItem: String, CaseIterable {
    case configs = "配置"
    case logs = "日志"
    case routing = "路由"
    case settings = "设置"
    
    var icon: String {
        switch self {
        case .configs:
            return "gear"
        case .settings:
            return "slider.horizontal.3"
        case .logs:
            return "doc.text"
        case .routing:
            return "arrow.branch"
        }
    }
}

// MARK: - 侧边栏视图
struct SidebarView: View {
    @ObservedObject private var v2rayManager = V2RayManager.shared
    @ObservedObject private var configManager = ConfigManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Binding var selectedItem: SidebarItem?
    
    var body: some View {
        List {
            // 连接状态概览 - 可点击显示主页内容
            Section {
                Button(action: {
                    selectedItem = nil // 设置为nil来显示主页内容
                }) {
                    VStack(spacing: 12) {
                        // 状态指示器
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(statusColor.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                PulsingDot(isActive: v2rayManager.connectionStatus == .connecting, color: statusColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v2rayManager.connectionStatus.description)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(statusSubtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // 添加箭头指示器
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // 连接详情
                        if v2rayManager.connectionStatus.isConnected {
                            VStack(spacing: 8) {
                                Divider()
                                
                                // HStack {
                                //     Label("连接时长", systemImage: "clock")
                                //         .font(.caption)
                                //         .foregroundColor(.secondary)
                                //     Spacer()
                                //     Text(connectionDuration)
                                //         .font(.caption)
                                //         .fontWeight(.medium)
                                //         .foregroundColor(.primary)
                                // }
                                
                                // HStack {
                                //     Label("本地端口", systemImage: "network")
                                //         .font(.caption)
                                //         .foregroundColor(.secondary)
                                //     Spacer()
                                //     Text("\(settingsManager.settings.socksLocalPort)")
                                //         .font(.caption)
                                //         .fontWeight(.medium)
                                //         .foregroundColor(.primary)
                                // }
                                
                                HStack {
                                    Label("Socks地址", systemImage: "network")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    HStack(spacing: 0) {
                                        Text(settingsManager.settings.socksHost)
                                        Text(":")
                                        Text(settingsManager.settings.socksLocalPort, format: .number.grouping(.never))
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                }
                                
                                HStack {
                                    Label("SocksUDP支持", systemImage: "network")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(settingsManager.settings.socksUdpEnabled ? "已启用" : "已禁用")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack {
                                    Label("HTTP地址", systemImage: "network")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    HStack(spacing: 0) {
                                        Text(settingsManager.settings.httpHost)
                                        Text(":")
                                        Text(settingsManager.settings.httpPort, format: .number.grouping(.never))
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                }

                                HStack {
                                    Label("路由模式", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(settingsManager.settings.routingMode.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text("连接状态")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            // 导航
            Section {
                ForEach(SidebarItem.allCases, id: \.self) { item in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedItem = item
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedItem == item ? .accentColor : .secondary)
                                .frame(width: 20)
                            
                            Text(item.rawValue)
                                .font(.system(.subheadline, weight: selectedItem == item ? .semibold : .regular))
                                .foregroundColor(selectedItem == item ? .accentColor : .primary)
                            
                            Spacer()
                            
                            if selectedItem == item {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("导航")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("控制面板")
        .frame(minWidth: 220, idealWidth: 250)
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

// MARK: - 细分组件：脉冲点
struct PulsingDot: View {
    let isActive: Bool
    let color: Color
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
            .scaleEffect(scale)
            .onChange(of: isActive) { _, new in
                if new {
                    start()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = 1.0
                    }
                }
            }
            .onAppear {
                if isActive { start() }
            }
    }

    private func start() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            scale = 1.2
        }
    }
}

// MARK: - 侧边栏配置行
struct SidebarConfigRow: View {
    let config: V2RayConfig
    @ObservedObject private var configManager = ConfigManager.shared
    
    var body: some View {
        Button(action: {
            configManager.selectConfig(config)
        }) {
            HStack(spacing: 12) {
                // 配置图标
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                
                // 配置信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(config.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(config.serverAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(config.serverPort)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 协议标签
                    HStack(spacing: 6) {
                        Label(config.network.uppercased(), systemImage: "network")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        
                        if let tls = config.tls, tls == "tls" {
                            Label("TLS", systemImage: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green.opacity(0.1))
                                )
                        }
                    }
                }
                
                Spacer()
                
                // 选中状态指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var isSelected: Bool {
        configManager.selectedConfig?.id == config.id
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let switchToTab = Notification.Name("switchToTab")
}

#Preview {
    MainView()
}