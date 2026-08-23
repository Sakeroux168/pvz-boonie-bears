@echo off
REM P2 one-click GUT test runner (Windows). Usage:
REM   scripts\run-tests.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-tests.ps1" %*
exit /b %ERRORLEVEL%
