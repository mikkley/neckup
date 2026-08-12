import Foundation

/// 本地滚动调试日志：只记关键事件（启动/连接/权限/校准/对局/更新），不记录姿态原始流。
/// 文件在 ~/Library/Application Support/NeckUp/debug.log，超 512KB 截断头部。
enum DebugLog {
    private static let queue = DispatchQueue(label: "neckup.debuglog")
    private static let maxBytes = 512 * 1024
    private static let keepBytes = 256 * 1024

    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeckUp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("debug.log")
    }

    static func log(_ message: String) {
        queue.async {
            let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
            let url = fileURL
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? line.write(to: url, atomically: true, encoding: .utf8)
            }
            truncateIfNeeded(url)
        }
    }

    /// 最近 maxLines 行（issue 预填用）
    static func recent(maxLines: Int = 60) -> String {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return "(无日志)" }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        return lines.suffix(maxLines).joined(separator: "\n")
    }

    /// 导出完整日志到桌面并在 Finder 中显示
    @discardableResult
    static func exportToDesktop() -> URL? {
        let stamp = DateFormatter().then { $0.dateFormat = "yyyyMMdd-HHmm" }.string(from: Date())
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        let dest = desktop.appendingPathComponent("NeckUp-debug-\(stamp).log")
        try? FileManager.default.removeItem(at: dest)
        guard let _ = try? FileManager.default.copyItem(at: fileURL, to: dest) else { return nil }
        return dest
    }

    private static func truncateIfNeeded(_ url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int, size > maxBytes,
              let data = try? Data(contentsOf: url) else { return }
        try? data.suffix(keepBytes).write(to: url)
    }
}

private extension DateFormatter {
    func then(_ body: (DateFormatter) -> Void) -> DateFormatter { body(self); return self }
}
