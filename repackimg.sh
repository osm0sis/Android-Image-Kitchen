#!/bin/sh
# AIK-Linux/repackimg: repack ramdisk and build image
# osm0sis @ xda-developers

abort() { cd "$PWD"; echo "Error!"; }

args="$*";
bin="$PWD/bin";
chmod -R 755 "$bin" "$PWD"/*.sh;
chmod 644 "$bin/magic";
cd "$PWD";

if [ -z "$(ls split_img/* 2> /dev/null)" -o -z "$(ls ramdisk/* 2> /dev/null)" ]; then
  echo "No files found to be packed/built.";
  abort;
  return 1;
fi;

clear;
echo "\nAndroid Image Kitchen - RepackImg Script";
echo "by osm0sis @ xda-developers\n";

if [ ! -z "$(ls *-new.* 2> /dev/null)" ]; then
  echo "Warning: Overwriting existing files!\n";
fi;

rm -f ramdisk-new.cpio*;
case $args in
  --original)
    echo "Repacking with original ramdisk...";;
  *)
    echo "Packing ramdisk...\n";
    ramdiskcomp=`cat split_img/*-ramdiskcomp`;
    echo "Using compression: $ramdiskcomp";
    repackcmd="$ramdiskcomp";
    compext=$ramdiskcomp;
    case $ramdiskcomp in
      gzip) compext=gz;;
      lzop) compext=lzo;;
      xz) repackcmd="xz -1 -Ccrc32";;
      lzma) repackcmd="xz -Flzma";;
      bzip2) compext=bz2;;
      lz4) repackcmd="$bin/lz4 -l stdin stdout";;
    esac;
    cd ramdisk;
    find . | cpio -o -H newc | $repackcmd > ../ramdisk-new.cpio.$compext;
    if [ $? -eq "1" ]; then
      abort;
      return 1;
    fi;
    cd ..;;
esac;

echo "\nGetting build information...\n";
cd split_img;
kernel=`ls *-zImage`;               echo "kernel = $kernel";
if [ "$args" = "--original" ]; then
  ramdisk=`ls *-ramdisk.cpio*`;     echo "ramdisk = $ramdisk";
  ramdisk="split_img/$ramdisk";
else
  ramdisk="ramdisk-new.cpio.$compext";
fi;
cmdline=`cat *-cmdline`;            echo "cmdline = $cmdline";
board=`cat *-board`;                echo "board = $board";
base=`cat *-base`;                  echo "base = $base";
pagesize=`cat *-pagesize`;          echo "pagesize = $pagesize";
kerneloff=`cat *-kerneloff`;        echo "kernel_offset = $kerneloff";
ramdiskoff=`cat *-ramdiskoff`;      echo "ramdisk_offset = $ramdiskoff";
tagsoff=`cat *-tagsoff`;            echo "tags_offset = $tagsoff";
if [ -f *-second ]; then
  second=`ls *-second`;             echo "second = $second";  
  second="--second split_img/$second";
  secondoff=`cat *-secondoff`;      echo "second_offset = $secondoff";
  secondoff="--second_offset $secondoff";
fi;
if [ -f *-dtb ]; then
  dtb=`ls *-dtb`;                   echo "dtb = $dtb";
  dtb="--dt split_img/$dtb";
fi;
cd ..;

echo "\nBuilding image...\n"
$bin/mkbootimg --kernel "split_img/$kernel" --ramdisk "$ramdisk" $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset $tagsoff $dtb -o image-new.img;
if [ $? -eq "1" ]; then
  abort;
  return 1;
fi;

echo "Done!";
return 0;

