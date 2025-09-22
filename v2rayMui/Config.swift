import Foundation

enum AppConfig {
    // 默认服务端口：Xcode(调试) 58081，打包运行 58080
    #if DEBUG
    static let serverPort: Int = 58081
    #else
    static let serverPort: Int = 58080
    #endif
    static let serverAddress: String = "localhost"
}


