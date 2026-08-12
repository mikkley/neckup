import NeckUpCore
import SwiftUI

/// 岛内容：收缩 / 展开 / 提醒 三态
struct NotchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var monitor: PostureMonitor
    @EnvironmentObject var pomodoro: PomodoroTimer
    @EnvironmentObject var stats: StatsStore
    @EnvironmentObject var settings: AppSettings

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
                Group {
                    if let tutorial = appState.pendingTutorial {
                        TutorialCardView(monster: tutorial)
                    } else {
                        GameContainerView()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(islandBackground)
        .onHover { appState.hoverChanged($0) }
        .onTapGesture { appState.toggleLockExpand() }
        .onAppear {
            breathing = true
            pulsing = (appState.islandState == .reminder)   // 启动即提醒态时脉冲也要起
        }
        .onChange(of: appState.islandState) { _, s in
            pulsing = (s == .reminder)
        }
    }

    // MARK: 收缩态（也是提醒态的载体）

    private var collapsedRow: some View {
        Group {
            if appState.islandState == .reminder {
                // 提醒态：整幅暖黄 + 文案（底对齐，落在刘海下缘以下的加高区，不被开孔遮挡）
                HStack(spacing: 8) {
                    statusDot
                    Text(monitor.reminderText)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(.black.opacity(0.85))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 6)
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
        if appState.islandState == .game { return "" }   // 对局中不显示（评估豁免期，避免陈旧文案）
        if !monitor.isMonitoring { return L10n.statusPaused }
        if !monitor.isWearing { return L10n.statusNotWearing }
        switch monitor.status {
        case .good: return L10n.statusGood
        case .borderline: return L10n.statusLow
        case .bad: return L10n.statusBad
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
        if !monitor.isMonitoring { return L10n.statusPaused }
        if !monitor.isWearing { return L10n.statusNotWearing }
        return ""
    }

    // MARK: 展开态卡片（直接排在岛背景上，无额外卡片层）

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
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        // 静音开关（与菜单栏「静音音效」、设置页同一开关）
                        Button {
                            settings.soundEnabled.toggle()
                        } label: {
                            Image(systemName: settings.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.45))
                                .frame(width: 16, height: 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // 设置入口（与菜单栏「设置…」等效），放在角落不抢信息
                        Button {
                            NotificationCenter.default.post(name: .neckUpShowSettings, object: nil)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.45))
                                .frame(width: 16, height: 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    // 姿态镜像小人：比水平仪直观，转头/低头/侧倾都能看出来
                    HeadAvatar(pose: monitor.headPose)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .font(.callout)

            if monitor.permissionDenied {
                // 无权限：引导行替换提示行（控制行保留——番茄钟不依赖传感器）
                permissionGuide
            } else {
                if monitor.calibrationFlash {
                    Text(L10n.calibratedFlash)
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else {
                    Text(L10n.avatarHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                pomodoroControls
                Spacer()
                Button(monitor.isMonitoring ? L10n.pauseMonitoring : L10n.resumeMonitoring) {
                    monitor.isMonitoring.toggle()
                }
                .buttonStyle(.bordered)
                Button(L10n.recalibrate) { monitor.recalibrate(flash: true) }
                    .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(height: 156)
    }

    /// 当前姿势状态 → 直接告诉用户好不好、该怎么做
    private var statusSentence: String {
        guard monitor.isMonitoring else { return L10n.sentencePaused }
        guard monitor.isWearing else { return L10n.sentenceNotWearing }
        switch monitor.status {
        case .good: return L10n.sentenceGood
        case .borderline: return L10n.sentenceLow
        case .bad: return L10n.sentenceBad
        case .idle: return ""
        }
    }

    /// 今日评分 → 三档状态词
    private var dayStatusWord: String {
        if !hasDataToday { return L10n.dayNoData }
        switch stats.today.score {
        case 80...: return L10n.dayGreat
        case 60...: return L10n.dayOk
        default: return L10n.dayWarning
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
        if !hasDataToday { return L10n.dayDescNoData }
        switch stats.today.score {
        case 80...: return L10n.dayDescGreat
        case 60...: return L10n.dayDescOk
        default: return L10n.dayDescWarning
        }
    }

    private var hasDataToday: Bool {
        stats.today.goodPostureSec + stats.today.badPostureSec > 0
    }

    @ViewBuilder
    private var pomodoroControls: some View {
        switch pomodoro.phase {
        case .idle:
            Button(L10n.startPomodoro("25:00")) { pomodoro.start() }
                .buttonStyle(.borderedProminent)
        case .focus, .rest:
            HStack(spacing: 8) {
                Text(pomodoro.phase == .focus ? L10n.focusTime(pomodoro.displayString) : L10n.restTime(pomodoro.displayString))
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                Button(pomodoro.isPaused ? L10n.resumeTimer : L10n.pauseTimer) { pomodoro.togglePause() }
                    .buttonStyle(.bordered)
                Button(L10n.resetTimer) { pomodoro.reset() }
                    .buttonStyle(.bordered)
            }
        }
    }

    /// F7：未授权引导（文案从简，适配无刘海屏的窄卡片）
    private var permissionGuide: some View {
        HStack(spacing: 8) {
            Text(L10n.permNeeded)
                .font(.footnote)
                .foregroundStyle(.orange)
            Button(L10n.openSystemSettings) {
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
            // 实心黑：半透明在浅色壁纸上会让岛「发白」，看起来不贴合屏幕边缘
            UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
                .fill(Color.black)
        }
    }
}
