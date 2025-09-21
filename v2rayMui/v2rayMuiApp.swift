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
        MenuBarExtra {
            StatusMenuView()
        } label: {
            StatusBarIconView()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let goManager = GoServerManager()
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标，仅显示状态栏图标
        NSApp.setActivationPolicy(.accessory)
        goManager.startServerIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        goManager.requestGoServerExit(wait: 0.6)
        goManager.stopServerIfRunning()
        print("applicationWillTerminate")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        goManager.requestGoServerExit(wait: 0.6)
        goManager.stopServerIfRunning()
        print("applicationShouldTerminate")
        return .terminateNow
    }
}
