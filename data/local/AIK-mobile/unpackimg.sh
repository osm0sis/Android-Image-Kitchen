#!/system/bin/sh
# AIK-mobile/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

case $0 in
  *.sh) aik="$0";;
     *) aik="$(lsof -p $$ 2>/dev/null | grep -o '/.*unpackimg.sh$')";;
esac;
aik="$(dirname "$(readlink -f "$aik")")";

cleanup() { rm -rf ramdisk split_img *new.*; }
abort() { cd "$aik"; echo "Error!"; }

cd "$aik";
bb=bin/busybox;
chmod -R 755 bin *.sh;
chmod 644 bin/magic;

if [ ! -f $bb ]; then
  bb=busybox;
else
  rel="../";
fi;

img="$1";
if [ ! "$img" ]; then
  for i in *.img; do
    test "$i" == "image-new.img" && continue;
    img="$i"; break;
  done;
fi;
if [ ! -f "$img" ]; then
  echo "No image file supplied.";
  abort;
  return 1;
fi;

case $0 in *.sh) clear;; esac;
echo "\nAndroid Image Kitchen - UnpackImg Script";
echo "by osm0sis @ xda-developers\n";

file=$($bb basename "$img");
echo "Supplied image: $file\n";

if [ -d split_img -o -d ramdisk ]; then
  echo "Removing old work folders and files...\n";
  cleanup;
fi;

echo "Setting up work folders...\n";
mkdir split_img ramdisk;

echo 'Splitting image to "split_img/"...';
bin/unpackbootimg -i "$img" -o split_img;
if [ $? != "0" ]; then
  cleanup;
  abort;
  return 1;
fi;

cd split_img;
../bin/file -m ../bin/magic *-ramdisk.gz | $rel$bb cut -d: -f2 | $rel$bb awk '{ print $1 }' > "$file-ramdiskcomp";
ramdiskcomp=`cat *-ramdiskcomp`;
unpackcmd="$rel$bb $ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) compext=gz;;
  lzop) compext=lzo;;
  xz) ;;
  lzma) ;;
  bzip2) compext=bz2;;
  lz4) unpackcmd="../bin/lz4 -dq"; extra="stdout";;
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
$unpackcmd "../split_img/$file-ramdisk.cpio$compext" $extra | $rel$bb cpio -i 2>&1;
if [ $? != "0" ]; then
  abort;
  return 1;
fi;
cd ..;

echo "\nDone!";
return 0;

