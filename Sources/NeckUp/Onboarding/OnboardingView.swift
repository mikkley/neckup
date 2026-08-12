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
            Text(L10n.welcomeTitle)
                .font(.title.weight(.semibold))
            Text(L10n.welcomeBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(L10n.welcomeAirpods)
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
            Text(L10n.permTitle)
                .font(.title2.weight(.semibold))
            Text(L10n.permBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if permissionGranted {
                Text(L10n.permGranted)
                    .foregroundStyle(.green)
            } else if authStatus == .denied || authStatus == .restricted {
                Text(L10n.permDenied)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                Button(L10n.openSystemSettings) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                Button(L10n.permAuthorize) { monitor.start() }
                    .buttonStyle(.borderedProminent)
            }

            if permissionGranted, !monitor.isWearing {
                Text(L10n.permNoAirpods)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    // MARK: 第 3 步：校准 + 试动

    private var calibratePage: some View {
        VStack(spacing: 12) {
            Text(L10n.calTitle)
                .font(.title2.weight(.semibold))

            HeadAvatar(pose: monitor.headPose)
                .frame(width: 140, height: 140)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !monitor.isWearing {
                Text(L10n.calNoAirpods)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else if calibrated {
                Text(L10n.calDone)
                    .font(.footnote)
                    .foregroundStyle(.green)
            } else {
                Text(L10n.calInstruction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(L10n.calButton) {
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
            Text(L10n.obGameTitle)
                .font(.title2.weight(.semibold))
            Text(L10n.obGameBody)
                .foregroundStyle(.secondary)

            Form {
                Toggle(L10n.obGameToggle, isOn: $settings.gameEnabled)
                Picker(L10n.obBreakPicker, selection: $settings.breakIntervalMin) {
                    Text(L10n.followPomodoro).tag(0.0)
                    Text(L10n.everyMinutes(30)).tag(30.0)
                    Text(L10n.everyMinutes(45)).tag(45.0)
                    Text(L10n.everyMinutes(60)).tag(60.0)
                }
                Picker(L10n.sensitivityLabel, selection: sensitivity) {
                    Text(L10n.sensStrict).tag(0)
                    Text(L10n.sensStandard).tag(1)
                    Text(L10n.sensRelaxed).tag(2)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)

            Text(L10n.obSettingsHint)
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: 底部导航

    private var bottomBar: some View {
        HStack {
            Button(L10n.back) { step -= 1 }
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
                Button(L10n.next) { step += 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else if step > 3 {
                Button(L10n.done) { onFinish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            // step == 3（方向校准）页内自带「完成 / 跳过」，底部不再放按钮
        }
        .controlSize(.large)
    }
}

