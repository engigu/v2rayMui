//
//  v2rayMuiApp.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/9/16.
//

import SwiftUI
import AppKit

@main
struct v2rayMuiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 仅状态栏应用（macOS 13+）
        MenuBarExtra("V2Ray", systemImage: "network") {
            StatusMenuView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标，仅显示状态栏图标
        NSApp.setActivationPolicy(.accessory)
    }
}
