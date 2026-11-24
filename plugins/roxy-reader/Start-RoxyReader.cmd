@echo off
pwsh.exe -NoLogo -NoProfile -File "%~dp0Start-RoxyReader.ps1" %*
if errorlevel 1 pause
