//
//  ConfigView.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import SwiftUI

struct ConfigView: View {
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var showingAddConfig = false
    @State private var editingConfig: V2RayConfig?
    @State private var showingDeleteAlert = false
    @State private var configToDelete: V2RayConfig?
    
    
    var body: some View {
        NavigationStack {
            // 配置列表
            List {
                ForEach(configManager.configs) { config in
                    NavigationLink {
                        ConfigDetailView(config: config)
                    } label: {
                        ConfigRowView(config: config)
                    }
                    .contextMenu {
                        Button("编辑") { editingConfig = config }
                        Button("复制") { configManager.duplicateConfig(config) }
                        Button("删除", role: .destructive) {
                            configToDelete = config
                            showingDeleteAlert = true
                        }
                    }
                }
            }
            .navigationTitle("配置列表")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("添加配置") {
                        showingAddConfig = true
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("从剪贴板导入") {
                        ConfigManager.shared.importFromClipboard()
                    }
                }
            }
            .frame(minWidth: 300, idealWidth: 350, maxWidth: 400)
            .listStyle(.inset)
            .listRowSeparator(.hidden)
            .scrollContentBackground(.hidden)
            .padding(.vertical, 12)
            // .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        }
        .sheet(isPresented: $showingAddConfig) {
            ConfigEditView(config: V2RayConfig()) { newConfig in
                configManager.addConfig(newConfig)
            }
        }
        .sheet(item: $editingConfig) { config in
            ConfigEditView(config: config) { updatedConfig in
                configManager.updateConfig(updatedConfig)
            }
        }
        .alert("删除配置", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let config = configToDelete {
                    configManager.deleteConfig(config)
                }
            }
        } message: {
            Text("确定要删除配置 \"\(configToDelete?.name ?? "")\" 吗？")
        }
    }
}

// 过滤功能已移除

// MARK: - 配置行视图
struct ConfigRowView: View {
    let config: V2RayConfig
    @ObservedObject private var configManager = ConfigManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 协议图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(protocolColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: protocolIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(protocolColor)
            }
            
            // 配置信息
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(config.name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16))
                    }
                }
                
                Text("\(config.serverAddress):\(config.serverPort)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // 标签行
                HStack(spacing: 6) {
                    // 协议标签
                    Text(config.protocolType.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(protocolColor.opacity(0.12))
                        )
                        .foregroundColor(protocolColor)
                    
                    // 网络标签（非 Shadowsocks）
                    if config.protocolType != "shadowsocks" {
                        Text(config.network.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.secondary.opacity(0.12))
                            )
                            .foregroundColor(.secondary)
                    }
                    
                    // TLS/XTLS/REALITY 标签
                    if let tls = config.tls, !tls.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: tlsIcon)
                                .font(.system(size: 8))
                            Text(tls.uppercased())
                        }
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(tlsColor.opacity(0.12))
                        )
                        .foregroundColor(tlsColor)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private var isSelected: Bool {
        configManager.selectedConfig?.id == config.id
    }
    
    private var protocolColor: Color {
        switch config.protocolType {
        case "vmess": return .blue
        case "vless": return .green
        case "trojan": return .orange
        case "shadowsocks": return .purple
        default: return .gray
        }
    }
    
    private var protocolIcon: String {
        switch config.protocolType {
        case "vmess": return "v.circle.fill"
        case "vless": return "v.square.fill"
        case "trojan": return "t.circle.fill"
        case "shadowsocks": return "s.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    private var tlsColor: Color {
        guard let tls = config.tls else { return .gray }
        switch tls {
        case "tls": return .green
        case "xtls": return .blue
        case "reality": return .purple
        default: return .gray
        }
    }
    
    private var tlsIcon: String {
        guard let tls = config.tls else { return "lock" }
        switch tls {
        case "reality": return "eye.trianglebadge.exclamationmark"
        default: return "lock.shield"
        }
    }
}

