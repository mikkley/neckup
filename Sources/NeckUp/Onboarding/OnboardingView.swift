import CoreMotion
import NeckUpCore
import SwiftUI

/// 新手引导：欢迎 → 权限 → 校准试动（像素人头跟随）→ 游戏与提醒设置
struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var monitor: PostureMonitor

    /// 完成后回调（窗口控制器关闭窗口）
    let onFinish: () -> Void

    @State private var step = 0
    @State private var calibrated = false
    @State private var authStatus = CMHeadphoneMotionManager.authorizationStatus()
    private let authPoller = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    /// 灵敏度三档 ↔ 内部阈值角度（与设置页同一映射）
    private var sensitivity: Binding<Int> {
        Binding(
            get: { settings.thresholdDeg >= -10 ? 0 : (settings.thresholdDeg <= -20 ? 2 : 1) },
            set: { settings.thresholdDeg = [-10.0, -15.0, -20.0][$0] }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcomePage
                case 1: permissionPage
                case 2: calibratePage
                case 3: directionPage
                default: gamePage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .padding(20)
        .frame(width: 560, height: 420)
        .onReceive(authPoller) { _ in
            authStatus = CMHeadphoneMotionManager.authorizationStatus()
        }
    }

    // MARK: 第 1 步：欢迎

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🐢")
                .font(.system(size: 56))
            Text("欢迎使用 NeckUp")
                .font(.title.weight(.semibold))
            Text("脖子曲度变直这件事，自己是感觉不到的。\nNeckUp 用 AirPods 的传感器实时感知你的低头，\n在该抬头的时候轻轻提醒你。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("使用前请准备好 AirPods（Pro / 3 代 / Max / Beats Fit Pro）")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: 第 2 步：权限

    private var permissionGranted: Bool {
        AppSettings.mockRequested || authStatus == .authorized
    }

    private var permissionPage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: permissionGranted ? "checkmark.circle.fill" : "figure.motion")
                .font(.system(size: 48))
                .foregroundStyle(permissionGranted ? .green : .orange)
                .contentTransition(.symbolEffect(.replace))
            Text("授权「运动与健身」权限")
                .font(.title2.weight(.semibold))
            Text("NeckUp 只读取 AirPods 的头部姿态数据，\n所有记录只保存在本机，绝不上传。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if permissionGranted {
                Text("已授权 ✓")
                    .foregroundStyle(.green)
            } else if authStatus == .denied || authStatus == .restricted {
                Text("权限曾被拒绝，需要在系统设置里手动打开")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                Button("打开系统设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                Button("去授权") { monitor.start() }
                    .buttonStyle(.borderedProminent)
            }

            if permissionGranted, !monitor.isWearing {
                Text("还没检测到 AirPods，戴上后自动开始；也可以先跳过")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    // MARK: 第 3 步：校准 + 试动

    private var calibratePage: some View {
        VStack(spacing: 12) {
            Text("校准你的坐姿")
                .font(.title2.weight(.semibold))

            HeadAvatar(pose: monitor.headPose)
                .frame(width: 140, height: 140)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !monitor.isWearing {
                Text("未检测到 AirPods。可以先跳过，之后随时在岛上点「坐直校准」。")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else if calibrated {
                Text("校准完成！点点头、转转头，小人会跟着你动 🐢")
                    .font(.footnote)
                    .foregroundStyle(.green)
            } else {
                Text("戴上 AirPods，坐直、目视前方，然后点击校准")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("我坐直了，校准") {
                monitor.recalibrate()
                calibrated = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!monitor.isWearing)

            // --logpose 调试：点按钮 → 做动作保持 2s → 回正；日志里按 MARK 分段识别转轴
            if PoseDebugLog.enabled {
                HStack(spacing: 8) {
                    Button("左转") { PoseDebugLog.mark("turn_left") }
                    Button("右转") { PoseDebugLog.mark("turn_right") }
                    Button("低头") { PoseDebugLog.mark("nod_down") }
                    Button("左侧倾") { PoseDebugLog.mark("tilt_left") }
                }
                .controlSize(.small)
                Text("调试：点按钮后做出动作并保持 2 秒，再回正")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: 第 4 步：方向校准（实测符号，自动适配不同 AirPods 轴向）

    private var directionPage: some View {
        DirectionCalibrationView(
            onDone: { step = 4 },
            onSkip: { step = 4 }
        )
    }

    // MARK: 第 5 步：游戏与提醒

    private var gamePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Text("休息时，打一局")
                .font(.title2.weight(.semibold))
            Text("番茄钟休息或活动提醒到点时，岛上会开一局 60 秒头控小游戏——\n用点头、转头、侧屈打跑五只「僵硬怪」，顺便把脖子活动开。\n不玩没有任何惩罚，点一下岛就能收掉。")
                .foregroundStyle(.secondary)

            Form {
                Toggle("休息段打怪小游戏", isOn: $settings.gameEnabled)
                Picker("定时活动提醒", selection: $settings.breakIntervalMin) {
                    Text("跟随番茄钟").tag(0.0)
                    Text("每 30 分钟").tag(30.0)
                    Text("每 45 分钟").tag(45.0)
                    Text("每 60 分钟").tag(60.0)
                }
                Picker("提醒灵敏度", selection: sensitivity) {
                    Text("严格").tag(0)
                    Text("标准").tag(1)
                    Text("宽松").tag(2)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)

            Text("这些以后都能在菜单栏「设置…」里随时修改。")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: 底部导航

    private var bottomBar: some View {
        HStack {
            Button("上一步") { step -= 1 }
                .disabled(step == 0)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0 ..< 5, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: i == step ? 16 : 6, height: 6)
                }
            }
            Spacer()
            if step < 3 {
                Button("下一步") { step += 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else if step > 3 {
                Button("完成") { onFinish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            // step == 3（方向校准）页内自带「完成 / 跳过」，底部不再放按钮
        }
        .controlSize(.large)
    }
}

