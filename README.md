# Roxy Reader

Windows 本地语音朗读。Roxy Reader 将文本交给本机的 GPT-SoVITS，生成可在 Codex 桌面聊天里点击播放的 WAV。也可以用划词快捷键朗读桌面客户端里的选中文本。

## 准备环境

- 安装 Windows 版 PowerShell 7，并确认终端能运行 `pwsh`。
- 部署 [GPT-SoVITS v2Pro](https://github.com/RVC-Boss/GPT-SoVITS/releases/tag/20250606v2pro)。也可解压[上游 Windows 整合包](https://huggingface.co/lj1995/GPT-SoVITS-windows-package/blob/main/GPT-SoVITS-v2pro-20250604.7z)。
- 准备一段约 3 到 10 秒的日语参考 WAV 以及准确的日语转录。要复现特定音色，还需要相应的 SoVITS 权重。参考录音和权重由使用者自行准备。
- 按需安装 [FFmpeg](https://ffmpeg.org/download.html) 做响度标准化，或安装 [AutoHotkey v2](https://www.autohotkey.com/) 使用划词快捷键。

## 启动语音服务

在 GPT-SoVITS 目录内，从已配置好依赖的 Python 环境运行下面的命令。使用 Windows 整合包时，可在 PowerShell 中把 `python` 改成 `./runtime/python.exe`。

```powershell
python api_v2.py -a 127.0.0.1 -p 9880 -c GPT_SoVITS/configs/tts_infer.yaml
```

若使用自己的 v2Pro 模型，在对应的推理 YAML 的 `custom` 部分配置 `version: v2Pro`、`t2s_weights_path` 和 `vits_weights_path`。本项目的原始音色配置使用 v2Pro 基础 GPT 权重 `s1v3.ckpt` 和单独微调的 SoVITS 权重。推理服务绑定本机回环地址。

## 配置与测试

从本仓库根目录执行以下命令，将配置放到固定的本机目录。也可以将副本命名为 `settings.json`，放在 `Speak.ps1` 旁作为该副本的独立配置。

```powershell
$configDir = Join-Path $env:LOCALAPPDATA 'RoxyReader'
New-Item -ItemType Directory -Path $configDir -Force | Out-Null
Copy-Item ./plugins/roxy-reader/settings.example.json (Join-Path $configDir 'settings.json')
```

在配置文件里填写 `referenceAudio` 和 `referenceText`。前者是参考 WAV 路径，后者是该录音的日语转录。路径相对于配置文件所在目录，也可用绝对路径。在 JSON 里的 Windows 路径可写成 `D:/Voice/reference.wav`。可选的 `ffmpegPath` 指向 `ffmpeg.exe`，用于将输出音频调整至约 −18 LUFS。配置示例使用 `cut2` 合并短分句，`textLanguage` 默认为 `auto`。

启动语音服务后，从仓库根目录执行以下测试。合成成功时，脚本会返回 WAV 的绝对路径。测试文件名每次生成一份，方便反复验证。

```powershell
$reader = './plugins/roxy-reader'
& "$reader/Start-RoxyReader.ps1" -ServiceOnly
$name = 'roxy-' + [guid]::NewGuid().ToString('N')
$inputFile = Join-Path $env:TEMP "$name.txt"
$outputFile = Join-Path $env:TEMP "$name.wav"
'你好，这是一条本地朗读测试。' | Set-Content -Encoding utf8 -LiteralPath $inputFile
& "$reader/Speak.ps1" -InputPath $inputFile -OutputPath $outputFile
```

## 在 Codex 中使用

在支持插件安装的 Codex CLI 中，从仓库根目录执行以下命令。也可以在桌面客户端中打开此项目，重启客户端，然后在本地插件市场安装 Roxy Reader。[插件安装文档](https://developers.openai.com/plugins/build/plugins#build-your-own-curated-plugin-list)

```powershell
codex plugin marketplace add (Get-Location).Path
codex plugin add roxy-reader@zero-4
```

打开新聊天，可以说「用 Roxy Reader 朗读这条回复」。如需默认点播，在桌面客户端的个性化设置中添加下面这条个人指令。[Codex 个性化配置](https://learn.chatgpt.com/docs/agent-configuration/agents-md)

> 在本机 Codex 桌面聊天里，用 roxy-reader 给主要回复附上点播音频。用户点击才播放。说「关闭朗读」时暂停这个聊天的点播，说「开启朗读」时恢复。

点播需要聊天能运行本机技能、访问本地 GPT-SoVITS 服务并显示音频附件。网页版普通 Chat 的逐条点播需要单独的浏览器扩展。

## 使用划词快捷键

先启动 GPT-SoVITS API，然后在 Windows 资源管理器里双击 `plugins/roxy-reader/Start-RoxyReader.cmd`。看到就绪提示后，在 ChatGPT 或 Codex 桌面客户端选中文字，按 **Ctrl+Alt+Shift+R** 朗读。启动器从 PATH 或 AutoHotkey v2 默认安装目录查找可执行文件。用了自定义位置，也可运行 `Start-RoxyReader.ps1 -AutoHotkeyPath <AutoHotkey.exe 的路径>`。
