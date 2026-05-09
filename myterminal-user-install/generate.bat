@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate.ps1" %*
exit /b %ERRORLEVEL%
