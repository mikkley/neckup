import NeckUpCore
import SwiftUI

/// 休息段微游戏容器：像素风 Canvas 渲染 M1「石斧史莱姆」（30fps）。
/// 逻辑全在 NeckUpCore.SlimeAxeGame，这里只读 AppState.gameSnapshot 画像素。
struct GameContainerView: View {
    @EnvironmentObject var appState: AppState

    /// 劈中粒子：出生时刻 + 随机初速度，0.6s 寿命
    private struct Particle {
        var born: Date
        var vx: Double
        var vy: Double
    }

    @State private var particles: [Particle] = []

    /// 史莱姆像素画（12×7，G=身体 W=眼白 K=瞳孔）
    private static let slimeArt: [[Character]] = [
        Array("....GGGG...."),
        Array("..GGGGGGGG.."),
        Array(".GGGGGGGGGG."),
        Array("GGKGGGGGGKGG"),
        Array("GGGGGGGGGGGG"),
        Array(".GGGGGGGGGG."),
        Array("..G.G..G.G.."),
    ]

    private static let pixel: CGFloat = 4
    private static let axeZone: CGFloat = 52   // 底部斧头区高度

    var body: some View {
        VStack(spacing: 2) {
            topBar
            TimelineView(.periodic(from: .now, by: 1.0 / 30)) { context in
                Canvas { ctx, size in
                    guard let snap = appState.gameSnapshot else { return }
                    drawSlime(ctx: &ctx, size: size, snap: snap)
                    drawAxe(ctx: &ctx, size: size, snap: snap)
                    drawParticles(ctx: &ctx, size: size, now: context.date)
                }
            }
            .frame(maxHeight: .infinity)
            .onChange(of: appState.gameSnapshot?.kills) { _, _ in spawnParticles() }
            bottomLine
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(height: 280)
        .background(Color(red: 0.06, green: 0.08, blue: 0.14))   // 贴岛深色底
        .overlay(alignment: .top) { safetyHintBanner }
    }

    // MARK: 顶部信息条 / 底部文案

    private var topBar: some View {
        HStack {
            Text("水滴 ×\(appState.gameSnapshot?.droplets ?? 0)")
            Spacer()
            if let combo = appState.gameSnapshot?.combo, combo >= 2 {
                Text("连击 ×\(combo)")
                    .foregroundStyle(.yellow)
            }
            Spacer()
            Text("\(appState.gameSnapshot?.remainingSec ?? 0)s")
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.85))
    }

    /// 底部一行：结算 > 临时提示 > 默认引导（零学习）
    private var bottomLine: some View {
        let snap = appState.gameSnapshot
        let text: String = if let result = snap?.result {
            "打跑啦！往复 \(result.reps) 个 · 最高连击 \(result.maxCombo) · 水滴 +\(result.droplets) 🎉"
        } else if let msg = snap?.message {
            msg
        } else {
            "慢慢点头，劈中史莱姆"
        }
        return Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .frame(height: 16)
    }

    /// 首次进入的一次性安全提示（设计文档 §7）
    @ViewBuilder
    private var safetyHintBanner: some View {
        if let hint = appState.safetyHint {
            Text(hint)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 1.0, green: 0.82, blue: 0.45), in: Capsule())
                .padding(.top, 26)
        }
    }

    // MARK: Canvas 绘制

    /// 史莱姆按行下落（每格 = 可玩区高 / totalRows）
    private func drawSlime(ctx: inout GraphicsContext, size: CGSize, snap: SlimeAxeGame.Snapshot) {
        let rows = max(snap.totalRows, 1)
        let rowHeight = (size.height - Self.axeZone) / CGFloat(rows)
        let origin = CGPoint(x: size.width / 2 - 6 * Self.pixel,
                             y: rowHeight * CGFloat(snap.slimeRow) + 6)
        for (r, row) in Self.slimeArt.enumerated() {
            for (c, ch) in row.enumerated() {
                let color: Color? = switch ch {
                case "G": Color(red: 0.35, green: 0.85, blue: 0.45)
                case "W": .white
                case "K": .black
                default: nil
                }
                if let color {
                    let rect = CGRect(x: origin.x + CGFloat(c) * Self.pixel,
                                      y: origin.y + CGFloat(r) * Self.pixel,
                                      width: Self.pixel, height: Self.pixel)
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
    }

    /// 斧头随手低头进度劈下（柄绕尾端旋转 -60° → +20°）
    private func drawAxe(ctx: inout GraphicsContext, size: CGSize, snap: SlimeAxeGame.Snapshot) {
        let pivot = CGPoint(x: size.width / 2, y: size.height - 26)
        let angle = Angle.degrees(-60 + snap.pitchProgress * 80)
        var c = ctx
        c.translateBy(x: pivot.x, y: pivot.y)
        c.rotate(by: angle)
        // 柄（棕）
        c.fill(Path(CGRect(x: -3, y: -34, width: 6, height: 34)),
               with: .color(Color(red: 0.55, green: 0.35, blue: 0.2)))
        // 斧刃（浅灰像素块）
        c.fill(Path(CGRect(x: -16, y: -44, width: 20, height: 14)),
               with: .color(Color(red: 0.75, green: 0.78, blue: 0.85)))
        c.fill(Path(CGRect(x: -20, y: -40, width: 6, height: 8)),
               with: .color(Color(red: 0.75, green: 0.78, blue: 0.85)))
    }

    // MARK: 粒子

    private func spawnParticles() {
        guard let snap = appState.gameSnapshot, snap.kills > 0 else { return }
        let now = Date()
        particles = (0 ..< 12).map { _ in
            Particle(born: now,
                     vx: Double.random(in: -90 ... 90),
                     vy: Double.random(in: -140 ... -30))
        }
    }

    private func drawParticles(ctx: inout GraphicsContext, size: CGSize, now: Date) {
        guard let snap = appState.gameSnapshot else { return }
        let rows = max(snap.totalRows, 1)
        let rowHeight = (size.height - Self.axeZone) / CGFloat(rows)
        let origin = CGPoint(x: size.width / 2,
                             y: rowHeight * CGFloat(snap.lastKillRow ?? 0) + 20)
        for p in particles {
            let age = now.timeIntervalSince(p.born)
            guard age <= 0.6 else { continue }
            let x = origin.x + p.vx * age
            let y = origin.y + p.vy * age + 260 * age * age   // 像素重力
            let alpha = max(0, 1 - age / 0.6)
            ctx.fill(Path(CGRect(x: x, y: y, width: 3, height: 3)),
                     with: .color(Color(red: 0.35, green: 0.85, blue: 0.45).opacity(alpha)))
        }
    }
}
