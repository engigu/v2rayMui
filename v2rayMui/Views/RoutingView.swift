//
//  RoutingView.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import SwiftUI
import AppKit

struct RoutingView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var v2rayManager = V2RayManager.shared
    
    var body: some View {
        Form {
            Section("路由模式") {
                HStack(alignment: .center, spacing: 12) {
                    Text("模式")
                        .frame(width: 120, alignment: .leading)
                    Picker("", selection: Binding<RoutingMode>(
                        get: { settingsManager.settings.routingMode },
                        set: { newValue in
                            settingsManager.updateRoutingMode(newValue)
                        }
                    )) {
                        ForEach(RoutingMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("选择流量路由模式")
                }
                .padding(.vertical, 2)

                // 高级：domainStrategy 与自定义规则
                HStack(alignment: .top, spacing: 12) {
                    Text("域名策略")
                        .frame(width: 120, alignment: .leading)
                    Picker("", selection: Binding<String>(
                        get: { settingsManager.settings.domainStrategy },
                        set: { settingsManager.updateDomainStrategy($0) }
                    )) {
                        Text("AsIs").tag("AsIs")
                        Text("IPIfNonMatch").tag("IPIfNonMatch")
                        Text("IPOnDemand").tag("IPOnDemand")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                .padding(.vertical, 2)

                HStack() {
                    Text("代理的IP/域名")
                        .frame(width: 120, alignment: .leading)
                    TextEditor(text: Binding<String>(
                        get: { settingsManager.settings.customProxyRules },
                        set: { settingsManager.updateCustomProxyRules($0) }
                    ))
                    // .textEditorStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 80)
                    // .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                }
                .padding(.vertical, 2)

                HStack() {
                    Text("直连的IP/域名")
                        .frame(width: 120, alignment: .leading)
                    TextEditor(text: Binding<String>(
                        get: { settingsManager.settings.customDirectRules },
                        set: { settingsManager.updateCustomDirectRules($0) }
                    ))
                    // .textEditorStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 80)
                    // .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                }
                .padding(.vertical, 2)

                HStack() {
                    Text("阻止的ip/域名")
                        .frame(width: 120, alignment: .leading)
                    TextEditor(text: Binding<String>(
                        get: { settingsManager.settings.customBlockRules },
                        set: { settingsManager.updateCustomBlockRules($0) }
                    ))
                    // .textEditorStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 80)
                    // .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                }
                .padding(.vertical, 2)
            }
            
            Section("说明") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("路由模式说明：")
                        .font(.headline)
                    
                    Text("• 全局代理：所有流量都通过代理服务器")
                        .font(.callout)
                    
                    Text("• 绕过大陆：仅代理非中国大陆的流量")
                        .font(.callout)
                    
                    Text("• 直连模式：所有流量直接连接，不使用代理")
                        .font(.callout)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 400)
        .navigationTitle("路由设置")
    }
}

#Preview {
    RoutingView()
}