@echo off
title Tala Hotel - run in Chrome
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo [X] Flutter was not found. Install Flutter or use FlutLab.io.
  pause
  exit /b 1
)
echo Getting packages...
call flutter pub get
if errorlevel 1 ( pause & exit /b 1 )
echo Make sure Apache and MySQL are running in XAMPP.
echo Starting Tala Hotel in Chrome...
call flutter run -d chrome
pause
