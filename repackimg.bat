@echo off
setlocal
set CYGWIN=nodosfilewarning
set hideErrors=n

cd "%~p0"
if "%~1" == "--help" echo usage: repackimg.bat [--original] [--level ^<0-9^>] & goto end
dir /a-d split_img >nul 2>nul || goto nofiles
dir /a-d ramdisk >nul 2>nul || goto nofiles
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
del *-new.* 2>nul
if "%1" == "--original" echo Repacking with original ramdisk . . . & goto skipramdisk
echo Packing ramdisk . . .
echo.
for /f "delims=" %%a in ('dir /b split_img\*-ramdiskcomp') do @set ramdiskcname=%%a
for /f "delims=" %%a in ('type "split_img\%ramdiskcname%"') do @set ramdiskcomp=%%a

if "%1" == "--level" if not [%2] == [] (
  if "%ramdiskcomp%" == "lz4" ( set "level=-c%2" ) else ( set "level=-%2" )
  set "lvltxt= - Level: %2"
) else (
  set lvltxt=
  set level=
  if "%ramdiskcomp%" == "xz" set "level=-1"
)
echo Using compression: %ramdiskcomp%%lvltxt%
if "%ramdiskcomp%" == "gzip" set "repackcmd=gzip %level%" & set "compext=gz"
if "%ramdiskcomp%" == "lzop" set "repackcmd=lzop %level%" & set "compext=lzo"
if "%ramdiskcomp%" == "lzma" set "repackcmd=xz -Flzma %level%" & set "compext=lzma"
if "%ramdiskcomp%" == "xz" set "repackcmd=xz %level% -Ccrc32" & set "compext=xz"
if "%ramdiskcomp%" == "bzip2" set "repackcmd=bzip2 %level%" & set "compext=bz2"
if "%ramdiskcomp%" == "lz4" set "repackcmd=lz4 %level% stdin stdout 2>nul" & set "compext=lz4"
%bin%\mkbootfs ramdisk %errout% | %bin%\%repackcmd% %errout% > ramdisk-new.cpio.%compext%
if errorlevel == 1 goto error
:skipramdisk
echo.

echo Getting build information . . .
echo.
for /f "delims=" %%a in ('dir /b split_img\*-zImage') do @set kernel=%%a
echo kernel = %kernel%
for /f "delims=" %%a in ('dir /b split_img\*-ramdisk.cpio*') do @set ramdiskname=%%a
if "%1" == "--original" echo ramdisk = %ramdiskname% & set "ramdisk=--ramdisk "split_img/%ramdiskname%""
if not "%1" == "--original" set "ramdiskname=ramdisk-new.cpio.%compext%" & set "ramdisk=--ramdisk ramdisk-new.cpio.%compext%"
if not exist "split_img\*-cmdline" goto skipcmd
for /f "delims=" %%a in ('dir /b split_img\*-cmdline') do @set cmdname=%%a
for /f "delims=" %%a in ('type "split_img\%cmdname%"') do @set cmdline=%%a
:skipcmd
echo cmdline = %cmdline%
if defined cmdline set cmdline=%cmdline:"=\"%
if not exist "split_img\*-board" goto skipboard
for /f "delims=" %%a in ('dir /b split_img\*-board') do @set boardname=%%a
for /f "delims=" %%a in ('type "split_img\%boardname%"') do @set board=%%a
:skipboard
echo board = %board%
if defined board set board=%board:"=\"%
for /f "delims=" %%a in ('dir /b split_img\*-base') do @set basename=%%a
for /f "delims=" %%a in ('type "split_img\%basename%"') do @set base=%%a
echo base = %base%
for /f "delims=" %%a in ('dir /b split_img\*-pagesize') do @set pagename=%%a
for /f "delims=" %%a in ('type "split_img\%pagename%"') do @set pagesize=%%a
echo pagesize = %pagesize%
for /f "delims=" %%a in ('dir /b split_img\*-kerneloff') do @set koffname=%%a
for /f "delims=" %%a in ('type "split_img\%koffname%"') do @set kerneloff=%%a
echo kernel_offset = %kerneloff%
for /f "delims=" %%a in ('dir /b split_img\*-ramdiskoff') do @set roffname=%%a
for /f "delims=" %%a in ('type "split_img\%roffname%"') do @set ramdiskoff=%%a
echo ramdisk_offset = %ramdiskoff%
if not exist "split_img\*-tagsoff" goto skiptags
for /f "delims=" %%a in ('dir /b split_img\*-tagsoff') do @set toffname=%%a
for /f "delims=" %%a in ('type "split_img\%toffname%"') do @set tagsoff=%%a
:skiptags
echo tags_offset = %tagsoff%
if not exist "split_img\*-osversion" goto skiposver
for /f "delims=" %%a in ('dir /b split_img\*-osversion') do @set osvname=%%a
for /f "delims=" %%a in ('type "split_img\%osvname%"') do @set osver=%%a
echo os_version = %osver%
:skiposver
if not exist "split_img\*-oslevel" goto skiposlvl
for /f "delims=" %%a in ('dir /b split_img\*-oslevel') do @set oslname=%%a
for /f "delims=" %%a in ('type "split_img\%oslname%"') do @set oslvl=%%a
echo os_patch_level = %oslvl%
:skiposlvl
if not exist "split_img\*-second" goto skipsecond
for /f "delims=" %%a in ('dir /b split_img\*-second') do @set second=%%a
echo second = %second% & set "second=--second "split_img/%second%""
for /f "delims=" %%a in ('dir /b split_img\*-secondoff') do @set soffname=%%a
for /f "delims=" %%a in ('type "split_img\%soffname%"') do @set secondoff=%%a
echo second_offset = %secondoff% & set "second_offset=--second_offset %secondoff%"
:skipsecond
if not exist "split_img\*-dtb" goto skipdtb
for /f "delims=" %%a in ('dir /b split_img\*-dtb') do @set dtb=%%a
echo dtb = %dtb% & set "dtb=--dt "split_img/%dtb%""

