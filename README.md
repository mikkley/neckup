# NeckUp for Mac

Mac 上用 AirPods 传感器守护颈椎的灵动岛应用：工作时安静待在刘海里，低头久了就轻轻提醒你。

## 系统要求

- macOS 14 Sonoma 及以上（`CMHeadphoneMotionManager` 硬性要求）
- AirPods Pro（1 代+）/ AirPods（3 代）/ AirPods Max / Beats Fit Pro（无耳机可用 mock 模式开发预览）

## 构建与运行

```bash
# 仅编译验证
swift build

# 打包 NeckUp.app（release 构建 + ad-hoc 签名）
bash scripts/build-app.sh

# 运行
open NeckUp.app

# 无 AirPods：用模拟数据运行（正弦波模拟俯仰角，会周期性触发提醒）
./NeckUp.app/Contents/MacOS/NeckUp --mock
```

也可以在设置里打开「使用模拟数据」（等价于写入 `defaults write com.neckup.mac mockMode -bool true`），需重启 App 生效。

## 权限

首次运行需在系统弹窗中授予**「运动与健身」**权限（用于读取 AirPods 头部运动数据，对应 Info.plist 的 `NSMotionUsageDescription`）。若之前拒绝过，展开灵动岛后点击「打开系统设置」跳转：系统设置 → 隐私与安全性 → 运动与健身 → 打开 NeckUp。

系统通知授权用于：连续无视提醒后的降级通知、番茄钟结束通知。

## 功能清单

- **F1 姿势实时监测**：CMHeadphoneMotionManager 25Hz 读取头部俯仰角，首次佩戴自动校准零点，1s 滑动平均防抖
- **F2 不良姿势提醒**：默认俯仰 < -15° 持续 5s 触发提醒态，阈值/时长可在设置调整；连续无视 3 次降级为系统通知并静默 30 分钟
- **F3 灵动岛三态 UI**：收缩（呼吸圆点 绿/黄/红 + 评分/倒计时）/ 悬停展开（玻璃拟态卡片，移出 0.5s 收回，点击锁定）/ 提醒（暖黄色呼吸脉动 + 温和文案）；无刘海屏降级为顶部居中悬浮胶囊
- **F4 番茄钟 25+5**：开始/暂停/重置，收缩态显示倒计时，结束系统通知
- **F5 当日统计**：坐姿评分、良好时长、低头次数、专注时长，JSON 持久化于 `~/Library/Application Support/NeckUp/stats.json`
- **F6 佩戴状态感知**：AirPods 断开自动变灰「未佩戴」并暂停统计，重新佩戴自动恢复
- **F7 权限引导**：未授权时展开态显示引导文案 + 一键跳转系统设置
- **F8 菜单栏入口**：展开岛 / 暂停监测 / 番茄钟 / 重新校准 / 设置 / 退出
- **G1 即时姿势反馈**：呼吸圆点 + 实时评分 + 随头转动的小球指示器
- **G7 提醒文案轮换池**：「抬头一下 🐢」「脖子说它想你了」等温和文案随机轮换

## 功耗策略

非番茄钟时段传感器降频为每 2s 上报一次（番茄钟专注期恢复 25Hz 全速）。

## 已知限制

- 未实现：周/月统计视图（F9）、休息拉伸引导（F10）、勿扰规则（F12）、山峰成长/热力图/成就/岛中微游戏（G2–G6）
- 头部俯仰 ≠ 探颈，不宣称医学准确
- 分发需 Developer ID 签名 + 公证，当前为本地 ad-hoc 签名
