[CmdletBinding()]
param(
    [switch]$ServiceOnly,
    [string]$AutoHotkeyPath
)

$ErrorActionPreference = 'Stop'

function Assert-RoxyInputDesktop {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class RoxyReaderDesktop {
    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    private static extern IntPtr GetThreadDesktop(uint threadId);

    [DllImport("user32.dll")]
    private static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);

    [DllImport("user32.dll")]
    private static extern bool CloseDesktop(IntPtr desktop);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool GetUserObjectInformation(
        IntPtr handle, int index, StringBuilder buffer, int bytes, out int required);

    private static string DesktopName(IntPtr handle) {
        var name = new StringBuilder(256);
        return handle != IntPtr.Zero &&
            GetUserObjectInformation(handle, 2, name, name.Capacity * sizeof(char), out _)
            ? name.ToString()
            : null;
    }

    public static bool CanReceiveKeyboardInput() {
        var desktop = OpenInputDesktop(0, false, 1);
        if (desktop == IntPtr.Zero) return false;
        try {
            var current = DesktopName(GetThreadDesktop(GetCurrentThreadId()));
            return !String.IsNullOrEmpty(current) &&
                String.Equals(current, DesktopName(desktop), StringComparison.OrdinalIgnoreCase);
        } finally {
            CloseDesktop(desktop);
        }
    }
}
'@
    if (-not [RoxyReaderDesktop]::CanReceiveKeyboardInput()) {
        throw '当前窗口位于隔离桌面，快捷键监听无法接收实体按键。请从 Windows 资源管理器双击 Start-RoxyReader.cmd。'
    }
}

try {
    $api = Invoke-RestMethod -Uri 'http://127.0.0.1:9880/openapi.json' -TimeoutSec 2
} catch {
    throw '无法连接本机语音服务。请按 README 启动 GPT-SoVITS API。'
}
if (-not $api.paths.'/tts'.post) {
    throw '本机端口 9880 未提供 GPT-SoVITS 的 POST /tts 接口。'
}

if ($ServiceOnly) { return }

Assert-RoxyInputDesktop
if ($AutoHotkeyPath) {
    $ahk = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($AutoHotkeyPath)
} else {
    $ahk = Get-Command AutoHotkey64.exe, AutoHotkey.exe -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty Source
    if (-not $ahk) {
        $ahk = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'AutoHotkey/v2/AutoHotkey64.exe'
    }
}
if (-not (Test-Path -LiteralPath $ahk -PathType Leaf)) {
    throw '找不到 AutoHotkey v2。请将它加到 PATH，或通过 -AutoHotkeyPath 指定可执行文件。'
}
$script = Join-Path $PSScriptRoot 'ReadSelection.ahk'
$env:ROXY_READER_PWSH = Join-Path $PSHOME 'pwsh.exe'
$shortcut = Start-Process -FilePath $ahk -ArgumentList @('/ErrorStdOut',('"' + $script + '"')) -WindowStyle Hidden -PassThru
if ($shortcut.WaitForExit(1000)) { throw "快捷键监听启动失败，退出码 $($shortcut.ExitCode)。" }
Write-Host 'Roxy Reader 已就绪。在 ChatGPT 或 Codex 桌面端选中文字，按 Ctrl+Alt+Shift+R 朗读。'

