#!/bin/bash
# 组装 TurtleUp.app：release 构建 + Info.plist + ad-hoc 签名
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="TurtleUp.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TurtleUp "$APP/Contents/MacOS/TurtleUp"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# 收款码等资源（设置页「支持 TurtleUp」）
mkdir -p "$APP/Contents/Resources"
cp Resources/Donate/*.jpg "$APP/Contents/Resources/"

# ad-hoc 签名，保证本地可运行（分发需 Developer ID + 公证）
codesign --force --sign - "$APP" || echo "警告: ad-hoc 签名失败，仍可尝试直接运行"

echo "完成: $(pwd)/$APP"
