//
//  v2rayMuiApp.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import SwiftUI
import AppKit

@main
struct v2rayMuiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 750)
        .commands {
            // 移除默认的文件菜单等
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
        }
    }
}

// MARK: - 应用代理
class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarManager = StatusBarManager.shared
    private let settingsManager = SettingsManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化设置管理器（确保设置文件被创建和加载）
        _ = settingsManager
        // 设置运行时 Dock 图标
        setDockIcon()
        
        // 初始化状态栏
        statusBarManager.showStatusBar()
        
        // 设置应用不在Dock中显示（可选）
        // NSApp.setActivationPolicy(.accessory)
        
        // 设置窗口关闭行为和固定大小
        if let window = NSApplication.shared.windows.first {
            window.delegate = WindowDelegate.shared
            
            // 设置固定窗口大小
            let fixedSize = NSSize(width: 1000, height: 750)
            window.setContentSize(fixedSize)
            window.minSize = fixedSize
            window.maxSize = fixedSize
            
            // 禁用全屏功能
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            // 禁用窗口缩放按钮
            if let zoomButton = window.standardWindowButton(.zoomButton) {
                zoomButton.isEnabled = false
            }
        }
    }
    
    /// 运行时设置 Dock 图标（优先 icns，其次 png）
    private func setDockIcon() {
        let bundle = Bundle.main
        if let icnsURL = bundle.url(forResource: "v2rayMui", withExtension: "icns"),
           let image = NSImage(contentsOf: icnsURL) {
            NSApplication.shared.applicationIconImage = image
            return
        }
        if let pngURL = bundle.url(forResource: "new", withExtension: "png"),
           let image = NSImage(contentsOf: pngURL) {
            NSApplication.shared.applicationIconImage = image
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当用户点击Dock图标时显示主窗口
        if !flag {
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 应用退出时断开连接
        V2RayManager.shared.disconnect()
    }
}

// MARK: - 窗口代理
class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 点击关闭按钮时隐藏窗口而不是退出应用
        sender.orderOut(nil)
        return false
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // 窗口变为活跃时更新状态栏菜单
        if let menuItem = StatusBarManager.shared.statusItem?.menu?.items.first(where: { $0.title.contains("窗口") }) {
            menuItem.title = "隐藏主窗口"
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // 窗口失去焦点时更新状态栏菜单
        if let window = notification.object as? NSWindow, !window.isVisible {
            if let menuItem = StatusBarManager.shared.statusItem?.menu?.items.first(where: { $0.title.contains("窗口") }) {
                menuItem.title = "显示主窗口"
            }
        }
    }
}
