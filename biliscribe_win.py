#!/usr/bin/env python3
# ============================================================
# 🎬 BiliScribe Windows 版
# https://github.com/huahuahua0126/BiliScribe
#
# 用法: python biliscribe_win.py <B站视频链接>
# 示例: python biliscribe_win.py "https://www.bilibili.com/video/BV1XFhPzoEBx/"
#
# 依赖安装:
#   pip install yt-dlp openai-whisper
#   ffmpeg 需单独安装: https://ffmpeg.org/download.html
# ============================================================

import sys
import os
import re
import subprocess
import threading
import time
import shutil
from pathlib import Path

# ---- 配置 ----
OUTPUT_DIR = Path(os.environ.get("BILISCRIBE_OUTPUT_DIR", Path(__file__).parent / "output"))
WHISPER_MODEL = os.environ.get("BILISCRIBE_MODEL", "large-v3")
DEBUG = os.environ.get("BILISCRIBE_DEBUG", "0") == "1"

# ---- 颜色输出（Windows 10+ 支持 ANSI）----
GREEN  = "\033[0;32m"
BLUE   = "\033[0;34m"
YELLOW = "\033[1;33m"
RED    = "\033[0;31m"
BOLD   = "\033[1m"
DIM    = "\033[2m"
NC     = "\033[0m"

def print_step(msg):  print(f"\n{BLUE}▶ {msg}{NC}")
def print_done(msg):  print(f"{GREEN}✅ {msg}{NC}")
def print_warn(msg):  print(f"{YELLOW}⚠️  {msg}{NC}")
def print_error(msg): print(f"{RED}❌ {msg}{NC}")
def print_debug(msg):
    if DEBUG:
        print(f"{DIM}[DEBUG] {msg}{NC}")

def show_banner():
    print(f"{BLUE}")
    print("  ┌──────────────────────────────────────┐")
    print("  │  🎬 BiliScribe Windows               │")
    print("  │  B站视频一键转文字                    │")
    print("  └──────────────────────────────────────┘")
    print(f"{NC}")

def show_usage():
    show_banner()
    print("  用法:")
    print(f"    {BOLD}python biliscribe_win.py{NC} <B站视频链接>")
    print()
    print("  示例:")
    print('    python biliscribe_win.py "https://www.bilibili.com/video/BV1XFhPzoEBx/"')
    print()
    print("  环境变量:")
    print(f"    {DIM}BILISCRIBE_OUTPUT_DIR{NC}  输出目录")
    print(f"    {DIM}BILISCRIBE_MODEL{NC}       Whisper 模型 (tiny/base/small/medium/large-v3)")
    print(f"    {DIM}BILISCRIBE_DEBUG{NC}       设为 1 保留中间文件")
    print()

def parse_url(raw: str) -> str:
    """兼容分享文案、BV号、av号等多种输入格式"""
    # 提取 http/https 链接（兼容 app 分享的 "【标题】https://..." 格式）
    match = re.search(r'https?://[^ "]+', raw)
    if match:
        return match.group(0)
    # BV号
    if re.match(r'^BV', raw):
        return f"https://www.bilibili.com/video/{raw}/"
    # av号
    if re.match(r'^av\d+', raw, re.IGNORECASE):
        return f"https://www.bilibili.com/video/{raw}/"
    # 纯数字视为 av 号
    if re.match(r'^\d+$', raw):
        return f"https://www.bilibili.com/video/av{raw}/"
    return raw

def check_dependencies():
    """检查必要的依赖"""
    missing = []
    for cmd in ["yt-dlp", "ffmpeg"]:
        if not shutil.which(cmd):
            missing.append(cmd)
    if missing:
        print_error(f"缺少依赖: {', '.join(missing)}")
        print()
        print("  请安装:")
        print("    pip install yt-dlp")
        print("    ffmpeg: https://ffmpeg.org/download.html (需加入 PATH)")
        sys.exit(1)

    try:
        import whisper
    except ImportError:
        print_error("缺少 openai-whisper")
        print()
        print("  请运行: pip install openai-whisper")
        sys.exit(1)

def sanitize_title(title: str) -> str:
    """清洗文件名，去除非法字符，截断过长标题"""
    safe = re.sub(r'[\\/:*?"<>|]', '_', title)
    return safe[:200]

def spinner_task(stop_event: threading.Event):
    """转录时显示旋转动画"""
    frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    i = 0
    t0 = time.time()
    while not stop_event.is_set():
        elapsed = time.time() - t0
        sys.stdout.write(f"\r  {frames[i % len(frames)]}  转录中... 已用时 {elapsed:.0f}s ")
        sys.stdout.flush()
        i += 1
        time.sleep(0.1)
    sys.stdout.write("\r" + " " * 45 + "\r")
    sys.stdout.flush()

