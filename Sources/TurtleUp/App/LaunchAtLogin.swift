import ServiceManagement

/// 开机自启：SMAppService Login Item（macOS 13+）。
/// 状态以系统为准（用户可在 系统设置 → 通用 → 登录项 里直接管理），不另存 UserDefaults。
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 开关自启；失败只记日志（例如 swift run 裸二进制无法注册登录项）
    static func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                guard service.status != .enabled else { return }
                try service.register()
            } else {
                guard service.status == .enabled else { return }
                try service.unregister()
            }
            DebugLog.log("launchAtLogin \(enabled ? "enabled" : "disabled")")
        } catch {
            DebugLog.log("launchAtLogin setEnabled(\(enabled)) failed: \(error.localizedDescription)")
        }
    }
}
