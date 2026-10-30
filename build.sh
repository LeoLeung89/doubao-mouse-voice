#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/build/鼠标长按豆包语音.app"
if [ -e "$APP" ]; then
  echo "构建目标已存在：$APP。请先备份或移走旧构建，避免覆盖。" >&2
  exit 1
fi
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>鼠标长按豆包语音</string>
<key>CFBundleDisplayName</key><string>鼠标长按豆包语音</string>
<key>CFBundleIdentifier</key><string>local.leo.mouse-doubao-voice</string>
<key>CFBundleExecutable</key><string>MouseDoubaoVoice</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
swiftc -module-cache-path /private/tmp/mouse-doubao-swift-cache -O Sources/main.swift -o "$APP/Contents/MacOS/MouseDoubaoVoice" -framework AppKit -framework ApplicationServices
xattr -d com.apple.FinderInfo "$APP" 2>/dev/null || true
codesign --force --sign - "$APP"
echo "已生成：$APP"
