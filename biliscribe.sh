#!/bin/bash
# ============================================================
# 🎬 BiliScribe - B站视频一键转文字
# https://github.com/huahuahua0126/BiliScribe
# 
# 用法: ./biliscribe.sh <B站视频链接>
# 示例: ./biliscribe.sh "https://www.bilibili.com/video/BV1XFhPzoEBx/"
# ============================================================

set -e

# ---- 配置 ----
OUTPUT_DIR="${BILISCRIBE_OUTPUT_DIR:-$HOME/Downloads/BiliScribe/output}"
VENV_DIR="${BILISCRIBE_VENV_DIR:-$HOME/.biliscribe/venv}"
WHISPER_MODEL="${BILISCRIBE_MODEL:-mlx-community/whisper-large-v3-mlx}"
DEBUG="${BILISCRIBE_DEBUG:-0}" # 设置为 1 开启调试模式（保留中间文件）

# ---- 颜色输出 ----
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

print_step()  { echo -e "\n${BLUE}▶ $1${NC}"; }
print_done()  { echo -e "${GREEN}✅ $1${NC}"; }
print_warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_debug() { if [ "$DEBUG" = "1" ]; then echo -e "${DIM}[DEBUG] $1${NC}"; fi; }

show_banner() {
    echo -e "${BLUE}"
    echo "  ┌──────────────────────────────────────┐"
    echo "  │  🎬 BiliScribe (Audio Only)          │"
    echo "  │  B站视频一键转文字                    │"
    echo "  └──────────────────────────────────────┘"
    echo -e "${NC}"
}

show_usage() {
    show_banner
    echo "  用法:"
    echo -e "    ${BOLD}biliscribe${NC} <B站视频链接>"
    echo ""
    echo "  示例:"
    echo "    biliscribe \"https://www.bilibili.com/video/BV1XFhPzoEBx/\""
    echo ""
    echo "  环境变量:"
    echo -e "    ${DIM}BILISCRIBE_OUTPUT_DIR${NC}  输出目录"
    echo -e "    ${DIM}BILISCRIBE_MODEL${NC}       Whisper 模型"
    echo -e "    ${DIM}BILISCRIBE_DEBUG${NC}       设为 1 保留中间文件"
    echo ""
}

# ---- 检查参数 ----
if [ -z "$1" ]; then
    show_usage
    exit 1
fi

URL="$1"

# 1. 尝试提取 URL (兼容 "【视频标题】https://..." 这种分享格式)
EXTRACTED_URL=$(echo "$URL" | grep -oE 'https?://[^ "]+' | head -n1)
if [ -n "$EXTRACTED_URL" ]; then
    URL="$EXTRACTED_URL"
fi

# 2. 支持简写格式 (BV号 / av号)
if [[ "$URL" =~ ^BV ]]; then
    URL="https://www.bilibili.com/video/${URL}/"
elif [[ "$URL" =~ ^av[0-9]+ ]]; then
    URL="https://www.bilibili.com/video/${URL}/"
elif [[ "$URL" =~ ^[0-9]+$ ]]; then
    URL="https://www.bilibili.com/video/av${URL}/"
fi

show_banner

# ---- 检查依赖 ----
print_step "检查依赖..."

MISSING_DEPS=0
for cmd in yt-dlp ffmpeg python3; do
    if ! command -v $cmd &> /dev/null; then
        print_error "$cmd 未安装"
        MISSING_DEPS=1
    fi
done

if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    echo "  请运行: brew install yt-dlp ffmpeg python"
    exit 1
fi

# 自动创建虚拟环境
if [ ! -d "$VENV_DIR" ]; then
    print_step "首次运行：创建 Python 虚拟环境..."
    mkdir -p "$(dirname "$VENV_DIR")"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install mlx-whisper
    touch "$VENV_DIR/.installed"
    deactivate
    print_done "虚拟环境创建完成"
elif [ ! -f "$VENV_DIR/.installed" ]; then
    source "$VENV_DIR/bin/activate"
    pip install --quiet mlx-whisper
    touch "$VENV_DIR/.installed"
    deactivate
fi

print_done "依赖检查通过"

