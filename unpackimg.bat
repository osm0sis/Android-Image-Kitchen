@echo off
setlocal
set CYGWIN=nodosfilewarning

set "aik=%~dp0"
set "bin=%~dp0\android_win_tools"
set "cur=%cd%"

if "%~1" == "--help" echo usage: unpackimg.bat [--local] ^<file^> & goto end
if "%~1" == "--local" (
  set "local=--local"
  shift
) else (
  %~d0
  cd "%~p0"
)
if "[%~1]" == "[]" (
  for /f "delims=" %%a in ('dir /b /o *.elf *.img *.sin 2^>nul') do (
    if not "%%a" == "aboot.img" if not "%%a" == "image-new.img" if not "%%a" == "unlokied-new.img" if not "%%a" == "unsigned-new.img" (
      set "img=%%a"
      goto imgset
    )
  )
) else (
  set "img=%~1"
)
:imgset
if "[%img%]" == "[]" goto noargs
if exist "%cur%\%img%" set "img=%cur%\%img%"
call :main "%img%" & exit /b
:main
set attr=%~a1
set dirattr=%attr:~0,1%
if /i "%dirattr%"=="d" goto noargs
set "file=%~dsp1%~nx1"
if not exist "%file%" goto noargs

echo Android Image Kitchen - UnpackImg Script
echo by osm0sis @ xda-developers
echo.

echo Supplied image: %~nx1
echo.

if exist split_img\nul set "noclean=1"
if exist ramdisk\nul set "noclean=1"
if defined noclean (
  echo Removing old work folders and files . . .
  echo.
  call "%aik%\cleanup.bat" %local% >nul
)

echo Setting up work folders . . .
echo.
md split_img
if errorlevel == 1 call "%aik%\cleanup.bat" %local% >nul & goto error
md ramdisk
if errorlevel == 1 call "%aik%\cleanup.bat" %local% >nul & goto error
icacls ramdisk /inheritance:d >nul 2>&1
icacls ramdisk /remove:g "NT AUTHORITY\Authenticated Users" >nul 2>&1
icacls ramdisk /remove:g "BUILTIN\Users" >nul 2>&1
icacls ramdisk /grant %userdomain%\%username%:(OI)(CI)(F) >nul 2>&1

cd split_img
for /f "usebackq" %%a in ('%file%') do @set "filesize=%%~za"
echo %filesize%>"%~nx1-origsize"
"%bin%"\file -m "%bin%\androidbootimg.magic" "%file%" 2>nul | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f3 | "%bin%"\cut -d, -f1 > "%~nx1-imgtype"
for /f "delims=" %%a in ('type "%~nx1-imgtype"') do @set "imgtest=%%a"
if "%imgtest%" == "signing" (
  "%bin%"\file -m "%bin%\androidbootimg.magic" "%file%" 2>nul | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-sigtype"
  for /f "delims=" %%a in ('type "%~nx1-sigtype"') do @set "sigtype=%%a" & echo Signature with "%%a" type detected, removing . . .
  echo.
)
if "%sigtype%" == "BLOB" (
  copy /b "%file%" . >nul
  "%bin%"\blobunpack "%~nx1" | findstr "Name:" | "%bin%"\cut -d" " -f2 > "%~nx1-blobtype" 2>nul
  move /y "%~nx1.LNX" "%~nx1" >nul 2>&1
  move /y "%~nx1.SOS" "%~nx1" >nul 2>&1
  set "file=%~nx1"
)
if "%sigtype%" == "CHROMEOS" "%bin%"\futility vbutil_kernel --get-vmlinuz "%file%" --vmlinuz-out "%~nx1" & set "file=%~nx1"
if "%sigtype%" == "DHTB" "%bin%"\dd bs=4096 skip=512 iflag=skip_bytes conv=notrunc if="%file%" of="%~nx1" 2>nul & set "file=%~nx1"
if "%sigtype%" == "NOOK" (
  "%bin%"\dd bs=1048576 count=1 conv=notrunc if="%file%" of="%~nx1-master_boot.key" 2>nul
  "%bin%"\dd bs=1048576 skip=1 conv=notrunc if="%file%" of="%~nx1" 2>nul
  set "file=%~nx1"
)
if "%sigtype%" == "NOOKTAB" (
  "%bin%"\dd bs=262144 count=1 conv=notrunc if="%file%" of="%~nx1-master_boot.key" 2>nul
  "%bin%"\dd bs=262144 skip=1 conv=notrunc if="%file%" of="%~nx1" 2>nul
  set "file=%~nx1"
)
if "%sigtype%" == "SINv1" set "sigtype=SIN"
if "%sigtype%" == "SINv2" set "sigtype=SIN"
if "%sigtype%" == "SINv3" set "sigtype=SIN"
if "%sigtype%" == "SIN" (
  "%bin%"\sony_dump . "%file%" >nul
  move /y "%~nx1."* "%~nx1" >nul 2>&1
  set "file=%~nx1"
  del "%~nx1-sigtype"
)

