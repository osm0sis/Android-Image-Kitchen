@echo off
setlocal
set CYGWIN=nodosfilewarning

set "bin=%~dp0\android_win_tools"
set "cur=%cd%"

if "%~1" == "--help" echo usage: repackimg.bat [--local] [--original] [--origsize] [--level ^<0-9^>] [--avbkey ^<name^>] [--forceelf] & goto end
if "%~1" == "--local" (
  shift
) else (
  %~d0
  cd "%~p0"
)
dir /a-d split_img >nul 2>&1 || goto nofiles
for /f "delims=" %%a in ('dir /b split_img\*-*ramdiskcomp') do @set "ramdiskcname=%%a"
for /f "delims=" %%a in ('type "split_img\%ramdiskcname%"') do @set "ramdiskcomp=%%a"
dir /a ramdisk >nul 2>&1 || if not "%ramdiskcomp%" == "empty" goto nofiles

echo Android Image Kitchen - RepackImg Script
echo by osm0sis @ xda-developers
echo.

if exist *-new.* (
  echo Warning: Overwriting existing files!
  echo.
)
del *-new.* 2>nul

:parseargs
if not "[%~1]" == "[]" (
  if "%~1" == "--original" (
    set "original=1"
    echo Repacking with original ramdisk . . .
  )
  if "%~1" == "--origsize" (
    set "origsize=1"
  )
  if "%~1" == "--forceelf" (
    set "repackelf=1"
  )
  if "%~1" == "--level" (
    if not "[%~2]" == "[]" (
      set "lvltest=" & for /f "delims=0123456789" %%a in ("%~2") do @set "lvltest=%%a"
      if not defined lvltest (
        set "level=-%~2"
        set "lvltxt= - Level: %~2"
        shift
      )
    )
  )
  if "%~1" == "--avbkey" (
    if not "[%~2]" == "[]" (
      if exist "%~2.pk8" if exist "%~2.x509."* set "avbkey=%~2" & set "avbtxt= - Key: %~2"
      if exist "%cur%\%~2.pk8" if exist "%cur%\%~2.x509."* set "avbkey=%cur%\%~2" & set "avbtxt= - Key: %~2"
      shift
    )
  )
  shift
  goto parseargs
)

if defined original goto skipramdisk
if "%ramdiskcomp%" == "empty" (
  echo Warning: Using empty ramdisk for repack!
  set "compext=.empty"
  copy /y nul ramdisk-new.cpio.empty >nul
  goto skipramdisk
)
"%bin%"\find ramdisk >nul 2>&1
if errorlevel == 1 (
  set "sumsg= (as root)"
) else (
  "%bin%"\find ramdisk 2>&1 | "%bin%"\cpio --quiet -o >nul 2>&1
  if errorlevel == 1 set "sumsg= (as root)"
)
echo Packing ramdisk%sumsg% . . .
echo.
if not "[%sumsg%]" == "[]" (
  if not exist "%bin%"\sudo.exe (
    echo Windows sudo required but not found.
    set "nosudo=1"
  ) else (
    "%bin%"\sudo.exe --help >nul 2>&1
    if not errorlevel == 2 (
      echo Windows sudo required but unable to run.
      set "nosudo=1"
    )
  )
  if defined nosudo (
    echo.
    echo *** Reinstall Android Image Kitchen, then add ***
    echo *** sudo.exe to your antivirus exceptions!    ***
    echo.
    goto error
  )
)