# ---- 确保输出目录存在 ----
mkdir -p "$OUTPUT_DIR"

# ---- 临时文件清理 (Trap) ----
cleanup() {
    if [ "$DEBUG" != "1" ]; then
        if [ -n "$RAW_AUDIO_TMP" ] && [ -f "$RAW_AUDIO_TMP" ]; then
            rm -f "$RAW_AUDIO_TMP"
        fi
    fi
}
trap cleanup EXIT INT TERM

# ---- 步骤 1: 获取视频信息 ----
print_step "步骤 1/3: 解析视频信息..."
echo -e "  ${DIM}链接: $URL${NC}"

TITLE=$(yt-dlp --get-title "$URL" 2>&1 | grep -v '\[' | head -n1 || true)
TITLE=$(echo "$TITLE" | tr -d '\n')
if [ -z "$TITLE" ]; then
    print_error "无法获取视频信息，请检查链接是否正确"
    exit 1
fi

# 文件名清洗 (Sanitization) & 长度截断 (Max 200 chars)
SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]/_/g' | awk '{print substr($0, 1, 200)}')

echo -e "  ${BOLD}标题: $TITLE${NC}"
print_debug "安全文件名: $SAFE_TITLE"

# 定义文件路径
RAW_AUDIO_TMP="$OUTPUT_DIR/${SAFE_TITLE}.raw_audio"
AUDIO_WAV="$OUTPUT_DIR/${SAFE_TITLE}.wav"
TEXT_FILE="$OUTPUT_DIR/${SAFE_TITLE}.txt"
TIMESTAMP_FILE="$OUTPUT_DIR/${SAFE_TITLE}_timestamps.txt"

# 检查是否已有文字稿
if [ -f "$TEXT_FILE" ]; then
    print_warn "文字稿已存在，跳过处理"
    echo ""
    echo -e "  📄 文字稿: ${BOLD}$TEXT_FILE${NC}"
    if command -v pbcopy &> /dev/null; then
        cat "$TEXT_FILE" | pbcopy
        echo -e "  ${YELLOW}📋 已复制到剪贴板${NC}"
    fi
    exit 0
fi

# ---- 步骤 2: 下载音频 + 转换 ----
print_step "步骤 2/3: 下载并转换音频..."

if [ -f "$AUDIO_WAV" ]; then
    print_done "音频 WAV 已存在，跳过下载"
else
    if [ ! -f "$RAW_AUDIO_TMP" ]; then
        echo -e "  ${DIM}正在下载音频流...${NC}"
        # yt-dlp 会在文件名后自动追加真实扩展名（如 .m4a/.webm）
        # 所以用 --output 指定不含扩展名的路径，下载后用 glob 找到实际文件
        yt-dlp --no-warnings --progress -f bestaudio \
            --no-playlist \
            --no-part \
            -o "$RAW_AUDIO_TMP" \
            "$URL" 2>&1

        # 用 glob 找到 yt-dlp 实际生成的文件（带真实扩展名）
        ACTUAL_FILE=$(ls "${RAW_AUDIO_TMP}"* 2>/dev/null | head -n1)
        if [ -z "$ACTUAL_FILE" ]; then
            print_error "音频下载失败，请检查链接或网络"
            exit 1
        fi
        # 统一重命名为脚本期望的路径
        if [ "$ACTUAL_FILE" != "$RAW_AUDIO_TMP" ]; then mv "$ACTUAL_FILE" "$RAW_AUDIO_TMP"; fi
        print_debug "下载完成: $RAW_AUDIO_TMP"
    fi

    # 转换为 16kHz WAV
    echo -e "  ${DIM}转换为 16kHz WAV 用于 Whisper...${NC}"
    ffmpeg -i "$RAW_AUDIO_TMP" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$AUDIO_WAV" -y -v error

    if [ ! -f "$AUDIO_WAV" ]; then
        print_error "音频转换失败"
        exit 1
    fi

    DURATION=$(ffmpeg -i "$AUDIO_WAV" 2>&1 | grep "Duration" | awk '{print $2}' | tr -d ',')
    print_done "音频准备就绪 (时长: $DURATION)"
