# AGENTS.md — NeckUp for Mac

## 项目简介

macOS 灵动岛应用：用 AirPods 运动传感器（CMHeadphoneMotionManager，macOS 14+）监测头部俯仰角，低头提醒 + 25+5 番茄钟 + 坐姿统计。SwiftPM executable target，无 .xcodeproj。

## 协作规则（用户明确要求）

1. **有疑问先确认**：需求模糊、有多种合理解法、或操作不可逆时，先向用户确认再动手；不要自行揣测推进。
2. **先计划后执行**：任何代码改动（新功能、重构、修复）必须先给出实现计划（改哪些文件、为什么、怎么验证），经用户确认后再写代码。
3. **对抗思考**：执行前先自我反驳计划——最可能出错的地方是什么？有没有更简单的方案？会不会破坏现有行为？把风险想清楚再动手。
4. **防止无效代码**：不写占位符/死代码/过度抽象；每处改动都要有明确目的并可验证。

## 构建与验证

- 编译：`swift build`（必须零 error）
- 打包：`bash scripts/build-app.sh` → 产出 `NeckUp.app`
- 无 AirPods 开发预览：`swift run NeckUp --mock`

## 代码约定

- Swift 6 严格并发；UI 文案中文，注释中文精炼
- 设计稿在 `design/`（Open Design pacman 像素风）
