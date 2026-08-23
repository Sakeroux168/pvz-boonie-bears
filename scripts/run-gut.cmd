@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-gut.ps1" %*
exit /b %ERRORLEVEL%
