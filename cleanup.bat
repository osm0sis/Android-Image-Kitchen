@echo off
setlocal
set CYGWIN=nodosfilewarning

set "bin=%~dp0\android_win_tools"
%~d0
cd "%~p0"
if "%~1" == "--help" echo usage: cleanup.bat & goto end

"%bin%"\chmod -fR +rw ramdisk split_img >nul 2>&1
rd /s /q ramdisk >nul 2>&1
rd /s /q split_img >nul 2>&1
del *new.* *original.* >nul 2>&1
echo %cmdcmdline% | findstr /i pushd >nul
if not errorlevel 1 echo Working directory cleaned. & echo.

:end
