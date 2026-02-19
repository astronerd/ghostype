#!/bin/bash
# GHOSTYPE 统一构建脚本
# 用法:
#   bash ghostype.sh debug [--clean]        编译 debug + 打包 + 启动
#   bash ghostype.sh release [--clean]      编译 release + 打包 + 启动
#   bash ghostype.sh publish [version]      编译 release + 打包 + 签名 + 发布
#
# --clean: 清除所有本地数据（UserDefaults、CoreData、Ghost Twin、Skills），模拟全新安装

set -e

APP_NAME="AIInputMethod"
DISPLAY_NAME="GHOSTYPE"
APP_BUNDLE="$DISPLAY_NAME.app"

# ============================================================
# 子命令解析
# ============================================================

COMMAND="${1:-}"
shift || true

if [ -z "$COMMAND" ]; then
    echo "用法: bash ghostype.sh <debug|release|publish> [options]"
    echo ""
    echo "  debug   [--clean]     编译 debug + 打包 + 启动"
    echo "  release [--clean]     编译 release + 打包 + 启动"
    echo "  publish [version]     编译 release + 打包 + 签名 + 发布到 GitHub"
    exit 1
fi

# ============================================================
# --clean: 清除所有本地数据
# ============================================================

do_clean() {
    echo "🧹 Cleaning all app data..."
    defaults delete com.gengdawei.ghostype 2>/dev/null || true
    rm -rf ~/Library/Application\ Support/GHOSTYPE/ 2>/dev/null || true
    rm -rf ~/Library/Application\ Support/AIInputMethod/ 2>/dev/null || true
    echo "   ✅ UserDefaults cleared"
    echo "   ✅ ~/Library/Application Support/GHOSTYPE/ removed"
    echo "   ✅ ~/Library/Application Support/AIInputMethod/ removed (CoreData)"
}

# ============================================================
# 打包 .app bundle（共用逻辑）
# 参数: $1 = debug | release
# ============================================================

