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
cur="$(readlink -f "$PWD")";

cleanup() { $aik/cleanup.sh --quiet; }
abort() { cd $aik; echo "Error!"; }

cd $aik;
bb=$bin/busybox;
chmod -R 755 $bin *.sh;
chmod 644 $bin/magic $bin/androidbootimg.magic $bin/boot_signer-dexed.jar $bin/module.prop $bin/ramdisk.img $bin/avb/* $bin/chromeos/*;

[ ! -f $bb ] && bb=busybox;

img="$1";
[ -f "$cur/$1" ] && img="$cur/$1";
if [ ! "$img" ]; then
  $bb ls *.elf *.img *.sin 2>/dev/null |& while IFS= read -r -p line; do
    case $line in
      aboot.img|image-new.img|unlokied-new.img|unsigned-new.img) continue;;
    esac;
    img="$line";
    break;
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
chmod 755 split_img ramdisk;
echo "run remount.sh to remount the current image's unpacked ramdisk" > ramdisk/README;
chmod 666 ramdisk/README;
cp -fp $bin/remount.sh ramdisk/remount.sh;
cp -f $bin/ramdisk.img split_img/.aik-ramdisk.img;

$bin/remount.sh --mount-only || return 1;

cd split_img;
filesize=$($bb wc -c < "$img");
echo "$filesize" > "$file-origsize";
imgtest="$($bin/file -m $bin/androidbootimg.magic "$img" 2>/dev/null | $bb cut -d: -f2-)";
if [ "$(echo $imgtest | $bb awk '{ print $2 }' | $bb cut -d, -f1)" == "signing" ]; then
  echo $imgtest | $bb awk '{ print $1 }' > "$file-sigtype";
  sigtype=$(cat "$file-sigtype");
  echo "Signature with \"$sigtype\" type detected, removing...\n";
  case $sigtype in
    BLOB)
      $bb cp -f "$img" "$file";
      $bin/blobunpack "$file" | $bb tail -n+5 | $bb cut -d" " -f2 | $bb dd bs=1 count=3 > "$file-blobtype" 2>/dev/null;
      $bb mv -f "$file."* "$file";
    ;;
    CHROMEOS) $bin/futility vbutil_kernel --get-vmlinuz "$img" --vmlinuz-out "$file";;
    DHTB) $bb dd bs=4096 skip=512 iflag=skip_bytes conv=notrunc if="$img" of="$file" 2>/dev/null;;
    NOOK)
      $bb dd bs=1048576 count=1 conv=notrunc if="$img" of="$file-master_boot.key" 2>/dev/null;
      $bb dd bs=1048576 skip=1 conv=notrunc if="$img" of="$file" 2>/dev/null;
    ;;
    NOOKTAB)
      $bb dd bs=262144 count=1 conv=notrunc if="$img" of="$file-master_boot.key" 2>/dev/null;
      $bb dd bs=262144 skip=1 conv=notrunc if="$img" of="$file" 2>/dev/null;
    ;;
    SIN*)
      $bin/sony_dump . "$img" >/dev/null;
      $bb mv -f "$file."* "$file";
      rm -f "$file-sigtype";
    ;;
  esac;
  img="$file";
fi;

imgtest="$($bin/file -m $bin/androidbootimg.magic "$img" 2>/dev/null | $bb cut -d: -f2-)";
if [ "$(echo $imgtest | $bb awk '{ print $2 }' | $bb cut -d, -f1)" == "bootimg" ]; then
  [ "$(echo $imgtest | $bb awk '{ print $3 }')" == "PXA" ] && typesuffix=-PXA;
  echo "$(echo $imgtest | $bb awk '{ print $1 }')$typesuffix" > "$file-imgtype";
  imgtype=$(cat "$file-imgtype");
else
  cd ..;
  cleanup;
  echo "Unrecognized format.";
  abort;
  return 1;
fi;
echo "Image type: $imgtype\n";

case $imgtype in
  AOSP*|ELF|KRNL|OSIP|U-Boot) ;;
  *)
    cd ..;
    cleanup;
    echo "Unsupported format.";
    abort;
    return 1;
  ;;
esac;

case $(echo $imgtest | $bb awk '{ print $3 }') in
  LOKI)
    echo $imgtest | $bb awk '{ print $5 }' | $bb cut -d\( -f2 | $bb cut -d\) -f1 > "$file-lokitype";
    lokitype=$(cat "$file-lokitype");
    echo "Loki patch with \"$lokitype\" type detected, reverting...\n";
    echo "Warning: A dump of your device's aboot.img is required to re-Loki!\n";
    $bin/loki_tool unlok "$img" "$file" >/dev/null;
    img="$file";
  ;;
  AMONET)
    echo "Amonet patch detected, reverting...\n";
    $bb dd bs=2048 count=1 conv=notrunc if="$img" of="$file-microloader.bin" 2>/dev/null;
    $bb dd bs=1024 skip=1 conv=notrunc if="$file-microloader.bin" of="$file-head" 2>/dev/null;
    $bb truncate -s 1024 "$file-microloader.bin";
    $bb truncate -s 2048 "$file-head";
    $bb dd bs=2048 skip=1 conv=notrunc if="$img" of="$file-tail" 2>/dev/null;
    cat "$file-head" "$file-tail" > "$file";
    rm -f "$file-head" "$file-tail";
    img="$file";
  ;;
esac;

tailtest="$($bb dd if="$img" iflag=skip_bytes skip=$(($(wc -c < "$img") - 8192)) bs=8192 count=1 2>/dev/null | $bin/file -m $bin/androidbootimg.magic - 2>/dev/null | $bb cut -d: -f2-)";
case $tailtest in
  *data)
    trim=$($bb od -Ad -tx8 "$img" | $bb tail -n3 | $bb sed 's/*/-/g');
    if [ "$(echo $trim | $bb awk '{ print $(NF-3) $(NF-2) $(NF-1) }')" == "00000000000000000000000000000000-" ]; then
      offset=$(echo $trim | $bb awk '{ print $(NF-4) }');
    else
      offset=$(echo $trim | $bb awk '{ print $NF }');
    fi;
    tailtest="$($bb dd if="$img" iflag=skip_bytes skip=$((offset - 8192)) bs=8192 count=1 2>/dev/null | $bin/file -m $bin/androidbootimg.magic - 2>/dev/null | $bb cut -d: -f2-)";
  ;;
