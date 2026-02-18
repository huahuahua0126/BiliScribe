#!/bin/bash
# ============================================================
# 🎬 BiliScribe 桌面启动器
# 双击此文件即可运行，无需打开终端
# ============================================================

# 自动定位 biliscribe.sh（和本文件在同一目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BILISCRIBE="$SCRIPT_DIR/biliscribe.sh"

# 检查主脚本是否存在
if [ ! -f "$BILISCRIBE" ]; then
    osascript -e 'display alert "找不到 BiliScribe！" message "请确认 biliscribe.sh 和启动器在同一目录下。" as critical'
    exit 1
fi

# 循环：每次转录完后询问是否继续
while true; do
    URL=$(osascript -e '
        set dialogResult to display dialog "请粘贴 B 站视频链接或 BV 号：" default answer "" with title "🎬 BiliScribe" buttons {"退出", "开始转录"} default button "开始转录"
        if button returned of dialogResult is "退出" then
            return ""
        else
            return text returned of dialogResult
        end if
    ')

    if [ -z "$URL" ]; then
        echo "👋 已退出 BiliScribe"
        break
    fi

    bash "$BILISCRIBE" "$URL"

    osascript -e 'display notification "文字稿已保存！" with title "🎉 BiliScribe 转录完成"'

    echo ""
    echo "✅ 转录完成！继续等待下一个任务..."
    echo ""
done

echo ""
echo "按任意键关闭此窗口..."
read -n 1