"%bin%"\file -m "%bin%\androidbootimg.magic" "%file%" 2>nul | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f3 | "%bin%"\cut -d, -f1 > "%~nx1-imgtype"
for /f "delims=" %%a in ('type "%~nx1-imgtype"') do @set "imgtest=%%a"
if "%imgtest%" == "bootimg" (
  set "imgtest="
  "%bin%"\file -m "%bin%\androidbootimg.magic" "%file%" 2>nul | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f4 > "%~nx1-imgtype"
  for /f "delims=" %%a in ('type "%~nx1-imgtype"') do (
    if "%%a" == "PXA" set "imgtest=-%%a"
  )
  "%bin%"\file -m "%bin%\androidbootimg.magic" "%file%" 2>nul | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-imgtype"
  for /f "delims=" %%a in ('type "%~nx1-imgtype"') do @set "imgtype=%%a"
) else (
  cd ..
  call "%aik%\cleanup.bat" %local% >nul
  echo Unrecognized format.
  goto error
)
set "imgtype=%imgtype%%imgtest%"
echo %imgtype%>"%~nx1-imgtype"
echo Image type: %imgtype%
echo.

if "%imgtype%" == "AOSP_VNDR" set "supported=1"
if "%imgtype%" == "AOSP" set "supported=1"
if "%imgtype%" == "AOSP-PXA" set "supported=1"
if "%imgtype%" == "ELF" set "supported=1"
if "%imgtype%" == "KRNL" set "supported=1"
if "%imgtype%" == "OSIP" set "supported=1"
if "%imgtype%" == "U-Boot" set "supported=1"
if not defined supported (
  cd ..
  call "%aik%\cleanup.bat" %local% >nul
  echo Unsupported format.
  goto error
)

"%bin%"\file -m "%bin%\androidbootimg.magic" "%file%" 2>nul | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f4 > "%~nx1-aosphacktype"
for /f "delims=" %%a in ('type "%~nx1-aosphacktype"') do @set "aosphacktest=%%a"
if "%aosphacktest%" == "LOKI" (
  move /y "%~nx1-aosphacktype" "%~nx1-lokitype" >nul
  "%bin%"\file -m "%bin%\androidbootimg.magic" "%file%" 2>nul | "%bin%"\cut -d: -f2- | "%bin%"\cut -d: -f2 | "%bin%"\cut -d( -f2 | "%bin%"\cut -d^) -f1 > "%~nx1-lokitype"
  for /f "delims=" %%a in ('type "%~nx1-lokitype"') do @echo Loki patch with "%%a" type detected, reverting . . .
  echo.
  echo Warning: A dump of your device's aboot.img is required to re-Loki!
  "%bin%"\loki_tool unlok "%file%" "%~nx1" >nul
  echo.
  set "file=%~nx1"
) else if "%aosphacktest%" == "AMONET" (
  echo Amonet patch detected, reverting . . .
  echo.
  "%bin%"\dd bs=2048 count=1 conv=notrunc if="%file%" of="%~nx1-microloader.bin" 2>nul
  "%bin%"\dd bs=1024 skip=1 conv=notrunc if="%~nx1-microloader.bin" of="%~nx1-head" 2>nul
  "%bin%"\truncate -s 1024 "%~nx1-microloader.bin"
  "%bin%"\truncate -s 2048 "%~nx1-head"
  "%bin%"\dd bs=2048 skip=1 conv=notrunc if="%file%" of="%~nx1-tail" 2>nul
  copy /b "%~nx1-head"+"%~nx1-tail" "%~nx1" >nul
  set "file=%~nx1"
  del "%~nx1-aosphacktype" "%~nx1-head" "%~nx1-tail"
) else (
  del "%~nx1-aosphacktype"
)