:skipdtb
echo.
if not exist "split_img\*-mtktype" goto skipmtk
for /f "delims=" %%a in ('dir /b split_img\*-mtktype') do @set mtktypename=%%a
for /f "delims=" %%a in ('type "split_img\%mtktypename%"') do @set mtktype=%%a
echo Generating MTK headers . . .
echo.
echo Using ramdisk type: %mtktype%
if "%1" == "--original" set "mtkramdisk=--%mtktype% "split_img/%ramdiskname%""
if not "%1" == "--original" set "mtkramdisk=--%mtktype% "%ramdiskname%""
%bin%\mkmtkhdr --kernel "split_img/%kernel%" %mtkramdisk% >nul %errout%
if errorlevel == 1 goto error
move /y "%kernel%-mtk" "kernel-new.mtk" >nul
move /y "%ramdiskname%-mtk" "%mtktype%-new.mtk" >nul
set "kernel=../kernel-new.mtk"
set "ramdisk=--ramdisk "%mtktype%-new.mtk""
echo.

:skipmtk
for /f "delims=" %%a in ('dir /b split_img\*-imgtype') do @set imgtypename=%%a
for /f "delims=" %%a in ('type "split_img\%imgtypename%"') do @set imgtype=%%a
if "%imgtype%" == "ELF" set "imgtype=AOSP" & echo Warning: ELF format detected; will be repacked using AOSP format! & echo.
if "%imgtype%" == "AOSP" set "buildcmd=mkbootimg --kernel "split_img/%kernel%" %ramdisk% %second% --cmdline "%cmdline%" --board "%board%" --base %base% --pagesize %pagesize% --kernel_offset %kerneloff% --ramdisk_offset %ramdiskoff% %second_offset% --tags_offset "%tagsoff%" --os_version "%osver%" --os_patch_level "%oslvl%" %dtb% -o image-new.img"

echo Building image . . .
echo.
echo Using format: %imgtype%
echo.
%bin%\%buildcmd% %errout%
if errorlevel == 1 goto error

if not exist "split_img\*-lokitype" goto skiploki
for /f "delims=" %%a in ('dir /b split_img\*-lokitype') do @set lokitypename=%%a
for /f "delims=" %%a in ('type "split_img\%lokitypename%"') do @set lokitype=%%a
echo Loki patching new image . . .
echo.
echo Using type: %lokitype%
echo.
move /y image-new.img unlokied-new.img >nul
if exist aboot.img (
  %bin%\loki_tool patch %lokitype% aboot.img unlokied-new.img image-new.img >nul %errout%
  if errorlevel == 1 echo Patching failed. & goto error
) else (
  echo Device aboot.img required in script directory to find Loki patch offset.
  goto error
)

:skiploki
echo Done!
goto end

:nofiles
echo No files found to be packed/built.

:error
echo Error!

:end
echo.
pause