echo Using compression: %ramdiskcomp%%lvltxt%
if not defined level if "%ramdiskcomp%" == "xz" set "level=-1"
if not defined level if "%ramdiskcomp%" == "lz4" set "level=-9"
if not defined level if "%ramdiskcomp%" == "lz4-l" set "level=-9"
set "repackcmd=%ramdiskcomp% %level%"
set "compext=%ramdiskcomp%"
if "%ramdiskcomp%" == "gzip" set "compext=gz"
if "%ramdiskcomp%" == "lzop" set "compext=lzo"
if "%ramdiskcomp%" == "lzma" set "repackcmd=xz -Flzma %level%"
if "%ramdiskcomp%" == "xz" set "repackcmd=xz %level% -Ccrc32"
if "%ramdiskcomp%" == "bzip2" set "compext=bz2"
if "%ramdiskcomp%" == "lz4-l" set "repackcmd=lz4 %level% -l" & set "compext=lz4"
if "%ramdiskcomp%" == "cpio" set "repackcmd=cat" & set "compext="
if defined compext set "compext=.%compext%"
cd ramdisk
if "[%sumsg%]" == "[]" (
  "%bin%"\find . | "%bin%"\cpio -H newc -R 0:0 -o -F ..\ramdisk-new.cpio 2>nul
) else (
  "%bin%"\sudo "%bin%"\find2cpio.bat >nul
)
if errorlevel == 1 goto error
cd ..
if not "%ramdiskcomp%" == "cpio" (
  type ramdisk-new.cpio | "%bin%"\%repackcmd% > ramdisk-new.cpio%compext%
  del ramdisk-new.cpio
)
if errorlevel == 1 goto error
:skipramdisk
echo.

echo Getting build information . . .
echo.

for /f "delims=" %%a in ('dir /b split_img\*-imgtype') do @set "imgtypename=%%a"
for /f "delims=" %%a in ('type "split_img\%imgtypename%"') do @set "imgtype=%%a"

if "%imgtype%" == "AOSP_VNDR" (
  set "vendor=vendor_"
  goto skipkern
)
if "%imgtype%" == "KRNL" goto skipkern
if not exist "split_img\*-kernel" goto skipkern
for /f "delims=" %%a in ('dir /b split_img\*-kernel') do @set "kernelname=%%a"
echo kernel = %kernelname% & set "kernel=split_img/%kernelname%"
:skipkern
for /f "delims=" %%a in ('dir /b split_img\*-*ramdisk.cpio*') do @set "ramdiskname=%%a"
if not defined original (
  set "ramdiskname=ramdisk-new.cpio%compext%"
  set "ramdisk=ramdisk-new.cpio%compext%"
  goto skiporig
)
echo %vendor%ramdisk = %ramdiskname%
set "ramdisk=split_img/"%ramdiskname%""
:skiporig
if "%imgtype%" == "KRNL" (
  for %%i in (%ramdisk%) do @echo ramdisk_size = %%~z%i
)

if not "%imgtype%" == "OSIP" goto skipos
for /f "delims=" %%a in ('dir /b split_img\*-*cmdline') do @set "cmdname=%%a"
for /f "delims=" %%a in ('type "split_img\%cmdname%"') do @set "cmdline=%%a"
echo cmdline = %cmdline%
goto skipaosp

:skipos
if not "%imgtype%" == "U-Boot" goto skipuboot
for /f "delims=" %%a in ('dir /b split_img\*-name') do @set "namename=%%a"
for /f "delims=" %%a in ('type "split_img\%namename%"') do @set "name=%%a"
echo name = %name%
for /f "delims=" %%a in ('dir /b split_img\*-arch') do @set "archname=%%a"
for /f "delims=" %%a in ('type "split_img\%archname%"') do @set "arch=%%a"
for /f "delims=" %%a in ('dir /b split_img\*-os') do @set "osname=%%a"
for /f "delims=" %%a in ('type "split_img\%osname%"') do @set "os=%%a"
for /f "delims=" %%a in ('dir /b split_img\*-type') do @set "typename=%%a"
for /f "delims=" %%a in ('type "split_img\%typename%"') do @set "type=%%a"
for /f "delims=" %%a in ('dir /b split_img\*-comp') do @set "compname=%%a"
for /f "delims=" %%a in ('type "split_img\%compname%"') do @set "comp=%%a"
echo type = %arch% %os% %type% (%comp%)
if "%comp%" == "uncompressed" set "comp=none"
for /f "delims=" %%a in ('dir /b split_img\*-addr') do @set "addrname=%%a"
for /f "delims=" %%a in ('type "split_img\%addrname%"') do @set "addr=%%a"
echo load_addr = %addr%
for /f "delims=" %%a in ('dir /b split_img\*-ep') do @set "epname=%%a"
for /f "delims=" %%a in ('type "split_img\%epname%"') do @set "ep=%%a"
echo entry_point = %ep%
goto skipaosp

