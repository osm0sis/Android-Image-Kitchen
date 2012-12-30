@echo off

cd %~p0
rd /s /q ramdisk > nul 2>&1
rd /s /q split_img > nul 2>&1
del *new.* > nul 2>&1
