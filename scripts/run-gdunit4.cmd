@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-gdunit4.ps1" %*
exit /b %ERRORLEVEL%
