# AGENTS.md — TurtleUp for Mac

## 项目简介

macOS 灵动岛应用：用 AirPods 运动传感器（`CMHeadphoneMotionManager`，macOS 14+）监测头部俯仰角，
低头提醒 + 25+5 番茄钟 + 坐姿统计 + 休息段头控微游戏（五只"僵硬怪"对应五个颈部舒展动作）
+ 成长系统（水滴浇山、五怪图鉴星级）。菜单栏常驻 accessory 应用（`LSUIElement`，不进 Dock）。

- Bundle ID：`com.turtleup.mac`；当前版本 0.3.1（见 `Resources/Info.plist`，发版要同步改这里）
- 硬件要求：AirPods Pro（1 代+）/ AirPods 3 / AirPods Max / Beats Fit Pro；
  首次运行需授予「运动与健身」权限（`NSMotionUsageDescription`）
- 设计依据：`docs/gamification-design.md`（源码注释里的「设计文档 §x.x」都指它）；
  视觉设计稿在 `design/`（Open Design pacman 像素风）

## 协作规则（用户明确要求）

1. **有疑问先确认**：需求模糊、有多种合理解法、或操作不可逆时，先向用户确认再动手；不要自行揣测推进。
2. **先计划后执行**：任何代码改动（新功能、重构、修复）必须先给出实现计划（改哪些文件、为什么、怎么验证），经用户确认后再写代码。
3. **对抗思考**：执行前先自我反驳计划——最可能出错的地方是什么？有没有更简单的方案？会不会破坏现有行为？把风险想清楚再动手。
4. **防止无效代码**：不写占位符/死代码/过度抽象；每处改动都要有明确目的并可验证。

## 技术栈与工程形态

- 纯 SwiftPM 工程（swift-tools-version 6.0，Swift 6 严格并发），**无 .xcodeproj**，平台 macOS 14+
- 三个 target（`Package.swift`）：
  - `TurtleUpCore`（library）：纯逻辑——游戏状态机 / 棘轮档位 / 安全常量 / 多语言文案，
    无 AppKit/CoreMotion 依赖，可单测
  - `TurtleUp`（executable）：AppKit/SwiftUI UI + 传感器 + 音效，依赖 TurtleUpCore
  - `TurtleUpTests`（XCTest）：只测 TurtleUpCore
- 零第三方依赖；无 CI（`.github/` 里只有 FUNDING.yml）

## 构建与验证

```bash
swift build                 # 编译（必须零 error）
swift test                  # 跑 TurtleUpCore 单测
bash scripts/build-app.sh   # 打包：release 构建 + Info.plist + 收款码资源 + ad-hoc 签名 → TurtleUp.app
swift run TurtleUp --mock   # 无 AirPods 开发预览：Mock 慢速点头模拟（也可用打好的 .app 加 --mock）
```

调试参数（`ProcessInfo.arguments` 判定）：`--mock` 模拟传感器、`--quick` 启动自动开番茄钟快进休息段、
`--logpose` 传感器帧/动作标记写 `/tmp/turtleup-qlog.txt`。

**环境注意**：曾在 Xcode 26.3（macOS 26 SDK）下遇到 `OperationQueue? has no member 'main'` 等诡报错，
实为旧 `.build` 增量缓存与新 SDK 不兼容——`rm -rf .build` 全量重编即恢复。
当前 Xcode 26.3 下 `swift build` / `swift test` 全部通过（仅剩的一例真实错误是
`SoundEngine.swift` 的 Swift 6 严格并发 `sending risks data races`，已用 `@unchecked Sendable`
弱引用封装修复）。遇到莫名 SDK 报错先清 `.build` 再排查。

## 运行时架构

- 入口 `Sources/TurtleUp/TurtleUpApp.swift`：纯 AppKit 手写 `@main`（不走 SwiftUI App 生命周期——
  accessory 应用上 Settings 场景不可靠），`AppDelegate` 持有 `AppState` 并装配各控制器
- `App/AppState.swift`：全局状态聚合（`@MainActor ObservableObject`）——监测/番茄钟/统计/图鉴/设置，
  驱动灵动岛四态（`collapsed / expanded / reminder / game`），负责休息段开局的编排
- 数据流：`MotionProvider`（真实 `CMHeadphoneMotionManager` 或 Mock，回调在非主线程）
  → `PostureMonitor`（校准零点、1s 滑动平均、阈值判定、连续无视降级提醒）
  → 回调进 `AppState` / `StatsStore` / 游戏输入（`onRawPose` 走未平滑姿态，游戏要响应性）
