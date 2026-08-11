import NeckUpCore
import SwiftUI

/// 12×12 像素小人（伪 3D）：yaw 转头 = 五官在脸内左右滑动 + 转向侧眼睛压缩；
/// roll 侧倾 = 整体旋转；pitch 低头 = 整体下移。镜像呈现（用户左转，小人转向屏幕左）。
/// 引导校准页与岛展开态共用。
struct HeadAvatar: View {
    let pose: HeadPose

    // H=头发 S=皮肤 E=眼睛 M=嘴 .=空
    private static let grid: [String] = [
        "....HHHH....",
        "..HHHHHHHH..",
        ".HHHHHHHHHH.",
        ".HHSSSSSSHH.",
        ".HHSSSSSSHH.",
        ".HHSESSESHH.",
        ".HHSSSSSSHH.",
        ".HHSSMMSSHH.",
        "..SSSSSSSS..",
        "..SSSSSSSS..",
        "...SSSSSS...",
        "............",
    ]

    private static let colors: [Character: Color] = [
        "H": Color(red: 0.25, green: 0.18, blue: 0.14),
        "S": Color(red: 0.98, green: 0.78, blue: 0.58),
        "E": Color(red: 0.12, green: 0.12, blue: 0.14),
        "M": Color(red: 0.75, green: 0.3, blue: 0.25),
    ]

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 12
            let yawN = max(-1, min(1, pose.yaw / 25))      // 左转为正（真机约定）
            let pitchDown = max(-1, min(1, -pose.pitch / 25))  // 低头为正
            var c = ctx
            // roll 侧倾 → 小幅旋转（CG 正角度视觉上顺时针，取负即镜像）
            c.translateBy(x: size.width / 2, y: size.height / 2)
            c.rotate(by: .degrees(-pose.roll * 0.4))
            c.translateBy(x: -yawN * k * 1.2, y: pitchDown * k * 1.8)
            c.translateBy(x: -size.width / 2, y: -size.height / 2)
            // 五官在脸内反向滑动 → 伪 3D 转头（皮肤区横向只有 ±1 格余量）
            let featureDx = -yawN * k
            for (row, line) in Self.grid.enumerated() {
                for (col, ch) in line.enumerated() {
                    guard let color = Self.colors[ch] else { continue }
                    var rect = CGRect(x: CGFloat(col) * k, y: CGFloat(row) * k,
                                      width: k + 0.5, height: k + 0.5)
                    if ch == "E" || ch == "M" {
                        rect.origin.x += featureDx
                        // 转向内侧的眼睛压缩（左转为正 → 左眼在 col 较小侧）
                        if ch == "E", abs(yawN) > 0.5 {
                            let leading = (yawN > 0 && col <= 5) || (yawN < 0 && col >= 6)
                            if leading { rect.size.width *= 0.55 }
                        }
                    }
                    c.fill(Path(rect), with: .color(color))
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: pose)
    }
}
