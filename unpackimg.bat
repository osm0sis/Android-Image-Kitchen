@echo off
set CYGWIN=nodosfilewarning
set hideErrors=n

%~d0
cd "%~p0"
if "%~1" == "" goto noargs
set "file=%~f1"
set bin=..\android_win_tools
set "errout= "
if "%hideErrors%" == "y" set "errout=2>nul"

echo Android Image Kitchen - UnpackImg Script
echo by osm0sis @ xda-developers
echo.

echo Supplied image: %~nx1
echo.

if exist split_img\nul set "noclean=1"
if exist ramdisk\nul set "noclean=1"
if not "%noclean%" == "1" goto noclean
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
%bin%\unpackbootimg -i "%file%"
if errorlevel == 1 call "%~p0\cleanup.bat" & goto error
echo.
%bin%\file -m %bin%\magic *-ramdisk.gz %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f2 %errout% > "%~nx1-ramdiskcomp"
for /f "delims=" %%a in ('type "%~nx1-ramdiskcomp"') do @set ramdiskcomp=%%a
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
if "%compext%" == "" goto error
%bin%\%unpackcmd% "../split_img/%~nx1-ramdisk.cpio.%compext%" %extra% %errout% | %bin%\cpio -i %errout%
if errorlevel == 1 goto error
echo.
cd ..

echo Done!
goto end

:noargs
echo No image file supplied.

:error
echo Error!

:end
echo.
pause
