@echo off

if "%~1" == "" goto noargs
set bin=..\android_win_tools
cd "%~p0"

echo Android Image Kitchen - UnpackImg Script
echo by osm0sis @ xda-developers
echo.

echo Supplied image: %~n1%~x1
echo.

if not exist split_img\nul goto noclean
echo Removing old work folders and files . . .
echo.
call cleanup.bat

:noclean
echo Setting up work folders . . .
echo.
md split_img
md ramdisk

echo Splitting image to "/split_img/" . . .
echo.
cd split_img
%bin%\unpackbootimg -i "%~p0%~n1%~x1"
%bin%\dd ibs=1 count=2 skip=22 obs=1 if="%~p0%~n1%~x1" 2>nul | %bin%\od -h | %bin%\head -n 1 | %bin%\cut -c 9- > %~n1%~x1-ramdiskaddr
for /f "delims=" %%a in ('dir /b *-ramdiskaddr') do @set ramdiskaname=%%a
for /f "delims=" %%a in ('type %ramdiskaname%') do @set ramdiskaddr=%%a0000
echo BOARD_RAMDISK_ADDR %ramdiskaddr%
echo.
%bin%\file -m %bin%\magic "%~n1%~x1-ramdisk.gz" 2>nul | %bin%\cut -d: -f2 | %bin%\cut -d" " -f2 > %~n1%~x1-ramdiskcomp
for /f "delims=" %%a in ('dir /b *-ramdiskcomp') do @set ramdiskcname=%%a
for /f "delims=" %%a in ('type %ramdiskcname%') do @set ramdiskcomp=%%a
if "%ramdiskcomp%"=="gzip" ren "%~n1%~x1-ramdisk.gz" "%~n1%~x1-ramdisk.cpio.gz"
if "%ramdiskcomp%"=="lzop" ren "%~n1%~x1-ramdisk.gz" "%~n1%~x1-ramdisk.cpio.lzo"
if "%ramdiskcomp%"=="LZMA" set "ramdiskcomp=lzma" & ren "%~n1%~x1-ramdisk.gz" "%~n1%~x1-ramdisk.cpio.lzma"
if "%ramdiskcomp%"=="XZ" set "ramdiskcomp=xz" & ren "%~n1%~x1-ramdisk.gz" "%~n1%~x1-ramdisk.cpio.xz"
if "%ramdiskcomp%"=="bzip2" ren "%~n1%~x1-ramdisk.gz" "%~n1%~x1-ramdisk.cpio.bz2"
cd ..

echo Unpacking ramdisk to "/ramdisk/" . . .
echo.
cd ramdisk
echo Compression used: %ramdiskcomp%
if "%ramdiskcomp%"=="gzip" %bin%\gzip -dc "../split_img/%~n1%~x1-ramdisk.cpio.gz" | %bin%\cpio -i
if "%ramdiskcomp%"=="lzop" %bin%\lzop -dc "../split_img/%~n1%~x1-ramdisk.cpio.lzo" | %bin%\cpio -i
if "%ramdiskcomp%"=="lzma" %bin%\xz -dc "../split_img/%~n1%~x1-ramdisk.cpio.lzma" | %bin%\cpio -i
if "%ramdiskcomp%"=="xz" %bin%\xz -dc "../split_img/%~n1%~x1-ramdisk.cpio.xz" | %bin%\cpio -i
if "%ramdiskcomp%"=="bzip2" %bin%\bzip2 -dc "../split_img/%~n1%~x1-ramdisk.cpio.bz2" | %bin%\cpio -i
echo.
cd ..

echo Done!
goto end

:noargs
echo No image file supplied.

:end
echo.
pause
