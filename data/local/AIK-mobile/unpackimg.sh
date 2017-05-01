#!/system/bin/sh
# AIK-mobile/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

case $1 in
  --help) echo "usage: unpackimg.sh <file>"; return 1;
esac;

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
chmod 644 bin/magic bin/androidbootimg.magic bin/chromeos/*;

if [ ! -f $bb ]; then
  bb=busybox;
else
  rel="../";
fi;

img="$1";
if [ ! "$img" ]; then
  for i in `ls *.elf *.img 2>/dev/null`; do
    case $i in
      aboot.img|image-new.img|unlokied-new.img|unsigned-new.img) continue;;
    esac;
    img="$i"; break;
  done;
fi;
img="$(readlink -f "$img")";
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

imgtest="$(bin/file -m bin/androidbootimg.magic "$img" | $bb cut -d: -f2-)";
if [ "$(echo $imgtest | $bb awk '{ print $2 }' | $bb cut -d, -f1)" == "signing" ]; then
  echo $imgtest | $bb awk '{ print $1 }' > "split_img/$file-sigtype";
  sigtype=`cat split_img/$file-sigtype`;
  echo "Signature with \"$sigtype\" type detected, removing...\n";
  case $sigtype in
    CHROMEOS) bin/futility vbutil_kernel --get-vmlinuz "$img" --vmlinuz-out split_img/$file;;
    BLOB)
      cd split_img;
      cp -f "$img" $file;
      ../bin/blobunpack $file | $rel$bb tail -n+5 | $rel$bb cut -d" " -f2 | $rel$bb dd bs=1 count=3 > $file-blobtype 2>/dev/null;
      mv $file.* $file;
      cd ..;
    ;;
  esac;
  img="$aik/split_img/$file";
fi;

imgtest="$(bin/file -m bin/androidbootimg.magic "$img" | $bb cut -d: -f2-)";
if [ "$(echo $imgtest | $bb awk '{ print $2 }' | $bb cut -d, -f1)" == "bootimg" ]; then
  echo $imgtest | $bb awk '{ print $1 }' > "split_img/$file-imgtype";
  imgtype=`cat split_img/$file-imgtype`;
else
  cleanup;
  echo "Unrecognized format.";
  abort;
  return 1;
fi;
echo "Image type: $imgtype\n";

case $imgtype in
  AOSP) splitcmd="unpackbootimg -i";;
  ELF) splitcmd="unpackelf -i";;
esac;
if [ ! "$splitcmd" ]; then
  cleanup;
  echo "Unsupported format.";
  abort;
  return 1;
fi;

if [ "$(echo $imgtest | $bb awk '{ print $3 }')" == "LOKI" ]; then
  echo $imgtest | $bb awk '{ print $5 }' | $bb cut -d\( -f2 | $bb cut -d\) -f1 > "split_img/$file-lokitype";
  lokitype=`cat split_img/$file-lokitype`;
  echo "Loki patch with \"$lokitype\" type detected, reverting...\n";
  echo "Warning: A dump of your device's aboot.img is required to re-Loki!\n";
  bin/loki_tool unlok "$img" "split_img/$file" >/dev/null;
  img="$file";
fi;

tailtype="$(cat "$img" | $bb tail 2>/dev/null | bin/file -m bin/androidbootimg.magic - | $bb cut -d: -f2 | $bb cut -d" " -f2)";
case $tailtype in
  SEAndroid|Bump) echo "Footer with \"$tailtype\" type detected.\n"; echo $tailtype > "split_img/$file-tailtype";;
  *) ;;
esac;

echo 'Splitting image to "split_img/"...';
cd split_img;
../bin/$splitcmd "$img";
if [ $? != "0" ]; then
  cleanup;
  abort;
  return 1;
fi;

if [ "$(../bin/file -m ../bin/androidbootimg.magic *-zImage | $rel$bb cut -d: -f2 | $rel$bb awk '{ print $1 }')" == "MTK" ]; then
  mtk=1;
  echo "\nMTK header found in zImage, removing...";
  $rel$bb dd bs=512 skip=1 conv=notrunc if="$file-zImage" of=tempzimg 2>/dev/null;
  mv -f tempzimg "$file-zImage";
fi;
mtktest="$(../bin/file -m ../bin/androidbootimg.magic *-ramdisk*.gz | $rel$bb cut -d: -f2-)";
mtktype=$(echo $mtktest | $rel$bb awk '{ print $3 }');
if [ "$(echo $mtktest | $rel$bb awk '{ print $1 }')" == "MTK" ]; then
  if [ ! "$mtk" ]; then
    echo "\nWarning: No MTK header found in zImage!";
    mtk=1;
  fi;
  echo "MTK header found in \"$mtktype\" type ramdisk, removing...";
  $rel$bb dd bs=512 skip=1 conv=notrunc if="$(ls *-ramdisk*.gz)" of=temprd 2>/dev/null;
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
  dtbtest="$(../bin/file -m ../bin/androidbootimg.magic *-dtb | $rel$bb cut -d: -f2 | $rel$bb awk '{ print $1 }')";
  if [ "$imgtype" == "ELF" ]; then
    case $dtbtest in
      QCDT|ELF) ;;
      *) echo "\nNon-QC DTB found, packing zImage and appending...";
         $rel$bb gzip "$file-zImage";
         mv -f "$file-zImage.gz" "$file-zImage";
         cat "$file-dtb" >> "$file-zImage";
         rm -f "$file-dtb";;
    esac;
  fi;
fi;

../bin/file -m ../bin/magic *-ramdisk*.gz | $rel$bb cut -d: -f2 | $rel$bb awk '{ print $1 }' > "$file-ramdiskcomp";
ramdiskcomp=`cat *-ramdiskcomp`;
unpackcmd="$rel$bb $ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) compext=gz;;
  lzop) compext=lzo;;
  xz) ;;
  lzma) ;;
  bzip2) compext=bz2;;
  lz4) unpackcmd="../bin/lz4 -dcq";;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
mv "$(ls *-ramdisk*.gz)" "$file-ramdisk.cpio$compext" 2>/dev/null;
cd ..;

echo '\nUnpacking ramdisk to "ramdisk/"...\n';
cd ramdisk;
echo "Compression used: $ramdiskcomp";
if [ ! "$compext" ]; then
  abort;
  return 1;
fi;
$unpackcmd "../split_img/$file-ramdisk.cpio$compext" | $rel$bb cpio -i 2>&1;
if [ $? != "0" ]; then
  abort;
  return 1;
fi;
cd ..;

echo "\nDone!";
return 0;

