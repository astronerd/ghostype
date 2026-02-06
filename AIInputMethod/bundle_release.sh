#!/bin/bash
# 打包 Release 版本的 GhosTYPE.app

APP_NAME="GhosTYPE"
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
echo "✅ Release executable copied."

# 复制资源文件
if [ -f "Sources/Resources/AppIcon.png" ]; then
    sips -s format icns "Sources/Resources/AppIcon.png" --out "${RESOURCES_DIR}/AppIcon.icns" 2>/dev/null || cp "Sources/Resources/AppIcon.png" "${RESOURCES_DIR}/AppIcon.icns"
    echo "✅ App icon created."
fi

if [ -f "Sources/Resources/MenuBarIcon.pdf" ]; then
    cp "Sources/Resources/MenuBarIcon.pdf" "${RESOURCES_DIR}/MenuBarIcon.pdf"
    echo "✅ MenuBar icon (PDF) copied."
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
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSMicrophoneUsageDescription</key>
    <string>GhosTYPE 需要使用麦克风进行语音输入</string>
    <key>NSContactsUsageDescription</key>
    <string>GhosTYPE 使用通讯录联系人姓名作为语音识别热词，提高人名识别准确率</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
echo "✅ Info.plist created."

echo "🚀 Done: ${APP_DIR} (Release)"