for %%i in ("%file%") do @set /a "tailoffset=%%~z%i - 8192"
"%bin%"\dd if="%file%" iflag=skip_bytes skip=%tailoffset% bs=8192 count=1 2>nul | "%bin%"\file -m "%bin%\androidbootimg.magic" - 2>nul | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-tailtype"
for /f "delims=" %%a in ('type "%~nx1-tailtype"') do @set "tailtype=%%a"
if "%tailtype%" == "data" (
  "%bin%"\tail -n50 "%file%" 2>nul | "%bin%"\file -m "%bin%\androidbootimg.magic" - 2>nul | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-tailtype"
  for /f "delims=" %%a in ('type "%~nx1-tailtype"') do @set "tailtype=%%a"
)
if not "%tailtype%" == "AVBv1" if not "%tailtype%" == "Bump" if not "%tailtype%" == "SEAndroid" del "%~nx1-tailtype"
if not "%tailtype%" == "AVBv1" if not "%tailtype%" == "AVBv2" goto skipavb
if "%tailtype%" == "AVBv1" (
  "%bin%"\tail -n50 "%file%" 2>nul | "%bin%"\file -m "%bin%\androidbootimg.magic" - 2>nul | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f5 > "%~nx1-avbtype"
  move /y "%~nx1-tailtype" "%~nx1-sigtype" >nul
)
echo Signature with "%tailtype%" type detected. & echo.
:skipavb
if exist "*-tailtype" echo Footer with "%tailtype%" type detected. & echo.

if not "%imgtype%" == "U-Boot" goto skiptrim
"%bin%"\hexdump -n 4 -s 12 -e '16/1 "%%02x""\n"' "%file%" > "%~nx1-sizetest"
for /f "delims=" %%a in ('type "%~nx1-sizetest"') do @"%bin%"\printf '%%d\n' 0x%%a > "%~nx1-sizetest"
for /f "delims=" %%a in ('type "%~nx1-sizetest"') do @set /a "imgsize = %%a + 64"
if not "%imgsize%" == "%filesize%" (
  echo Trimming . . .
  echo.
  for /f "delims=" %%a in ('call echo %%imgsize%%') do @"%bin%"\dd bs=%%a count=1 conv=notrunc if="%file%" of="%~nx1" 2>nul
  set "file=%~nx1"
)
del "%~nx1-sizetest"

