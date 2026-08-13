import TurtleUpCore
import SwiftUI

/// 休息段微游戏容器（30fps）：顶部/底部信息条走公共 HUD，Canvas 按 MonsterType 分发到各怪场景。
/// 逻辑全在 TurtleUpCore 各状态机，这里只读 AppState.gameViewState 画像素。
struct GameContainerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var monitor: PostureMonitor

    /// 命中粒子：出生时刻 + 随机初速度，0.6s 寿命
    private struct Particle {
        var born: Date
        var vx: Double
        var vy: Double
    }

    @State private var particles: [Particle] = []

    var body: some View {
        VStack(spacing: 4) {
            topBar
            TimelineView(.periodic(from: .now, by: 1.0 / 30)) { context in
                Canvas { ctx, size in
                    guard let state = appState.gameViewState else { return }
                    switch state {
                    case .slime(let snap):
                        SlimeScene.draw(ctx: &ctx, size: size, snap: snap)
                    case .beetle(let snap):
                        BeetleScene.draw(ctx: &ctx, size: size, snap: snap, now: context.date)
                    case .jelly(let snap):
                        JellyScene.draw(ctx: &ctx, size: size, snap: snap, now: context.date)
                    case .turtle(let snap):
                        TurtleScene.draw(ctx: &ctx, size: size, snap: snap)
                    case .bat(let snap):
                        BatScene.draw(ctx: &ctx, size: size, snap: snap, now: context.date)
                    }
                    drawParticles(ctx: &ctx, size: size, state: state, now: context.date)
                }
            }
            .frame(maxHeight: .infinity)
            .onChange(of: appState.gameViewState?.hud.kills) { _, _ in spawnParticles() }
            bottomLine
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(height: 288)
        .background(Color(red: 0.06, green: 0.08, blue: 0.14),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .overlay(alignment: .top) { safetyHintBanner }
    }

    // MARK: 顶部信息条 / 底部文案（公共 HUD）

    private var topBar: some View {
        HStack {
            Text(L10n.droplets(appState.gameViewState?.hud.droplets ?? 0))
            Spacer()
            if let combo = appState.gameViewState?.hud.combo, combo >= 2 {
                Text(L10n.combo(combo))
                    .foregroundStyle(.yellow)
            }
            Spacer()
            Text("\(appState.gameViewState?.hud.remainingSec ?? 0)s")
            // 常驻迷你小人：实时跟随头部，任何时刻都能确认动作被识别
            HeadAvatar(pose: monitor.headPose)
                .frame(width: 18, height: 18)
                .padding(.leading, 6)
        }
        .font(.system(.footnote, design: .rounded).weight(.medium))
        .foregroundStyle(.white.opacity(0.85))
    }

    /// 底部一行：结算 > 临时提示 > 默认引导（零学习）
    private var bottomLine: some View {
        let hud = appState.gameViewState?.hud
        let text: String = if let result = hud?.result {
            L10n.gameResult(prefix: result.monster.resultPrefix, verb: result.monster.resultVerb,
                            reps: result.reps, maxCombo: result.maxCombo, droplets: result.droplets)
        } else if let msg = hud?.message {
            msg
        } else {
            appState.gameViewState?.monster.guideText ?? ""
        }
        return Text(text)
            .font(.system(.footnote, design: .rounded).weight(.medium))
            .foregroundStyle(.white.opacity(0.75))
            .frame(height: 16)
    }

    /// 首次进入的一次性安全提示（设计文档 §7）
    @ViewBuilder
    private var safetyHintBanner: some View {
        if let hint = appState.safetyHint {
            Text(hint)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(red: 1.0, green: 0.82, blue: 0.45), in: Capsule())
                .padding(.top, 28)
        }
    }

    // MARK: 粒子

    private func spawnParticles() {
        guard appState.gameViewState != nil else { return }
        let now = Date()
        particles = (0 ..< 12).map { _ in
            Particle(born: now,
                     vx: Double.random(in: -90 ... 90),
                     vy: Double.random(in: -140 ... -30))
        }
    }

    private func drawParticles(ctx: inout GraphicsContext, size: CGSize, state: GameViewState, now: Date) {
        let origin = killAnchor(of: state, in: size)
        for p in particles {
            let age = now.timeIntervalSince(p.born)
            guard age <= 0.6 else { continue }
            let x = origin.x + p.vx * age
            let y = origin.y + p.vy * age + 260 * age * age   // 像素重力
            let alpha = max(0, 1 - age / 0.6)
            ctx.fill(Path(CGRect(x: x, y: y, width: 3, height: 3)),
                     with: .color(state.monster.themeColor.opacity(alpha)))
        }
    }

    /// 粒子锚点：M1 在被劈史莱姆那格，其余取画面中央
    private func killAnchor(of state: GameViewState, in size: CGSize) -> CGPoint {
        if case .slime(let snap) = state {
            let rows = max(snap.totalRows, 1)
            let rowHeight = (size.height - SlimeScene.axeZone) / CGFloat(rows)
            return CGPoint(x: size.width / 2, y: rowHeight * CGFloat(snap.lastKillRow ?? 0) + 20)
        }
        return CGPoint(x: size.width / 2, y: size.height / 2)
    }
}
