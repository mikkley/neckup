import TurtleUpCore
import SwiftUI

/// 怪物静态肖像（教学卡 / 设置页「游戏玩法」共用）：按网格自适应居中
struct MonsterPortrait: View {
    let monster: MonsterType

    var body: some View {
        Canvas { ctx, size in
            let (art, palette) = monster.portrait
            let w = CGFloat(art.first?.count ?? 1)
            let h = CGFloat(art.count)
            let pixel = min(size.width / w, size.height / h)
            PixelArt.draw(ctx: &ctx, art: art, palette: palette,
                          origin: CGPoint(x: (size.width - w * pixel) / 2,
                                          y: (size.height - h * pixel) / 2),
                          pixel: pixel)
        }
    }
}

/// 首次遭遇教学卡：像素怪 + 动作说明 + 实时小人演示，4.5s 自动开局（或点「开始」跳过）
struct TutorialCardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var monitor: PostureMonitor
    let monster: MonsterType

    var body: some View {
        VStack(spacing: 10) {
            MonsterPortrait(monster: monster)
                .frame(width: 108, height: 48)
            Text(monster.displayName)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text(monster.tutorialText)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                HeadAvatar(pose: monitor.headPose)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(L10n.tutorialTryMove)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Button(L10n.start) { appState.beginGame(monster) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(height: 288)
        .background(Color(red: 0.06, green: 0.08, blue: 0.14),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}
