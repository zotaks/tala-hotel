@echo off
title Tala Hotel - XAMPP setup
cd /d "%~dp0"
echo ============================================================
echo   TALA HOTEL - XAMPP setup
echo   Start Apache and MySQL in the XAMPP Control Panel first.
echo ============================================================
echo.

set "XAMPP=C:\xampp"
if not exist "%XAMPP%\htdocs" (
  set /p XAMPP="XAMPP folder not found at C:\xampp. Type your XAMPP folder: "
)
if not exist "%XAMPP%\htdocs" (
  echo [X] Could not find "%XAMPP%\htdocs". Setup stopped.
  pause
  exit /b 1
)

echo [1/2] Copying the API to %XAMPP%\htdocs\tala_api ...
xcopy "xampp\htdocs\tala_api" "%XAMPP%\htdocs\tala_api\" /E /I /Y >nul
if errorlevel 1 (
  echo [X] Copy failed.
  pause
  exit /b 1
)
echo       done.

echo [2/2] Creating the tala_hotel database with dummy data ...
"%XAMPP%\mysql\bin\mysql.exe" -u root --default-character-set=utf8mb4 < "xampp\database\tala_hotel.sql"
if errorlevel 1 (
  echo [X] Import failed. Is MySQL running in XAMPP? If your MySQL root user has a
  echo     password, import xampp\database\tala_hotel.sql in phpMyAdmin instead.
  pause
  exit /b 1
)
echo       done.
echo.
echo All set! Opening the API check page...
start "" "http://localhost/tala_api/"
echo.
echo The app uses http://localhost/tala_api/api.php by default.
echo Staff log in on the same page as guests and set a new password at first sign-in.
pause
