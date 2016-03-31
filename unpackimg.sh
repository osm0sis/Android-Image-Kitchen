#!/bin/sh
# AIK-Linux/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

cleanup() { $sudo$rmsu rm -rf ramdisk split_img *new.*; }
abort() { cd "$aik"; echo "Error!"; }

case $1 in
  --sudo) sudo=sudo; sumsg=" (as root)"; shift;;
esac;

aik="${BASH_SOURCE:-$0}";
aik="$(dirname "$(readlink -f "$aik")")";

cd "$aik";
chmod -R 755 bin *.sh;
chmod 644 bin/magic;

arch=`uname -m`;

img="$1";
if [ ! "$img" ]; then
  for i in *.img; do
    test "$i" = "image-new.img" && continue;
    img="$i"; break;
  done;
fi;
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
  if [ ! -z "$(ls ramdisk/* 2> /dev/null)" ] && [ "$(stat -c %U ramdisk/* | head -n 1)" = "root" ]; then
    test ! "$sudo" && rmsu=sudo; rmsumsg=" (as root)";
  fi;
  echo "Removing old work folders and files$rmsumsg...";
  echo " ";
  cleanup;
fi;

echo "Setting up work folders...";
echo " ";
mkdir split_img ramdisk;

echo 'Splitting image to "split_img/"...';
bin/$arch/unpackbootimg -i "$img" -o split_img;
if [ ! $? -eq "0" ]; then
  cleanup;
  abort;
  exit 1;
fi;

cd split_img;
file -m ../bin/magic *-ramdisk.gz | cut -d: -f2 | awk '{ print $1 }' > "$file-ramdiskcomp";
ramdiskcomp=`cat *-ramdiskcomp`;
unpackcmd="$ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) compext=gz;;
  lzop) compext=lzo;;
  xz) ;;
  lzma) ;;
  bzip2) compext=bz2;;
  lz4) unpackcmd="../bin/$arch/lz4 -dq"; extra="stdout";;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
mv "$file-ramdisk.gz" "$file-ramdisk.cpio$compext";
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
$unpackcmd "../split_img/$file-ramdisk.cpio$compext" $extra | $sudo cpio -i;
if [ ! $? -eq "0" ]; then
  abort;
  exit 1;
fi;
cd ..;

echo " ";
echo "Done!";
exit 0;

