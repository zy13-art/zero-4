---
name: roxy-reader
description: Use when the user asks to hear text in the local Roxy voice or enables Roxy audio playback in the current ChatGPT or Codex desktop conversation.
---

## 对话内点播

为用户要听的回复正文生成 WAV。将正文按 UTF-8 写入工作目录中的临时文本文件，调用插件目录下的 `Speak.ps1 -InputPath <文本文件> -OutputPath <绝对 WAV 路径>`。使用输出目录内独立的文件名。

确认 WAV 已生成，再用 `![播放洛琪希朗读](/绝对路径.wav)` 附在回复里。用户点击时播放。已在当前对话开启点播时，每条主要回复都附上对应音频，直到用户关闭。

## 直接读出

用户明确要求立即读出指定内容时，可以省略 `-OutputPath`，由 `Speak.ps1` 直接通过本机播放器朗读。

语音合成使用本机的 127.0.0.1:9880。找不到配置或合成失败时，说明具体错误。工作区根目录的 README 提供安装和启动方法。
