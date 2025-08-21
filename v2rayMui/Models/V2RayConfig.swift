//
//  V2RayConfig.swift
//  v2rayMui
//
//  Created by SayHeya on 2025/3/13.
//

import Foundation

// MARK: - V2Ray配置数据模型
struct V2RayConfig: Codable, Identifiable {
    var id = UUID()
    var name: String
    var protocolType: String
    var serverAddress: String
    var serverPort: Int
    var userId: String
    var alterId: Int
    var security: String
    var network: String
    var path: String?
    var host: String?
    var tls: String?
    var isEnabled: Bool
    
    // Trojan 特定字段
    var password: String?
    
    // Shadowsocks 特定字段
    var method: String?
    
    // REALITY 特定字段
    var publicKey: String?
    var shortId: String?
    var spiderX: String?
    var fingerprint: String?
    
    // TLS 特定字段
    var allowInsecure: Bool?
    
    // xHTTP 特定字段
    var xhttpMode: String?
    
    init(name: String = "新配置",
         protocolType: String = "vmess",
         serverAddress: String = "",
         serverPort: Int = 443,
         userId: String = "",
         alterId: Int = 0,
         security: String = "auto",
         network: String = "tcp",
         path: String? = nil,
         host: String? = nil,
         tls: String? = nil,
         password: String? = nil,
         method: String? = nil,
         publicKey: String? = nil,
         shortId: String? = nil,
         spiderX: String? = nil,
         fingerprint: String? = nil,
         allowInsecure: Bool? = nil,
         xhttpMode: String? = nil,
         isEnabled: Bool = false) {
        self.name = name
        self.protocolType = protocolType
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.userId = userId
        self.alterId = alterId
        self.security = security
        self.network = network
        self.path = path
        self.host = host
        self.tls = tls
        self.password = password
        self.method = method
        self.publicKey = publicKey
        self.shortId = shortId
        self.spiderX = spiderX
        self.fingerprint = fingerprint
        self.allowInsecure = allowInsecure
        self.xhttpMode = xhttpMode
        self.isEnabled = isEnabled
    }
}

// MARK: - V2Ray连接状态
enum V2RayConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var description: String {
        switch self {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .error(let message):
            return "错误: \(message)"
        }
    }
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

// MARK: - 网络类型枚举
enum NetworkType: String, CaseIterable {
    case tcp = "tcp"
    case kcp = "kcp"
    case ws = "ws"
    case h2 = "h2"
    case quic = "quic"
    case grpc = "grpc"
    case xhttp = "xhttp"
    
    var displayName: String {
        switch self {
        case .tcp: return "TCP"
        case .kcp: return "mKCP"
        case .ws: return "WebSocket"
        case .h2: return "HTTP/2"
        case .quic: return "QUIC"
        case .grpc: return "gRPC"
        case .xhttp: return "xHTTP"
        }
    }
}

// MARK: - 安全类型枚举
enum SecurityType: String, CaseIterable {
    case auto = "auto"
    case aes128gcm = "aes-128-gcm"
    case aes128cfb = "aes-128-cfb"
    case chacha20poly1305 = "chacha20-poly1305"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .auto: return "auto"
        case .aes128gcm: return "aes-128-gcm"
        case .aes128cfb: return "aes-128-cfb"
        case .chacha20poly1305: return "chacha20-poly1305"
        case .none: return "none"
        }
    }
}

// MARK: - 协议类型枚举
enum ProtocolType: String, CaseIterable {
    case vmess = "vmess"
    case vless = "vless"
    case trojan = "trojan"
    case shadowsocks = "shadowsocks"
    
    var displayName: String {
        switch self {
        case .vmess: return "VMess"
        case .vless: return "VLESS"
        case .trojan: return "Trojan"
        case .shadowsocks: return "Shadowsocks"
        }
    }
}

// MARK: - TLS类型枚举
enum TLSType: String, CaseIterable {
    case none = ""
    case tls = "tls"
    case xtls = "xtls"
    case reality = "reality"
    
    var displayName: String {
        switch self {
        case .none: return "无"
        case .tls: return "TLS"
        case .xtls: return "XTLS"
        case .reality: return "REALITY"
        }
    }
}

// MARK: - Shadowsocks加密方法枚举
enum ShadowsocksMethod: String, CaseIterable {
    case aes256gcm = "aes-256-gcm"
    case aes128gcm = "aes-128-gcm"
    case chacha20poly1305 = "chacha20-poly1305"
    case xchacha20poly1305 = "xchacha20-poly1305"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .aes256gcm: return "AES-256-GCM"
        case .aes128gcm: return "AES-128-GCM"
        case .chacha20poly1305: return "ChaCha20-Poly1305"
        case .xchacha20poly1305: return "XChaCha20-Poly1305"
        case .none: return "无加密"
        }
    }
}

// MARK: - 指纹类型枚举（REALITY）
enum FingerprintType: String, CaseIterable {
    case chrome = "chrome"
    case firefox = "firefox"
    case safari = "safari"
    case ios = "ios"
    case android = "android"
    case edge = "edge"
    case _360 = "360"
    case qq = "qq"
    case random = "random"
    
    var displayName: String {
        switch self {
        case .chrome: return "Chrome"
        case .firefox: return "Firefox"
        case .safari: return "Safari"
        case .ios: return "iOS"
        case .android: return "Android"
        case .edge: return "Edge"
        case ._360: return "360浏览器"
        case .qq: return "QQ浏览器"
        case .random: return "随机"
        }
    }
}
