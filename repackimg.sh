#!/bin/bash
# AIK-Linux/repackimg: repack ramdisk and build image
# osm0sis @ xda-developers

abort() { cd "$aik"; echo "Error!"; }

case $1 in
  --help) echo "usage: repackimg.sh [--original] [--level <0-9>] [--avbkey <name>] [--forceelf]"; exit 1;
esac;

case $(uname -s) in
  Darwin|Macintosh)
    plat="macos";
    readlink() { perl -MCwd -e 'print Cwd::abs_path shift' "$2"; }
  ;;
  *) plat="linux";;
esac;
arch=$plat/`uname -m`;

aik="${BASH_SOURCE:-$0}";
aik="$(dirname "$(readlink -f "$aik")")";
bin="$aik/bin";
rel=bin;
cur="$(readlink -f "$PWD")";

case $plat in
  macos)
    cpio="env DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/cpio"";
    statarg="-f %Su";
    dd() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/dd" "$@"; }
    java() { "/Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin/java" "$@"; }
    lzop() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/lzop" "$@"; }
    xz() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/xz" "$@"; }
  ;;
  linux)
    cpio=cpio;
    statarg="-c %U";
  ;;
esac;

cd "$aik";
chmod -R 755 "$bin" *.sh;
chmod 644 "$bin/magic" "$bin/androidbootimg.magic" "$bin/BootSignature.jar" "$bin/avb/"* "$bin/chromeos/"*;

ramdiskcomp=`cat split_img/*-ramdiskcomp 2>/dev/null`;
if [ -z "$(ls split_img/* 2>/dev/null)" -o -z "$(ls ramdisk/* 2>/dev/null)" -a ! "$ramdiskcomp" = "empty" ]; then
  echo "No files found to be packed/built.";
  abort;
  exit 1;
fi;

clear;
echo " ";
echo "Android Image Kitchen - RepackImg Script";
echo "by osm0sis @ xda-developers";
echo " ";

if [ ! -z "$(ls *-new.* 2>/dev/null)" ]; then
  echo "Warning: Overwriting existing files!";
  echo " ";
fi;

if [ -d ramdisk ] && [ "$(stat $statarg ramdisk | head -n 1)" = "root" ]; then
  sudo=sudo; sumsg=" (as root)";
else
  cpioarg="-R 0:0";
fi;

rm -f "*-new.*";
while [ "$1" ]; do
  case $1 in
    --original) original=1;;
    --forceelf) repackelf=1;;
    --level)
      case $2 in
        ''|*[!0-9]*) ;;
        *) level="-$2"; lvltxt=" - Level: $2"; shift;;
      esac;
    ;;
    --avbkey)
      if [ "$2" ]; then
        for keytest in "$2" "$cur/$2" "$aik/$2"; do
          if [ ! -z "$(ls $keytest.pk8 2>/dev/null)" -a ! -z "$(ls $keytest.x509.* 2>/dev/null)" ]; then
            avbkey="$keytest"; avbtxt=" - Key: $2"; shift; break;
          fi;
        done;
      fi;
    ;;
  esac;
  shift;
done;

if [ "$original" ]; then
  echo "Repacking with original ramdisk...";
elif [ "$ramdiskcomp" = "empty" ]; then
  echo "Warning: Using empty ramdisk for repack!";
  compext=empty;
  touch ramdisk-new.cpio.$compext;
else
  echo "Packing ramdisk$sumsg...";
  echo " ";
  test -z "$level" -a "$ramdiskcomp" = "xz" && level=-1;
  echo "Using compression: $ramdiskcomp$lvltxt";
  repackcmd="$ramdiskcomp $level";
  compext=$ramdiskcomp;
  case $ramdiskcomp in
    gzip) compext=gz;;
    lzop) compext=lzo;;
    xz) repackcmd="xz $level -Ccrc32";;
    lzma) repackcmd="xz $level -Flzma";;
    bzip2) compext=bz2;;
    lz4) repackcmd="$bin/$arch/lz4 $level -l";;
    *) abort; exit 1;;
  esac;
  cd ramdisk;
  $sudo find . | $sudo $cpio $cpioarg -H newc -o 2>/dev/null | $repackcmd > ../ramdisk-new.cpio.$compext;
  if [ ! $? -eq "0" ]; then
    abort;
    exit 1;
  fi;
  cd ..;
fi;

echo " ";
echo "Getting build information...";
cd split_img;
imgtype=`cat *-imgtype`;
if [ "$imgtype" != "KRNL" ]; then
  kernel=`ls *-zImage`;                 echo "kernel = $kernel";
  kernel="split_img/$kernel";