:skipuboot
if "%imgtype%" == "KRNL" goto skipaosp
if not exist "split_img\*-second" goto skipsecond
for /f "delims=" %%a in ('dir /b split_img\*-second') do @set "second=%%a"
echo second = %second% & set "second=--second "split_img/%second%""
:skipsecond
if not exist "split_img\*-dtb" goto skipdtb
for /f "delims=" %%a in ('dir /b split_img\*-dtb') do @set "dtb=%%a"
echo dtb = %dtb% & set "dtb=--dtb "split_img/%dtb%""
:skipdtb
if not exist "split_img\*-recovery_dtbo" goto skiprecdtbo
for /f "delims=" %%a in ('dir /b split_img\*-recovery_dtbo') do @set "recoverydtbo=%%a"
echo recovery_dtbo = %recoverydtbo% & set "recoverydtbo=--recovery_dtbo "split_img/%recoverydtbo%""
:skiprecdtbo
if not exist "split_img\*-*cmdline" goto skipcmd
for /f "delims=" %%a in ('dir /b split_img\*-*cmdline') do @set "cmdname=%%a"
for /f "delims=" %%a in ('type "split_img\%cmdname%"') do @set "cmdline=%%a"
set "cmd="split_img/%cmdname%"@cmdline"
echo %vendor%cmdline = %cmdline%
if defined cmdline set "cmdline=%cmdline:"=\"%"
:skipcmd
if not exist "split_img\*-board" goto skipboard
for /f "delims=" %%a in ('dir /b split_img\*-board') do @set "boardname=%%a"
for /f "delims=" %%a in ('type "split_img\%boardname%"') do @set "board=%%a"
echo board = %board%
if defined board set board=%board:"=\"%
:skipboard
if not exist "split_img\*-base" goto skipbase
for /f "delims=" %%a in ('dir /b split_img\*-base') do @set "basename=%%a"
for /f "delims=" %%a in ('type "split_img\%basename%"') do @set "base=%%a"
echo base = %base%
:skipbase
if not exist "split_img\*-pagesize" goto skippage
for /f "delims=" %%a in ('dir /b split_img\*-pagesize') do @set "pagename=%%a"
for /f "delims=" %%a in ('type "split_img\%pagename%"') do @set "pagesize=%%a"
echo pagesize = %pagesize%
:skippage
if not exist "split_img\*-kernel_offset" goto skipkoff
for /f "delims=" %%a in ('dir /b split_img\*-kernel_offset') do @set "koffname=%%a"
for /f "delims=" %%a in ('type "split_img\%koffname%"') do @set "kerneloff=%%a"
echo kernel_offset = %kerneloff%
:skipkoff
if not exist "split_img\*-ramdisk_offset" goto skiproff
for /f "delims=" %%a in ('dir /b split_img\*-ramdisk_offset') do @set "roffname=%%a"
for /f "delims=" %%a in ('type "split_img\%roffname%"') do @set "ramdiskoff=%%a"
echo ramdisk_offset = %ramdiskoff%
:skiproff
if not exist "split_img\*-second_offset" goto skipsoff
for /f "delims=" %%a in ('dir /b split_img\*-second_offset') do @set "soffname=%%a"
for /f "delims=" %%a in ('type "split_img\%soffname%"') do @set "secondoff=%%a"
echo second_offset = %secondoff%
:skipsoff
if not exist "split_img\*-tags_offset" goto skiptoff
for /f "delims=" %%a in ('dir /b split_img\*-tags_offset') do @set "toffname=%%a"
for /f "delims=" %%a in ('type "split_img\%toffname%"') do @set "tagsoff=%%a"
echo tags_offset = %tagsoff%
:skiptoff
if not exist "split_img\*-dtb_offset" goto skipdoff
for /f "delims=" %%a in ('dir /b split_img\*-dtb_offset') do @set "doffname=%%a"
for /f "delims=" %%a in ('type "split_img\%doffname%"') do @set "dtboff=%%a"
echo dtb_offset = %dtboff%
:skipdoff
if not exist "split_img\*-os_version" goto skiposver
for /f "delims=" %%a in ('dir /b split_img\*-os_version') do @set "osvname=%%a"
for /f "delims=" %%a in ('type "split_img\%osvname%"') do @set "osver=%%a"
echo os_version = %osver%
:skiposver
if not exist "split_img\*-os_patch_level" goto skiposlvl
for /f "delims=" %%a in ('dir /b split_img\*-os_patch_level') do @set "oslname=%%a"
for /f "delims=" %%a in ('type "split_img\%oslname%"') do @set "oslvl=%%a"
echo os_patch_level = %oslvl%
:skiposlvl
if not exist "split_img\*-header_version" goto skiphdrver
for /f "delims=" %%a in ('dir /b split_img\*-header_version') do @set "hdrvname=%%a"
for /f "delims=" %%a in ('type "split_img\%hdrvname%"') do @set "hdrver=%%a"
echo header_version = %hdrver%
:skiphdrver
if not exist "split_img\*-hashtype" goto skiphash
for /f "delims=" %%a in ('dir /b split_img\*-hashtype') do @set "hashname=%%a"
for /f "delims=" %%a in ('type "split_img\%hashname%"') do @set "hashtype=%%a"
echo hashtype = %hashtype% & set "hashtype=--hashtype %hashtype%"
:skiphash
if not exist "split_img\*-dt" goto skipdt
for /f "delims=" %%a in ('dir /b split_img\*-dttype') do @set "dtname=%%a"
for /f "delims=" %%a in ('type "split_img\%dtname%"') do @set "dttype=%%a"
for /f "delims=" %%a in ('dir /b split_img\*-dt') do @set "dt=%%a"
echo dt = %dt% & set "rpm="split_img/%dt%",rpm" & set "dt=--dt "split_img/%dt%""
:skipdt
if not exist "split_img\*-unknown" goto skipunknown
for /f "delims=" %%a in ('dir /b split_img\*-unknown') do @set "unkname=%%a"
for /f "delims=" %%a in ('type "split_img\%unkname%"') do @set "unknown=%%a"
echo unknown = %unknown%
:skipunknown
if exist "split_img\*-header" (
  for /f "delims=" %%a in ('dir /b split_img\*-header') do @set "header=%%a"
)
:skipaosp
echo.