fi

# ---- 步骤 3: Whisper 转录 ----
print_step "步骤 3/3: 语音转文字 (本地 Whisper)..."

source "$VENV_DIR/bin/activate"

# Export 变量供 Python 使用 (比字符串拼接更安全)
export PY_AUDIO_FILE="$AUDIO_WAV"
export PY_TEXT_FILE="$TEXT_FILE"
export PY_TIMESTAMP_FILE="$TIMESTAMP_FILE"
export PY_WHISPER_MODEL="$WHISPER_MODEL"

python3 << 'PYTHON_SCRIPT'
import mlx_whisper
import time
import sys
import os
import threading

audio_file = os.getenv("PY_AUDIO_FILE")
text_file = os.getenv("PY_TEXT_FILE")
timestamp_file = os.getenv("PY_TIMESTAMP_FILE")
model = os.getenv("PY_WHISPER_MODEL")

print(f"  模型: {model}")
print(f"  正在加载模型并转录... (按 Ctrl+C 可终止)", flush=True)

# 旋转动画，在后台线程中运行
stop_spinner = threading.Event()
def spinner_fn():
    frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    i = 0
    t0 = time.time()
    while not stop_spinner.is_set():
        elapsed = time.time() - t0
        sys.stdout.write(f"\r  {frames[i % len(frames)]}  转录中... 已用时 {elapsed:.0f}s ")
        sys.stdout.flush()
        i += 1
        time.sleep(0.1)
    sys.stdout.write("\r" + " " * 45 + "\r")
    sys.stdout.flush()

spinner_thread = threading.Thread(target=spinner_fn, daemon=True)
spinner_thread.start()

start_time = time.time()

try:
    result = mlx_whisper.transcribe(
        audio_file,
        path_or_hf_repo=model,
        language='zh',
        verbose=False,
        # 提示模型输出带标点的中文
        initial_prompt="以下是普通话的句子，请使用标准中文标点符号。"
    )

    stop_spinner.set()
    spinner_thread.join()
    elapsed = time.time() - start_time

    with open(text_file, 'w', encoding='utf-8') as f:
        f.write(result['text'])

    with open(timestamp_file, 'w', encoding='utf-8') as f:
        for seg in result.get('segments', []):
            s_m, s_s = divmod(seg['start'], 60)
            e_m, e_s = divmod(seg['end'], 60)
            text = seg['text'].strip()
            f.write(f"[{int(s_m):02d}:{s_s:05.2f} -> {int(e_m):02d}:{e_s:05.2f}] {text}\n")

    char_count = len(result['text'])
    print(f"  ✅ 转录完成！耗时 {elapsed:.1f} 秒，共 {char_count} 字")

except Exception as e:
    stop_spinner.set()
    print(f"\n❌ Python 转录错误: {e}")
    sys.exit(1)

PYTHON_SCRIPT

TRANS_EXIT_CODE=$?
deactivate 2>/dev/null || true

if [ $TRANS_EXIT_CODE -ne 0 ]; then
    print_error "转录过程中发生错误"
    exit 1
fi

# ---- 清理与完成 ----
if [ "$DEBUG" != "1" ]; then
    rm -f "$RAW_AUDIO_TMP" "$AUDIO_WAV"
else
    print_warn "Debug 模式开启：中间文件已保留"
    print_debug "Raw: $RAW_AUDIO_TMP"
    print_debug "Wav: $AUDIO_WAV"
fi

echo ""
echo -e "${GREEN}  ┌──────────────────────────────────────┐${NC}"
echo -e "${GREEN}  │  🎉 转录完成！                       │${NC}"
echo -e "${GREEN}  └──────────────────────────────────────┘${NC}"
echo ""
echo -e "  📄 文字稿:   ${BOLD}$TEXT_FILE${NC}"
echo -e "  ⏱️  时间戳:   ${DIM}$TIMESTAMP_FILE${NC}"
echo ""

if command -v pbcopy &> /dev/null; then
    pbcopy < "$TEXT_FILE"
    echo -e "  ${YELLOW}📋 文字稿已复制到剪贴板${NC}"
    echo ""
fi