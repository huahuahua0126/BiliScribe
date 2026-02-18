# BiliScribe 🎬

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%20Apple%20Silicon-000000?style=for-the-badge&logo=apple&logoColor=white">
  <img src="https://img.shields.io/badge/Model-Whisper%20Large%20v3-74aa9c?style=for-the-badge&logo=openai&logoColor=white">
  <img src="https://img.shields.io/badge/Privacy-100%25%20Local-4CAF50?style=for-the-badge">
  <img src="https://img.shields.io/badge/Cost-Free%20Forever-FF6B35?style=for-the-badge">
</p>

<p align="center">
  <strong>B 站视频一键转文字 — 双击启动 · 纯本地 · 零成本</strong>
</p>

---

## ✨ 它能做什么

粘贴一个 B 站链接，几分钟后得到完整文字稿，自动保存 + 复制到剪贴板。

```
你          →  粘贴链接
BiliScribe  →  下载音频 → 转录 → 保存文字稿
你          →  直接粘贴到 AI 总结 / 做笔记
```

**支持的输入格式：**
- 完整链接：`https://www.bilibili.com/video/BV1XFhPzoEBx/`
- APP 分享文案：`【视频标题】 https://b23.tv/xxx`
- BV 号：`BV1XFhPzoEBx`
- AV 号：`av999999`

---

## 🚀 快速开始

### 1. 安装依赖

```bash
brew install yt-dlp ffmpeg python
```

### 2. 克隆 & 安装

```bash
git clone https://github.com/huahuahua0126/BiliScribe.git
cd BiliScribe
bash install.sh
```

`install.sh` 会自动检查依赖、设置权限，并将启动器放到你的桌面。

### 3. 使用

**🖱️ 方式 A（推荐）：双击桌面启动器**

桌面出现 `BiliScribe启动器`，双击 → 粘贴链接 → 等待完成。支持连续转录多个视频，不用反复打开。

**⌨️ 方式 B：命令行**

```bash
./biliscribe.sh "https://www.bilibili.com/video/BV1XFhPzoEBx/"
```

> 首次运行会自动创建 Python 虚拟环境并下载 Whisper 模型（约 3GB），之后无需重复下载。

---

## 📂 输出文件

转录完成后，文字稿保存在项目目录的 `output/` 文件夹：

| 文件 | 说明 |
|:-----|:-----|
| `标题.txt` | 纯净文字稿，适合 AI 处理 |
| `标题_timestamps.txt` | 带时间戳版本，适合字幕制作 |

文字稿同时会自动复制到剪贴板，可直接粘贴使用。

---

## ⚙️ 高级配置

通过环境变量自定义行为：

```bash
# 更换模型（速度更快，精度略低）
export BILISCRIBE_MODEL="mlx-community/whisper-medium-mlx"

# 自定义输出目录
export BILISCRIBE_OUTPUT_DIR="$HOME/Desktop/transcripts"

# Debug 模式（保留中间音频文件，用于排错）
export BILISCRIBE_DEBUG=1
```

---

## 🛠️ 故障排查

遇到问题时，开启 Debug 模式运行：

```bash
BILISCRIBE_DEBUG=1 ./biliscribe.sh <URL>
```

脚本会保留 `.raw_audio` 和 `.wav` 文件，可试听确认音频是否正常下载。

---

## 🔧 技术栈

| 工具 | 职责 |
|:-----|:-----|
| `yt-dlp` | 解析并下载 B 站纯音频流 |
| `ffmpeg` | 转码为 Whisper 所需的 16kHz WAV |
| `mlx-whisper` | Apple Silicon 本地语音识别 |
| `Bash` | 流程编排、信号处理、文件管理 |

---

## 📝 License

[MIT License](LICENSE)

---

<p align="center">Made with ❤️ for efficiency · 数据不离本机，永久免费</p>