:skiptrim
echo Splitting image to "split_img/" . . .
echo.
if "%imgtype%" == "AOSP_VNDR" "%bin%"\unpackbootimg -i "%file%" & set "vendor=vendor_"
if "%imgtype%" == "AOSP" "%bin%"\unpackbootimg -i "%file%"
if "%imgtype%" == "AOSP-PXA" "%bin%"\pxa-unpackbootimg -i "%file%"
if "%imgtype%" == "ELF" (
  md elftool_out
  "%bin%"\elftool unpack -i "%file%" -o elftool_out >nul
  move /y elftool_out\header "%~nx1-header" >nul 2>&1
  rd /s /q elftool_out >nul 2>&1
  "%bin%"\unpackelf -i "%file%"
)
if "%imgtype%" == "KRNL" "%bin%"\dd bs=4096 skip=8 iflag=skip_bytes conv=notrunc if="%file%" of="%~nx1-ramdisk" 2>&1 | "%bin%"\tail -n+3 | "%bin%"\cut -d" " -f1-2
if "%imgtype%" == "OSIP" (
  "%bin%"\mboot -u -f "%file%"
  if errorlevel == 1 set "error=1"
  move /y hdr "%~nx1-header" >nul 2>&1
  move /y sig "%~nx1-sig" >nul 2>&1
  move /y cmdline.txt "%~nx1-cmdline" >nul 2>&1
  move /y parameter "%~nx1-parameter" >nul 2>&1
  move /y bootstub "%~nx1-bootstub" >nul 2>&1
  move /y kernel "%~nx1-kernel" >nul 2>&1
  move /y ramdisk.cpio.gz "%~nx1-ramdisk" >nul 2>&1
)
if "%imgtype%" == "U-Boot" (
  "%bin%"\dumpimage -l "%file%"
  "%bin%"\dumpimage -l "%file%" > "%~nx1-header"
  type "%~nx1-header" | findstr "Name:" | "%bin%"\cut -c15- > "%~nx1-name"
  type "%~nx1-header" | findstr "Type:" | "%bin%"\cut -c15- | "%bin%"\cut -d" " -f1 > "%~nx1-arch"
  type "%~nx1-header" | findstr "Type:" | "%bin%"\cut -c15- | "%bin%"\cut -d" " -f2 > "%~nx1-os"
  type "%~nx1-header" | findstr "Type:" | "%bin%"\cut -c15- | "%bin%"\cut -d" " -f3 | "%bin%"\cut -d- -f1 > "%~nx1-type"
  type "%~nx1-header" | findstr "Type:" | "%bin%"\cut -d^( -f2 | "%bin%"\cut -d^) -f1 | "%bin%"\cut -d" " -f1 | "%bin%"\cut -d- -f1 > "%~nx1-comp"
  type "%~nx1-header" | findstr "Address:" | "%bin%"\cut -c15- > "%~nx1-addr"
  type "%~nx1-header" | findstr "Point:" | "%bin%"\cut -c15- > "%~nx1-ep"
  del "%~nx1-header"
  "%bin%"\dumpimage -p 0 -o "%~nx1-kernel" "%file%"
  if errorlevel == 1 set "error=1"
  for /f "delims=" %%a in ('type "%~nx1-type"') do (
    if "%%a" == "Multi" (
      "%bin%"\dumpimage -p 1 -o "%~nx1-ramdisk" "%file%"
    ) else if "%%a" == "RAMDisk" (
      move /y "%~nx1-kernel" "%~nx1-ramdisk" >nul 2>&1
    ) else (
      copy /y nul "%~nx1-ramdisk" >nul
    )
  )
)
if errorlevel == 1 set "error=1"
if "%error%" == "1" (
  cd ..
  call "%aik%\cleanup.bat" %local% >nul
  goto error
)
echo.

if exist "*-kernel" (
  "%bin%"\file -m "%bin%\androidbootimg.magic" *-kernel 2>nul | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-mtktest"
  for /f "delims=" %%a in ('type "%~nx1-mtktest"') do @set "mtktest=%%a"
)
if "%mtktest%" == "MTK" (
  set "mtk=1"
  echo MTK header found in kernel, removing . . .
  "%bin%"\dd bs=512 skip=1 conv=notrunc if="%~nx1-kernel" of="tempkern" 2>nul
  move /y tempkern "%~nx1-kernel" >nul
)
for /f "delims=" %%a in ('dir /b *-*ramdisk') do @set "ramdiskname=%%a"
"%bin%"\file -m "%bin%\androidbootimg.magic" "%ramdiskname%" 2>nul | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-mtktest"
for /f "delims=" %%a in ('type "%~nx1-mtktest"') do @set "mtktest=%%a"
"%bin%"\file -m "%bin%\androidbootimg.magic" "%ramdiskname%" 2>nul | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f4 > "%~nx1-mtktype"
for /f "delims=" %%a in ('type "%~nx1-mtktype"') do @set "mtktype=%%a"
if "%mtktest%" == "MTK" (
  if not defined mtk echo Warning: No MTK header found in kernel! & set "mtk=1"
  echo MTK header found in "%mtktype%" type ramdisk, removing . . .
  "%bin%"\dd bs=512 skip=1 conv=notrunc if="%ramdiskname%" of="temprd" 2>nul
  move /y temprd "%ramdiskname%" >nul
) else (
  if defined mtk (
    if "[%mtktype%]" == "[]" (
      echo Warning: No MTK header found in ramdisk, assuming "rootfs" type!
      echo rootfs>"%~nx1-mtktype"
    )
  ) else (
    del "%~nx1-mtktype"
  )
)
del "%~nx1-mtktest"
if defined mtk echo.