fi;
if [ "$original" ]; then
  ramdisk=`ls *-ramdisk.cpio*`;       echo "ramdisk = $ramdisk";
  ramdisk="split_img/$ramdisk";
else
  ramdisk="ramdisk-new.cpio.$compext";
fi;
if [ "$imgtype" = "U-Boot" ]; then
  name=`cat *-name`;                  echo "name = $name";
  uarch=`cat *-arch`;
  os=`cat *-os`;
  type=`cat *-type`;
  comp=`cat *-comp`;                  echo "type = $uarch $os $type ($comp)";
  test "$comp" = "uncompressed" && comp=none;
  addr=`cat *-addr`;                  echo "load_addr = $addr";
  ep=`cat *-ep`;                      echo "entry_point = $ep";
elif [ "$imgtype" = "KRNL" ]; then
  rsz=$(wc -c < "$aik/$ramdisk");     echo "ramdisk_size = $rsz";
else
  if [ -f *-second ]; then
    second=`ls *-second`;             echo "second = $second";
    second=(--second "split_img/$second");
  fi;
  if [ -f *-cmdline ]; then
    cmdname=`ls *-cmdline`;
    cmdname="split_img/$cmdname";
    cmdline=`cat *-cmdline`;          echo "cmdline = $cmdline";
  fi;
  if [ -f *-board ]; then
    board=`cat *-board`;              echo "board = $board";
  fi;
  base=`cat *-base`;                  echo "base = $base";
  pagesize=`cat *-pagesize`;          echo "pagesize = $pagesize";
  kerneloff=`cat *-kerneloff`;        echo "kernel_offset = $kerneloff";
  ramdiskoff=`cat *-ramdiskoff`;      echo "ramdisk_offset = $ramdiskoff";
  if [ -f *-secondoff ]; then
    secondoff=`cat *-secondoff`;      echo "second_offset = $secondoff";
  fi;
  if [ -f *-tagsoff ]; then
    tagsoff=`cat *-tagsoff`;          echo "tags_offset = $tagsoff";
  fi;
  if [ -f *-osversion ]; then
    osver=`cat *-osversion`;          echo "os_version = $osver";
  fi;
  if [ -f *-oslevel ]; then
    oslvl=`cat *-oslevel`;            echo "os_patch_level = $oslvl";
  fi;
  if [ -f *-hash ]; then
    hash=`cat *-hash`;                echo "hash = $hash";
    hash="--hash $hash";
  fi;
  if [ -f *-dtb ]; then
    dtbtype=`cat *-dtbtype`;
    dtb=`ls *-dtb`;                   echo "dtb = $dtb";
    rpm=("split_img/$dtb",rpm);
    dtb=(--dt "split_img/$dtb");
  fi;
  if [ -f *-unknown ]; then
    unknown=`cat *-unknown`;          echo "unknown = $unknown";
  fi;
  if [ -f *-header ]; then
    header=`ls *-header`;
    header="split_img/$header";
  fi;
fi;
cd ..;