def main():
    # 启用 Windows 终端 ANSI 颜色支持
    if sys.platform == "win32":
        os.system("")

    if len(sys.argv) < 2:
        show_usage()
        sys.exit(1)

    url = parse_url(sys.argv[1])
    show_banner()

    # ---- 检查依赖 ----
    print_step("检查依赖...")
    check_dependencies()
    print_done("依赖检查通过")

    # ---- 创建输出目录 ----
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # ---- 步骤 1: 获取视频标题 ----
    print_step("步骤 1/3: 解析视频信息...")
    print(f"  {DIM}链接: {url}{NC}")

    result = subprocess.run(
        ["yt-dlp", "--get-title", url],
        capture_output=True, text=True, encoding="utf-8"
    )
    title = result.stdout.strip()
    if not title:
        print_error("无法获取视频信息，请检查链接是否正确")
        if result.stderr:
            print(f"  {DIM}{result.stderr.strip()}{NC}")
        sys.exit(1)

    safe_title = sanitize_title(title)
    print(f"  {BOLD}标题: {title}{NC}")
    print_debug(f"安全文件名: {safe_title}")

    # ---- 定义文件路径 ----
    raw_audio_tmp = OUTPUT_DIR / f"{safe_title}.raw_audio"
    audio_wav     = OUTPUT_DIR / f"{safe_title}.wav"
    text_file     = OUTPUT_DIR / f"{safe_title}.txt"
    timestamp_file= OUTPUT_DIR / f"{safe_title}_timestamps.txt"

    if text_file.exists():
        print_warn("文字稿已存在，跳过处理")
        print(f"\n  📄 文字稿: {BOLD}{text_file}{NC}")
        if sys.platform == "win32":
            try:
                subprocess.run(["clip"], input=text_file.read_bytes(), check=False)
                print(f"  {YELLOW}📋 已复制到剪贴板{NC}")
            except Exception:
                pass
        sys.exit(0)

    # ---- 步骤 2: 下载音频 ----
    print_step("步骤 2/3: 下载并转换音频...")

    if not audio_wav.exists():
        if not raw_audio_tmp.exists():
            print(f"  {DIM}正在下载音频流...{NC}")
            subprocess.run([
                "yt-dlp", "--no-warnings", "--progress",
                "-f", "bestaudio",
                "--no-playlist", "--no-part",
                "-o", str(raw_audio_tmp),
                url
            ], check=True)

            # yt-dlp 会自动加真实扩展名，用 glob 找到实际文件
            # glob.escape 防止文件名里的 [ ] 等字符被当作通配符
            import glob
            pattern = glob.escape(str(raw_audio_tmp)) + "*"
            matches = [Path(p) for p in glob.glob(pattern)]
            if not matches:
                print_error("音频下载失败，请检查链接或网络")
                sys.exit(1)
            actual = matches[0]
            if actual != raw_audio_tmp:
                actual.rename(raw_audio_tmp)
            print_debug(f"下载完成: {raw_audio_tmp}")

        # 转换为 16kHz WAV
        print(f"  {DIM}转换为 16kHz WAV 用于 Whisper...{NC}")
        subprocess.run([
            "ffmpeg", "-i", str(raw_audio_tmp),
            "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
            str(audio_wav), "-y", "-v", "error"
        ], check=True)

        if not audio_wav.exists():
            print_error("音频转换失败")
            sys.exit(1)

        print_done(f"音频准备就绪")

    # ---- 步骤 3: Whisper 转录 ----
    print_step("步骤 3/3: 语音转文字 (本地 Whisper)...")
    print(f"  模型: {WHISPER_MODEL}")
    print(f"  正在加载模型并转录... (按 Ctrl+C 可终止)", flush=True)

    import whisper

    stop_spinner = threading.Event()
    spinner_thread = threading.Thread(target=spinner_task, args=(stop_spinner,), daemon=True)
    spinner_thread.start()

    t_start = time.time()
    try:
        model = whisper.load_model(WHISPER_MODEL)
        result = model.transcribe(
            str(audio_wav),
            language="zh",
            verbose=False,
            initial_prompt="以下是普通话的句子，请使用标准中文标点符号。"
        )
    except Exception as e:
        stop_spinner.set()
        spinner_thread.join()
        print_error(f"转录失败: {e}")
        sys.exit(1)

    stop_spinner.set()
    spinner_thread.join()
    elapsed = time.time() - t_start

    # ---- 保存结果 ----
    text_file.write_text(result["text"], encoding="utf-8")

    with timestamp_file.open("w", encoding="utf-8") as f:
        for seg in result.get("segments", []):
            s_m, s_s = divmod(seg["start"], 60)
            e_m, e_s = divmod(seg["end"], 60)
            f.write(f"[{int(s_m):02d}:{s_s:05.2f} -> {int(e_m):02d}:{e_s:05.2f}] {seg['text'].strip()}\n")

    char_count = len(result["text"])
    print(f"  ✅ 转录完成！耗时 {elapsed:.1f} 秒，共 {char_count} 字")

    # ---- 清理中间文件 ----
    if not DEBUG:
        raw_audio_tmp.unlink(missing_ok=True)
        audio_wav.unlink(missing_ok=True)
    else:
        print_warn("Debug 模式：中间文件已保留")

    # ---- 完成 ----
    print()
    print(f"{GREEN}  ┌──────────────────────────────────────┐{NC}")
    print(f"{GREEN}  │  🎉 转录完成！                       │{NC}")
    print(f"{GREEN}  └──────────────────────────────────────┘{NC}")
    print()
    print(f"  📄 文字稿:   {BOLD}{text_file}{NC}")
    print(f"  ⏱️  时间戳:   {DIM}{timestamp_file}{NC}")
    print()

    # 复制到剪贴板（Windows）
    if sys.platform == "win32":
        try:
            subprocess.run(["clip"], input=text_file.read_bytes(), check=False)
            print(f"  {YELLOW}📋 文字稿已复制到剪贴板{NC}")
            print()
        except Exception:
            pass

if __name__ == "__main__":
    main()
