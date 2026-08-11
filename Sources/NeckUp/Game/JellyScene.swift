import NeckUpCore
import SwiftUI

/// M3「天平水母」场景：顶部水母 + 随侧屈平移倾斜的托盘，宝石飘落；大宝石悬停带蓄力条
enum JellyScene {
    private static let pixel: CGFloat = 4

    /// 天平水母（12×8，J=伞体 W=眼 K=瞳 T=触手）；教学卡/设置页也复用
    static let jellyArt: [[Character]] = [
        Array("...JJJJJJ..."),
        Array("..JJJJJJJJ.."),
        Array(".JWKJJJJKWJ."),
        Array(".JJJJJJJJJJ."),
        Array("..JJJJJJJJ.."),
        Array("..T..TT..T.."),
        Array("..T..TT..T.."),
        Array("........T..."),
    ]

    static let palette: [Character: Color] = [
        "J": MonsterType.scaleJellyfish.themeColor,
        "W": .white,
        "K": .black,
        "T": Color(red: 0.6, green: 0.9, blue: 1.0),
    ]

    static func draw(ctx: inout GraphicsContext, size: CGSize, snap: ScaleJellyfishGame.Snapshot, now: Date) {
        let trayY = size.height - 32
        let span = size.width / 2 - 56

        PixelArt.draw(ctx: &ctx, art: jellyArt, palette: palette,
                      origin: CGPoint(x: size.width / 2 - 6 * pixel, y: 4), pixel: pixel)

        // 托盘：随 roll 平移 + 倾斜
        let trayX = size.width / 2 + snap.trayX * span
        var tray = ctx
        tray.translateBy(x: trayX, y: trayY)
        tray.rotate(by: .degrees(snap.trayX * 12))
        tray.fill(Path(CGRect(x: -36, y: -4, width: 72, height: 8)),
                  with: .color(Color(red: 0.85, green: 0.9, blue: 0.95)))
        tray.fill(Path(CGRect(x: -3, y: 4, width: 6, height: 10)),
                  with: .color(Color(red: 0.6, green: 0.65, blue: 0.7)))

        guard snap.gemActive else { return }
        let gemX = size.width / 2 + snap.gemX * span
        let bob = snap.gemHovering ? sin(now.timeIntervalSince1970 * 4) * 3 : 0
        let gemY = 40 + snap.gemY * (trayY - 40) + bob
        if snap.gemBig {
            // 大宝石（金）+ 悬停蓄力条
            ctx.fill(Path(CGRect(x: gemX - 7, y: gemY - 7, width: 14, height: 14)),
                     with: .color(Color(red: 1.0, green: 0.8, blue: 0.3)))
            ctx.fill(Path(CGRect(x: gemX - 3, y: gemY - 3, width: 4, height: 4)),
                     with: .color(.white))
            // 蓄力条（定住进度，替代盯屏倒计时）
            ctx.fill(Path(CGRect(x: gemX - 16, y: gemY - 18, width: 32, height: 5)),
                     with: .color(.white.opacity(0.25)))
            ctx.fill(Path(CGRect(x: gemX - 16, y: gemY - 18, width: 32 * snap.charge, height: 5)),
                     with: .color(Color(red: 1.0, green: 0.8, blue: 0.3)))
        } else {
            ctx.fill(Path(CGRect(x: gemX - 4, y: gemY - 4, width: 8, height: 8)),
                     with: .color(Color(red: 0.4, green: 0.9, blue: 1.0)))
            ctx.fill(Path(CGRect(x: gemX - 2, y: gemY - 2, width: 3, height: 3)),
                     with: .color(.white))
        }
    }
}
