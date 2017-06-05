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
bin="$aik/bin";
rel=bin;

cleanup() { rm -rf ramdisk split_img *new.*; }
abort() { cd "$aik"; echo "Error!"; }

cd "$aik";
bb=$bin/busybox;
chmod -R 755 $bin *.sh;
chmod 644 $bin/magic $bin/androidbootimg.magic $bin/BootSignature_Android.jar $bin/avb/* $bin/chromeos/*;

if [ ! -f $bb ]; then
  bb=busybox;
fi;

img="$1";
if [ ! "$img" ]; then
  for i in `ls *.elf *.img *.sin 2>/dev/null`; do
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

imgtest="$($bin/file -m $rel/androidbootimg.magic "$img" | $bb cut -d: -f2-)";
if [ "$(echo $imgtest | $bb awk '{ print $2 }' | $bb cut -d, -f1)" == "signing" ]; then
  echo $imgtest | $bb awk '{ print $1 }' > "split_img/$file-sigtype";
  sigtype=`cat split_img/$file-sigtype`;
  echo "Signature with \"$sigtype\" type detected, removing...\n";
  case $sigtype in
    CHROMEOS) $bin/futility vbutil_kernel --get-vmlinuz "$img" --vmlinuz-out split_img/$file;;
    BLOB)
      cd split_img;
      cp -f "$img" $file;
      $bin/blobunpack $file | $bb tail -n+5 | $bb cut -d" " -f2 | $bb dd bs=1 count=3 > $file-blobtype 2>/dev/null;
      mv -f $file.* $file;
      cd ..;
    ;;
    SIN)
      $bin/kernel_dump split_img "$img" >/dev/null;
      mv -f split_img/$file.* split_img/$file;
      rm -rf split_img/$file-sigtype;
    ;;
  esac;
  img="$aik/split_img/$file";
fi;

imgtest="$($bin/file -m $rel/androidbootimg.magic "$img" | $bb cut -d: -f2-)";
if [ "$(echo $imgtest | $bb awk '{ print $2 }' | $bb cut -d, -f1)" == "bootimg" ]; then
  test "$(echo $imgtest | $bb awk '{ print $3 }')" == "PXA" && typesuffix=-PXA;
  echo "$(echo $imgtest | $bb awk '{ print $1 }')$typesuffix" > "split_img/$file-imgtype";
  imgtype=`cat split_img/$file-imgtype`;
else
  cleanup;
  echo "Unrecognized format.";
  abort;
  return 1;
fi;
echo "Image type: $imgtype\n";

case $imgtype in
  AOSP*|ELF|U-Boot) ;;
  *)
    cleanup;
    echo "Unsupported format.";
    abort;
    return 1;
  ;;
esac;

if [ "$(echo $imgtest | $bb awk '{ print $3 }')" == "LOKI" ]; then
  echo $imgtest | $bb awk '{ print $5 }' | $bb cut -d\( -f2 | $bb cut -d\) -f1 > "split_img/$file-lokitype";
  lokitype=`cat split_img/$file-lokitype`;
  echo "Loki patch with \"$lokitype\" type detected, reverting...\n";
  echo "Warning: A dump of your device's aboot.img is required to re-Loki!\n";
  $bin/loki_tool unlok "$img" "split_img/$file" >/dev/null;
  img="$file";
fi;

tailtest="$(cat "$img" | $bb tail 2>/dev/null | $bin/file -m $rel/androidbootimg.magic - | $bb cut -d: -f2-)";
tailtype="$(echo $tailtest | $bb awk '{ print $1 }')";
case $tailtype in
  AVB)
    echo "Signature with \"$tailtype\" type detected.\n";
    echo $tailtype > "split_img/$file-sigtype";
    echo $tailtest | $bb awk '{ print $4 }' > "split_img/$file-avbtype";
  ;;
  SEAndroid|Bump)
    echo "Footer with \"$tailtype\" type detected.\n";
    echo $tailtype > "split_img/$file-tailtype";
  ;;
esac;

echo 'Splitting image to "split_img/"...';
cd split_img;
case $imgtype in
  AOSP) $bin/unpackbootimg -i "$img";;
  AOSP-PXA) $bin/pxa1088-unpackbootimg -i "$img";;
  ELF) $bin/unpackelf -i "$img";;
  U-Boot)
    $bin/dumpimage -l "$img";
    $bin/dumpimage -l "$img" > "$file-header";
    $bb grep "Name:" "$file-header" | $bb cut -c15- > "$file-name";
    $bb grep "Type:" "$file-header" | $bb cut -c15- | $bb cut -d" " -f1 > "$file-arch";
    $bb grep "Type:" "$file-header" | $bb cut -c15- | $bb cut -d" " -f2 > "$file-os";
    $bb grep "Type:" "$file-header" | $bb cut -c15- | $bb cut -d" " -f3 | $bb cut -d- -f1 > "$file-type";
    $bb grep "Type:" "$file-header" | $bb cut -d\( -f2 | $bb cut -d\) -f1 | $bb cut -d" " -f1 | $bb cut -d- -f1 > "$file-comp";
    $bb grep "Address:" "$file-header" | $bb cut -c15- > "$file-addr";
    $bb grep "Point:" "$file-header" | $bb cut -c15- > "$file-ep";
    rm -rf "$file-header";
    $bin/dumpimage -i "$img" -p 0 "$file-zImage";
    if [ $? != "0" ]; then
      cleanup;
      abort;
      return 1;
    fi;
    if [ "$(cat $file-type)" != "Multi" ]; then
      echo "\nNo ramdisk found.";
      cleanup;
      abort;
      return 1;
    fi;
    $bin/dumpimage -i "$img" -p 1 "$file-ramdisk.cpio.gz";
  ;;
esac;
if [ $? != "0" ]; then
  cleanup;
  abort;
  return 1;
fi;

if [ "$($bin/file -m ../$rel/androidbootimg.magic *-zImage | $bb cut -d: -f2 | $bb awk '{ print $1 }')" == "MTK" ]; then
  mtk=1;
  echo "\nMTK header found in zImage, removing...";
  $bb dd bs=512 skip=1 conv=notrunc if="$file-zImage" of=tempzimg 2>/dev/null;
  mv -f tempzimg "$file-zImage";
fi;
mtktest="$($bin/file -m ../$rel/androidbootimg.magic *-ramdisk*.gz | $bb cut -d: -f2-)";
mtktype=$(echo $mtktest | $bb awk '{ print $3 }');
if [ "$(echo $mtktest | $bb awk '{ print $1 }')" == "MTK" ]; then
  if [ ! "$mtk" ]; then
    echo "\nWarning: No MTK header found in zImage!";
    mtk=1;
  fi;
  echo "MTK header found in \"$mtktype\" type ramdisk, removing...";
  $bb dd bs=512 skip=1 conv=notrunc if="$(ls *-ramdisk*.gz)" of=temprd 2>/dev/null;
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
  dtbtest="$($bin/file -m ../$rel/androidbootimg.magic *-dtb | $bb cut -d: -f2 | $bb awk '{ print $1 }')";
  if [ "$imgtype" == "ELF" ]; then
    case $dtbtest in
      QCDT|ELF) ;;
      *) echo "\nNon-QC DTB found, packing zImage and appending...";
         $bb gzip "$file-zImage";
         mv -f "$file-zImage.gz" "$file-zImage";
         cat "$file-dtb" >> "$file-zImage";
         rm -f "$file-dtb";;
    esac;
  fi;
fi;

$bin/file -m ../$rel/magic *-ramdisk*.gz | $bb cut -d: -f2 | $bb awk '{ print $1 }' > "$file-ramdiskcomp";
ramdiskcomp=`cat *-ramdiskcomp`;
unpackcmd="$bb $ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) compext=gz;;
  lzop) compext=lzo;;
  xz) unpackcmd="$bin/xz -dc";;
  lzma) unpackcmd="$bin/xz -dc";;
  bzip2) compext=bz2;;
  lz4) unpackcmd="$bin/lz4 -dcq";;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
mv -f "$(ls *-ramdisk*.gz)" "$file-ramdisk.cpio$compext" 2>/dev/null;
cd ..;
if [ "$ramdiskcomp" == "data" ]; then
  echo "Unrecognized format.";
  abort;
  return 1;
fi;

echo '\nUnpacking ramdisk to "ramdisk/"...\n';
cd ramdisk;
echo "Compression used: $ramdiskcomp";
if [ ! "$compext" ]; then
  echo "Unsupported format.";
  abort;
  return 1;
fi;
$unpackcmd "../split_img/$file-ramdisk.cpio$compext" | $bb cpio -i 2>&1;
if [ $? != "0" ]; then
  abort;
  return 1;
fi;
cd ..;

echo "\nDone!";
return 0;

