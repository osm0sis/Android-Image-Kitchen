#!/system/bin/sh
# AIK-mobile/repackimg: repack ramdisk and build image
# osm0sis @ xda-developers

case $0 in
  /system/bin/sh|sh|tmp-mksh|sush)
    echo "Please run without using the source command.";
    echo "Example: sh ./repackimg.sh boot.img";
    return 1;;
esac;

abort() { cd "$aik"; echo "Error!"; }

aik="$PWD";
bin="$aik/bin";
bb="$bin/busybox";
chmod -R 755 "$bin" "$aik"/*.sh;
chmod 644 "$bin/magic";
cd "$aik";

if [ ! -f $bb ]; then
  bb=busybox;
fi;

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
case $1 in
  --original)
    echo "Repacking with original ramdisk...";;
  --level|*)
    echo "Packing ramdisk...\n";
    ramdiskcomp=`cat split_img/*-ramdiskcomp`;
    if [ "$1" == "--level" -a "$2" ]; then
      level="-$2";
      lvltxt=" - Level: $2";
    elif [ "$ramdiskcomp" == "xz" ]; then
      level=-1;
    fi;
    echo "Using compression: $ramdiskcomp$lvltxt";
    repackcmd="$bb $ramdiskcomp $level";
    compext=$ramdiskcomp;
    case $ramdiskcomp in
      gzip) compext=gz;;
      lzop) compext=lzo;;
      xz) repackcmd="$bin/xz $level -Ccrc32";;
      lzma) repackcmd="$bin/xz $level -Flzma";;
      bzip2) compext=bz2;;
      lz4) repackcmd="$bin/lz4 $level -l stdin stdout";;
    esac;
    $bin/mkbootfs ramdisk | $repackcmd > ramdisk-new.cpio.$compext;
    if [ $? != "0" ]; then
      abort;
      return 1;
    fi;;
esac;

echo "\nGetting build information...";
cd split_img;
kernel=`ls *-zImage`;               echo "kernel = $kernel";
if [ "$1" == "--original" ]; then
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

echo "\nBuilding image...\n";
$bin/mkbootimg --kernel "split_img/$kernel" --ramdisk "$ramdisk" $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset $tagsoff $dtb -o image-new.img;
if [ $? != "0" ]; then
  abort;
  return 1;
fi;

echo "Done!";
return 0;

