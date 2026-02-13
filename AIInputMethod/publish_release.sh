#!/bin/bash
# GHOSTYPE 发布脚本
# 用法: bash publish_release.sh [version]
# 不传版本号则自动生成: 0.1.MMDDHHmm
#
# 前置条件:
# 1. EdDSA 私钥已在 Keychain 中 (generate_keys 已执行过)
# 2. gh CLI 已安装 (brew install gh)
# 3. 已登录 GitHub (gh auth login)

set -e

# 版本号：手动传入 or 自动生成
if [ -n "$1" ]; then
    VERSION="$1"
else
    VERSION="0.1.$(date +%m%d%H%M)"
fi

APP_NAME="GHOSTYPE"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
APPCAST_FILE="appcast.xml"

echo "🚀 发布 ${APP_NAME} v${VERSION}"
echo "================================"

# Step 1: 更新 bundle_release.sh 中的版本号
echo ""
echo "📝 Step 1: 更新版本号..."

# 更新 CFBundleShortVersionString
sed -i '' "s|<key>CFBundleShortVersionString</key>|<key>CFBundleShortVersionString</key>|" bundle_release.sh
sed -i '' "/<key>CFBundleShortVersionString<\/key>/{n;s|<string>.*</string>|<string>${VERSION}</string>|;}" bundle_release.sh

# 获取当前 build number 并递增
CURRENT_BUILD=$(sed -n '/<key>CFBundleVersion<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' bundle_release.sh)
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i '' "/<key>CFBundleVersion<\/key>/{n;s|<string>.*</string>|<string>${NEW_BUILD}</string>|;}" bundle_release.sh

echo "   版本: ${VERSION}, Build: ${NEW_BUILD}"

# Step 2: 编译 Release
echo ""
echo "🔨 Step 2: 编译 Release..."
swift build -c release
echo "   ✅ 编译完成"

# Step 3: 打包 .app
echo ""
echo "📦 Step 3: 打包 .app..."
bash bundle_release.sh
echo "   ✅ 打包完成"

# Step 4: 创建 zip
echo ""
echo "📦 Step 4: 创建 ${ZIP_NAME}..."
rm -f "${ZIP_NAME}"
ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${ZIP_NAME}"
echo "   ✅ ZIP 创建完成: $(du -h "${ZIP_NAME}" | cut -f1)"

# Step 5: 签名 zip (EdDSA)
echo ""
echo "🔐 Step 5: EdDSA 签名..."
SIGNATURE_OUTPUT=$(Tools/sparkle/sign_update "${ZIP_NAME}" 2>&1)
echo "   ${SIGNATURE_OUTPUT}"

# 提取签名信息
EDDSA_SIGNATURE=$(echo "${SIGNATURE_OUTPUT}" | grep 'sparkle:edSignature=' | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
FILE_LENGTH=$(echo "${SIGNATURE_OUTPUT}" | grep 'length=' | sed 's/.*length="\([^"]*\)".*/\1/')

if [ -z "$EDDSA_SIGNATURE" ]; then
    echo "❌ 签名失败"
    exit 1
fi
echo "   ✅ 签名成功"

# Step 6: 生成/更新 appcast.xml
echo ""
echo "📄 Step 6: 生成 appcast.xml..."

DOWNLOAD_URL="https://github.com/astronerd/ghostype/releases/download/v${VERSION}/${ZIP_NAME}"
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

echo "   ✅ appcast.xml 已生成"

# Step 7: 提交 appcast.xml 到 Git
echo ""
echo "📤 Step 7: 提交 appcast.xml..."
cd ..
git add AIInputMethod/${APPCAST_FILE}
git commit -m "release: v${VERSION} appcast"
git push
cd AIInputMethod
echo "   ✅ appcast.xml 已推送"

# Step 8: 创建 GitHub Release
echo ""
echo "🏷️ Step 8: 创建 GitHub Release..."
cd ..
gh release create "v${VERSION}" \
    "AIInputMethod/${ZIP_NAME}" \
    --title "GHOSTYPE v${VERSION}" \
    --notes "GHOSTYPE v${VERSION} 更新" \
    --latest
cd AIInputMethod
echo "   ✅ GitHub Release 已创建"

echo ""
echo "================================"
echo "🎉 发布完成! GHOSTYPE v${VERSION}"
echo ""
echo "用户将在下次启动时自动收到更新提示。"
echo "appcast URL: https://raw.githubusercontent.com/astronerd/ghostype/main/appcast.xml"
echo "下载 URL: ${DOWNLOAD_URL}"
