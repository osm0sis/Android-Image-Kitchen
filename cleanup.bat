@echo off

cd %~p0
if "%~1" == "--help" echo usage: cleanup.bat & goto end
rd /s /q ramdisk > nul 2>&1
rd /s /q split_img > nul 2>&1
del *new.* *original.* > nul 2>&1

:end
