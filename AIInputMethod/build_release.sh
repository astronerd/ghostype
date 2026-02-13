#!/bin/bash
# GHOSTYPE - Release 构建脚本
# 用法: bash build_release.sh [--clean]
# --clean: 清除应用数据重新开始

set -e

echo "🔨 Building GHOSTYPE (Release)..."
swift build -c release

echo ""
echo "📦 Bundling app..."
bash bundle_app.sh "$@"

echo ""
echo "🚀 Launching GHOSTYPE..."
open GHOSTYPE.app
