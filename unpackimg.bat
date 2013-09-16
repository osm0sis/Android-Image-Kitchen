@echo off
set CYGWIN=nodosfilewarning
set hideErrors=n

cd "%~p0"
if "%~1" == "" goto noargs
set bin=..\android_win_tools
set "errout= "
if "%hideErrors%" == "y" set "errout=2>nul"

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
%bin%\dd ibs=1 count=2 skip=22 obs=1 if="%~p0%~n1%~x1" 2>nul | %bin%\od -h %errout% | %bin%\head -n 1 %errout% | %bin%\cut -c 9- %errout% > %~n1%~x1-ramdiskaddr
for /f "delims=" %%a in ('type "%~n1%~x1-ramdiskaddr"') do @echo %%a0000 > "%~n1%~x1-ramdiskaddr" & echo BOARD_RAMDISK_ADDR %%a0000
echo.
%bin%\file -m %bin%\magic *-ramdisk.gz %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f2 %errout% > "%~n1%~x1-ramdiskcomp"
for /f "delims=" %%a in ('type "%~n1%~x1-ramdiskcomp"') do @set ramdiskcomp=%%a
if "%ramdiskcomp%" == "gzip" set "unpackcmd=gzip -dc" & set "compext=gz"
if "%ramdiskcomp%" == "lzop" set "unpackcmd=lzop -dc" & set "compext=lzo"
if "%ramdiskcomp%" == "lzma" set "unpackcmd=xz -dc" & set "compext=lzma"
if "%ramdiskcomp%" == "xz" set "unpackcmd=xz -dc" & set "compext=xz"
if "%ramdiskcomp%" == "bzip2" set "unpackcmd=bzip2 -dc" & set "compext=bz2"
if "%ramdiskcomp%" == "lz4" ( set "unpackcmd=lz4" & set "extra=stdout 2>nul" & set "compext=lz4"  ) else ( set "extra= " )
ren *ramdisk.gz *ramdisk.cpio.%compext%
cd ..

echo Unpacking ramdisk to "/ramdisk/" . . .
echo.
cd ramdisk
echo Compression used: %ramdiskcomp%
%bin%\%unpackcmd% "../split_img/%~n1%~x1-ramdisk.cpio.%compext%" %extra% %errout% | %bin%\cpio -i %errout%
echo.
cd ..

echo Done!
goto end

:noargs
echo No image file supplied.

:end
echo.
pause
