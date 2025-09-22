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
    private var didCleanup = false

    private func performCleanup() {
        if didCleanup { return }
        didCleanup = true
        goManager.requestGoServerExit(wait: 0.3)
        goManager.stopServerIfRunning()
        SystemProxyManager.clearSystemProxy()
        SystemProxyManager.releaseAuthorization()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标，仅显示状态栏图标
        NSApp.setActivationPolicy(.accessory)
        goManager.startServerIfNeeded()
        // 根据数据库设置系统代理
        SystemProxyManager.setSystemProxyFromDB()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出时清理（只执行一次）
        performCleanup()
        print("applicationWillTerminate")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 提前清理（只执行一次）
        performCleanup()
        print("applicationShouldTerminate")
        return .terminateNow
    }
}