// MARK: - 配置详情视图
struct ConfigDetailView: View {
    let config: V2RayConfig
    @State private var showingEditSheet = false
    @ObservedObject private var configManager = ConfigManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 配置头部卡片
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // 协议图标
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(protocolColor.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: protocolIcon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(protocolColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(config.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("\(config.serverAddress):\(config.serverPort)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            // 协议标签
                            HStack(spacing: 8) {
                                Text(config.protocolType.uppercased())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(protocolColor.opacity(0.15))
                                    )
                                    .foregroundColor(protocolColor)
                                
                                if let tls = config.tls, !tls.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: tlsIcon)
                                        Text(tls.uppercased())
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(tlsColor.opacity(0.15))
                                    )
                                    .foregroundColor(tlsColor)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.controlBackgroundColor))
                )
                
                // 详细信息
                VStack(spacing: 16) {
                    // 基本信息
                    DetailSection(title: "基本信息") {
                        DetailRow(title: "name", value: config.name)
                        DetailRow(title: "protocol", value: config.protocolType)
                        DetailRow(title: "address", value: config.serverAddress)
                        DetailRow(title: "port", value: "\(config.serverPort)")
                        
                        // 协议特定字段
                        if config.protocolType == "vmess" || config.protocolType == "vless" {
                            DetailRow(title: "id", value: config.userId, isSecret: true)
                        }
                        
                        if config.protocolType == "trojan" {
                            if let password = config.password {
                                DetailRow(title: "password", value: password, isSecret: true)
                            }
                        }
                        
                        if config.protocolType == "shadowsocks" {
                            if let password = config.password {
                                DetailRow(title: "password", value: password, isSecret: true)
                            }
                            if let method = config.method {
                                DetailRow(title: "method", value: method)
                            }
                        }
                        
                        if config.protocolType == "vmess" {
                            DetailRow(title: "security", value: config.security)
                            DetailRow(title: "alterId", value: "\(config.alterId)")
                        }
                    }
                    
                    // 传输设置
                    if config.protocolType != "shadowsocks" {
                        DetailSection(title: "传输设置") {
                            DetailRow(title: "network", value: config.network)
                            
                            if let path = config.path, !path.isEmpty {
                                DetailRow(title: "path", value: path)
                            }
                            
                            if let host = config.host, !host.isEmpty {
                                DetailRow(title: "host", value: host)
                            }
                            
                            if let tls = config.tls, !tls.isEmpty {
                                DetailRow(title: "tls", value: tls)
                                
                                if tls == "tls", let allowInsecure = config.allowInsecure {
                                    DetailRow(title: "allowInsecure", value: allowInsecure ? "true" : "false")
                                }
                            }
                        }
                    }
                    
                    // REALITY 设置
                    if config.tls == "reality" {
                        DetailSection(title: "REALITY 设置") {
                            if let publicKey = config.publicKey, !publicKey.isEmpty {
                                DetailRow(title: "publicKey", value: publicKey, isSecret: true)
                            }
                            if let shortId = config.shortId, !shortId.isEmpty {
                                DetailRow(title: "shortId", value: shortId)
                            }
                            if let spiderX = config.spiderX, !spiderX.isEmpty {
                                DetailRow(title: "spiderX", value: spiderX)
                            }
                            if let fingerprint = config.fingerprint, !fingerprint.isEmpty {
                                DetailRow(title: "fingerprint", value: fingerprint)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 500)
            .padding(20)
            // .frame(maxWidth: .infinity)
        }
        .navigationTitle(config.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("编辑") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ConfigEditView(config: config) { updatedConfig in
                configManager.updateConfig(updatedConfig)
            }
        }
    }
    
    private var protocolColor: Color {
        switch config.protocolType {
        case "vmess": return .blue
        case "vless": return .green
        case "trojan": return .orange
        case "shadowsocks": return .purple
        default: return .gray
        }
    }
    
    private var protocolIcon: String {
        switch config.protocolType {
        case "vmess": return "v.circle.fill"
        case "vless": return "v.square.fill"
        case "trojan": return "t.circle.fill"
        case "shadowsocks": return "s.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    private var tlsColor: Color {
        guard let tls = config.tls else { return .gray }
        switch tls {
        case "tls": return .green
        case "xtls": return .blue
        case "reality": return .purple
        default: return .gray
        }
    }
    
    private var tlsIcon: String {
        guard let tls = config.tls else { return "lock" }
        switch tls {
        case "reality": return "eye.trianglebadge.exclamationmark"
        default: return "lock.shield"
        }
    }
}

// MARK: - 详情组件
struct DetailSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var isSecret: Bool = false
    @State private var isRevealed = false
    
    var body: some View {
        HStack {
            Text(title)
                // .font(.system(.caption, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
                .padding(.trailing, 20)
            
            HStack {
                if isSecret && !isRevealed {
                    Text("••••••••")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                Spacer()
                
                if isSecret {
                    Button(action: {
                        isRevealed.toggle()
                    }) {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ConfigView()
}
