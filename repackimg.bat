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
%bin%\mkbootfs ramdisk | %bin%\gzip > ramdisk-new.cpio.gz

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
echo.

echo Building image . . .
echo.
setlocal EnableDelayedExpansion
if "!cmdline!"=="" endlocal & goto nocmd
endlocal
%bin%\mkbootimg --kernel split_img/%kernel% --ramdisk ramdisk-new.cpio.gz --cmdline %cmdline% --base %base% --pagesize %pagesize% -o image-new.img
goto done
:nocmd
%bin%\mkbootimg --kernel split_img/%kernel% --ramdisk ramdisk-new.cpio.gz --base %base% --pagesize %pagesize% -o image-new.img

:done
echo Done!
goto end

:nofiles
echo No files found to be packed/built.

:end
echo.
pause
