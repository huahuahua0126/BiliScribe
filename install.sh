#!/bin/bash
# ============================================================
# 🎬 BiliScribe 安装脚本
# 运行此脚本，将桌面启动器安装到你的桌面
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER_SRC="$SCRIPT_DIR/BiliScribe启动器.command"
LAUNCHER_DST="$HOME/Desktop/BiliScribe启动器.command"

echo ""
echo "  🎬 BiliScribe 安装程序"
echo "  ─────────────────────────────────"
echo ""

# 1. 检查依赖
echo "  检查依赖..."
MISSING=0
for cmd in yt-dlp ffmpeg python3; do
    if ! command -v $cmd &>/dev/null; then
        echo "  ❌ 缺少依赖: $cmd"
        MISSING=1
    fi
done

if [ $MISSING -eq 1 ]; then
    echo ""
    echo "  请先运行: brew install yt-dlp ffmpeg python"
    echo ""
    exit 1
fi
echo "  ✅ 依赖检查通过"

# 2. 给脚本加执行权限
chmod +x "$SCRIPT_DIR/biliscribe.sh"
chmod +x "$LAUNCHER_SRC"
echo "  ✅ 执行权限已设置"

# 3. 复制启动器到桌面
cp "$LAUNCHER_SRC" "$LAUNCHER_DST"
echo "  ✅ 启动器已安装到桌面"

echo ""
echo "  ─────────────────────────────────"
echo "  🎉 安装完成！"
echo ""
echo "  👉 双击桌面上的「BiliScribe启动器」即可开始使用"
echo "  👉 首次运行会自动下载 Whisper 模型（约 3GB）"
echo ""
