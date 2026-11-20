@echo off
setlocal
set "LOGDIR=%LOCALAPPDATA%\RetroConsoleManager"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOG=%LOGDIR%\launcher.log"
start "" /min powershell.exe -NoProfile -NoLogo -STA -WindowStyle Hidden -ExecutionPolicy Bypass -Command "try { & '%~dp0retro-console-manager.ps1' } catch { Add-Type -AssemblyName PresentationFramework; $_ | Out-String | Add-Content -LiteralPath '%LOG%' -Encoding UTF8; [System.Windows.MessageBox]::Show($_.Exception.Message, 'Retro Console Manager - Startup Error', 'OK', 'Error') | Out-Null }"
endlocal