esac;
tailtype="$(echo $tailtest | $bb awk '{ print $1 }')";
case $tailtype in
  AVB*)
    echo "Signature with \"$tailtype\" type detected.\n";
    case $tailtype in
      *v1)
        echo $tailtype > "$file-sigtype";
        echo $tailtest | $bb awk '{ print $4 }' > "$file-avbtype";
      ;;
    esac;
  ;;
  Bump|SEAndroid)
    echo "Footer with \"$tailtype\" type detected.\n";
    echo $tailtype > "$file-tailtype";
  ;;
esac;

if [ "$imgtype" == "U-Boot" ]; then
  imgsize=$(($($bb printf '%d\n' 0x$($bb hexdump -n 4 -s 12 -e '16/1 "%02x""\n"' "$img")) + 64));
  if [ "$filesize" != "$imgsize" ]; then
    echo "Trimming...\n";
    $bb dd bs=$imgsize count=1 conv=notrunc if="$img" of="$file" 2>/dev/null;
    img="$file";
  fi;
fi;

echo 'Splitting image to "split_img/"...';
case $imgtype in
  AOSP_VNDR) vendor=vendor_;;
esac;
case $imgtype in
  AOSP|AOSP_VNDR) $bin/unpackbootimg -i "$img";;
  AOSP-PXA) $bin/pxa-unpackbootimg -i "$img";;
  ELF)
    mkdir elftool_out;
    $bin/elftool unpack -i "$img" -o elftool_out >/dev/null;
    $bb mv -f elftool_out/header "$file-header" 2>/dev/null;
    rm -rf elftool_out;
    $bin/unpackelf -i "$img";
  ;;
  KRNL) $bb dd bs=4096 skip=8 iflag=skip_bytes conv=notrunc if="$img" of="$file-ramdisk" 2>&1 | $bb tail -n+3 | $bb cut -d" " -f1-2;;
  OSIP)
    $bin/mboot -u -f "$img";
    [ $? != 0 ] && error=1;
    for i in bootstub cmdline.txt hdr kernel parameter ramdisk.cpio.gz sig; do
      $bb mv -f $i "$file-$($bb basename $i .txt | $bb sed -e 's/hdr/header/' -e 's/ramdisk.cpio.gz/ramdisk/')" 2>/dev/null || true;
    done;
  ;;
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
    rm -f "$file-header";
    $bin/dumpimage -p 0 -o "$file-kernel" "$img";
    [ $? != 0 ] && error=1;
    case $(cat "$file-type") in
      Multi) $bin/dumpimage -p 1 -o "$file-ramdisk" "$img";;
      RAMDisk) $bb mv -f "$file-kernel" "$file-ramdisk";;
      *) touch "$file-ramdisk";;
    esac;
  ;;
