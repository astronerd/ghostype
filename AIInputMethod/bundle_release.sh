#!/bin/bash
# GHOSTYPE - Release 打包脚本
# 用法: bash bundle_release.sh [--clean]
# --clean: 清除应用数据重新开始

APP_NAME="AIInputMethod"
DISPLAY_NAME="GHOSTYPE"
APP_BUNDLE="$DISPLAY_NAME.app"

# 清除应用数据（仅在传入 --clean 参数时执行）
if [ "$1" = "--clean" ]; then
    echo "🧹 Clearing app data for fresh start..."
    defaults delete com.gengdawei.ghostype 2>/dev/null || true
else
    echo "📌 Keeping existing app data (use --clean to reset)"
fi

echo "📦 Bundling $DISPLAY_NAME (Release)..."

# 检查 release 可执行文件
if [ ! -f ".build/release/$APP_NAME" ]; then
    echo "❌ Release executable not found. Run 'swift build -c release' first."
    exit 1
fi

# 清理旧的 app bundle
rm -rf "$APP_BUNDLE"

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# Copy Executable
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
echo "✅ Executable copied (release)."

# Copy Sparkle.framework
if [ -d "Frameworks/Sparkle.framework" ]; then
    cp -R "Frameworks/Sparkle.framework" "$APP_BUNDLE/Contents/Frameworks/"
    echo "✅ Sparkle.framework copied."
else
    echo "⚠️ Sparkle.framework not found in Frameworks/, skipping."
fi

# App Icon
if [ -d "AppIcon.iconset" ]; then
    iconutil -c icns "AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null
    echo "✅ App icon created (AppIcon.icns)."
else
    echo "⚠️ AppIcon.iconset not found, skipping icon generation."
fi

# MenuBar Icon
if [ -f "Sources/Resources/MenuBarIcon.pdf" ]; then
    cp Sources/Resources/MenuBarIcon.pdf "$APP_BUNDLE/Contents/Resources/"
    echo "✅ MenuBar icon (PDF) copied."
fi
if [ -f "Sources/Resources/MenuBarIcon.png" ]; then
    cp Sources/Resources/MenuBarIcon.png "$APP_BUNDLE/Contents/Resources/"
    echo "✅ MenuBar icon (PNG) copied."
fi

# Ghost Icon for overlay
if [ -f "Sources/Resources/GhostIcon.png" ]; then
    cp Sources/Resources/GhostIcon.png "$APP_BUNDLE/Contents/Resources/"
    echo "✅ Ghost icon copied."
fi

# SVG Logo files
for svg in Sources/Resources/*.svg; do
    if [ -f "$svg" ]; then
        cp "$svg" "$APP_BUNDLE/Contents/Resources/"
        echo "✅ SVG copied: $(basename "$svg")"
    fi
done

# PNG resource files (CRT frame, etc.)
for png in Sources/Resources/*.png; do
    if [ -f "$png" ]; then
        basename_png=$(basename "$png")
        if [ "$basename_png" != "MenuBarIcon.png" ] && [ "$basename_png" != "GhostIcon.png" ]; then
            cp "$png" "$APP_BUNDLE/Contents/Resources/"
            echo "✅ PNG copied: $basename_png"
        fi
    fi
done

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
    <string>0.1.02131837</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>GHOSTYPE needs microphone access for speech recognition.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>GHOSTYPE needs accessibility access to detect text fields.</string>
    <key>NSContactsUsageDescription</key>
    <string>GHOSTYPE uses contact names as hotwords to improve speech recognition accuracy.</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.gengdawei.ghostype</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>ghostype</string>
            </array>
        </dict>
    </array>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/astronerd/ghostype/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>8MGfJ7NMeozRnAzggep3bI3Yi4deZgOzyFJ9AtVRUOo=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
EOF
echo "✅ Info.plist created."

# 🔐 代码签名
echo "🔐 Signing app with ad-hoc signature..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ App signed successfully."
else
    echo "⚠️ Signing failed, but app may still work."
fi

# 验证签名
echo "🔍 Verifying signature..."
codesign -dv --verbose=2 "$APP_BUNDLE" 2>&1 | head -5

echo ""
echo "🚀 Done: $APP_BUNDLE (Release)"
echo "📍 Location: $(pwd)/$APP_BUNDLE"

# 复制 .env 到 app bundle
if [ -f ".env" ]; then
    cp .env "$APP_BUNDLE/Contents/MacOS/.env"
    echo "✅ .env copied into app bundle."
elif [ -f ".env.example" ]; then
    cp .env.example "$APP_BUNDLE/Contents/MacOS/.env"
    echo "✅ .env.example copied as .env into app bundle."
fi

ls -la "$APP_BUNDLE/Contents/Resources/"
