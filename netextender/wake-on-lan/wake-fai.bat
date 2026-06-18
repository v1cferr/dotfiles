@echo off
REM ===========================================================================
REM  wake-fai.bat — atalho cliccavel para o wake-fai.ps1 (de duplo-clique).
REM  Roda o PowerShell sem mexer na ExecutionPolicy do sistema. Repassa
REM  quaisquer argumentos (ex.: wake-fai.bat -KeepVpn  /  -Reconfigure).
REM ===========================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0wake-fai.ps1" %*
echo.
pause
