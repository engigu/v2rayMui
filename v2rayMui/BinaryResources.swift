import Foundation

enum BinaryResources {
    /// 优先从 Bundle 的 Binaries 子目录查找；若无文件夹引用，则在整个 Bundle 内兜底搜索同名文件。
    static func url(for fileName: String) -> URL? {
        if let u = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Binaries") {
            return u
        }
        // 兜底：未以“文件夹引用”方式添加时，资源可能被扁平复制到根目录
        if let all = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: nil) {
            return all.first { $0.lastPathComponent == fileName }
        }
        return nil
    }

    static func path(for fileName: String) -> String? {
        url(for: fileName)?.path
    }

    /// 将 Bundle 内的二进制复制到应用支持目录，并赋予可执行权限，返回可执行路径。
    static func installToApplicationSupport(fileName: String) throws -> String {
        let fm = FileManager.default
        guard let srcURL = url(for: fileName) else {
            throw NSError(domain: "BinaryResources", code: 1, userInfo: [NSLocalizedDescriptionKey: "Resource not found: \(fileName)"])
        }
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let bundleId = Bundle.main.bundleIdentifier ?? "v2rayMui"
        let dstDir = appSupport.appendingPathComponent(bundleId).appendingPathComponent("Binaries")
        try fm.createDirectory(at: dstDir, withIntermediateDirectories: true)
        let dstURL = dstDir.appendingPathComponent(fileName)
        if fm.fileExists(atPath: dstURL.path) {
            try fm.removeItem(at: dstURL)
        }
        try fm.copyItem(at: srcURL, to: dstURL)
        // 赋予可执行权限（rwxr-xr-x）
        var attrs = [FileAttributeKey.posixPermissions: NSNumber(value: Int16(0o755))]
        try fm.setAttributes(attrs, ofItemAtPath: dstURL.path)
        return dstURL.path
    }
}