if [ -f split_img/*-mtktype ]; then
  mtktype=`cat split_img/*-mtktype`;
  echo " ";
  echo "Generating MTK headers...";
  echo " ";
  echo "Using ramdisk type: $mtktype";
  "$bin/$arch/mkmtkhdr" --kernel "$kernel" --$mtktype "$ramdisk" >/dev/null;
  if [ ! $? -eq "0" ]; then
    abort;
    exit 1;
  fi;
  mv -f "$(basename "$kernel")-mtk" kernel-new.mtk;
  mv -f "$(basename "$ramdisk")-mtk" $mtktype-new.mtk;
  kernel=kernel-new.mtk;
  ramdisk=$mtktype-new.mtk;
fi;

if [ -f split_img/*-sigtype ]; then
  outname=unsigned-new.img;
else
  outname=image-new.img;
fi;

test "$dtbtype" == "ELF" && repackelf=1;
if [ "$imgtype" = "ELF" ] && [ ! "$header" -o ! "$repackelf" ]; then
  imgtype=AOSP;
  echo " ";
  echo "Warning: ELF format without RPM detected; will be repacked using AOSP format!";
fi;

echo " ";
echo "Building image...";
echo " ";
echo "Using format: $imgtype";
echo " ";
case $imgtype in
  AOSP) "$bin/$arch/mkbootimg" --kernel "$kernel" --ramdisk "$ramdisk" "${second[@]}" --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff --second_offset "$secondoff" --tags_offset "$tagsoff" --os_version "$osver" --os_patch_level "$oslvl" $hash "${dtb[@]}" -o $outname;;
  AOSP-PXA) "$bin/$arch/pxa-mkbootimg" --kernel "$kernel" --ramdisk "$ramdisk" "${second[@]}" --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff --second_offset "$secondoff" --tags_offset "$tagsoff" --unknown $unknown "${dtb[@]}" -o $outname;;
  ELF) "$bin/$arch/elftool" pack -o $outname header="$header" "$kernel" "$ramdisk",ramdisk "${rpm[@]}" "$cmdname"@cmdline >/dev/null;;
  KRNL) "$bin/$arch/rkcrc" -k "$ramdisk" $outname;;
  U-Boot)
    test "$type" == "Multi" && uramdisk=(:"$ramdisk");
    "$bin/$arch/mkimage" -A $uarch -O $os -T $type -C $comp -a $addr -e $ep -n "$name" -d "$kernel""${uramdisk[@]}" $outname >/dev/null;
  ;;
  *) echo " "; echo "Unsupported format."; abort; exit 1;;
esac;
if [ ! $? -eq "0" ]; then
  abort;
  exit 1;
fi;

if [ -f split_img/*-sigtype ]; then
  sigtype=`cat split_img/*-sigtype`;
  if [ -f split_img/*-avbtype ]; then
    avbtype=`cat split_img/*-avbtype`;
  fi;
  if [ -f split_img/*-blobtype ]; then
    blobtype=`cat split_img/*-blobtype`;
  fi;
  echo "Signing new image...";
  echo " ";
  echo "Using signature: $sigtype $avbtype$avbtxt$blobtype";
  test ! "$avbkey" && avbkey="$rel/avb/verity";
  echo " ";
  case $sigtype in
    AVB) java -jar "$bin/BootSignature.jar" /$avbtype unsigned-new.img "$avbkey.pk8" "$avbkey.x509."* image-new.img 2>/dev/null;;
    BLOB)
      awk 'BEGIN { printf "-SIGNED-BY-SIGNBLOB-\00\00\00\00\00\00\00\00" }' > image-new.img;
      "$bin/$arch/blobpack" tempblob $blobtype unsigned-new.img >/dev/null;
      cat tempblob >> image-new.img;
      rm -rf tempblob;
    ;;
    CHROMEOS) "$bin/$arch/futility" vbutil_kernel --pack image-new.img --keyblock $rel/chromeos/kernel.keyblock --signprivate $rel/chromeos/kernel_data_key.vbprivk --version 1 --vmlinuz unsigned-new.img --bootloader $rel/chromeos/empty --config $rel/chromeos/empty --arch arm --flags 0x1;;
    DHTB)
      "$bin/$arch/dhtbsign" -i unsigned-new.img -o image-new.img >/dev/null;
      rm -rf split_img/*-tailtype 2>/dev/null;
    ;;
    NOOK*) cat split_img/*-master_boot.key unsigned-new.img > image-new.img;;
  esac;
  if [ ! $? -eq "0" ]; then
    abort;
    exit 1;
  fi;
fi;

if [ -f split_img/*-lokitype ]; then
  lokitype=`cat split_img/*-lokitype`;
  echo "Loki patching new image...";
  echo " ";
  echo "Using type: $lokitype";
  echo " ";
  mv -f image-new.img unlokied-new.img;
  if [ -f aboot.img ]; then
    "$bin/$arch/loki_tool" patch $lokitype aboot.img unlokied-new.img image-new.img >/dev/null;
    if [ ! $? -eq "0" ]; then
      echo "Patching failed.";
      abort;
      exit 1;
    fi;
  else
    echo "Device aboot.img required in script directory to find Loki patch offset.";
    abort;
    exit 1;
  fi;
fi;

if [ -f split_img/*-tailtype ]; then
  tailtype=`cat split_img/*-tailtype`;
  echo "Appending footer...";
  echo " ";
  echo "Using type: $tailtype";
  echo " ";
  case $tailtype in
    Bump) awk 'BEGIN { printf "\x41\xA9\xE4\x67\x74\x4D\x1D\x1B\xA4\x29\xF2\xEC\xEA\x65\x52\x79" }' >> image-new.img;;
    SEAndroid) printf 'SEANDROIDENFORCE' >> image-new.img;;
  esac;
fi;

echo "Done!";
exit 0;