if exist "*-dt" (
  "%bin%"\file -m "%bin%\androidbootimg.magic" *-dt 2>nul | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-dttype"
  for /f "delims=" %%a in ('type "%~nx1-dttype"') do (
    if "%imgtype%" == "ELF" if not "%%a" == "QCDT" if not "%%a" == "ELF" (
      echo Non-QC DTB found, packing kernel and appending . . .
      echo.
      "%bin%"\gzip --no-name -9 "%~nx1-kernel"
      copy /b "%~nx1-kernel.gz"+"%~nx1-dt" "%~nx1-kernel" >nul
      del "%~nx1-dt"* "%~nx1-kernel.gz"
    )
  )
)

"%bin%"\file -m "%bin%\magic" *-*ramdisk 2>nul | "%bin%"\cut -d: -f2 | "%bin%"\cut -d" " -f2 > "%~nx1-%vendor%ramdiskcomp"
for /f "delims=" %%a in ('type "%~nx1-%vendor%ramdiskcomp"') do @set "ramdiskcomp=%%a"
set "unpackcmd=%ramdiskcomp% -dc"
set "compext=%ramdiskcomp%"
if "%ramdiskcomp%" == "gzip" set "unpackcmd=gzip -dcq" & set "compext=gz"
if "%ramdiskcomp%" == "lzop" set "compext=lzo"
if "%ramdiskcomp%" == "lzma" set "unpackcmd=xz -dc"
if "%ramdiskcomp%" == "bzip2" set "compext=bz2"
if "%ramdiskcomp%" == "lz4" set "unpackcmd=lz4 -dcq"
if "%ramdiskcomp%" == "lz4-l" set "unpackcmd=lz4 -dcq" & set "compext=lz4"
if "%ramdiskcomp%" == "cpio" set "unpackcmd=cat" & set "compext="
if "%ramdiskcomp%" == "empty" set "compext=empty"
if defined compext set "compext=.%compext%"
ren *-*ramdisk *-*ramdisk.cpio%compext%
cd ..
if "%ramdiskcomp%" == "data" echo Unrecognized format. & goto error

if "%ramdiskcomp%" == "empty" if not "%ramdiskcomp%" == "cpio" echo Warning: No ramdisk found to be unpacked! & goto nord
echo Unpacking ramdisk to "ramdisk/" . . .
echo.
cd ramdisk
if errorlevel == 1 goto error
echo Compression used: %ramdiskcomp%
if not defined compext if not "%ramdiskcomp%" == "cpio" echo. & echo Unsupported format. & goto error
"%bin%"\%unpackcmd% "..\split_img\%~nx1-%vendor%ramdisk.cpio%compext%" | "%bin%"\cpio -i -d --no-absolute-filenames
if errorlevel == 1 goto error
cd ..
:nord
"%bin%"\chmod -f 755 ramdisk >nul 2>&1
echo.

echo Done!
goto end

:noargs
echo No image file supplied.

:error
echo Error!
set "exitcode=1"

:end
echo.
echo %cmdcmdline% | findstr /i pushd >nul
if errorlevel 1 pause
exit /b %exitcode%