bundle_app() {
    local CONFIG="$1"
    local EXE_DIR=".build/${CONFIG}"

    if [ ! -f "${EXE_DIR}/${APP_NAME}" ]; then
        echo "❌ Executable not found at ${EXE_DIR}/${APP_NAME}"
        exit 1
    fi

    rm -rf "$APP_BUNDLE"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"

    # Executable
    cp "${EXE_DIR}/${APP_NAME}" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    echo "✅ Executable copied (${CONFIG})."

    # Sparkle.framework
    if [ -d "Frameworks/Sparkle.framework" ]; then
        cp -R "Frameworks/Sparkle.framework" "$APP_BUNDLE/Contents/Frameworks/"
        echo "✅ Sparkle.framework copied."
    fi

    # App Icon
    if [ -d "AppIcon.iconset" ]; then
        iconutil -c icns "AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null
        echo "✅ App icon created."
    fi

    # Resources
    for res in Sources/Resources/MenuBarIcon.pdf Sources/Resources/MenuBarIcon.png Sources/Resources/GhostIcon.png; do
        [ -f "$res" ] && cp "$res" "$APP_BUNDLE/Contents/Resources/" && echo "✅ Copied: $(basename "$res")"
    done
    for svg in Sources/Resources/*.svg; do
        [ -f "$svg" ] && cp "$svg" "$APP_BUNDLE/Contents/Resources/" && echo "✅ SVG: $(basename "$svg")"
    done
    for png in Sources/Resources/*.png; do
        [ -f "$png" ] || continue
        local bn=$(basename "$png")
        [[ "$bn" == "MenuBarIcon.png" || "$bn" == "GhostIcon.png" ]] && continue
        cp "$png" "$APP_BUNDLE/Contents/Resources/" && echo "✅ PNG: $bn"
    done

    # Default Skills (builtin only, exclude user-created UUID directories)
    if [ -d "default_skills" ]; then
        mkdir -p "$APP_BUNDLE/Contents/Resources/default_skills"
        for skill_dir in default_skills/builtin-* default_skills/internal-*; do
            [ -d "$skill_dir" ] && cp -R "$skill_dir" "$APP_BUNDLE/Contents/Resources/default_skills/" && echo "✅ Skill: $(basename "$skill_dir")"
        done
    fi

    # .env
    if [ -f ".env" ]; then
        cp .env "$APP_BUNDLE/Contents/MacOS/.env"
        echo "✅ .env copied."
    elif [ -f ".env.example" ]; then
        cp .env.example "$APP_BUNDLE/Contents/MacOS/.env"
        echo "✅ .env.example copied as .env."
    fi

    # Info.plist（根据 config 区分）
    write_info_plist "$CONFIG"

    # 签名
    echo "🔐 Signing..."
    codesign --force --deep --sign - "$APP_BUNDLE" 2>&1
    echo "✅ Signed."
}

# ============================================================
# Info.plist 生成
# 参数: $1 = debug | release
# ============================================================

write_info_plist() {
    local CONFIG="$1"

    if [ "$CONFIG" = "debug" ]; then
        local VERSION_STRING="0.0.0-debug"
        local BUILD_NUMBER="0"
        local AUTO_UPDATE="false"
    else
        # release: 从现有 plist 模板读取版本号，或使用默认值
        local VERSION_STRING="${PUBLISH_VERSION:-0.1.$(date +%m%d%H%M)}"
        local BUILD_NUMBER="${PUBLISH_BUILD:-1}"
        local AUTO_UPDATE="true"
    fi

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
    <string>${VERSION_STRING}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
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
    <${AUTO_UPDATE}/>
</dict>
</plist>
EOF
    echo "✅ Info.plist created (${CONFIG}, v${VERSION_STRING}, build ${BUILD_NUMBER})."
}

# ============================================================
# 命令: debug
# ============================================================

cmd_debug() {
    local CLEAN=false
    for arg in "$@"; do
        [ "$arg" = "--clean" ] && CLEAN=true
    done

    echo "🔨 GHOSTYPE Debug Build"
    echo "========================"

    [ "$CLEAN" = true ] && do_clean

    echo ""
    echo "📦 Compiling (debug)..."
    swift build -c debug

    echo ""
    echo "📦 Bundling..."
    bundle_app debug

    echo ""
    echo "🚀 Launching..."
    open "$APP_BUNDLE"
}

# ============================================================
# 命令: release
# ============================================================

cmd_release() {
    local CLEAN=false
    for arg in "$@"; do
        [ "$arg" = "--clean" ] && CLEAN=true
    done

    echo "🔨 GHOSTYPE Release Build"
    echo "=========================="

    [ "$CLEAN" = true ] && do_clean

    echo ""
    echo "📦 Compiling (release)..."
    swift build -c release

    echo ""
    echo "📦 Bundling..."
    bundle_app release

    echo ""
    echo "🚀 Launching..."
    open "$APP_BUNDLE"
}

# ============================================================
# 命令: publish
# ============================================================

cmd_publish() {
    local VERSION="${1:-}"

    if [ -z "$VERSION" ]; then
        VERSION="0.1.$(date +%m%d%H%M)"
    fi

    local ZIP_NAME="${DISPLAY_NAME}-${VERSION}.zip"
    local APPCAST_FILE="appcast.xml"

    # 读取当前 build number 并递增
    local CURRENT_BUILD=0
    if [ -f "$APPCAST_FILE" ]; then
        CURRENT_BUILD=$(sed -n 's/.*<sparkle:version>\(.*\)<\/sparkle:version>.*/\1/p' "$APPCAST_FILE" | head -1)
    fi
    local NEW_BUILD=$((CURRENT_BUILD + 1))

    # 导出给 bundle_app 使用
    export PUBLISH_VERSION="$VERSION"
    export PUBLISH_BUILD="$NEW_BUILD"

    echo "🚀 GHOSTYPE Publish v${VERSION} (build ${NEW_BUILD})"
    echo "======================================================"

    # Step 1: 编译
    echo ""
    echo "🔨 Step 1: Compiling (release)..."
    swift build -c release
    echo "   ✅ Done"

    # Step 2: 打包
    echo ""
    echo "📦 Step 2: Bundling..."
    bundle_app release

    # Step 3: 创建 zip
    echo ""
    echo "📦 Step 3: Creating ${ZIP_NAME}..."
    rm -f "${ZIP_NAME}"
    ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_NAME}"
    echo "   ✅ ZIP: $(du -h "${ZIP_NAME}" | cut -f1)"

    # Step 4: EdDSA 签名
    echo ""
    echo "🔐 Step 4: EdDSA signing..."
    local SIGNATURE_OUTPUT
    SIGNATURE_OUTPUT=$(Tools/sparkle/sign_update "${ZIP_NAME}" 2>&1)
    echo "   ${SIGNATURE_OUTPUT}"

    local EDDSA_SIGNATURE
    EDDSA_SIGNATURE=$(echo "${SIGNATURE_OUTPUT}" | grep 'sparkle:edSignature=' | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
    local FILE_LENGTH
    FILE_LENGTH=$(echo "${SIGNATURE_OUTPUT}" | grep 'length=' | sed 's/.*length="\([^"]*\)".*/\1/')

    if [ -z "$EDDSA_SIGNATURE" ]; then
        echo "❌ Signing failed"
        exit 1
    fi
    echo "   ✅ Signed"

    # Step 5: 生成 appcast.xml
    echo ""
    echo "📄 Step 5: Generating appcast.xml..."
    local DOWNLOAD_URL="https://github.com/astronerd/ghostype/releases/download/v${VERSION}/${ZIP_NAME}"
    local PUB_DATE
    PUB_DATE=$(date -R)

    cat > "${APPCAST_FILE}" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>GHOSTYPE Updates</title>
        <link>https://raw.githubusercontent.com/astronerd/ghostype/main/appcast.xml</link>
        <description>GHOSTYPE automatic updates</description>
        <language>zh-cn</language>
        <item>
            <title>GHOSTYPE v${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${NEW_BUILD}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure
                url="${DOWNLOAD_URL}"
                sparkle:edSignature="${EDDSA_SIGNATURE}"
                length="${FILE_LENGTH}"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
APPCAST_EOF
    echo "   ✅ appcast.xml generated"

    # Step 6: 提交 appcast.xml
    echo ""
    echo "📤 Step 6: Pushing appcast.xml..."
    cd ..
    git add AIInputMethod/${APPCAST_FILE}
    git commit -m "release: v${VERSION} appcast"
    git push
    cd AIInputMethod
    echo "   ✅ Pushed"

    # Step 7: GitHub Release
    echo ""
    echo "🏷️ Step 7: Creating GitHub Release..."
    cd ..
    gh release create "v${VERSION}" \
        "AIInputMethod/${ZIP_NAME}" \
        --title "GHOSTYPE v${VERSION}" \
        --notes "GHOSTYPE v${VERSION} 更新" \
        --latest
    cd AIInputMethod
    echo "   ✅ Released"

    echo ""
    echo "======================================================"
    echo "🎉 Published! GHOSTYPE v${VERSION}"
    echo "   appcast: https://raw.githubusercontent.com/astronerd/ghostype/main/appcast.xml"
    echo "   download: ${DOWNLOAD_URL}"
}

# ============================================================
# 路由
# ============================================================

case "$COMMAND" in
    debug)   cmd_debug "$@" ;;
    release) cmd_release "$@" ;;
    publish) cmd_publish "$@" ;;
    *)
        echo "❌ Unknown command: $COMMAND"
        echo "用法: bash ghostype.sh <debug|release|publish> [options]"
        exit 1
        ;;
esac
