@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-graybox.ps1" %*
exit /b %ERRORLEVEL%
