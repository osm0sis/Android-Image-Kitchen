@echo off

%~d0
cd "%~p0"
if "%~1" == "--help" echo usage: cleanup.bat & goto end

rd /s /q ramdisk >nul 2>&1
rd /s /q split_img >nul 2>&1
del *new.* *original.* >nul 2>&1
echo %cmdcmdline% | findstr /i pushd >nul
if not errorlevel 1 echo Working directory cleaned. & echo.

:end
