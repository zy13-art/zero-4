#Requires AutoHotkey v2.0
#SingleInstance Force
#HotIf WinActive("ahk_exe ChatGPT.exe") || WinActive("ahk_exe Codex.exe")
^!+r:: {
    saved := ClipboardAll()
    A_Clipboard := ""
    try {
        Send "^c"
        if !ClipWait(1)
            return
        text := A_Clipboard
    } finally {
        A_Clipboard := saved
    }
    input := A_Temp "\roxy-" A_TickCount "-" Random(10000, 99999) ".txt"
    try {
        FileAppend text, input, "UTF-8-RAW"
        powerShell := EnvGet("ROXY_READER_PWSH")
        if !powerShell
            powerShell := "pwsh.exe"
        exitCode := RunWait('"' powerShell '" -NoLogo -NoProfile -File "' A_ScriptDir '\Speak.ps1" -InputPath "' input '"',, "Hide")
        if exitCode
            MsgBox "朗读失败。请检查本地模型及 settings.json。", "洛琪希朗读"
    } catch as err {
        MsgBox err.Message, "洛琪希朗读"
    } finally {
        if FileExist(input)
            FileDelete input
    }
}
#HotIf


