# BiliScribe 🎬

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Apple%20Silicon-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS Apple Silicon">
  <img src="https://img.shields.io/badge/Model-OpenAI%20Whisper%20v3-74aa9c?style=for-the-badge&logo=openai&logoColor=white" alt="Whisper">
  <img src="https://img.shields.io/badge/Privacy-100%25%20Local-success?style=for-the-badge" alt="Local">
</p>

<p align="center">
  <strong>B站视频一键转文字 — 极速・纯本地・零干扰</strong>
</p>

> 🚀 **v2.0 新特性**：采用纯音频流下载，速度提升 10 倍；全流程原子化操作，自带中断保护与自动清理，只留干货！

---

## ⚡️ 核心亮点

- **零成本**：无需 API Key，不消耗任何 token，永久免费。
- **隐私安全**：基于 Apple MLX 框架，Deep Learning 模型完全在本地运行。
- **极速体验**：智能解析 B 站音频流，**跳过庞大的视频下载**，秒级完成准备工作。
- **干净卫生**：
  - **原子写入**：使用临时文件处理，只有成功才会生成最终文件。
  - **中断保护**：运行中按 `Ctrl+C` 会自动触发清理，不留垃圾文件。
  - **自动扫除**：转录完成后自动删除音频中间件，节省磁盘空间。

## 📖 工作流

BiliScribe 将繁琐的人工操作压缩为一条全自动流水线：

```mermaid
graph LR
    A[B站链接] -->|yt-dlp| B(下载纯音频)
    B -->|ffmpeg| C(转换为 16kHz WAV)
    C -->|mlx-whisper| D(本地模型转录)
    D --> E[生成 TXT + 时间戳]
    E --> F{自动清理}
    F -->|删除音频| G[📋 自动复制到剪贴板]
```

## 🚀 快速开始

### 1. 环境准备

需要 macOS (Apple Silicon) 和 Homebrew：

```bash
brew install yt-dlp ffmpeg python
```

### 2. 安装与运行

```bash
# 下载脚本
git clone https://github.com/reallier/BiliScribe.git
cd BiliScribe
chmod +x biliscribe.sh

# 开始转录！
./biliscribe.sh "https://www.bilibili.com/video/BV1XFhPzoEBx/"
```

首次运行会自动配置 Python 虚拟环境并下载 Whisper 模型（约 3GB）。

## 📂 输出产物

脚本运行完毕后，**文字稿会自动复制到剪贴板**，可直接粘贴到 AI 工具中总结。

同时在 `~/Downloads/bilibili-downloads/` 目录下生成：

| 文件名 | 说明 |
|:-------|:-----|
| `标题.txt` | **纯净文本**，适合阅读与 AI 处理 |
| `标题_timestamps.txt` | **带时间戳**，适合人工校对与字幕制作 |
| ~~`标题.wav`~~ | *已自动删除，节省空间* |

## ⚙️ 高级配置

通过环境变量控制脚本行为：

```bash
# Debug 模式：保留中间音频文件，输出详细日志（用于排错）
export BILISCRIBE_DEBUG=1

# 更换模型：使用 medium 模型（速度更快，精度略降）
export BILISCRIBE_MODEL="mlx-community/whisper-medium-mlx"

# 自定义下载目录
export BILISCRIBE_OUTPUT_DIR="$HOME/Desktop/transcripts"
```

## 📊 性能基准

基于 MacBook Air M4 (16GB) 测试：

| 视频时长 | 下载音频 | Whisper 转录 (Large v3) | 总耗时 | 提升 (vs v1) |
|:---------|:---------|:------------------------|:-------|:-------------|
| 10 分钟 | < 3s | ~ 1 min | **~ 1.1 min** | 🟢 速度 +40% |
| 60 分钟 | < 10s | ~ 8 min | **~ 8.2 min** | 🟢 速度 +30% |

*注：得益于 Audio Only 策略，下载耗时几乎可以忽略不计。*

## 🛠️ 故障排查

如果遇到转录失败或乱码，请**开启 Debug 模式**运行：

```bash
BILISCRIBE_DEBUG=1 ./biliscribe.sh <URL>
```

脚本会保留 `.raw_audio` 和 `.wav` 文件，你可以试听这些音频确认是否下载正常。

## 📝 License

本项目基于 [MIT License](LICENSE) 开源。

---
<p align="center">
  Made with ❤️ for efficiency
</p>
