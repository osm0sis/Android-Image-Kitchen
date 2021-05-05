"%bin%"\find . | "%bin%"\cpio -H newc -R 0:0 -o -F ..\ramdisk-new.cpio 2>nul
