//
//  ConfigEditView.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import SwiftUI

struct ConfigEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: V2RayConfig
    @State private var validationErrors: [String] = []
    @State private var showingValidationAlert = false
    
    let onSave: (V2RayConfig) -> Void
    private let isNewConfig: Bool
    
    init(config: V2RayConfig, onSave: @escaping (V2RayConfig) -> Void) {
        self._config = State(initialValue: config)
        self.onSave = onSave
        self.isNewConfig = config.name.isEmpty || config.name == "新配置"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic
                Section("基本设置") {
                    HStack {
                        Text("name")
                        Spacer()
                        TextField("", text: $config.name)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    
                    HStack {
                        Text("protocol")
                        Spacer()
                        Picker("", selection: $config.protocolType) {
                            ForEach(ProtocolType.allCases, id: \.rawValue) { type in
                                Text(type.displayName).tag(type.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    HStack {
                        Text("address")
                        Spacer()
                        TextField("", text: $config.serverAddress)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    
                    HStack {
                        Text("port")
                        Spacer()
                        TextField("", value: $config.serverPort, format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // VMess/VLESS require id
                    if config.protocolType == "vmess" || config.protocolType == "vless" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("id")
                                Spacer()
                                TextField("", text: $config.userId)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)
                            }
                            
                            HStack {
                                Spacer()
                                Button("Generate UUID") {
                                    DispatchQueue.main.async {
                                        config.userId = UUID().uuidString
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    // Trojan requires password
                    if config.protocolType == "trojan" {
                        HStack {
                            Text("password")
                            Spacer()
                            SecureField("", text: Binding(
                                get: { config.password ?? "" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.password = newValue.isEmpty ? nil : newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        }
                    }
                    
                    // Shadowsocks requires password and method
                    if config.protocolType == "shadowsocks" {
                        HStack {
                            Text("password")
                            Spacer()
                            SecureField("", text: Binding(
                                get: { config.password ?? "" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.password = newValue.isEmpty ? nil : newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        }
                        
                        HStack {
                            Text("method")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { config.method ?? "aes-256-gcm" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.method = newValue
                                    }
                                }
                            )) {
                                ForEach(ShadowsocksMethod.allCases, id: \.rawValue) { method in
                                    Text(method.displayName).tag(method.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                        }
                    }
                }
                
                // Transport
                Section("传输设置") {
                    // network (not required for shadowsocks)
                    if config.protocolType != "shadowsocks" {
                        HStack {
                            Text("network")
                            Spacer()
                            Picker("", selection: $config.network) {
                                ForEach(NetworkType.allCases, id: \.rawValue) { type in
                                    Text(type.displayName).tag(type.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                    }
                    
                    // security (vmess only)
                    if config.protocolType == "vmess" {
                        HStack {
                            Text("security")
                            Spacer()
                            Picker("", selection: $config.security) {
                                ForEach(SecurityType.allCases, id: \.rawValue) { type in
                                    Text(type.displayName).tag(type.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                        
                        HStack {
                            Text("alterId")
                            Spacer()
                            TextField("", value: $config.alterId, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                // Advanced
                Section("高级设置") {
                    if needsPathField {
                        HStack {
                            Text(config.network == "xhttp" ? "xhttp.path" : "path")
                            Spacer()
                            TextField("", text: Binding(
                                get: { config.path ?? "" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.path = newValue.isEmpty ? nil : newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        }
                    }
                    
                    if needsHostField {
                        HStack {
                            Text("host")
                            Spacer()
                            TextField("", text: Binding(
                                get: { config.host ?? "" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.host = newValue.isEmpty ? nil : newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        }
                    }

                    // xhttp mode 专属字段
                    if config.network == "xhttp" {
                        HStack {
                            Text("xhttp.mode")
                            Spacer()
                            TextField("", text: Binding(
                                get: { config.xhttpMode ?? "" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.xhttpMode = newValue.isEmpty ? nil : newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        }
                    }
                    
                    // tls (not required for shadowsocks)
                    if config.protocolType != "shadowsocks" {
                        HStack {
                            Text("tls")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { config.tls ?? "" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.tls = newValue.isEmpty ? nil : newValue
                                    }
                                }
                            )) {
                                ForEach(TLSType.allCases, id: \.rawValue) { type in
                                    Text(type.displayName).tag(type.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                        
                        // allowInsecure (only for TLS)
                        if config.tls == "tls" {
                            HStack {
                                Text("allowInsecure")
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { config.allowInsecure ?? false },
                                    set: { newValue in
                                        DispatchQueue.main.async {
                                            config.allowInsecure = newValue
                                        }
                                    }
                                ))
                            }
                        }
                    }
                    
                    // REALITY-specific
                    if config.tls == "reality" {
                        HStack {
                            Text("publicKey")
                            Spacer()
                            TextField("", text: Binding(
                                get: { config.publicKey ?? "" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.publicKey = newValue.isEmpty ? nil : newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        }
                        
                        HStack {
                            Text("shortId")
                            Spacer()
                            TextField("", text: Binding(
                                get: { config.shortId ?? "" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.shortId = newValue.isEmpty ? nil : newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        }
                        
                        HStack {
                            Text("SpiderX")
                            Spacer()
                            TextField("", text: Binding(
                                get: { config.spiderX ?? "" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.spiderX = newValue.isEmpty ? nil : newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        }
                        
                        HStack {
                            Text("fingerprint")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { config.fingerprint ?? "chrome" },
                                set: { newValue in
                                    DispatchQueue.main.async {
                                        config.fingerprint = newValue
                                    }
                                }
                            )) {
                                ForEach(FingerprintType.allCases, id: \.rawValue) { type in
                                    Text(type.displayName).tag(type.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                    }
                }
                
                // Preview (card)
                Section("预览") {
                    let proto = config.protocolType.uppercased()
                    let showNet = config.protocolType != "shadowsocks"
                    let tlsRaw = (config.tls ?? "")
                    let tlsUpper = tlsRaw.uppercased()
                    let tlsColor: Color = tlsRaw == "reality" ? .purple : .green
                    
                    // VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "server.rack")
                                .foregroundColor(.secondary)
                            Text("\(config.serverAddress):\(config.serverPort)")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack(spacing: 8) {
                            // 协议 chip
                            Text(proto)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(Color.accentColor.opacity(0.12))
                                )
                                .foregroundColor(.accentColor)
                            
                            // 网络 chip（非 shadowsocks 才显示）
                            if showNet {
                                Text(config.network.uppercased())
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(Color.secondary.opacity(0.12))
                                    )
                                    .foregroundColor(.secondary)
                            }
                            
                            // TLS / REALITY chip（有设置时显示）
                            if !tlsRaw.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: tlsRaw == "reality" ? "eye.trianglebadge.exclamationmark" : "lock.shield")
                                    Text(tlsUpper)
                                }
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(tlsColor.opacity(0.12))
                                )
                                .foregroundColor(tlsColor)
                            }
                            
                            // Shadowsocks 方法 chip（仅在 SS 且有 method 时）
                            if config.protocolType == "shadowsocks", let method = config.method, !method.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.circle")
                                    Text(method.uppercased())
                                }
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(Color.blue.opacity(0.12))
                                )
                                .foregroundColor(.blue)
                            }
                        }
                    // }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                    )
                    // .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNewConfig ? "添加配置" : "编辑配置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveConfig()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .alert("Validation Failed", isPresented: $showingValidationAlert) {
            Button("OK") { }
        } message: {
            VStack(alignment: .leading) {
                ForEach(validationErrors, id: \.self) { error in
                    Text("• \(error)")
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var needsPathField: Bool {
        config.protocolType != "shadowsocks" && (config.network == "ws" || config.network == "h2" || config.network == "grpc" || config.network == "xhttp")
    }
    
    private var needsHostField: Bool {
        config.protocolType != "shadowsocks" && (config.network == "ws" || config.network == "h2" || config.network == "grpc" || config.network == "xhttp" || config.tls == "tls" || config.tls == "reality")
    }
    
    private var isFormValid: Bool {
        let basicValid = !config.name.trimmingCharacters(in: .whitespaces).isEmpty &&
                        !config.serverAddress.trimmingCharacters(in: .whitespaces).isEmpty &&
                        config.serverPort > 0 && config.serverPort <= 65535
        
        switch config.protocolType {
        case "vmess", "vless":
            return basicValid && !config.userId.trimmingCharacters(in: .whitespaces).isEmpty
        case "trojan":
            return basicValid && !(config.password?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        case "shadowsocks":
            return basicValid && 
                   !(config.password?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) &&
                   !(config.method?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        default:
            return basicValid
        }
    }
    
    // MARK: - 方法
    
    private func saveConfig() {
        // 验证配置
        validationErrors = ConfigManager.shared.validateConfig(config)
        
        // 检查名称重复
        if ConfigManager.shared.isConfigNameDuplicate(config.name, excludingId: isNewConfig ? nil : config.id) {
            validationErrors.append("配置名称已存在")
        }
        
        if !validationErrors.isEmpty {
            showingValidationAlert = true
            return
        }
        
        // 保存配置
        onSave(config)
        dismiss()
    }
}



#Preview {
    ConfigEditView(config: V2RayConfig()) { _ in }
}