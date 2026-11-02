@echo off
title Tala Hotel - install
cd /d "%~dp0"
set "XAMPP=C:\xampp"

echo ============================================================
echo   TALA HOTEL - install on this laptop
echo ============================================================
echo.
if not exist "%XAMPP%\htdocs" set /p XAMPP="Where is XAMPP installed? Example C:\xampp : "
if not exist "%XAMPP%\htdocs" goto noxampp

"%XAMPP%\mysql\bin\mysqladmin.exe" -u root ping >nul 2>nul
if errorlevel 1 goto nomysql

echo [1/3] Copying the app into XAMPP...
if exist "%XAMPP%\htdocs\tala" rmdir /S /Q "%XAMPP%\htdocs\tala"
xcopy "app" "%XAMPP%\htdocs\tala\" /E /I /Y >nul
xcopy "tala_api" "%XAMPP%\htdocs\tala_api\" /E /I /Y >nul

echo [2/3] Setting up the database...
"%XAMPP%\mysql\bin\mysql.exe" -u root -e "USE tala_hotel" >nul 2>nul
if errorlevel 1 goto importdb
echo.
echo   This laptop ALREADY has Tala Hotel records.
set /p ANS="  Replace them with the records in this folder? Type Y or N then Enter: "
if /I "%ANS%"=="Y" goto importdb
echo   Keeping the existing records.
goto done

:importdb
set "SQL=tala_hotel.sql"
if exist "my_records.sql" set "SQL=my_records.sql"
"%XAMPP%\mysql\bin\mysql.exe" -u root --default-character-set=utf8mb4 < "%SQL%"
if errorlevel 1 goto sqlfail
echo       Database ready.

:done
echo [3/3] Opening Tala Hotel...
start "" "http://localhost/tala/"
echo.
echo ============================================================
echo   INSTALLED!  The app opens at   http://localhost/tala/
echo   Bookmark that page. Next time just start XAMPP and open it.
echo ============================================================
pause
exit /b 0

:noxampp
echo [X] XAMPP was not found. Install XAMPP first: https://www.apachefriends.org
pause
exit /b 1

:nomysql
echo [X] MySQL is not running.
echo     Open the XAMPP Control Panel, click START on Apache and MySQL,
echo     then double-click INSTALL.bat again.
pause
exit /b 1

:sqlfail
echo [X] The database could not be created. Is MySQL green in XAMPP?
pause
exit /b 1
