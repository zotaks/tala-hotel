@echo off
title Tala Hotel - build and publish to XAMPP
cd /d "%~dp0"
set "XAMPP=C:\xampp"
if not exist "%XAMPP%\htdocs" set /p XAMPP="Type your XAMPP folder: "
echo Building the web app (takes a minute)...
call flutter pub get
call flutter build web --release --base-href /tala/
if errorlevel 1 (
  echo [X] Build failed. Copy the red error message and send it for a fix.
  pause
  exit /b 1
)
echo Copying to %XAMPP%\htdocs\tala ...
if exist "%XAMPP%\htdocs\tala" rmdir /S /Q "%XAMPP%\htdocs\tala"
xcopy "build\web" "%XAMPP%\htdocs\tala\" /E /I /Y >nul
echo Done! Opening http://localhost/tala/
start "" "http://localhost/tala/"
echo.
echo Other phones/PCs on the same Wi-Fi: http://YOUR-PC-IP/tala/
echo (and set the API address in the app to http://YOUR-PC-IP/tala_api/api.php)
pause
