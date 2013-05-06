@echo off

cd "%~p0"
if not exist split_img\nul goto nofiles
set bin=android_win_tools

echo Android Image Kitchen - RepackImg Script
echo by osm0sis @ xda-developers
echo.

if not exist *-new.* goto nowarning
echo Warning: Overwriting existing files!
echo.

:nowarning
echo Packing ramdisk . . .
echo.
for /f "delims=" %%a in ('dir /b split_img\*-ramdiskcomp') do @set ramdiskcname=%%a
for /f "delims=" %%a in ('type split_img\%ramdiskcname%') do @set ramdiskcomp=%%a
if "%ramdiskcomp%"=="LZMA" set "ramdiskcomp=lzma"
if "%ramdiskcomp%"=="XZ" set "ramdiskcomp=xz"
echo Using compression: %ramdiskcomp%
if "%ramdiskcomp%"=="gzip" %bin%\mkbootfs ramdisk | %bin%\gzip > ramdisk-new.cpio.gz
if "%ramdiskcomp%"=="lzop" %bin%\mkbootfs ramdisk | %bin%\lzop > ramdisk-new.cpio.lzo
if "%ramdiskcomp%"=="lzma" %bin%\mkbootfs ramdisk | %bin%\xz -Flzma > ramdisk-new.cpio.lzma
if "%ramdiskcomp%"=="xz" %bin%\mkbootfs ramdisk | %bin%\xz -1 -Ccrc32 > ramdisk-new.cpio.xz
if "%ramdiskcomp%"=="bzip2" %bin%\mkbootfs ramdisk | %bin%\bzip2 > ramdisk-new.cpio.bz2
for /f "delims=" %%a in ('dir /b ramdisk-new.cpio.*') do @set ramdisk=%%a
echo.

echo Getting build information . . .
echo.
for /f "delims=" %%a in ('dir /b split_img\*-zImage') do @set kernel=%%a
echo kernel = %kernel%
for /f "delims=" %%a in ('dir /b split_img\*-cmdline') do @set cmdname=%%a
for /f "delims=" %%a in ('type split_img\%cmdname%') do @set cmdline='%%a'
echo cmdline = %cmdline%
for /f "delims=" %%a in ('dir /b split_img\*-base') do @set basename=%%a
for /f "delims=" %%a in ('type split_img\%basename%') do @set base=0x%%a
echo base = %base%
for /f "delims=" %%a in ('dir /b split_img\*-pagesize') do @set pagename=%%a
for /f "delims=" %%a in ('type split_img\%pagename%') do @set pagesize=%%a
echo pagesize = %pagesize%
for /f "delims=" %%a in ('dir /b split_img\*-ramdiskaddr') do @set ramdiskaname=%%a
for /f "delims=" %%a in ('type split_img\%ramdiskaname%') do @set ramdiskaddr=%%a0000
echo ramdiskaddr = %ramdiskaddr%
echo.

echo Building image . . .
echo.
setlocal EnableDelayedExpansion
if "!cmdline!"=="" endlocal & goto nocmd
endlocal
%bin%\mkbootimg --kernel split_img/%kernel% --ramdisk %ramdisk% --cmdline %cmdline% --base %base% --pagesize %pagesize% --ramdiskaddr %ramdiskaddr% -o image-new.img
goto done
:nocmd
%bin%\mkbootimg --kernel split_img/%kernel% --ramdisk %ramdisk% --base %base% --pagesize %pagesize% --ramdiskaddr %ramdiskaddr% -o image-new.img

:done
echo Done!
goto end

:nofiles
echo No files found to be packed/built.

:end
echo.
pause
