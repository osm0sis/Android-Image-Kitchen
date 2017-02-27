#!/bin/sh
# AIK-Linux/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

cleanup() { $sudo$rmsu rm -rf ramdisk split_img *new.* *original.*; }
abort() { cd "$aik"; echo "Error!"; }

case $1 in
  --help) echo "usage: unpackimg.sh <file>"; exit 1;;
  --sudo) sudo=sudo; sumsg=" (as root)"; shift;;
esac;

aik="${BASH_SOURCE:-$0}";
aik="$(dirname "$(readlink -f "$aik")")";

cd "$aik";
chmod -R 755 bin *.sh;
chmod 644 bin/magic bin/androidbootimg.magic;

arch=`uname -m`;

img="$1";
if [ ! "$img" ]; then
  for i in `ls *.elf *.img 2>/dev/null`; do
    case $i in
      aboot.img|image-new.img) continue;;
    esac;
    img="$i"; break;
  done;
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
  if [ ! -z "$(ls ramdisk/* 2>/dev/null)" ] && [ "$(stat -c %U ramdisk/* | head -n 1)" = "root" ]; then
    test ! "$sudo" && rmsu=sudo; rmsumsg=" (as root)";
  fi;
  echo "Removing old work folders and files$rmsumsg...";
  echo " ";
  cleanup;
fi;

echo "Setting up work folders...";
echo " ";
mkdir split_img ramdisk;

imgtest="$(file -m bin/androidbootimg.magic "$img" | cut -d: -f2-)";
if [ "$(echo $imgtest | awk '{ print $2 }' | cut -d, -f1)" = "bootimg" ]; then
  echo $imgtest | awk '{ print $1 }' > "split_img/$file-imgtype";
  imgtype=`cat split_img/$file-imgtype`;
else
  cleanup;
  echo "Unrecognized format.";
  abort;
  exit 1;
fi;
echo "Image type: $imgtype";
echo " ";

case $imgtype in
  AOSP) splitcmd="unpackbootimg -i";;
  CHROMEOS) splitcmd="unpackbootimg -i";;
  ELF) splitcmd="unpackelf -i";;
esac;
if [ ! "$splitcmd" ]; then
  cleanup;
  echo "Unsupported format.";
  abort;
  return 1;
fi;

if [ "$(echo $imgtest | awk '{ print $3 }')" = "LOKI" ]; then
  echo $imgtest | awk '{ print $5 }' | cut -d\( -f2 | cut -d\) -f1 > "split_img/$file-lokitype";
  lokitype=`cat split_img/$file-lokitype`;
  echo "Loki patch with \"$lokitype\" type detected, reverting...";
  echo " ";
  echo "Warning: A dump of your device's aboot.img is required to re-Loki!";
  echo " ";
  bin/$arch/loki_tool unlok "$img" "split_img/$file" >/dev/null;
  img="$file";
fi;

tailtype="$(tail "$img" 2>/dev/null | file -m bin/androidbootimg.magic - | cut -d: -f2 | cut -d" " -f2)";
case $tailtype in
  SEAndroid|Bump) echo "Footer with \"$tailtype\" type detected."; echo " "; echo $tailtype > "split_img/$file-tailtype";;
  *) ;;
esac;

echo 'Splitting image to "split_img/"...';
cd split_img;
../bin/$arch/$splitcmd "$img";
if [ ! $? -eq "0" ]; then
  cleanup;
  abort;
  exit 1;
fi;

if [ -f *-lokitype ]; then
  mv -f $file ../unlokied-original.img;
fi;

if [ "$(file -m ../bin/androidbootimg.magic *-zImage | cut -d: -f2 | awk '{ print $1 }')" = "MTK" ]; then
  mtk=1;
  echo " ";
  echo "MTK header found in zImage, removing...";
  dd bs=512 skip=1 conv=notrunc if="$file-zImage" of=tempzimg 2>/dev/null;
  mv -f tempzimg "$file-zImage";
fi;
mtktest="$(file -m ../bin/androidbootimg.magic *-ramdisk*.gz | cut -d: -f2-)";
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

if [ -f *-dtb ]; then
  dtbtest="$(file -m ../bin/androidbootimg.magic *-dtb | cut -d: -f2 | awk '{ print $1 }')";
  if [ "$imgtype" = "ELF" ]; then
    case $dtbtest in
      QCDT|ELF) ;;
      *) echo " ";
         echo "Non-QC DTB found, packing zImage and appending...";
         gzip --no-name -9 "$file-zImage";
         mv -f "$file-zImage.gz" "$file-zImage";
         cat "$file-dtb" >> "$file-zImage";
         rm -f "$file-dtb";;
    esac;
  fi;
fi;

file -m ../bin/magic *-ramdisk*.gz | cut -d: -f2 | awk '{ print $1 }' > "$file-ramdiskcomp";
ramdiskcomp=`cat *-ramdiskcomp`;
unpackcmd="$ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) compext=gz;;
  lzop) compext=lzo;;
  xz) ;;
  lzma) ;;
  bzip2) compext=bz2;;
  lz4) unpackcmd="../bin/$arch/lz4 -dcq";;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
mv "$(ls *-ramdisk*.gz)" "$file-ramdisk.cpio$compext" 2>/dev/null;
cd ..;

echo " ";
echo "Unpacking ramdisk$sumsg to \"ramdisk/\"...";
echo " ";
cd ramdisk;
echo "Compression used: $ramdiskcomp";
if [ ! "$compext" ]; then
  abort;
  exit 1;
fi;
$unpackcmd "../split_img/$file-ramdisk.cpio$compext" | $sudo cpio -i;
if [ ! $? -eq "0" ]; then
  echo "Unpacking failed, try ./unpackimg.sh --sudo";
  abort;
  exit 1;
fi;
cd ..;

echo " ";
echo "Done!";
exit 0;

