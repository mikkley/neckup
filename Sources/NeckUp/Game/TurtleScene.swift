import NeckUpCore
import SwiftUI

/// M4「气功龟慢慢」场景：左下慢慢示范，右上僵硬云，底部蓄力条随收下巴填充
enum TurtleScene {
    private static let pixel: CGFloat = 4

    /// 慢慢（16×7，S=壳棕 G=身/头绿 K=眼）
    private static let turtleArt: [[Character]] = [
        Array("......SSSSSS......"),
        Array("....SSSSSSSSSS...."),
        Array("...SSSSSSSSSSSS..."),
        Array("..GGSSSSSSSSSSGG.."),
        Array(".GKGGGGGGGGGGGG..."),
        Array("..GGGGGGGGGGGGGG.."),
        Array("...G..........G..."),
    ]

    static func draw(ctx: inout GraphicsContext, size: CGSize, snap: QiTurtleGame.Snapshot) {
        PixelArt.draw(ctx: &ctx, art: turtleArt, palette: [
            "S": Color(red: 0.55, green: 0.4, blue: 0.25),
            "G": MonsterType.qiTurtle.themeColor,
            "K": .black,
        ], origin: CGPoint(x: 20, y: size.height - 60), pixel: pixel)

        drawCloud(ctx: &ctx, size: size)

        // 蓄力条（底部中央）：有效蓄力时金色高亮，否则玉色
        let barW: CGFloat = 128
        let barRect = CGRect(x: size.width / 2 - barW / 2, y: size.height - 24, width: barW, height: 10)
        ctx.fill(Path(barRect), with: .color(.white.opacity(0.15)))
        let fillColor: Color = snap.charging
            ? Color(red: 1.0, green: 0.8, blue: 0.3)
            : Color(red: 0.5, green: 0.85, blue: 0.6)
        ctx.fill(Path(CGRect(x: barRect.minX + 2, y: barRect.minY + 2,
                             width: max(0, (barW - 4) * snap.charge), height: 6)),
                 with: .color(fillColor))
    }

    /// 僵硬云（右上灰色像素团）
    private static func drawCloud(ctx: inout GraphicsContext, size: CGSize) {
        let gray = Color(red: 0.55, green: 0.58, blue: 0.65)
        let base = CGPoint(x: size.width - 110, y: 24)
        for rect in [
            CGRect(x: 0, y: 8, width: 60, height: 20),
            CGRect(x: 12, y: 0, width: 40, height: 16),
            CGRect(x: 8, y: 24, width: 48, height: 12),
        ] {
            ctx.fill(Path(rect.offsetBy(dx: base.x, dy: base.y)), with: .color(gray.opacity(0.85)))
        }
    }
}
