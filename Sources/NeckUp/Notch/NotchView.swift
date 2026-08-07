import SwiftUI

/// 岛内容：收缩 / 展开 / 提醒 三态
struct NotchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var monitor: PostureMonitor
    @EnvironmentObject var pomodoro: PomodoroTimer
    @EnvironmentObject var stats: StatsStore

    @State private var breathing = false
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 0) {
            collapsedRow
            if appState.islandState == .expanded {
                expandedCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(islandBackground)
        .onHover { appState.hoverChanged($0) }
        .onTapGesture { appState.toggleLockExpand() }
        .onAppear { breathing = true }
        .onChange(of: appState.islandState) { _, s in
            pulsing = (s == .reminder)
        }
    }

    // MARK: 收缩态（也是提醒态的载体）

    private var collapsedRow: some View {
        HStack(spacing: 6) {
            statusDot
            if appState.islandState == .reminder {
                Text(monitor.reminderText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.85))
            } else {
                Text(trailingText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 12)
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .scaleEffect(breathing ? 1.3 : 0.85)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: breathing)
    }

    private var dotColor: Color {
        switch monitor.status {
        case .good: return .green
        case .borderline: return .yellow
        case .bad: return .red
        case .idle: return .gray
        }
    }

    /// 收缩态右侧：番茄倒计时 > 未佩戴 > 坐姿评分
    private var trailingText: String {
        if pomodoro.phase != .idle { return pomodoro.displayString }
        if !monitor.isMonitoring { return "已暂停" }
        if !monitor.isWearing { return "未佩戴" }
        return "\(stats.today.score)"
    }

    // MARK: 展开态卡片（~140pt 玻璃拟态）

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("头部俯仰 \(Int(monitor.pitchDeg))°")
                Spacer()
                Text("今日评分 \(stats.today.score)%")
            }
            .font(.system(size: 12, weight: .medium))

            postureIndicator

            Text("良好 \(Int(stats.today.goodPostureSec / 60)) 分钟 · 低头 \(stats.today.slouchEvents) 次 · 专注 \(Int(stats.today.focusSec / 60)) 分钟")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                pomodoroControls
                Spacer()
                Button(monitor.isMonitoring ? "暂停监测" : "继续监测") {
                    monitor.isMonitoring.toggle()
                }
                Button("重新校准") { monitor.recalibrate() }
            }
            .controlSize(.small)

            if monitor.permissionDenied {
                permissionGuide
            }
        }
        .padding(10)
        .frame(height: 140)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    /// 迷你姿态指示器：小球随俯仰角上下移动
    private var postureIndicator: some View {
        ZStack {
            Capsule().fill(.white.opacity(0.12))
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .offset(y: CGFloat(max(-1, min(1, monitor.pitchDeg / 30))) * 6)
                .animation(.easeOut(duration: 0.2), value: monitor.pitchDeg)
        }
        .frame(height: 16)
    }

    @ViewBuilder
    private var pomodoroControls: some View {
        switch pomodoro.phase {
        case .idle:
            Button("开始番茄 25:00") { pomodoro.start() }
        case .focus, .rest:
            HStack(spacing: 8) {
                Text(pomodoro.phase == .focus ? "专注 \(pomodoro.displayString)" : "休息 \(pomodoro.displayString)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                Button(pomodoro.isPaused ? "继续" : "暂停") { pomodoro.togglePause() }
                Button("重置") { pomodoro.reset() }
            }
        }
    }

    /// F7：未授权引导
    private var permissionGuide: some View {
        HStack(spacing: 8) {
            Text("需要「运动与健身」权限才能读取 AirPods 数据")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Button("打开系统设置") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
    }

    // MARK: 背景

    @ViewBuilder
    private var islandBackground: some View {
        if appState.islandState == .reminder {
            // 提醒态：暖黄色呼吸脉动
            UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
                .fill(Color(red: 1.0, green: 0.82, blue: 0.45).opacity(pulsing ? 0.95 : 0.55))
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulsing)
        } else {
            UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
                .fill(Color.black.opacity(0.82))
        }
    }
}
