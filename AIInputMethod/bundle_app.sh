#!/bin/bash

APP_NAME="AIInputMethod"
DISPLAY_NAME="GhosTYPE"
APP_BUNDLE="$DISPLAY_NAME.app"

# 清除应用数据（用于测试首次启动）
echo "🧹 Clearing app data for fresh start..."
defaults delete com.gengdawei.ghostype 2>/dev/null || true

echo "📦 Bundling $DISPLAY_NAME..."

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Executable
if [ -f ".build/debug/$APP_NAME" ]; then
    cp ".build/debug/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    echo "✅ Executable copied."
else
    echo "❌ Executable not found."
    exit 1
fi

# App Icon - 使用 Sources/Resources/AppIcon.png
if [ -f "Sources/Resources/AppIcon.png" ]; then
    ICONSET="$APP_BUNDLE/Contents/Resources/AppIcon.iconset"
    mkdir -p "$ICONSET"
    sips -z 16 16 Sources/Resources/AppIcon.png --out "$ICONSET/icon_16x16.png" > /dev/null 2>&1
    sips -z 32 32 Sources/Resources/AppIcon.png --out "$ICONSET/icon_16x16@2x.png" > /dev/null 2>&1
    sips -z 32 32 Sources/Resources/AppIcon.png --out "$ICONSET/icon_32x32.png" > /dev/null 2>&1
    sips -z 64 64 Sources/Resources/AppIcon.png --out "$ICONSET/icon_32x32@2x.png" > /dev/null 2>&1
    sips -z 128 128 Sources/Resources/AppIcon.png --out "$ICONSET/icon_128x128.png" > /dev/null 2>&1
    sips -z 256 256 Sources/Resources/AppIcon.png --out "$ICONSET/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256 Sources/Resources/AppIcon.png --out "$ICONSET/icon_256x256.png" > /dev/null 2>&1
    sips -z 512 512 Sources/Resources/AppIcon.png --out "$ICONSET/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512 Sources/Resources/AppIcon.png --out "$ICONSET/icon_512x512.png" > /dev/null 2>&1
    sips -z 1024 1024 Sources/Resources/AppIcon.png --out "$ICONSET/icon_512x512@2x.png" > /dev/null 2>&1
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null
    rm -rf "$ICONSET"
    echo "✅ App icon created."
fi

# MenuBar Icon
if [ -f "Sources/Resources/MenuBarIcon.pdf" ]; then
    cp Sources/Resources/MenuBarIcon.pdf "$APP_BUNDLE/Contents/Resources/"
    echo "✅ MenuBar icon (PDF) copied."
elif [ -f "Sources/Resources/MenuBarIcon.png" ]; then
    cp Sources/Resources/MenuBarIcon.png "$APP_BUNDLE/Contents/Resources/"
    echo "✅ MenuBar icon (PNG) copied."
fi

# Ghost Icon for overlay
if [ -f "Sources/Resources/GhostIcon.png" ]; then
    cp Sources/Resources/GhostIcon.png "$APP_BUNDLE/Contents/Resources/"
    echo "✅ Ghost icon copied."
fi

# Info.plist
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.gengdawei.ghostype</string>
    <key>CFBundleName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>GhosTYPE needs microphone access for speech recognition.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>GhosTYPE needs accessibility access to detect text fields.</string>
    <key>NSContactsUsageDescription</key>
    <string>GhosTYPE uses contact names as hotwords to improve speech recognition accuracy.</string>
</dict>
</plist>
EOF
echo "✅ Info.plist created."

echo "🚀 Done: $APP_BUNDLE"
