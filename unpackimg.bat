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
echo.
cd ..

echo Unpacking ramdisk to "/ramdisk/" . . .
echo.
cd ramdisk
%bin%\gzip -dc "../split_img/%~n1%~x1-ramdisk.gz" | %bin%\cpio -i
echo.
cd ..

echo Done!
goto end

:noargs
echo No image file supplied.

:end
echo.
pause
