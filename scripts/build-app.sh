#!/bin/bash
# 组装 NeckUp.app：release 构建 + Info.plist + ad-hoc 签名
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="NeckUp.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/NeckUp "$APP/Contents/MacOS/NeckUp"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# ad-hoc 签名，保证本地可运行（分发需 Developer ID + 公证）
codesign --force --sign - "$APP" || echo "警告: ad-hoc 签名失败，仍可尝试直接运行"

echo "完成: $(pwd)/$APP"