if not exist "split_img\*-mtktype" goto skipmtk
for /f "delims=" %%a in ('dir /b split_img\*-mtktype') do @set "mtktypename=%%a"
for /f "delims=" %%a in ('type "split_img\%mtktypename%"') do @set "mtktype=%%a"
echo Generating MTK headers . . .
echo.
echo Using ramdisk type: %mtktype%
"%bin%"\mkmtkhdr --kernel "%kernel%" --%mtktype% "%ramdisk%" >nul
if errorlevel == 1 goto error
move /y "%kernelname%-mtk" kernel-new.mtk >nul
move /y "%ramdiskname%-mtk" %mtktype%-new.mtk >nul
set "kernel=kernel-new.mtk"
set "ramdisk=%mtktype%-new.mtk"
echo.

:skipmtk
if exist "split_img\*-sigtype" (
  set "outname=unsigned-new.img"
) else (
  set "outname=image-new.img"
)
if "%dttype%" == "ELF" set "repackelf=1"
if "%imgtype%" == "ELF" if not "[%header%]" == "[]" if defined repackelf (
  set "buildcmd=elftool pack -o %outname% header="split_img/%header%" "%kernel%" "%ramdisk%",ramdisk %rpm% %cmd% >nul"
)
if "%imgtype%" == "ELF" if not defined buildcmd set "imgtype=AOSP" & echo Warning: ELF format without RPM detected; will be repacked using AOSP format! & echo.
if "%imgtype%" == "AOSP_VNDR" set "buildcmd=mkbootimg --vendor_ramdisk "%ramdisk%" %dtb% --vendor_cmdline "%cmdline%" --board "%board%" --base %base% --pagesize %pagesize% --kernel_offset %kerneloff% --ramdisk_offset %ramdiskoff% --tags_offset "%tagsoff%" --dtb_offset "%dtboff%" --os_version "%osver%" --os_patch_level "%oslvl%" --header_version "%hdrver%" --vendor_boot %outname%"
if "%imgtype%" == "AOSP" set "buildcmd=mkbootimg --kernel "%kernel%" --ramdisk "%ramdisk%" %second% %dtb% %recoverydtbo% --cmdline "%cmdline%" --board "%board%" --base %base% --pagesize %pagesize% --kernel_offset %kerneloff% --ramdisk_offset %ramdiskoff% --second_offset "%secondoff%" --tags_offset "%tagsoff%" --dtb_offset "%dtboff%" --os_version "%osver%" --os_patch_level "%oslvl%" --header_version "%hdrver%" %hashtype% %dt% -o %outname%"
if "%imgtype%" == "AOSP-PXA" set "buildcmd=pxa-mkbootimg --kernel "%kernel%" --ramdisk "%ramdisk%" %second% --cmdline "%cmdline%" --board "%board%" --base %base% --pagesize %pagesize% --kernel_offset %kerneloff% --ramdisk_offset %ramdiskoff% --second_offset "%secondoff%" --tags_offset "%tagsoff%" --unknown "%unknown%" %dt% -o %outname%"
if "%imgtype%" == "KRNL" set "buildcmd=rkcrc -k "%ramdisk%" %outname%"
if "%imgtype%" == "OSIP" (
  md split_img\temp 2>nul
  copy /b split_img\*-header split_img\temp\hdr >nul 2>&1
  copy /b split_img\*-sig split_img\temp\sig >nul 2>&1
  copy /b split_img\*-*cmdline split_img\temp\cmdline.txt >nul
  copy /b split_img\*-parameter split_img\temp\parameter >nul
  copy /b split_img\*-bootstub split_img\temp\bootstub >nul
  copy /b split_img\*-kernel split_img\temp\kernel >nul
  "%bin%"\cat "%ramdisk%" > split_img\temp\ramdisk.cpio.gz
)
if "%imgtype%" == "OSIP" set "buildcmd=mboot -d split_img\temp -f %outname%"
if "%imgtype%" == "U-Boot" (
  set "part0=%kernel%"
  if "%type%" == "Multi" set "part1=:%ramdisk%"
  if "%type%" == "RAMDisk" set "part0=%ramdisk%"
)
if "%imgtype%" == "U-Boot" set "buildcmd=mkimage -A %arch% -O %os% -T %type% -C %comp% -a %addr% -e %ep% -n "%name%" -d "%part0%"%part1% %outname% >nul"

