#!/bin/bash

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

# 清理旧的 app bundle
rm -rf "$APP_BUNDLE"

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Executable - 优先使用 release 版本
if [ -f ".build/release/$APP_NAME" ]; then
    cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    echo "✅ Executable copied (release)."
elif [ -f ".build/debug/$APP_NAME" ]; then
    cp ".build/debug/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    echo "✅ Executable copied (debug)."
else
    echo "❌ Executable not found."
    exit 1
fi

# Copy Sparkle.framework
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
if [ -d "Frameworks/Sparkle.framework" ]; then
    cp -R "Frameworks/Sparkle.framework" "$APP_BUNDLE/Contents/Frameworks/"
    echo "✅ Sparkle.framework copied."
else
    echo "⚠️ Sparkle.framework not found in Frameworks/, skipping."
fi

# App Icon - 使用现有的 AppIcon.iconset 文件夹
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
        # Skip files already copied above
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
    <string>0.1.02131640</string>
    <key>CFBundleVersion</key>
    <string>3</string>
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

# 🔐 代码签名 (Ad-hoc signing for accessibility permissions)
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
echo "🚀 Done: $APP_BUNDLE"
echo "📍 Location: $(pwd)/$APP_BUNDLE"

# 复制 .env 到 app bundle 旁边
if [ -f ".env" ]; then
    cp .env "$APP_BUNDLE/Contents/MacOS/.env"
    echo "✅ .env copied into app bundle."
elif [ -f ".env.example" ]; then
    cp .env.example "$APP_BUNDLE/Contents/MacOS/.env"
    echo "✅ .env.example copied as .env into app bundle."
fi

ls -la "$APP_BUNDLE/Contents/Resources/"
