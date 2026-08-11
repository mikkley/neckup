import AppKit
import SwiftUI

/// 设置窗口：灵敏度、持续时长、提醒开关等（零学习：不暴露角度）
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var monitor: PostureMonitor

    /// 灵敏度三档 ↔ 内部阈值角度的映射
    private var sensitivity: Binding<Int> {
        Binding(
            get: { settings.thresholdDeg >= -10 ? 0 : (settings.thresholdDeg <= -20 ? 2 : 1) },
            set: { settings.thresholdDeg = [-10.0, -15.0, -20.0][$0] }
        )
    }

    var body: some View {
        Form {
            Section("姿势提醒") {
                Picker("提醒灵敏度", selection: sensitivity) {
                    Text("严格").tag(0)
                    Text("标准").tag(1)
                    Text("宽松").tag(2)
                }
                .pickerStyle(.segmented)
                Text("严格：稍微低头就提醒；宽松：低得比较明显才提醒。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper("持续时长：\(Int(settings.sustainedSec)) 秒",
                        value: $settings.sustainedSec, in: 2 ... 15)
                Toggle("启用低头提醒", isOn: $settings.remindersEnabled)
                Toggle("音效与提示音", isOn: $settings.soundEnabled)
            }
            Section("休息段微游戏") {
                Toggle("番茄休息时打怪舒展", isOn: $settings.gameEnabled)
                Toggle("佛系模式（山峰不枯萎）", isOn: $settings.zenMode)
                Text("休息 5 分钟里，用缓慢的颈部动作打跑僵硬怪；可随时关闭。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("灵动岛") {
                Picker("显示在", selection: $settings.displayID) {
                    Text("自动（刘海屏优先）").tag("")
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        Text(screen.localizedName).tag(NotchGeometry.displayID(of: screen))
                    }
                }
            }
            Section("传感器") {
                Button("坐直后点此校准") { monitor.recalibrate() }
                Toggle("使用模拟数据（无 AirPods 调试）", isOn: $settings.mockMode)
                Text("模拟数据开关需重启 App 后生效；也可用 --mock 启动参数临时开启。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
    }
}
