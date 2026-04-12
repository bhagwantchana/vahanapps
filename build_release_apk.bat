@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0build_release_apk.ps1" %*
endlocal
