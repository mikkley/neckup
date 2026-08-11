import NeckUpCore
import SwiftUI

/// M1「石斧史莱姆」场景：史莱姆按行下落，底部斧头随低头进度劈下
enum SlimeScene {
    static let axeZone: CGFloat = 52   // 底部斧头区高度（粒子锚点计算也用）

    /// 史莱姆像素画（12×7，G=身体 W=眼白 K=瞳孔）；教学卡/设置页也复用
    static let slimeArt: [[Character]] = [
        Array("....GGGG...."),
        Array("..GGGGGGGG.."),
        Array(".GGGGGGGGGG."),
        Array("GGKGGGGGGKGG"),
        Array("GGGGGGGGGGGG"),
        Array(".GGGGGGGGGG."),
        Array("..G.G..G.G.."),
    ]

    static let palette: [Character: Color] = [
        "G": MonsterType.slimeAxe.themeColor,
        "W": .white,
        "K": .black,
    ]

    static func draw(ctx: inout GraphicsContext, size: CGSize, snap: SlimeAxeGame.Snapshot) {
        let rows = max(snap.totalRows, 1)
        let rowHeight = (size.height - axeZone) / CGFloat(rows)
        PixelArt.draw(ctx: &ctx, art: slimeArt, palette: palette,
                      origin: CGPoint(x: size.width / 2 - 6 * 4,
                                      y: rowHeight * CGFloat(snap.slimeRow) + 6),
                      pixel: 4)
        drawAxe(ctx: &ctx, size: size, progress: snap.pitchProgress)
    }

    /// 斧头随手低头进度劈下（柄绕尾端旋转 -60° → +20°）
    private static func drawAxe(ctx: inout GraphicsContext, size: CGSize, progress: Double) {
        let pivot = CGPoint(x: size.width / 2, y: size.height - 26)
        var c = ctx
        c.translateBy(x: pivot.x, y: pivot.y)
        c.rotate(by: .degrees(-60 + progress * 80))
        // 柄（棕）
        c.fill(Path(CGRect(x: -3, y: -34, width: 6, height: 34)),
               with: .color(Color(red: 0.55, green: 0.35, blue: 0.2)))
        // 斧刃（浅灰像素块）
        c.fill(Path(CGRect(x: -16, y: -44, width: 20, height: 14)),
               with: .color(Color(red: 0.75, green: 0.78, blue: 0.85)))
        c.fill(Path(CGRect(x: -20, y: -40, width: 6, height: 8)),
               with: .color(Color(red: 0.75, green: 0.78, blue: 0.85)))
    }
}
