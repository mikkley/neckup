import TurtleUpCore
import SwiftUI

/// 像素画绘制统一入口：字符画 + 调色板 → 矩形像素块（8-bit 风格只在游戏 Canvas 内）
enum PixelArt {
    static func draw(ctx: inout GraphicsContext, art: [[Character]], palette: [Character: Color],
                     origin: CGPoint, pixel: CGFloat) {
        for (r, row) in art.enumerated() {
            for (c, ch) in row.enumerated() {
                guard let color = palette[ch] else { continue }
                let rect = CGRect(x: origin.x + CGFloat(c) * pixel, y: origin.y + CGFloat(r) * pixel,
                                  width: pixel, height: pixel)
                ctx.fill(Path(rect), with: .color(color))
            }
        }
    }
}

extension MonsterType {
    /// 五怪主题色（场景配色 / 成长行星级 mini）
    var themeColor: Color {
        switch self {
        case .slimeAxe: Color(red: 0.35, green: 0.85, blue: 0.45)
        case .twinBeetle: Color(red: 0.95, green: 0.55, blue: 0.25)
        case .scaleJellyfish: Color(red: 0.35, green: 0.8, blue: 0.95)
        case .qiTurtle: Color(red: 0.5, green: 0.72, blue: 0.38)
        case .moonBat: Color(red: 0.72, green: 0.5, blue: 0.95)
        }
    }

    /// 教学卡 / 设置页「游戏玩法」的静态肖像（复用各场景像素画，单一来源）
    var portrait: (art: [[Character]], palette: [Character: Color]) {
        switch self {
        case .slimeAxe: (SlimeScene.slimeArt, SlimeScene.palette)
        case .twinBeetle: (BeetleScene.beetleArt, BeetleScene.palette)
        case .scaleJellyfish: (JellyScene.jellyArt, JellyScene.palette)
        case .qiTurtle: (TurtleScene.turtleArt, TurtleScene.palette)
        case .moonBat: (BatScene.batUp, BatScene.palette)
        }
    }
}
