#!/bin/bash
# AIK-Linux/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

cleanup() { "$aik/cleanup.sh" $local --quiet; }
abort() { echo "Error!"; }

case $1 in
  --help) echo "usage: unpackimg.sh [--local] [--nosudo] <file>"; exit 1;;
  --local) local="--local"; shift;;
esac;
case $1 in
  --nosudo) nosudo=1; shift;;
  --sudo) shift;;
esac;
if [ ! "$nosudo" ]; then
  sudo=sudo; sumsg=" (as root)";
fi;

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
cur="$(readlink -f "$PWD")";

case $plat in
  macos)
    cpio="env DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/cpio"";
    statarg="-f %Su";
    dd() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/dd" "$@"; }
    file() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/file" "$@"; }
    lzma() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/xz" "$@"; }
    lzop() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/lzop" "$@"; }
    tail() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/tail" "$@"; }
    truncate() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/truncate" "$@"; }
    xz() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/xz" "$@"; }
  ;;
  linux)
    cpio=cpio;
    test "$(cpio --version | head -n1 | rev | cut -d\  -f1 | rev)" == "2.13" && cpiowarning=1;
    statarg="-c %U";
  ;;
esac;

if [ ! "$local" ]; then
  cd "$aik";
fi;
chmod -R 755 "$bin" "$aik"/*.sh;
chmod 644 "$bin/magic" "$bin/androidbootimg.magic" "$bin/boot_signer.jar" "$bin/avb/"* "$bin/chromeos/"*;

test -f "$cur/$1" && img="$cur/$1" || img="$1";
if [ ! "$img" ]; then
  while IFS= read -r line; do
    case $line in
      aboot.img|image-new.img|unlokied-new.img|unsigned-new.img) continue;;
    esac;
    img="$line";
    break;
  done < <(ls *.elf *.img *.sin 2>/dev/null);
fi;
img="$(readlink -f "$img")";
if [ ! -f "$img" ]; then
  echo "No image file supplied.";
  abort;
  exit 1;
fi;

clear;
echo " ";
echo "Android Image Kitchen - UnpackImg Script";
echo "by osm0sis @ xda-developers";
echo " ";

file=$(basename "$img");
echo "Supplied image: $file";
echo " ";

if [ -d split_img -o -d ramdisk ]; then
  if [ -d ramdisk ] && [ "$(stat $statarg ramdisk | head -n 1)" = "root" -o ! "$(find ramdisk 2>&1 | cpio -o >/dev/null 2>&1; echo $?)" -eq "0" ]; then
    rmsumsg=" (as root)";
  fi;
  echo "Removing old work folders and files$rmsumsg...";
  echo " ";
  cleanup;
fi;

echo "Setting up work folders...";
echo " ";
mkdir split_img ramdisk;

cd split_img;
filesize=$(wc -c < "$img");
echo "$filesize" > "$file-origsize";
imgtest="$(file -m "$bin/androidbootimg.magic" "$img" 2>/dev/null | cut -d: -f2-)";
if [ "$(echo $imgtest | awk '{ print $2 }' | cut -d, -f1)" = "signing" ]; then
  echo $imgtest | awk '{ print $1 }' > "$file-sigtype";
  sigtype=$(cat "$file-sigtype");
  echo "Signature with \"$sigtype\" type detected, removing...";
  echo " ";
  case $sigtype in
    BLOB)
      cp -f "$img" "$file";
      "$bin/$arch/blobunpack" "$file" | tail -n+5 | cut -d" " -f2 | dd bs=1 count=3 > "$file-blobtype" 2>/dev/null;
      mv -f "$file."* "$file";
    ;;
    CHROMEOS) "$bin/$arch/futility" vbutil_kernel --get-vmlinuz "$img" --vmlinuz-out "$file";;
    DHTB) dd bs=4096 skip=512 iflag=skip_bytes conv=notrunc if="$img" of="$file" 2>/dev/null;;
    NOOK)
      dd bs=1048576 count=1 conv=notrunc if="$img" of="$file-master_boot.key" 2>/dev/null;
      dd bs=1048576 skip=1 conv=notrunc if="$img" of="$file" 2>/dev/null;
    ;;
    NOOKTAB)
      dd bs=262144 count=1 conv=notrunc if="$img" of="$file-master_boot.key" 2>/dev/null;
      dd bs=262144 skip=1 conv=notrunc if="$img" of="$file" 2>/dev/null;
    ;;
    SIN*)
      "$bin/$arch/sony_dump" . "$img" >/dev/null;
      mv -f "$file."* "$file";
      rm -f "$file-sigtype";
    ;;
  esac;
  img="$file";
fi;

imgtest="$(file -m "$bin/androidbootimg.magic" "$img" 2>/dev/null | cut -d: -f2-)";
if [ "$(echo $imgtest | awk '{ print $2 }' | cut -d, -f1)" = "bootimg" ]; then
  test "$(echo $imgtest | awk '{ print $3 }')" = "PXA" && typesuffix=-PXA;
  echo "$(echo $imgtest | awk '{ print $1 }')$typesuffix" > "$file-imgtype";
  imgtype=$(cat "$file-imgtype");
else
  cd ..;
  cleanup;
  echo "Unrecognized format.";
  abort;
  exit 1;
fi;
echo "Image type: $imgtype";
echo " ";

case $imgtype in
  AOSP*|ELF|KRNL|OSIP|U-Boot) ;;
  *)
    cd ..;
    cleanup;
    echo "Unsupported format.";
    abort;
    exit 1;
  ;;
esac;

case $(echo $imgtest | awk '{ print $3 }') in
  LOKI)
    echo $imgtest | awk '{ print $5 }' | cut -d\( -f2 | cut -d\) -f1 > "$file-lokitype";
    lokitype=$(cat "$file-lokitype");
    echo "Loki patch with \"$lokitype\" type detected, reverting...";
    echo " ";
    echo "Warning: A dump of your device's aboot.img is required to re-Loki!";
    echo " ";
    "$bin/$arch/loki_tool" unlok "$img" "$file" >/dev/null;
    img="$file";
  ;;
  AMONET)
    echo "Amonet patch detected, reverting...";
    echo " ";
    dd bs=2048 count=1 conv=notrunc if="$img" of="$file-microloader.bin" 2>/dev/null;
    dd bs=1024 skip=1 conv=notrunc if="$file-microloader.bin" of="$file-head" 2>/dev/null;
    truncate -s 1024 "$file-microloader.bin";
    truncate -s 2048 "$file-head";
    dd bs=2048 skip=1 conv=notrunc if="$img" of="$file-tail" 2>/dev/null;
    cat "$file-head" "$file-tail" > "$file";
    rm -f "$file-head" "$file-tail";
    img="$file";
  ;;
esac;

tailtest="$(dd if="$img" iflag=skip_bytes skip=$(($(wc -c < "$img") - 8192)) bs=8192 count=1 2>/dev/null | file -m $bin/androidbootimg.magic - 2>/dev/null | cut -d: -f2-)";
case $tailtest in
  *data) tailtest="$(tail -n50 "$img" | file -m "$bin/androidbootimg.magic" - 2>/dev/null | cut -d: -f2-)";;
esac;
tailtype="$(echo $tailtest | awk '{ print $1 }')";
case $tailtype in
  AVB*)
    echo "Signature with \"$tailtype\" type detected.";
    echo " ";
    case $tailtype in
      *v1)
        echo $tailtype > "$file-sigtype";
        echo $tailtest | awk '{ print $4 }' > "$file-avbtype";
      ;;
    esac;
  ;;
  Bump|SEAndroid)
    echo "Footer with \"$tailtype\" type detected.";
    echo " ";
    echo $tailtype > "$file-tailtype";
  ;;
esac;

if [ "$imgtype" = "U-Boot" ]; then
  imgsize=$(($(printf '%d\n' 0x$(hexdump -n 4 -s 12 -e '16/1 "%02x""\n"' "$img")) + 64));
  if [ ! "$filesize" = "$imgsize" ]; then
    echo "Trimming...";
    echo " ";
    dd bs=$imgsize count=1 conv=notrunc if="$img" of="$file" 2>/dev/null;
    img="$file";
  fi;
fi;

echo 'Splitting image to "split_img/"...';
case $imgtype in
  AOSP) "$bin/$arch/unpackbootimg" -i "$img";;
  AOSP-PXA) "$bin/$arch/pxa-unpackbootimg" -i "$img";;
  ELF)
    mkdir elftool_out;
    "$bin/$arch/elftool" unpack -i "$img" -o elftool_out >/dev/null;
    mv -f elftool_out/header "$file-header" 2>/dev/null;
    rm -rf elftool_out;
    "$bin/$arch/unpackelf" -i "$img";
  ;;
  KRNL) dd bs=4096 skip=8 iflag=skip_bytes conv=notrunc if="$img" of="$file-ramdisk.cpio.gz" 2>&1 | tail -n+3 | cut -d" " -f1-2;;
  OSIP)
    "$bin/$arch/mboot" -u -f "$img";
    test ! $? -eq "0" && error=1;
    for i in bootstub cmdline.txt hdr kernel parameter ramdisk.cpio.gz sig; do
      mv -f $i "$file-$(basename $i .txt | sed -e 's/hdr/header/' -e 's/kernel/zImage/')" 2>/dev/null || true;
    done;
  ;;
  U-Boot)
    "$bin/$arch/dumpimage" -l "$img";
    "$bin/$arch/dumpimage" -l "$img" > "$file-header";
    grep "Name:" "$file-header" | cut -c15- > "$file-name";
    grep "Type:" "$file-header" | cut -c15- | cut -d" " -f1 > "$file-arch";
    grep "Type:" "$file-header" | cut -c15- | cut -d" " -f2 > "$file-os";
    grep "Type:" "$file-header" | cut -c15- | cut -d" " -f3 | cut -d- -f1 > "$file-type";
    grep "Type:" "$file-header" | cut -d\( -f2 | cut -d\) -f1 | cut -d" " -f1 | cut -d- -f1 > "$file-comp";
    grep "Address:" "$file-header" | cut -c15- > "$file-addr";
    grep "Point:" "$file-header" | cut -c15- > "$file-ep";
    rm -f "$file-header";
    "$bin/$arch/dumpimage" -p 0 -o "$file-zImage" "$img";
    test ! $? -eq "0" && error=1;
    case $(cat "$file-type") in
      Multi) "$bin/$arch/dumpimage" -p 1 -o "$file-ramdisk.cpio.gz" "$img";;
      RAMDisk) mv -f "$file-zImage" "$file-ramdisk.cpio.gz";;
      *) touch "$file-ramdisk.cpio.gz";;
    esac;
  ;;
esac;
if [ ! $? -eq "0" -o "$error" ]; then
  cd ..;
  cleanup;
  abort;
  exit 1;
fi;

if [ "$(file -m "$bin/androidbootimg.magic" *-zImage 2>/dev/null | cut -d: -f2 | awk '{ print $1 }')" = "MTK" ]; then
  mtk=1;
  echo " ";
  echo "MTK header found in zImage, removing...";
  dd bs=512 skip=1 conv=notrunc if="$file-zImage" of=tempzimg 2>/dev/null;
  mv -f tempzimg "$file-zImage";
fi;
mtktest="$(file -m "$bin/androidbootimg.magic" *-ramdisk*.gz 2>/dev/null | cut -d: -f2-)";
mtktype=$(echo $mtktest | awk '{ print $3 }');
if [ "$(echo $mtktest | awk '{ print $1 }')" = "MTK" ]; then
  if [ ! "$mtk" ]; then
    echo " ";
    echo "Warning: No MTK header found in zImage!";
    mtk=1;
  fi;
  echo "MTK header found in \"$mtktype\" type ramdisk, removing...";
  dd bs=512 skip=1 conv=notrunc if="$(ls *-ramdisk*.gz)" of=temprd 2>/dev/null;
  mv -f temprd "$(ls *-ramdisk*.gz)";
else
  if [ "$mtk" ]; then
    if [ ! "$mtktype" ]; then
      echo 'Warning: No MTK header found in ramdisk, assuming "rootfs" type!';
      mtktype="rootfs";
    fi;
  fi;
fi;
test "$mtk" && echo $mtktype > "$file-mtktype";

if [ -f *-dt ]; then
  dttest="$(file -m "$bin/androidbootimg.magic" *-dt 2>/dev/null | cut -d: -f2 | awk '{ print $1 }')";
  echo $dttest > "$file-dttype";
  if [ "$imgtype" = "ELF" ]; then
    case $dttest in
      QCDT|ELF) ;;
      *) echo " ";
         echo "Non-QC DTB found, packing zImage and appending...";
         gzip --no-name -9 "$file-zImage";
         mv -f "$file-zImage.gz" "$file-zImage";
         cat "$file-dt" >> "$file-zImage";
         rm -f "$file-dt"*;;
    esac;
  fi;
fi;

file -m "$bin/magic" *-ramdisk*.gz 2>/dev/null | cut -d: -f2 | awk '{ print $1 }' > "$file-ramdiskcomp";
ramdiskcomp=`cat *-ramdiskcomp`;
unpackcmd="$ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) unpackcmd="gzip -dcq"; compext=gz;;
  lzop) compext=lzo;;
  xz) ;;
  lzma) ;;
  bzip2) compext=bz2;;
  lz4) unpackcmd="$bin/$arch/lz4 -dcq";;
  lz4-l) unpackcmd="$bin/$arch/lz4 -dcq"; compext=lz4;;
  cpio) unpackcmd="cat"; compext="";;
  empty) compext=empty;;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
mv -f "$(ls *-ramdisk*.gz)" "$file-ramdisk.cpio$compext" 2>/dev/null;
cd ..;
if [ "$ramdiskcomp" = "data" ]; then
  echo "Unrecognized format.";
  abort;
  exit 1;
fi;

echo " ";
if [ "$ramdiskcomp" = "empty" ]; then
  echo "Warning: No ramdisk found to be unpacked!";
else
  echo "Unpacking ramdisk$sumsg to \"ramdisk/\"...";
  echo " ";
  if [ "$cpiowarning" ]; then
    echo "Warning: Using cpio 2.13 may result in an unusable repack; downgrade to 2.12 to be safe!";
    echo " ";
  fi;
  echo "Compression used: $ramdiskcomp";
  if [ ! "$compext" -a ! "$ramdiskcomp" = "cpio" ]; then
    echo "Unsupported format.";
    abort;
    exit 1;
  fi;
  $sudo chown 0:0 ramdisk 2>/dev/null;
  cd ramdisk;
  $unpackcmd "../split_img/$file-ramdisk.cpio$compext" | $sudo $cpio -i -d --no-absolute-filenames;
  if [ ! $? -eq "0" ]; then
    test "$nosudo" && echo "Unpacking failed, try without --nosudo.";
    cd ..;
    abort;
    exit 1;
  fi;
  cd ..;
fi;

echo " ";
echo "Done!";
exit 0;

