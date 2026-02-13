#!/bin/bash
# GHOSTYPE - 发布构建脚本
# 用法: bash build_publish.sh [version]
# 等同于 publish_release.sh，编译 release + 打包 + 签名 + 发布到 GitHub

set -e

echo "🚀 Starting publish flow..."
bash publish_release.sh "$@"
