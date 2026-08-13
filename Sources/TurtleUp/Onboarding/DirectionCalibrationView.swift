import TurtleUpCore
import SwiftUI

/// 方向校准：先坐直归零，再做两个已知方向的动作，实测数据符号并写入
/// AppSettings.yawSign/rollSign——零点和方向必须一起校准，否则方向是在错误基准上量的。
/// 自动适配不同 AirPods 型号的轴向差异（小人/游戏/提醒共用同一份修正）。
/// 采样率由调用方保证 25Hz（引导窗全程全速；设置页 sheet 打开时拉起）。
struct DirectionCalibrationView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var monitor: PostureMonitor

    /// 全部完成后的回调；跳过/取消回调
    let onDone: () -> Void
    let onSkip: () -> Void
    /// true = 设置页弹窗语义（显示「取消」），false = 引导页（显示「跳过」）
    var cancelStyle = false

    /// 0=坐直归零 1=向左转头 2=左侧倾 3=完成
    @State private var step = 0
    @State private var progress = 0.0   // 保持进度 0~1
    @State private var sum = 0.0        // 保持期间的角度累计（判符号）
    @State private var lastAt: Date?
    /// 已回正待命：每个动作步必须先回正再开始做动作，否则残留偏转会被误判成已完成
    @State private var armed = false

    private let threshold = 18.0   // 识别动作的最小幅度（度）
    private let centerDeg = 8.0    // 低于此角度视为「已回正」
    private let holdSec = 1.2      // 需要保持的时长（秒）

    var body: some View {
        VStack(spacing: 12) {
            Text(L10n.dirCalTitle)
                .font(.title2.weight(.semibold))

            HeadAvatar(pose: monitor.headPose)
                .frame(width: 120, height: 120)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !monitor.isWearing {
                Text(L10n.dirCalNoAirpods)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                Text(instruction)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                if step == 1 || step == 2 {
                    ProgressView(value: progress)
                        .frame(width: 160)
                    Text(armed ? L10n.dirCalDetected : L10n.dirCalRecenter)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            switch step {
            case 0:
                Button(L10n.dirCalStart) {
                    monitor.recalibrate()   // 零点与方向一起校准：先归零再做动作
                    step = 1
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!monitor.isWearing)
            case 3:
                Button(L10n.done, action: onDone)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            default:
                Button(cancelStyle ? L10n.cancel : L10n.skip, action: onSkip)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        }
        .onReceive(monitor.$headPose) { handle($0) }
    }

    private var instruction: String {
        switch step {
        case 0: L10n.dirCalStep1
        case 1: L10n.dirCalStep2
        case 2: L10n.dirCalStep3
        default: L10n.dirCalDone
        }
    }

    /// 实测符号 = 当前符号 × 观测值符号：无论之前是否校准过，都能收敛到「左 = 正」
    private func handle(_ pose: HeadPose) {
        guard step == 1 || step == 2, monitor.isWearing else { return }
        let now = Date()
        let dt = min(lastAt.map { now.timeIntervalSince($0) } ?? 0, 0.2)
        lastAt = now
        let v = step == 1 ? pose.yaw : pose.roll
        // 先回正再动作：未待命时等回正；待命后才开始识别保持
        if !armed {
            if abs(v) < centerDeg { armed = true }
            return
        }
        guard abs(v) >= threshold else { return }   // 幅度不够：保持进度，允许放松再试
        if sum != 0, (v > 0) != (sum > 0) {         // 中途换向：作废重新累计
            sum = 0
            progress = 0
        }
        sum += v
        progress = min(progress + dt / holdSec, 1)
        if progress >= 1 {
            let s = sum > 0 ? 1.0 : -1.0
            if step == 1 { settings.yawSign *= s } else { settings.rollSign *= s }
            step += 1
            progress = 0
            sum = 0
            lastAt = nil
            armed = false   // 下一步同样要求先回正
        }
    }
}
