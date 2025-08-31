//
//  StatusBarIcon.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import AppKit
import SwiftUI

// MARK: - 状态栏图标管理
struct StatusBarIcon {
    
    // MARK: - 创建状态栏图标
    static func createIcon(isConnected: Bool) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 绘制圆形背景
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
        
        if isConnected {
            // 连接状态：绿色
            NSColor.systemGreen.setFill()
        } else {
            // 断开状态：红色
            NSColor.systemRed.setFill()
        }
        
        path.fill()
        
        // 绘制边框
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        // 绘制中心点
        let centerRect = NSRect(x: 7, y: 7, width: 4, height: 4)
        let centerPath = NSBezierPath(ovalIn: centerRect)
        NSColor.white.setFill()
        centerPath.fill()
        
        image.unlockFocus()
        
        // 设置为模板图像以适应系统主题
        image.isTemplate = false
        
        return image
    }
    
    // MARK: - 创建菜单图标
    static func createMenuIcon(for config: V2RayConfig) -> NSImage? {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 根据配置类型绘制不同图标
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 2, yRadius: 2)
        
        switch config.network {
        case "tcp":
            NSColor.systemBlue.setFill()
        case "ws":
            NSColor.systemPurple.setFill()
        case "h2":
            NSColor.systemOrange.setFill()
        case "kcp":
            NSColor.systemTeal.setFill()
        case "quic":
            NSColor.systemGreen.setFill()
        default:
            NSColor.systemGray.setFill()
        }
        
        path.fill()
        
        // 绘制边框
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    // MARK: - 创建系统图标
    static func systemIcon(named: String) -> NSImage? {
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: named, accessibilityDescription: nil)
        } else {
            // macOS 10.15 兼容性
            switch named {
            case "play.circle":
                return NSImage(named: NSImage.statusAvailableName)
            case "stop.circle":
                return NSImage(named: NSImage.statusUnavailableName)
            case "eye":
                return NSImage(named: NSImage.revealFreestandingTemplateName)
            case "eye.slash":
                return NSImage(named: NSImage.stopProgressTemplateName)
            case "info.circle":
                return NSImage(named: NSImage.infoName)
            case "power":
                return NSImage(named: NSImage.stopProgressTemplateName)
            default:
                return nil
            }
        }
    }
}

// MARK: - SwiftUI 预览
struct StatusBarIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            if let connectedIcon = StatusBarIcon.createIcon(isConnected: true) {
                Image(nsImage: connectedIcon)
                    .frame(width: 18, height: 18)
            }
            
            if let disconnectedIcon = StatusBarIcon.createIcon(isConnected: false) {
                Image(nsImage: disconnectedIcon)
                    .frame(width: 18, height: 18)
            }
        }
        .padding()
    }
}