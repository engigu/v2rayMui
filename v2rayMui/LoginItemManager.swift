import Foundation
import ServiceManagement

enum LoginItemManager {
    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        #if DEBUG
        // Xcode/DEBUG 运行时，不执行真实变更，仅返回当前状态
        return isEnabled()
        #else
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return isEnabled()
            } catch {
                NSLog("[LoginItem] change failed: \(error.localizedDescription)")
                return isEnabled()
            }
        } else {
            // 旧系统暂不支持
            return false
        }
        #endif
    }
}