echo Building image . . .
echo.
echo Using format: %imgtype%
echo.
if not defined buildcmd echo Unsupported format. & goto error
"%bin%"\%buildcmd%
if errorlevel == 1 goto error

rd /s /q split_img\temp >nul 2>&1

if not exist "split_img\*-sigtype" goto skipsign
for /f "delims=" %%a in ('dir /b split_img\*-sigtype') do @set "sigtypename=%%a"
for /f "delims=" %%a in ('type "split_img\%sigtypename%"') do @set "sigtype=%%a"
if not exist "split_img\*-avbtype" goto skipavb
for /f "delims=" %%a in ('dir /b split_img\*-avbtype') do @set "avbtypename=%%a"
for /f "delims=" %%a in ('type "split_img\%avbtypename%"') do @set "avbtype=%%a"
:skipavb
if not exist "split_img\*-blobtype" goto skipblob
for /f "delims=" %%a in ('dir /b split_img\*-blobtype') do @set "blobtypename=%%a"
for /f "delims=" %%a in ('type "split_img\%blobtypename%"') do @set "blobtype=%%a"
:skipblob
echo Signing new image . . .
echo.
echo Using signature: %sigtype% %avbtype%%avbtxt%%blobtype%
echo.
if not defined avbkey set "avbkey=%bin%\avb\verity"
if "%sigtype%" == "AVBv1" java -jar "%bin%"\boot_signer.jar /%avbtype% unsigned-new.img "%avbkey%.pk8" "%avbkey%.x509."* image-new.img 2>nul
if "%sigtype%" == "BLOB" (
  "%bin%"\printf '-SIGNED-BY-SIGNBLOB-\00\00\00\00\00\00\00\00' > image-new.img
  "%bin%"\blobpack blob.tmp %blobtype% unsigned-new.img >nul
  type blob.tmp >> image-new.img
  del /q blob.tmp >nul
)
if "%sigtype%" == "CHROMEOS" "%bin%"\futility vbutil_kernel --pack image-new.img --keyblock "%bin%\chromeos\kernel.keyblock" --signprivate "%bin%\chromeos\kernel_data_key.vbprivk" --version 1 --vmlinuz unsigned-new.img --bootloader "%bin%\chromeos\empty" --config "%bin%\chromeos\empty" --arch arm --flags 0x1
if "%sigtype%" == "DHTB" "%bin%"\dhtbsign -i unsigned-new.img -o image-new.img >nul & del split_img\*-tailtype 2>nul
if "%sigtype%" == "NOOK" type "split_img\*-master_boot.key" unsigned-new.img > image-new.img 2>nul
if "%sigtype%" == "NOOKTAB" type "split_img\*-master_boot.key" unsigned-new.img > image-new.img 2>nul
if errorlevel == 1 goto error

