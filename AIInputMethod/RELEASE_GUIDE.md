# GHOSTYPE 自动更新 & 发布指南

## 架构概览

```
用户 App 启动
    ↓
Sparkle 检查 appcast.xml (每24小时自动检查)
    ↓
发现新版本 → 弹窗提示用户
    ↓
用户确认 → 自动下载 zip → 解压替换 → 重启 App
```

- 更新框架: Sparkle 2.8.1
- appcast 托管: GitHub repo main 分支 (`appcast.xml`)
- 更新包托管: GitHub Releases
- 签名方式: EdDSA (ed25519)

## 发布新版本

### 一键发布

```bash
cd AIInputMethod
bash publish_release.sh 1.2
```

脚本会自动完成:
1. 编译 Release
2. 打包 .app → .zip
3. EdDSA 签名
4. 生成 appcast.xml
5. 推送 appcast.xml 到 GitHub
6. 创建 GitHub Release 并上传 zip

### 前置条件

1. EdDSA 密钥已生成 (只需一次):
   ```bash
   Tools/sparkle/generate_keys
   ```
   私钥存在 macOS Keychain，公钥已写入 Info.plist

2. GitHub CLI 已安装并登录:
   ```bash
   brew install gh
   gh auth login
   ```

### 手动发布 (如果不用脚本)

```bash
# 1. 编译
swift build -c release

# 2. 打包
bash bundle_app.sh

# 3. 创建 zip (必须用 ditto 保留权限和符号链接)
ditto -c -k --sequesterRsrc --keepParent GHOSTYPE.app GHOSTYPE-1.2.zip

# 4. 签名
Tools/sparkle/sign_update GHOSTYPE-1.2.zip
# 输出: sparkle:edSignature="xxx" length="yyy"

# 5. 手动编辑 appcast.xml，填入签名和长度
# 6. git push appcast.xml
# 7. 在 GitHub 创建 Release，上传 zip
```

## 版本号规则

- `CFBundleShortVersionString`: 用户可见版本 (如 `1.2`)
- `CFBundleVersion`: 内部构建号 (如 `3`)，每次发布递增
- Sparkle 用 `CFBundleVersion` 判断是否有新版本

## 密钥管理

- 公钥: `8MGfJ7NMeozRnAzggep3bI3Yi4deZgOzyFJ9AtVRUOo=`
  - 写在 Info.plist 的 `SUPublicEDKey`
- 私钥: 存在 macOS Keychain (Sparkle 自动读取)
  - 导出: `Tools/sparkle/generate_keys -x private-key-file`
  - 导入: `Tools/sparkle/generate_keys -f private-key-file`
  - 换电脑时需要迁移私钥

## appcast.xml 格式

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="...">
  <channel>
    <title>GHOSTYPE Updates</title>
    <item>
      <title>GHOSTYPE v1.2</title>
      <sparkle:version>3</sparkle:version>
      <sparkle:shortVersionString>1.2</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="https://github.com/astronerd/ghostype/releases/download/v1.2/GHOSTYPE-1.2.zip"
        sparkle:edSignature="签名字符串"
        length="文件大小"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
```

## 用户侧行为

- 首次启动: 不检查更新 (Sparkle 默认行为)
- 第二次启动起: 每24小时自动检查一次
- 菜单栏 → 检查更新: 手动触发检查
- 发现新版本: 弹窗提示，用户可选择"安装并重启"或"稍后提醒"
- 自动更新: 下载 zip → 解压 → 替换旧 app → 重启

## 注意事项

- zip 必须用 `ditto` 创建，不能用 `zip` 命令 (会丢失 framework 的符号链接)
- 每次发布必须签名，否则 Sparkle 会拒绝安装
- appcast.xml 必须通过 HTTPS 访问
- 私钥丢失 = 无法发布更新，务必备份
