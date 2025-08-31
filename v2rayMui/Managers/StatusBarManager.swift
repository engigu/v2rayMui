//
//  StatusBarManager.swift
//  test11
//
//  Created by SayHeya on 2025/3/13.
//

import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - 状态栏管理器
class StatusBarManager: ObservableObject {
    static let shared = StatusBarManager()
    
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupStatusBar()
        setupPopover()
        observeConnectionStatus()
    }
    
    // MARK: - 状态栏设置
    
    /// 设置状态栏
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else { return }
        
        // 设置初始图标
        updateStatusBarIcon(for: .disconnected)
        
        // 设置点击事件
        if let button = statusItem.button {
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    /// 设置弹出窗口
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: StatusBarPopoverView())
    }
    
    /// 创建状态栏菜单
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // 连接状态显示
        let statusMenuItem = NSMenuItem(title: "状态: 未连接", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 连接/断开按钮
        let connectionMenuItem = NSMenuItem(title: "连接", action: #selector(toggleConnection), keyEquivalent: "")
        connectionMenuItem.target = self
        menu.addItem(connectionMenuItem)
        

        
        menu.addItem(NSMenuItem.separator())
        
        // 显示/隐藏主窗口
        let showWindowMenuItem = NSMenuItem(title: "显示主窗口", action: #selector(toggleMainWindow), keyEquivalent: "")
        showWindowMenuItem.target = self
        menu.addItem(showWindowMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 配置管理
        let configsMenuItem = NSMenuItem(title: "配置管理", action: nil, keyEquivalent: "")
        let configsSubmenu = createConfigsSubmenu()
        configsMenuItem.submenu = configsSubmenu
        menu.addItem(configsMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 关于
        let aboutMenuItem = NSMenuItem(title: "关于 V2Ray客户端", action: #selector(showAbout), keyEquivalent: "")
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)
        
        // 退出
        let quitMenuItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        return menu
    }
    
    /// 创建配置子菜单
    private func createConfigsSubmenu() -> NSMenu {
        let submenu = NSMenu()
        
        let configs = ConfigManager.shared.configs
        
        if configs.isEmpty {
            let noConfigItem = NSMenuItem(title: "无可用配置", action: nil, keyEquivalent: "")
            noConfigItem.isEnabled = false
            submenu.addItem(noConfigItem)
        } else {
            for config in configs {
                let configItem = NSMenuItem(title: config.name, action: #selector(selectConfig(_:)), keyEquivalent: "")
                configItem.target = self
                configItem.representedObject = config
                
                // 标记当前选中的配置
                if ConfigManager.shared.selectedConfig?.id == config.id {
                    configItem.state = .on
                }
                
                submenu.addItem(configItem)
            }
        }
        
        return submenu
    }
    
    // MARK: - 状态更新
    
    /// 监听连接状态变化
    private func observeConnectionStatus() {
        V2RayManager.shared.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateStatusBarIcon(for: status)
                self?.updateMenu(for: status)
            }
            .store(in: &cancellables)
        
        ConfigManager.shared.$selectedConfig
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateConfigsMenu()
            }
            .store(in: &cancellables)
        
        ConfigManager.shared.$configs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateConfigsMenu()
            }
            .store(in: &cancellables)
    }
    
    /// 更新状态栏图标
    private func updateStatusBarIcon(for status: V2RayConnectionStatus) {
        guard let statusItem = statusItem else { return }
        
        // 优先使用 new.png 作为底图，整体渲染为白色；未连接/错误时叠加斜杠
        if let baseURL = Bundle.main.url(forResource: "new", withExtension: "png"),
           let base = NSImage(contentsOf: baseURL) {
            let targetSize = NSSize(width: 20, height: 20)
            let composed = NSImage(size: targetSize)
            composed.lockFocus()
            let rect = NSRect(origin: .zero, size: targetSize)
            // 先绘制底图
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            // 将图标整体着色为白色（保持 alpha 形状）
            if let ctx = NSGraphicsContext.current {
                let previousOp = ctx.compositingOperation
                ctx.compositingOperation = .sourceAtop
                NSColor.white.setFill()
                NSBezierPath(rect: rect).fill()
                ctx.compositingOperation = previousOp
            }
            // 底部右侧状态点：未连接/错误=红色，连接中=黄色，已连接=绿色
            let dotSize: CGFloat = 6
            let margin: CGFloat = 2
            let dotRect = NSRect(x: rect.maxX - dotSize - margin, y: rect.minY + margin, width: dotSize, height: dotSize)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            switch status {
            case .disconnected:
                NSColor.systemRed.setFill()
            case .connecting:
                NSColor.systemYellow.setFill()
            case .error(_):
                NSColor.systemRed.setFill()
            case .connected:
                NSColor.systemGreen.setFill()
            }
            dotPath.fill()
            composed.unlockFocus()
            composed.isTemplate = false
            statusItem.button?.image = composed
        } else {
            let iconName: String
            switch status {
            case .disconnected:
                iconName = "wifi.slash"
            case .connecting:
                iconName = "wifi.exclamationmark"
            case .connected:
                iconName = "wifi"
            case .error:
                iconName = "wifi.exclamationmark"
            }
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
                image.isTemplate = true
                statusItem.button?.image = image
            }
        }
        
        // 设置工具提示
        statusItem.button?.toolTip = "V2Ray客户端 - \(status.description)"
    }
    
    /// 更新菜单状态
    private func updateMenu(for status: V2RayConnectionStatus) {
        guard let menu = statusItem?.menu else { return }
        
        // 更新状态显示
        if let statusMenuItem = menu.item(at: 0) {
            statusMenuItem.title = "状态: \(status.description)"
        }
        
        // 更新连接按钮
        if let connectionMenuItem = menu.item(at: 2) {
            switch status {
            case .disconnected, .error:
                connectionMenuItem.title = "连接"
                connectionMenuItem.isEnabled = ConfigManager.shared.selectedConfig != nil
            case .connecting:
                connectionMenuItem.title = "连接中..."
                connectionMenuItem.isEnabled = false
            case .connected:
                connectionMenuItem.title = "断开连接"
                connectionMenuItem.isEnabled = true
            }
        }
        

    }
    
    /// 更新配置菜单
    private func updateConfigsMenu() {
        guard let menu = statusItem?.menu,
              let configsMenuItem = menu.items.first(where: { $0.title == "配置管理" }) else { return }
        
        configsMenuItem.submenu = createConfigsSubmenu()
    }
    
    // MARK: - 状态栏交互
    
    @objc private func statusBarButtonClicked() {
//        guard let button = statusItem?.button else { return }
        
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            // 右键显示菜单
            showContextMenu()
        } else {
            // 左键显示弹出窗口
            togglePopover()
        }
    }
    
    private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    private func showContextMenu() {
        guard let statusItem = statusItem else { return }
        
        let menu = createMenu()
        statusItem.popUpMenu(menu)
    }
    
    // MARK: - 菜单动作

    @objc private func toggleConnection() {
        let v2rayManager = V2RayManager.shared
        
        if v2rayManager.connectionStatus.isConnected {
            v2rayManager.disconnect()
        } else {
            guard let config = ConfigManager.shared.selectedConfig else { return }
            v2rayManager.connect(with: config)
        }
    }
    

    
    @objc private func toggleMainWindow() {
        if let window = NSApplication.shared.windows.first {
            if window.isVisible {
                window.orderOut(nil)
                // 隐藏后切换为 accessory，隐藏 Dock 图标
                NSApp.setActivationPolicy(.accessory)
                if let menuItem = statusItem?.menu?.items.first(where: { $0.title.contains("窗口") }) {
                    menuItem.title = "显示主窗口"
                }
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
                // 显示主窗口时，恢复 Dock 图标
                NSApp.setActivationPolicy(.regular)
                if let menuItem = statusItem?.menu?.items.first(where: { $0.title.contains("窗口") }) {
                    menuItem.title = "隐藏主窗口"
                }
            }
        }
    }
    
    @objc private func selectConfig(_ sender: NSMenuItem) {
        guard let config = sender.representedObject as? V2RayConfig else { return }
        ConfigManager.shared.selectConfig(config)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "V2Ray客户端"
        alert.informativeText = "一个简单易用的V2Ray macOS客户端\n\n版本: 1.0.0\n作者: SayHeya"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        // 断开连接
        V2RayManager.shared.disconnect()
        
        // 退出应用
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - 公共方法
    
    /// 显示状态栏
    func showStatusBar() {
        if statusItem == nil {
            setupStatusBar()
        }
    }
    
    /// 隐藏状态栏
    func hideStatusBar() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
}
