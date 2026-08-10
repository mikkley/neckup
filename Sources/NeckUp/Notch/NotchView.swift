import NeckUpCore
import SwiftUI

/// 岛内容：收缩 / 展开 / 提醒 三态
struct NotchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var monitor: PostureMonitor
    @EnvironmentObject var pomodoro: PomodoroTimer
    @EnvironmentObject var stats: StatsStore
    @EnvironmentObject var codex: CodexStore

    @State private var breathing = false
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 0) {
            collapsedRow
            if appState.islandState == .expanded {
                expandedCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if appState.islandState == .game {
                GameContainerView()
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
        Group {
            if appState.islandState == .reminder {
                // 提醒态：整幅暖黄 + 文案
                HStack(spacing: 8) {
                    statusDot
                    Text(monitor.reminderText)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(.black.opacity(0.85))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.geometry.hasNotch {
                // 刘海屏：状态分列刘海两侧，中间留空给刘海——一眼可见，无需点开
                HStack(spacing: 0) {
                    postureSide
                        .frame(width: NotchGeometry.sideWidth, height: 24, alignment: .trailing)
                    Color.clear
                        .frame(width: appState.geometry.notchWidth)
                    pomodoroSide
                        .frame(width: NotchGeometry.sideWidth, height: 24, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            } else {
                // 无刘海胶囊：原单行内容
                HStack(spacing: 8) {
                    statusDot
                    if !trailingText.isEmpty {
                        Text(trailingText)
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
            }
        }
    }

    /// 刘海左侧：状态小字 + 呼吸圆点（贴刘海右对齐）
    private var postureSide: some View {
        HStack(spacing: 5) {
            if !postureWord.isEmpty {
                Text(postureWord)
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(monitor.status == .good || monitor.status == .idle
                                     ? .white.opacity(0.65) : dotColor)
            }
            statusDot
        }
    }

    /// 刘海右侧：番茄钟状态（贴刘海左对齐；平时留白）
    private var pomodoroSide: some View {
        HStack(spacing: 4) {
            if pomodoro.phase != .idle {
                Image(systemName: pomodoro.phase == .focus ? "brain.head.profile" : "cup.and.saucer")
                    .font(.system(size: 9))
                Text(pomodoro.displayString)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
            }
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    /// 左侧状态小字（零学习：直接说状态，不给数字）
    private var postureWord: String {
        if !monitor.isMonitoring { return "已暂停" }
        if !monitor.isWearing { return "未佩戴" }
        switch monitor.status {
        case .good: return "挺好"
        case .borderline: return "有点低"
        case .bad: return "快抬头"
        case .idle: return ""
        }
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

    /// 收缩态右侧：番茄倒计时 > 已暂停 > 未佩戴；平时只留呼吸圆点，不给数字
    private var trailingText: String {
        if pomodoro.phase != .idle { return pomodoro.displayString }
        if !monitor.isMonitoring { return "已暂停" }
        if !monitor.isWearing { return "未佩戴" }
        return ""
    }

    // MARK: 展开态卡片（~180pt 玻璃拟态）

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    // 零学习：只给状态和建议，不显示角度数值
                    Text(statusSentence)
                    // 一句人话总结；详细数字在菜单栏「今日统计」里
                    Text(daySummarySentence)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(dayStatusWord)
                    .foregroundStyle(dayStatusColor)
                postureGauge
            }
            .font(.callout)

            Text("小球跟着头动，居中就是坐直了")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                pomodoroControls
                Spacer()
                Button(monitor.isMonitoring ? "暂停监测" : "继续监测") {
                    monitor.isMonitoring.toggle()
                }
                .buttonStyle(.bordered)
                Button("坐直校准") { monitor.recalibrate() }
                    .buttonStyle(.bordered)
            }
            .controlSize(.small)

            growthRow

            if monitor.permissionDenied {
                permissionGuide
            }
        }
        .padding(12)
        .frame(height: 180)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    /// 成长行（G-3）：像素山峰当前档 + 水滴数 + 五怪星级 mini（1/10/30 击败 → 1/2/3 星）
    private var growthRow: some View {
        HStack(spacing: 12) {
            MountainPixel(stage: codex.mountain.stage)
                .frame(width: 24, height: 16)
            Text(codex.mountain.stage.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("水滴 \(codex.mountain.droplets)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ForEach(MonsterType.allCases, id: \.self) { monster in
                MonsterStarsMini(monster: monster, stars: codex.stars(for: monster))
            }
        }
    }

    /// 当前姿势状态 → 直接告诉用户好不好、该怎么做
    private var statusSentence: String {
        guard monitor.isMonitoring else { return "监测已暂停" }
        guard monitor.isWearing else { return "戴上 AirPods 开始守护" }
        switch monitor.status {
        case .good: return "姿势不错，继续保持"
        case .borderline: return "有点低头，抬一点"
        case .bad: return "低头太久了，抬一点 🐢"
        case .idle: return ""
        }
    }

    /// 今日评分 → 三档状态词
    private var dayStatusWord: String {
        if !hasDataToday { return "还没开始记录" }
        switch stats.today.score {
        case 80...: return "今天很棒"
        case 60...: return "今天还行"
        default: return "要注意了"
        }
    }

    private var dayStatusColor: Color {
        guard hasDataToday else { return .secondary }
        switch stats.today.score {
        case 80...: return .green
        case 60...: return .yellow
        default: return .red
        }
    }

    /// 一句人话的今日总结，不给数字
    private var daySummarySentence: String {
        if !hasDataToday { return "今天的记录会显示在这里" }
        switch stats.today.score {
        case 80...: return "今天状态很棒，继续保持"
        case 60...: return "今天还不错，记得偶尔抬头"
        default: return "今天低头有点多，多抬头休息"
        }
    }

    private var hasDataToday: Bool {
        stats.today.goodPostureSec + stats.today.badPostureSec > 0
    }

    /// 竖直水平仪：低头小球往下掉、抬头往上升，居中就是坐直（零学习）
    private var postureGauge: some View {
        ZStack {
            Capsule().fill(.white.opacity(0.12))
            // 居中参考线
            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: 8, height: 1)
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                // pitchDeg 负值=低头 → 小球向下（offset.y 正值向下）
                .offset(y: -CGFloat(max(-1, min(1, monitor.pitchDeg / 30))) * 22)
                .animation(.easeOut(duration: 0.2), value: monitor.pitchDeg)
        }
        .frame(width: 12, height: 56)
    }

    @ViewBuilder
    private var pomodoroControls: some View {
        switch pomodoro.phase {
        case .idle:
            Button("开始番茄 25:00") { pomodoro.start() }
                .buttonStyle(.borderedProminent)
        case .focus, .rest:
            HStack(spacing: 8) {
                Text(pomodoro.phase == .focus ? "专注 \(pomodoro.displayString)" : "休息 \(pomodoro.displayString)")
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                Button(pomodoro.isPaused ? "继续" : "暂停") { pomodoro.togglePause() }
                    .buttonStyle(.bordered)
                Button("重置") { pomodoro.reset() }
                    .buttonStyle(.bordered)
            }
        }
    }

    /// F7：未授权引导
    private var permissionGuide: some View {
        HStack(spacing: 8) {
            Text("需要「运动与健身」权限才能读取 AirPods 数据")
                .font(.footnote)
                .foregroundStyle(.orange)
            Button("打开系统设置") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
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

// MARK: - 成长行子组件

/// 像素山峰 mini（6×4 像素格）：秃山灰 → 青山绿 → 雪峰白顶
private struct MountainPixel: View {
    let stage: MountainState.Stage

    var body: some View {
        Canvas { ctx, size in
            let px = size.width / 6
            let py = size.height / 4
            // 山体三角（从底到顶每行内收一格）
            let rows: [[Int]] = [[0, 5], [1, 4], [2, 3], [2, 3]]
            let bodyColor: Color = switch stage {
            case .barren: Color(red: 0.5, green: 0.48, blue: 0.45)
            case .green, .snowPeak: Color(red: 0.35, green: 0.75, blue: 0.42)
            }
            for (r, cols) in rows.enumerated() {
                for c in cols[0] ... cols[1] {
                    ctx.fill(Path(CGRect(x: CGFloat(c) * px, y: CGFloat(r) * py, width: px, height: py)),
                             with: .color(bodyColor))
                }
            }
            // 雪峰：顶两格盖雪
            if stage == .snowPeak {
                for c in 2 ... 3 {
                    ctx.fill(Path(CGRect(x: CGFloat(c) * px, y: 0, width: px, height: py * 2)),
                             with: .color(.white))
                }
            }
        }
    }
}

/// 单怪星级 mini：主题色小方块 + 3 个星点（点亮数 = 星级）
private struct MonsterStarsMini: View {
    let monster: MonsterType
    let stars: Int

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(stars > 0 ? monster.themeColor : monster.themeColor.opacity(0.3))
                .frame(width: 6, height: 6)
            HStack(spacing: 2) {
                ForEach(0 ..< 3, id: \.self) { i in
                    Circle()
                        .fill(i < stars ? Color.yellow : Color.white.opacity(0.2))
                        .frame(width: 3, height: 3)
                }
            }
        }
        .help(monster.displayName)
    }
}
