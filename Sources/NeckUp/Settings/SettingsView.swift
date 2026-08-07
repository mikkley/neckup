import SwiftUI

/// 设置窗口：阈值、持续时长、提醒开关等
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var monitor: PostureMonitor

    var body: some View {
        Form {
            Section("姿势提醒") {
                Slider(value: $settings.thresholdDeg, in: -30 ... -5, step: 1) {
                    Text("低头阈值：\(Int(settings.thresholdDeg))°")
                }
                Stepper("持续时长：\(Int(settings.sustainedSec)) 秒",
                        value: $settings.sustainedSec, in: 2 ... 15)
                Toggle("启用低头提醒", isOn: $settings.remindersEnabled)
                Toggle("通知提示音", isOn: $settings.soundEnabled)
            }
            Section("传感器") {
                Button("重新校准零点") { monitor.recalibrate() }
                Toggle("使用模拟数据（无 AirPods 调试）", isOn: $settings.mockMode)
                Text("模拟数据开关需重启 App 后生效；也可用 --mock 启动参数临时开启。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}