:skipsign
if not exist "split_img\*-lokitype" goto skiploki
for /f "delims=" %%a in ('dir /b split_img\*-lokitype') do @set "lokitypename=%%a"
for /f "delims=" %%a in ('type "split_img\%lokitypename%"') do @set "lokitype=%%a"
echo Loki patching new image . . .
echo.
echo Using type: %lokitype%
echo.
move /y image-new.img unlokied-new.img >nul
if exist aboot.img (
  "%bin%"\loki_tool patch %lokitype% aboot.img unlokied-new.img image-new.img >nul
  if errorlevel == 1 echo Patching failed. & goto error
) else (
  echo Device aboot.img required in script directory to find Loki patch offset.
  goto error
)

:skiploki
if not exist "split_img\*-microloader.bin" goto skipamonet
echo Amonet patching new image . . .
echo.
copy /b image-new.img unamonet-new.img >nul
copy /b split_img\*-microloader.bin microloader.tmp >nul
"%bin%"\dd bs=1024 count=1 conv=notrunc if=unamonet-new.img of=head.tmp 2>nul
"%bin%"\dd bs=1024 seek=1 conv=notrunc if=head.tmp of=image-new.img 2>nul
"%bin%"\dd conv=notrunc if=microloader.tmp of=image-new.img 2>nul
del /q head.tmp microloader.tmp >nul

:skipamonet
if not exist "split_img\*-tailtype" goto skiptail
for /f "delims=" %%a in ('dir /b split_img\*-tailtype') do @set "tailtypename=%%a"
for /f "delims=" %%a in ('type "split_img\%tailtypename%"') do @set "tailtype=%%a"
echo Appending footer . . .
echo.
echo Using type: %tailtype%
echo.
if "%tailtype%" == "Bump" "%bin%"\printf '\x41\xA9\xE4\x67\x74\x4D\x1D\x1B\xA4\x29\xF2\xEC\xEA\x65\x52\x79' >> image-new.img
if "%tailtype%" == "SEAndroid" "%bin%"\printf 'SEANDROIDENFORCE' >> image-new.img

:skiptail
if not defined origsize goto skippad
if not exist "split_img\*-origsize" goto skippad
for /f "delims=" %%a in ('dir /b split_img\*-origsize') do @set "origsizename=%%a"
for /f "delims=" %%a in ('type "split_img\%origsizename%"') do @set "filesize=%%a"
echo Padding to original size . . .
echo.
copy /b image-new.img unpadded-new.img >nul
"%bin%"\truncate -s %filesize% image-new.img

:skippad
echo Done!
goto end

:nofiles
echo No files found to be packed/built.

:error
echo Error!
set "exitcode=1"

:end
echo.
echo %cmdcmdline% | findstr /i pushd >nul
if errorlevel 1 pause
exit /b %exitcode%
