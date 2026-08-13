import TurtleUpCore
import SwiftUI

/// M2「双头甲虫」场景：甲虫从侧缘逼近（前摇闪烁预告方向），中央盾牌随转头举起
enum BeetleScene {
    private static let pixel: CGFloat = 4

    /// 双头甲虫（18×5，H=头 K=眼 B=身 L=腿）；教学卡/设置页也复用
    static let beetleArt: [[Character]] = [
        Array(".KH..............HK."),
        Array("HHHBBBBBBBBBBBBBBHHH"),
        Array("HHHBBBBBBBBBBBBBBHHH"),
        Array(".HHBBBBBBBBBBBBBBHH."),
        Array("..L...L......L...L.."),
    ]

    static let palette: [Character: Color] = [
        "H": Color(red: 0.85, green: 0.35, blue: 0.25),
        "K": .black,
        "B": MonsterType.twinBeetle.themeColor,
        "L": Color(red: 0.4, green: 0.25, blue: 0.15),
    ]

    /// 盾（10×7，S=盾面 W=高光）
    private static let shieldArt: [[Character]] = [
        Array("..SSSSSS.."),
        Array(".SSSSSSSS."),
        Array("SSSWWSSSSS"),
        Array("SSSWWSSSSS"),
        Array("SSSSSSSSSS"),
        Array(".SSSSSSSS."),
        Array("..SSSSSS.."),
    ]

    static func draw(ctx: inout GraphicsContext, size: CGSize, snap: TwinBeetleGame.Snapshot, now: Date) {
        let ground = size.height - 28
        // 地面像素线
        ctx.fill(Path(CGRect(x: 0, y: ground, width: size.width, height: 2)),
                 with: .color(.white.opacity(0.15)))
        drawShield(ctx: &ctx, size: size, snap: snap, ground: ground)
        guard snap.side != 0 else { return }

        let beetleW = CGFloat(20) * pixel
        let edgeX: CGFloat = snap.side > 0 ? size.width - beetleW - 8 : 8
        if snap.phase == .telegraph {
            // 前摇：来怪方向边缘闪烁「!」预告
            if Int(now.timeIntervalSince1970 * 4) % 2 == 0 {
                let markX = snap.side > 0 ? size.width - 20 : 16
                ctx.fill(Path(CGRect(x: markX, y: ground - 44, width: 4, height: 12)),
                         with: .color(.yellow))
                ctx.fill(Path(CGRect(x: markX, y: ground - 28, width: 4, height: 4)),
                         with: .color(.yellow))
            }
            drawBeetle(ctx: &ctx, at: CGPoint(x: edgeX, y: ground - 24))
        } else {
            // 逼近：0=贴边 → 1=贴近盾牌
            let targetX: CGFloat = snap.side > 0 ? size.width / 2 + 24 : size.width / 2 - 24 - beetleW
            let x = edgeX + (targetX - edgeX) * snap.approach
            drawBeetle(ctx: &ctx, at: CGPoint(x: x, y: ground - 24))
        }
    }

    /// 盾随手转头连续左右滑动+微倾（yawAim 带方向：左转盾左移，镜像一致）；
    /// 转对方向增亮、格挡保持时上举
    private static func drawShield(ctx: inout GraphicsContext, size: CGSize,
                                   snap: TwinBeetleGame.Snapshot, ground: CGFloat) {
        let lift = snap.holdProgress * 10
        let span = size.width / 2 - 50
        let cx = size.width / 2 - snap.yawAim * span
        let cy = ground - 30 - lift + 3.5 * pixel   // 盾心（art 高 7 行）
        var c = ctx
        c.translateBy(x: cx, y: cy)
        c.rotate(by: .degrees(-snap.yawAim * 10))
        c.opacity = 0.45 + snap.yawProgress * 0.55
        PixelArt.draw(ctx: &c, art: shieldArt, palette: [
            "S": Color(red: 0.5, green: 0.7, blue: 0.95),
            "W": .white,
        ], origin: CGPoint(x: -5 * pixel, y: -3.5 * pixel), pixel: pixel)
    }

    private static func drawBeetle(ctx: inout GraphicsContext, at origin: CGPoint) {
        PixelArt.draw(ctx: &ctx, art: beetleArt, palette: palette, origin: origin, pixel: pixel)
    }
}
