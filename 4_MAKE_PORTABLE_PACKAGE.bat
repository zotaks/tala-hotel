@echo off
title Tala Hotel - make a package for another laptop
cd /d "%~dp0"
set "XAMPP=C:\xampp"
set "OUT=%~dp0Tala_Portable"

echo ============================================================
echo   TALA HOTEL - make a package for another laptop
echo   This takes about 1-2 minutes. Please wait.
echo ============================================================
echo.

where flutter >nul 2>nul
if errorlevel 1 goto noflutter

echo [1/3] Building the app...
call flutter pub get >nul
call flutter build web --release --base-href /tala/
if errorlevel 1 goto buildfail

echo [2/3] Collecting the files...
if exist "%OUT%" rmdir /S /Q "%OUT%"
mkdir "%OUT%"
xcopy "build\web" "%OUT%\app\" /E /I /Y >nul
xcopy "xampp\htdocs\tala_api" "%OUT%\tala_api\" /E /I /Y >nul
copy /Y "xampp\database\tala_hotel.sql" "%OUT%\tala_hotel.sql" >nul
copy /Y "portable\INSTALL.bat" "%OUT%\INSTALL.bat" >nul
copy /Y "portable\READ_ME_FIRST.txt" "%OUT%\READ_ME_FIRST.txt" >nul

echo [3/3] Saving your current records...
"%XAMPP%\mysql\bin\mysqladmin.exe" -u root ping >nul 2>nul
if errorlevel 1 goto norecords
"%XAMPP%\mysql\bin\mysql.exe" -u root -e "USE tala_hotel" >nul 2>nul
if errorlevel 1 goto norecords
"%XAMPP%\mysql\bin\mysqldump.exe" -u root --default-character-set=utf8mb4 --databases tala_hotel --result-file="%OUT%\my_records.sql"
echo       Your bookings and accounts were saved into the package.
goto finished

:norecords
echo       No records saved - XAMPP MySQL is not running here.
echo       The other laptop will start with the original sample data.

:finished
echo.
echo ============================================================
echo   DONE!  A folder called  Tala_Portable  was created.
echo   Copy it to a USB or Google Drive, then on the other laptop
echo   open it and double-click  INSTALL.bat
echo ============================================================
explorer "%OUT%"
pause
exit /b 0

:noflutter
echo [X] Flutter is not installed on this laptop.
echo     Run this on the laptop where the app already works.
pause
exit /b 1

:buildfail
echo [X] The build failed. Take a photo of the red message and send it for a fix.
pause
exit /b 1
