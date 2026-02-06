#!/bin/bash
# 打包 Release 版本的 GHOSTYPE.app

APP_NAME="GHOSTYPE"
RELEASE_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Bundling ${APP_NAME} (Release)..."

# 清理旧的 app
rm -rf "${APP_DIR}"

# 创建目录结构
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 复制 Release 可执行文件
cp "${RELEASE_DIR}/AIInputMethod" "${MACOS_DIR}/AIInputMethod"
chmod +x "${MACOS_DIR}/AIInputMethod"
echo "✅ Release executable copied."

# 复制图标 - 使用 bundle_app.sh 生成的 icns
if [ -f "GhosTYPE.app/Contents/Resources/AppIcon.icns" ]; then
    cp "GhosTYPE.app/Contents/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
    echo "✅ App icon copied from GhosTYPE.app."
elif [ -f "Sources/Resources/AppIcon.png" ]; then
    # 创建 iconset 目录
    ICONSET_DIR="AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    # 生成各种尺寸的图标
    sips -z 16 16     "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_16x16.png" 2>/dev/null
    sips -z 32 32     "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32     "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_32x32.png" 2>/dev/null
    sips -z 64 64     "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128   "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_128x128.png" 2>/dev/null
    sips -z 256 256   "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256   "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_256x256.png" 2>/dev/null
    sips -z 512 512   "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512   "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 "Sources/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_512x512@2x.png" 2>/dev/null
    
    # 转换为 icns
    iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf "${ICONSET_DIR}"
    echo "✅ App icon created."
fi

if [ -f "Sources/Resources/MenuBarIcon.pdf" ]; then
    cp "Sources/Resources/MenuBarIcon.pdf" "${RESOURCES_DIR}/MenuBarIcon.pdf"
    echo "✅ MenuBar icon (PDF) copied."
fi

if [ -f "Sources/Resources/MenuBarIcon.png" ]; then
    cp "Sources/Resources/MenuBarIcon.png" "${RESOURCES_DIR}/MenuBarIcon.png"
    echo "✅ MenuBar icon (PNG) copied."
fi

if [ -f "Sources/Resources/GhostIcon.png" ]; then
    cp "Sources/Resources/GhostIcon.png" "${RESOURCES_DIR}/GhostIcon.png"
    echo "✅ Ghost icon copied."
fi

# 创建 Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AIInputMethod</string>
    <key>CFBundleIdentifier</key>
    <string>com.gengdawei.ghostype</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSMicrophoneUsageDescription</key>
    <string>GHOSTYPE 需要使用麦克风进行语音输入</string>
    <key>NSContactsUsageDescription</key>
    <string>GHOSTYPE 使用通讯录联系人姓名作为语音识别热词，提高人名识别准确率</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
echo "✅ Info.plist created."

# 代码签名
echo "🔐 Signing app with ad-hoc signature..."
codesign --force --deep --sign - "${APP_DIR}" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ App signed successfully."
else
    echo "⚠️ Signing failed, app may not launch properly."
fi

echo "🚀 Done: ${APP_DIR} (Release)"
