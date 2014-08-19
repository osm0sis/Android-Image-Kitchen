#!/bin/sh
# AIK-Linux/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

cleanup() { rm -rf ramdisk split_img *new.*; }
abort() { cd "$PWD"; echo "Error!"; }

if [ ! "$1" -o ! -f "$1" ]; then
  echo "No image file supplied.";
  abort;
  return 1;
fi;

case $1 in
  *\ *)
    echo "Filename contains spaces.";
    abort;
    return 1;;
esac;

bin="$PWD/bin";
chmod -R 755 "$bin" "$PWD"/*.sh;
chmod 644 "$bin/magic";
cd "$PWD";

clear;
echo "\nAndroid Image Kitchen - UnpackImg Script";
echo "by osm0sis @ xda-developers\n";

file=`basename "$1"`;
echo "Supplied image: $file\n";

if [ -d split_img -o -d ramdisk ]; then
  echo "Removing old work folders and files...\n";
  cleanup;
fi;

echo "Setting up work folders...\n";
mkdir split_img ramdisk;

echo 'Splitting image to "split_img/"...\n'
$bin/unpackbootimg -i "$1" -o split_img;
if [ $? -eq "1" ]; then
  cleanup;
  abort;
  return 1;
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
  lz4) unpackcmd="$bin/lz4 -dq"; extra="stdout";;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
mv "$file-ramdisk.gz" "$file-ramdisk.cpio$compext";
cd ..;

echo '\nUnpacking ramdisk to "ramdisk/"...\n';
cd ramdisk;
echo "Compression used: $ramdiskcomp";
if [ ! "$compext" ]; then
  abort;
  return 1;
fi;
$unpackcmd "../split_img/$file-ramdisk.cpio$compext" $extra | cpio -i;
if [ $? -eq "1" ]; then
  abort;
  return 1;
fi;
cd ..;

echo "\nDone!";
return 0;

