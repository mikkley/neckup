import NeckUpCore
import SwiftUI

/// M5「斜月蝙蝠」场景：斜月下蝙蝠侧向飞过，底部准星随复合瞄准点亮、稳定 1s 锁定放箭
enum BatScene {
    private static let pixel: CGFloat = 4

    /// 蝙蝠展翅（13×5，B=身 K=翼尖）；教学卡/设置页也复用
    static let batUp: [[Character]] = [
        Array("K...........K"),
        Array("KK..BBBBB..KK"),
        Array(".KKBBBBBBBK.."),
        Array("...BBKBKBB..."),
        Array("....B...B...."),
    ]

    /// 蝙蝠收翅（拍翼第二帧）
    private static let batDown: [[Character]] = [
        Array("....BBBBB...."),
        Array("KK.BBBBBBB.KK"),
        Array(".K..BBKBB..K."),
        Array(".....B.B....."),
    ]

    static func draw(ctx: inout GraphicsContext, size: CGSize, snap: MoonBatGame.Snapshot, now: Date) {
        drawMoon(ctx: &ctx, size: size)
        if snap.batActive {
            drawCrosshair(ctx: &ctx, size: size, snap: snap)
            drawBat(ctx: &ctx, size: size, snap: snap, now: now)
        }
    }

    /// 斜月：两圆相切出月牙
    private static func drawMoon(ctx: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: 30)
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24)),
                 with: .color(Color(red: 0.95, green: 0.9, blue: 0.6)))
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 15, width: 22, height: 22)),
                 with: .color(Color(red: 0.06, green: 0.08, blue: 0.14)))   // 与游戏底色一致
    }

    /// 准星：自由跟随头部（yaw 横移镜像、低头下移），目标方位有暗色标记；
    /// 重合进窗口点亮，稳定进度环套在自由准星上
    private static func drawCrosshair(ctx: inout GraphicsContext, size: CGSize, snap: MoonBatGame.Snapshot) {
        // 目标方位标记（暗）：蝙蝠来向对应的「腋下」瞄准点
        let tx = size.width * (snap.batSide > 0 ? 0.72 : 0.28)
        let ty = size.height - 44
        ctx.stroke(Path(ellipseIn: CGRect(x: tx - 10, y: ty - 10, width: 20, height: 20)),
                   with: .color(.white.opacity(0.25)), lineWidth: 2)

        // 自由准星：连续跟随 (yaw, pitch)，无论是否瞄中都可见
        let cx = size.width / 2 - snap.aimX * (size.width / 2 - 40)
        let cy = size.height * 0.5 + snap.aimY * (size.height * 0.5 - 36)
        let alpha = 0.35 + snap.aimProgress * 0.65
        let color = snap.stableProgress > 0 ? MonsterType.moonBat.themeColor.opacity(alpha) : .white.opacity(alpha)
        // 四角括号
        for (dx, dy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
            ctx.fill(Path(CGRect(x: cx + 14 * dx + (dx < 0 ? -6 : 2), y: cy + 14 * dy - 2, width: 4, height: 4)),
                     with: .color(color))
        }
        ctx.fill(Path(CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4)), with: .color(color))
        // 稳定进度环
        if snap.stableProgress > 0 {
            var ring = Path()
            ring.addArc(center: CGPoint(x: cx, y: cy), radius: 18,
                        startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * snap.stableProgress),
                        clockwise: false)
            ctx.stroke(ring, with: .color(MonsterType.moonBat.themeColor), lineWidth: 3)
        }
    }

    /// 蝙蝠：从来怪侧飞向中央；命中后旋转坠落（batX 复用为坠落进度）
    private static func drawBat(ctx: inout GraphicsContext, size: CGSize, snap: MoonBatGame.Snapshot, now: Date) {
        let art = Int(now.timeIntervalSince1970 * 5) % 2 == 0 ? batUp : batDown
        let artW = CGFloat(13) * pixel
        let artH = CGFloat(5) * pixel
        let baseX: CGFloat = snap.batSide > 0
            ? size.width - 40 - snap.batX * (size.width / 2 - 40)
            : 40 + snap.batX * (size.width / 2 - 40) - artW
        let baseY: CGFloat = 52 + sin(snap.batX * .pi) * 8
        if snap.batFalling {
            var c = ctx
            let fall = snap.batX * snap.batX * (size.height - 100)
            c.translateBy(x: baseX + artW / 2, y: baseY + artH / 2 + fall)
            c.rotate(by: .degrees(snap.batX * 120))
            PixelArt.draw(ctx: &c, art: art, palette: palette,
                          origin: CGPoint(x: -artW / 2, y: -artH / 2), pixel: pixel)
        } else {
            PixelArt.draw(ctx: &ctx, art: art, palette: palette,
                          origin: CGPoint(x: baseX, y: baseY), pixel: pixel)
        }
    }

    static let palette: [Character: Color] = [
        "B": MonsterType.moonBat.themeColor,
        "K": .black,
    ]
}
