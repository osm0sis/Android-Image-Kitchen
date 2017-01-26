#!/system/bin/sh
# AIK-mobile/repackimg: repack ramdisk and build image
# osm0sis @ xda-developers

case $1 in
  --help) echo "usage: repackimg.sh [--original] [--level <0-9>]"; return 1;
esac;

case $0 in
  *.sh) aik="$0";;
     *) aik="$(lsof -p $$ 2>/dev/null | grep -o '/.*repackimg.sh$')";;
esac;
aik="$(dirname "$(readlink -f "$aik")")";

abort() { cd "$aik"; echo "Error!"; }

cd "$aik";
bb=bin/busybox;
chmod -R 755 bin *.sh;
chmod 644 bin/magic bin/androidbootimg.magic;

if [ ! -f $bb ]; then
  bb=busybox;
fi;

if [ -z "$(ls split_img/* 2>/dev/null)" -o -z "$(ls ramdisk/* 2>/dev/null)" ]; then
  echo "No files found to be packed/built.";
  abort;
  return 1;
fi;

case $0 in *.sh) clear;; esac;
echo "\nAndroid Image Kitchen - RepackImg Script";
echo "by osm0sis @ xda-developers\n";

if [ ! -z "$(ls *-new.* 2>/dev/null)" ]; then
  echo "Warning: Overwriting existing files!\n";
fi;

rm -f *-new.*;
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
      xz) repackcmd="bin/xz $level -Ccrc32";;
      lzma) repackcmd="bin/xz $level -Flzma";;
      bzip2) compext=bz2;;
      lz4) repackcmd="bin/lz4 $level -l stdin stdout";;
    esac;
    bin/mkbootfs ramdisk | $repackcmd > ramdisk-new.cpio.$compext;
    if [ $? != "0" ]; then
      abort;
      return 1;
    fi;;
esac;

echo "\nGetting build information...";
cd split_img;
kernel=`ls *-zImage`;               echo "kernel = $kernel";
kernel="split_img/$kernel";
if [ "$1" == "--original" ]; then
  ramdisk=`ls *-ramdisk.cpio*`;     echo "ramdisk = $ramdisk";
  ramdisk="split_img/$ramdisk";
else
  ramdisk="ramdisk-new.cpio.$compext";
fi;
if [ -f *-cmdline ]; then
  cmdline=`cat *-cmdline`;          echo "cmdline = $cmdline";
fi;
if [ -f *-board ]; then
  board=`cat *-board`;              echo "board = $board";
fi;
base=`cat *-base`;                  echo "base = $base";
pagesize=`cat *-pagesize`;          echo "pagesize = $pagesize";
kerneloff=`cat *-kerneloff`;        echo "kernel_offset = $kerneloff";
ramdiskoff=`cat *-ramdiskoff`;      echo "ramdisk_offset = $ramdiskoff";
if [ -f *-tagsoff ]; then
  tagsoff=`cat *-tagsoff`;          echo "tags_offset = $tagsoff";
fi;
if [ -f *-osversion ]; then
  osver=`cat *-osversion`;          echo "os_version = $osver";
fi;
if [ -f *-oslevel ]; then
  oslvl=`cat *-oslevel`;            echo "os_patch_level = $oslvl";
fi;
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

if [ -f split_img/*-mtktype ]; then
  mtktype=`cat split_img/*-mtktype`;
  echo "\nGenerating MTK headers...\n";
  echo "Using ramdisk type: $mtktype";
  bin/mkmtkhdr --kernel "$kernel" --$mtktype "$ramdisk" >/dev/null;
  if [ $? != "0" ]; then
    abort;
    return 1;
  fi;
  mv -f $($bb basename $kernel)-mtk kernel-new.mtk;
  mv -f $($bb basename $ramdisk)-mtk $mtktype-new.mtk;
  kernel=kernel-new.mtk;
  ramdisk=$mtktype-new.mtk;
fi;

imgtype=`cat split_img/*-imgtype`;
if [ "$imgtype" == "ELF" ]; then
  imgtype=AOSP;
  echo "\nWarning: ELF format detected; will be repacked using AOSP format!";
fi;

echo "\nBuilding image...\n";
echo "Using format: $imgtype\n";
case $imgtype in
  AOSP) bin/mkbootimg --kernel "$kernel" --ramdisk "$ramdisk" $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset "$tagsoff" --os_version "$osver" --os_patch_level "$oslvl" $dtb -o image-new.img;;
esac;
if [ $? != "0" ]; then
  abort;
  return 1;
fi;

if [ -f split_img/*-lokitype ]; then
  lokitype=`cat split_img/*-lokitype`;
  echo "Loki patching new image...\n"
  echo "Using type: $lokitype\n";
  mv -f image-new.img unlokied-new.img;
  if [ -f aboot.img ]; then
    bin/loki_tool patch $lokitype aboot.img unlokied-new.img image-new.img >/dev/null;
    if [ $? != "0" ]; then
      echo "Patching failed.";
      abort;
      return 1;
    fi;
  else
    echo "Device aboot.img required in script directory to find Loki patch offset.";
    abort;
    return 1;
  fi;
fi;

echo "Done!";
return 0;

