@echo off
setlocal
set CYGWIN=nodosfilewarning
set hideErrors=n

%~d0
cd "%~p0"
if "%~1" == "--help" echo usage: unpackimg.bat ^<file^> & goto end
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

cd split_img
%bin%\file -m %bin%\androidbootimg.magic "%file%" %errout% | %bin%\cut -d: -f2- %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f3 %errout% | %bin%\cut -d, -f1 %errout% > "%~nx1-imgtype"
for /f "delims=" %%a in ('type "%~nx1-imgtype"') do @set imgtest=%%a
if "%imgtest%" == "bootimg" (
  %bin%\file -m %bin%\androidbootimg.magic "%file%" %errout% | %bin%\cut -d: -f2- %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f2 %errout% > "%~nx1-imgtype"
  for /f "delims=" %%a in ('type "%~nx1-imgtype"') do @set imgtype=%%a
) else call "%~p0\cleanup.bat" & echo Unrecognized format. & goto error
echo Image type: %imgtype%
echo.

if "%imgtype%" == "AOSP" set "splitcmd=unpackbootimg -i"
if "%imgtype%" == "CHROMEOS" set "splitcmd=unpackbootimg -i"
if "%imgtype%" == "ELF" set "splitcmd=unpackelf -i"
if not defined splitcmd call "%~p0\cleanup.bat" & echo Unsupported format. & goto error

%bin%\file -m %bin%\androidbootimg.magic "%file%" %errout% | %bin%\cut -d: -f2- %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f4 %errout% > "%~nx1-lokitype"
for /f "delims=" %%a in ('type "%~nx1-lokitype"') do @set lokitest=%%a
if "%lokitest%" == "LOKI" (
  %bin%\file -m %bin%\androidbootimg.magic "%file%" %errout% | %bin%\cut -d: -f2- %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d( -f2 %errout% | %bin%\cut -d^) -f1 %errout% > "%~nx1-lokitype"
  for /f "delims=" %%a in ('type "%~nx1-lokitype"') do @set "lokitype=%%a" & echo Loki patch with "%%a" type detected, reverting . . .
  echo.
  echo Warning: A dump of your device's aboot.img is required to re-Loki!
  %bin%\loki_tool unlok "%file%" "%~nx1" >nul
  echo.
  set "file=%~nx1"
) else del %~nx1-lokitype

%bin%\tail "%file%" 2>nul | %bin%\file -m %bin%\androidbootimg.magic - %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f2 %errout% > "%~nx1-tailtype"
for /f "delims=" %%a in ('type "%~nx1-tailtype"') do @set tailtype=%%a
if not "%tailtype%" == "SEAndroid" if not "%tailtype%" == "Bump" del %~nx1-tailtype
if exist "*-tailtype" echo Footer with "%tailtype%" type detected. & echo.

echo Splitting image to "split_img/" . . .
echo.
%bin%\%splitcmd% "%file%"
if errorlevel == 1 call "%~p0\cleanup.bat" & goto error
echo.

if "%lokitest%" == "LOKI" move /y "%~nx1" "../unlokied-original.img" >nul

%bin%\file -m %bin%\androidbootimg.magic *-zImage %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f2 %errout% > "%~nx1-mtktest"
for /f "delims=" %%a in ('type "%~nx1-mtktest"') do @set mtktest=%%a
if "%mtktest%" == "MTK" (
  set "mtk=1"
  echo MTK header found in zImage, removing . . .
  %bin%\dd bs=512 skip=1 conv=notrunc if="%~nx1-zImage" of="tempzimg" 2>nul
  move /y tempzimg "%~nx1-zImage" >nul
)
for /f "delims=" %%a in ('dir /b *-ramdisk*.gz') do @set ramdiskname=%%a
%bin%\file -m %bin%\androidbootimg.magic %ramdiskname% %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f2 %errout% > "%~nx1-mtktest"
for /f "delims=" %%a in ('type "%~nx1-mtktest"') do @set mtktest=%%a
%bin%\file -m %bin%\androidbootimg.magic %ramdiskname% %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f4 %errout% > "%~nx1-mtktype"
for /f "delims=" %%a in ('type "%~nx1-mtktype"') do @set mtktype=%%a
if "%mtktest%" == "MTK" (
  if not "%mtk%" == "1" echo Warning: No MTK header found in zImage! & set "mtk=1"
  echo MTK header found in "%mtktype%" type ramdisk, removing . . .
  %bin%\dd bs=512 skip=1 conv=notrunc if="%ramdiskname%" of="temprd" 2>nul
  move /y temprd "%ramdiskname%" >nul
) else (
  if "%mtk%" == "1" (
    if "%mtktype%" == "" (
      echo Warning: No MTK header found in ramdisk, assuming "rootfs" type!
      echo rootfs > "%~nx1-mtktype"
    )
  ) else del "%~nx1-mtktype"
)
del "%~nx1-mtktest"
if "%mtk%" == "1" echo.

if not exist "*-dtb" goto skipdtbtest
%bin%\file -m %bin%\androidbootimg.magic *-dtb %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f2 %errout% > "%~nx1-dtbtest"
for /f "delims=" %%a in ('type "%~nx1-dtbtest"') do @set dtbtest=%%a
if "%imgtype%" == "ELF" if not "%dtbtest%" == "QCDT" if not "%dtbtest%" == "ELF" (
  echo Non-QC DTB found, packing zImage and appending . . .
  echo.
  %bin%\gzip --no-name -9 "%~nx1-zImage"
  copy /b "%~nx1-zImage.gz"+"%~nx1-dtb" "%~nx1-zImage" >nul
  del *-dtb *-zImage.gz
)
del "%~nx1-dtbtest"

:skipdtbtest
%bin%\file -m %bin%\magic *-ramdisk*.gz %errout% | %bin%\cut -d: -f2 %errout% | %bin%\cut -d" " -f2 %errout% > "%~nx1-ramdiskcomp"
for /f "delims=" %%a in ('type "%~nx1-ramdiskcomp"') do @set ramdiskcomp=%%a
if "%ramdiskcomp%" == "gzip" set "unpackcmd=gzip -dc" & set "compext=gz"
if "%ramdiskcomp%" == "lzop" set "unpackcmd=lzop -dc" & set "compext=lzo"
if "%ramdiskcomp%" == "lzma" set "unpackcmd=xz -dc" & set "compext=lzma"
if "%ramdiskcomp%" == "xz" set "unpackcmd=xz -dc" & set "compext=xz"
if "%ramdiskcomp%" == "bzip2" set "unpackcmd=bzip2 -dc" & set "compext=bz2"
if "%ramdiskcomp%" == "lz4" set "unpackcmd=lz4 -dcq" & set "compext=lz4"
ren *ramdisk*.gz *ramdisk.cpio.%compext%
cd ..

echo Unpacking ramdisk to "ramdisk/" . . .
echo.
cd ramdisk
echo Compression used: %ramdiskcomp%
if "%compext%" == "" goto error
%bin%\%unpackcmd% "../split_img/%~nx1-ramdisk.cpio.%compext%" %errout% | %bin%\cpio -i %errout%
if errorlevel == 1 goto error
%bin%\chmod -fR +rw ../ramdisk ../split_img > nul 2>&1
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
