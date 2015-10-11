#!/bin/sh
# AIK-Linux/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

cleanup() { rm -rf ramdisk split_img *new.*; }
abort() { cd "$PWD"; echo "Error!"; }

if [ ! "$1" -o ! -f "$1" ]; then
  echo "No image file supplied.";
  abort;
  exit 1;
fi;

case $1 in
  *\ *)
    echo "Filename contains spaces.";
    abort;
    exit 1;;
esac;

bin="$PWD/bin";
chmod -R 755 "$bin" "$PWD"/*.sh;
chmod 644 "$bin/magic";
cd "$PWD";

arch=`uname -m`;

clear;
echo " ";
echo "Android Image Kitchen - UnpackImg Script";
echo "by osm0sis @ xda-developers";
echo " ";

file=`basename "$1"`;
echo "Supplied image: $file";
echo " ";

if [ -d split_img -o -d ramdisk ]; then
  echo "Removing old work folders and files...";
  echo " ";
  cleanup;
fi;

echo "Setting up work folders...";
echo " ";
mkdir split_img ramdisk;

echo 'Splitting image to "split_img/"...';
$bin/$arch/unpackbootimg -i "$1" -o split_img;
if [ ! $? -eq "0" ]; then
  cleanup;
  abort;
  exit 1;
fi;

cd split_img;
file -m $bin/magic *-ramdisk.gz | cut -d: -f2 | cut -d" " -f2 > "$file-ramdiskcomp";
ramdiskcomp=`cat *-ramdiskcomp`;
unpackcmd="$ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) compext=gz;;
  lzop) compext=lzo;;
  xz) ;;
  lzma) ;;
  bzip2) compext=bz2;;
  lz4) unpackcmd="$bin/$arch/lz4 -dq"; extra="stdout";;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
mv "$file-ramdisk.gz" "$file-ramdisk.cpio$compext";
cd ..;

echo " ";
echo 'Unpacking ramdisk to "ramdisk/"...';
echo " ";
cd ramdisk;
echo "Compression used: $ramdiskcomp";
if [ ! "$compext" ]; then
  abort;
  exit 1;
fi;
$unpackcmd "../split_img/$file-ramdisk.cpio$compext" $extra | cpio -i;
if [ ! $? -eq "0" ]; then
  abort;
  exit 1;
fi;
cd ..;

echo " ";
echo "Done!";
exit 0;

