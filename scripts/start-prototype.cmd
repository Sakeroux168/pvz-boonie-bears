@echo off
REM P2 prototype launcher (Windows). Usage:
REM   scripts\start-prototype.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64.exe"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  ". '%~dp0common.ps1'; $g = Resolve-P2Godot $args[0]; & $g --path (Split-Path -Parent $PSScriptRoot)" ^
  %1
exit /b %ERRORLEVEL%
