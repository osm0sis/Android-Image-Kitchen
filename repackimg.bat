@echo off
set CYGWIN=nodosfilewarning
set hideErrors=n

cd "%~p0"
if not exist split_img\nul goto nofiles
set bin=android_win_tools
set "errout= "
if "%hideErrors%" == "y" set "errout=2>nul"

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
for /f "delims=" %%a in ('type "split_img\%ramdiskcname%"') do @set ramdiskcomp=%%a
echo Using compression: %ramdiskcomp%
if "%ramdiskcomp%" == "gzip" set "repackcmd=gzip" & set "compext=gz"
if "%ramdiskcomp%" == "lzop" set "repackcmd=lzop" & set "compext=lzo"
if "%ramdiskcomp%" == "lzma" set "repackcmd=xz -Flzma" & set "compext=lzma"
if "%ramdiskcomp%" == "xz" set "repackcmd=xz -1 -Ccrc32" & set "compext=xz"
if "%ramdiskcomp%" == "bzip2" set "repackcmd=bzip2" & set "compext=bz2"
if "%ramdiskcomp%" == "lz4" set "repackcmd=lz4 stdin stdout 2>nul" & set "compext=lz4"
%bin%\mkbootfs ramdisk %errout% | %bin%\%repackcmd% %errout% > ramdisk-new.cpio.%compext%
echo.

echo Getting build information . . .
echo.
for /f "delims=" %%a in ('dir /b split_img\*-zImage') do @set kernel=%%a
echo kernel = %kernel%
for /f "delims=" %%a in ('dir /b split_img\*-cmdline') do @set cmdname=%%a
for /f "delims=" %%a in ('type "split_img\%cmdname%"') do @set cmdline=%%a
echo cmdline = %cmdline%
for /f "delims=" %%a in ('dir /b split_img\*-base') do @set basename=%%a
for /f "delims=" %%a in ('type "split_img\%basename%"') do @set base=%%a
echo base = %base%
for /f "delims=" %%a in ('dir /b split_img\*-pagesize') do @set pagename=%%a
for /f "delims=" %%a in ('type "split_img\%pagename%"') do @set pagesize=%%a
echo pagesize = %pagesize%
for /f "delims=" %%a in ('dir /b split_img\*-ramdiskaddr') do @set ramdiskaname=%%a
for /f "delims=" %%a in ('type "split_img\%ramdiskaname%"') do @set ramdiskaddr=%%a
echo ramdiskaddr = %ramdiskaddr%
echo.

echo Building image . . .
echo.
if not "%cmdline%" == "" set "cmdline=--cmdline '%cmdline%'"
%bin%\mkbootimg --kernel split_img/%kernel% --ramdisk ramdisk-new.cpio.%compext% %cmdline% --base %base% --pagesize %pagesize% --ramdiskaddr %ramdiskaddr% -o image-new.img %errout%

echo Done!
goto end

:nofiles
echo No files found to be packed/built.

:end
echo.
pause