esac;
if [ $? != 0 -o "$error" ]; then
  cd ..;
  cleanup;
  abort;
  return 1;
fi;

if [ -f *-kernel ] && [ "$($bin/file -m $bin/androidbootimg.magic *-kernel 2>/dev/null | $bb cut -d: -f2 | $bb awk '{ print $1 }')" == "MTK" ]; then
  mtk=1;
  echo "\nMTK header found in kernel, removing...";
  $bb dd bs=512 skip=1 conv=notrunc if="$file-kernel" of=tempkern 2>/dev/null;
  $bb mv -f tempkern "$file-kernel";
fi;
mtktest="$($bin/file -m $bin/androidbootimg.magic *-*ramdisk 2>/dev/null | $bb cut -d: -f2-)";
mtktype=$(echo $mtktest | $bb awk '{ print $3 }');
if [ "$(echo $mtktest | $bb awk '{ print $1 }')" == "MTK" ]; then
  if [ ! "$mtk" ]; then
    echo "\nWarning: No MTK header found in kernel!";
    mtk=1;
  fi;
  echo "MTK header found in \"$mtktype\" type ramdisk, removing...";
  $bb dd bs=512 skip=1 conv=notrunc if="$(ls *-*ramdisk)" of=temprd 2>/dev/null;
  $bb mv -f temprd "$(ls *-*ramdisk)";
else
  if [ "$mtk" ]; then
    if [ ! "$mtktype" ]; then
      echo 'Warning: No MTK header found in ramdisk, assuming "rootfs" type!';
      mtktype="rootfs";
    fi;
  fi;
fi;
[ "$mtk" ] && echo $mtktype > "$file-mtktype";

if [ -f *-dt ]; then
  dttest="$($bin/file -m $bin/androidbootimg.magic *-dt 2>/dev/null | $bb cut -d: -f2 | $bb awk '{ print $1 }')";
  echo $dttest > "$file-dttype";
  if [ "$imgtype" == "ELF" ]; then
    case $dttest in
      QCDT|ELF) ;;
      *) echo "\nNon-QC DTB found, packing kernel and appending...";
         $bb gzip "$file-kernel";
         $bb mv -f "$file-kernel.gz" "$file-kernel";
         cat "$file-dt" >> "$file-kernel";
         rm -f "$file-dt"*;;
    esac;
  fi;
fi;

$bin/file -m $bin/magic *-*ramdisk 2>/dev/null | $bb cut -d: -f2 | $bb awk '{ print $1 }' > "$file-${vendor}ramdiskcomp";
ramdiskcomp=`cat *-*ramdiskcomp`;
unpackcmd="$bb $ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) compext=gz;;
  lzop) compext=lzo;;
  xz) unpackcmd="$bin/xz -dc";;
  lzma) unpackcmd="$bin/xz -dc";;
  bzip2) compext=bz2;;
  lz4) unpackcmd="$bin/lz4 -dcq";;
  lz4-l) unpackcmd="$bin/lz4 -dcq"; compext=lz4;;
  cpio) unpackcmd="cat"; compext="";;
  empty) compext=empty;;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
$bb mv -f "$(ls *-*ramdisk)" "$file-${vendor}ramdisk.cpio$compext" 2>/dev/null;
cd ..;
if [ "$ramdiskcomp" == "data" ]; then
  echo "Unrecognized format.";
  abort;
  return 1;
fi;

if [ "$ramdiskcomp" == "empty" ]; then
  echo "\nWarning: No ramdisk found to be unpacked!";
else
  echo '\nUnpacking ramdisk to "ramdisk/"...\n';
  echo "Compression used: $ramdiskcomp";
  if [ ! "$compext" -a ! "$ramdiskcomp" == "cpio" ]; then
    echo "Unsupported format.";
    abort;
    return 1;
  fi;
  cd ramdisk;
  $unpackcmd "../split_img/$file-${vendor}ramdisk.cpio$compext" | EXTRACT_UNSAFE_SYMLINKS=1 $bb cpio -i -d 2>&1;
  if [ $? != 0 ]; then
    cd ..;
    abort;
    return 1;
  fi;
  cd ..;
fi;

echo "\nDone!";
return 0;

