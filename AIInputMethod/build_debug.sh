#!/bin/bash
# GHOSTYPE - Debug 构建脚本
# 用法: bash build_debug.sh [--clean]
# --clean: 清除应用数据重新开始

set -e

echo "🔨 Building GHOSTYPE (Debug)..."
swift build -c debug

echo ""
echo "📦 Bundling app..."
bash bundle_app.sh "$@"

echo ""
echo "🚀 Launching GHOSTYPE..."
open GHOSTYPE.app