- 功耗：非番茄钟时段传感器 0.5Hz 低频上报（`lowPower`），专注/对局/岛展开时恢复 25Hz
- 头部姿态约定（`TurtleUpCore/Motion/HeadPose.swift`）：pitch 低头为负；yaw 左转为正；roll 左侧倾为正；
  传感器以校准帧为相对参考零点投影到解剖学三轴，`yawSign/rollSign` 设置项修不同型号的轴向差异

## 代码组织

`Sources/TurtleUp/`（UI 与系统集成，按职责分目录）：

- `App/` — AppState、Notifier（系统通知）、UpdateChecker（GitHub Releases 比对）、DebugLog（本地滚动日志）、
  LaunchAtLogin（SMAppService 登录项，状态以系统为准不另存 UserDefaults）
- `Motion/` — MotionProvider 抽象 + 真实/Mock 实现、PostureMonitor
- `Notch/` — 灵动岛窗口（无边框 NSPanel，置顶菜单栏之上）、刘海几何避让、岛视图
- `Game/` — ActiveGame（五怪状态机的类型擦除，统一 update/tick/viewState）、
  GameContainerView（30fps Canvas 渲染）+ 各怪 Scene + PixelArt + 教学卡
- `Pomodoro/`、`Stats/`（StatsStore 统计 / CodexStore 图鉴+山峰，均 JSON 落盘）、
  `Settings/`（手动托管 NSWindow）、`Onboarding/`（新手引导 + 方向校准）、
  `MenuBar/`、`Audio/`（SoundEngine：AVAudioEngine 程序合成 8-bit 音效，零音频资产）
- `L10n+UI.swift` — UI 层文案

`Sources/TurtleUpCore/`（纯逻辑，全部可单测）：

- `Game/` — 五只怪各自的状态机（SlimeAxe/TwinBeetle/ScaleJellyfish/QiTurtle/MoonBat，对应
  点头/转头/侧屈/收下巴/复合五个动作）、EncounterDeck（洗牌式遭遇队列）、RatchetTracker（渐进档位
  到位感）、SafetyLimits（动作幅度/速度硬顶，任何玩法不得诱导突破）、MountainState（山峰成长/枯萎）、
  GameSession、GameHUDSnapshot、MonsterType
- `Motion/HeadPose.swift`、`L10n.swift`

## 代码约定

- Swift 6 严格并发；注释中文精炼（多引用设计文档章节号）
- UI 文案多语言（中/英/日/韩）：全部走 `L10n`（`TurtleUpCore/L10n.swift` + `TurtleUp/L10n+UI.swift`），
  **新增文案四语言写全**（缺失会兜底到 zh/en）；语言设置在 `AppSettings.language`
  （UserDefaults `appLanguage`，"" = 跟随系统）；工程无 .xcstrings，代码内字符串表运行时切换；
  禁止再硬编码中文字符串
- 设置持久化走 `UserDefaults.standard`（`Settings/Settings.swift` 集中管理 key）
- 提交信息风格：中文，`feat: / chore:` 前缀（见 git log）

## 测试

- `swift test`，只覆盖 TurtleUpCore（Tests/TurtleUpTests/，每怪状态机 + 洗牌队列 + 棘轮 + 山峰各一个测试文件）
- 改 TurtleUpCore 逻辑必须同步补/改对应单测；UI 层无自动化测试，靠 `--mock` / `--quick` 手动验证

## 数据与隐私

- 全部数据只存本机 `~/Library/Application Support/TurtleUp/`：`stats.json`（统计）、
  `game.json`（图鉴/对局/山峰）、`debug.log`（只记事件不含姿态原始流，超 512KB 截断）
- 退出前 `applicationWillTerminate` 强制 `stats.flush()`（统计有 throttle 缓冲）
- 品牌更名迁移逻辑在 `AppState.init`：旧目录 `NeckUp/` 与旧设置域 `com.neckup.mac` 自动搬迁，勿删
- 唯一网络访问：UpdateChecker 查 GitHub Releases API

## 分发

- `scripts/build-app.sh` 产出 ad-hoc 签名的 `TurtleUp.app`；正式分发需 Developer ID + 公证（未做）
- 发布渠道：GitHub Releases（`mikkley/turtleup`，`TurtleUp-macOS.zip`）+ Homebrew cask
  （`brew install --cask mikkley/turtleup/turtleup`）；UpdateChecker 按 Releases 比对版本号
