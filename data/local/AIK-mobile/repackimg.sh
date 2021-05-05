#!/system/bin/sh
# AIK-mobile/repackimg: repack ramdisk and build image
# osm0sis @ xda-developers

case $1 in
  --help) echo "usage: repackimg.sh [--original] [--origsize] [--level <0-9>] [--avbkey <name>] [--forceelf]"; return 1;
esac;

case $0 in
  *.sh) aik="$0";;
     *) aik="$(lsof -p $$ 2>/dev/null | grep -o '/.*repackimg.sh$')";;
esac;
aik="$(dirname "$(readlink -f "$aik")")";
bin="$aik/bin";
cur="$(readlink -f "$PWD")";

abort() { cd $aik; echo "Error!"; }

cd $aik;
bb=$bin/busybox;
chmod -R 755 $bin $aik/*.sh;
chmod 644 $bin/magic $bin/androidbootimg.magic $bin/boot_signer-dexed.jar $bin/module.prop $bin/ramdisk.img $bin/avb/* $bin/chromeos/*;

[ ! -f $bb ] && bb=busybox;

if [ -z "$(ls split_img/* 2>/dev/null)" -o ! -e ramdisk ]; then
  echo "No files found to be packed/built.";
  abort;
  return 1;
fi;

$bin/remount.sh --mount-only || return 1;

while [ "$1" ]; do
  case $1 in
    --original) original=1;;
    --origsize) origsize=1;;
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
          if [ -f "$keytest.pk8" -a -f "$keytest.x509."* ]; then
            avbkey="$keytest"; avbtxt=" - Key: $2"; shift; break;
          fi;
        done;
      fi;
    ;;
  esac;
  shift;
done;

ramdiskcomp=`cat split_img/*-*ramdiskcomp`;
if [ -z "$(ls ramdisk/* 2>/dev/null)" ] && [ ! "$ramdiskcomp" == "empty" -a ! "$original" ]; then
  echo "No files found to be packed/built.";
  abort;
  return 1;
fi;

case $0 in *.sh) clear;; esac;
echo "\nAndroid Image Kitchen - RepackImg Script";
echo "by osm0sis @ xda-developers\n";

if [ ! -z "$(ls *-new.* 2>/dev/null)" ]; then
  echo "Warning: Overwriting existing files!\n";
fi;
rm -f *-new.*;

if [ "$original" ]; then
  echo "Repacking with original ramdisk...";
elif [ "$ramdiskcomp" == "empty" ]; then
  echo "Warning: Using empty ramdisk for repack!";
  compext=.empty;
  touch ramdisk-new.cpio$compext;
else
  echo "Packing ramdisk...\n";
  if [ ! "$level" ]; then
    case $ramdiskcomp in
      xz) level=-1;;
      lz4*) level=-9;;
    esac;
  fi;
  echo "Using compression: $ramdiskcomp$lvltxt";
  repackcmd="$bb $ramdiskcomp $level";
  compext=$ramdiskcomp;
  case $ramdiskcomp in
    gzip) compext=gz;;
    lzop) compext=lzo;;
    xz) repackcmd="$bin/xz $level -Ccrc32";;
    lzma) repackcmd="$bin/xz $level -Flzma";;
    bzip2) compext=bz2;;
    lz4) repackcmd="$bin/lz4 $level";;
    lz4-l) repackcmd="$bin/lz4 $level -l"; compext=lz4;;
    cpio) repackcmd="cat"; compext="";;
    *) abort; exit 1;;
  esac;
  if [ "$compext" ]; then
    compext=.$compext;
  fi;
  cd ramdisk;
  $bb find . | $bb cpio -H newc -o 2>/dev/null | $repackcmd > ../ramdisk-new.cpio$compext;
  if [ $? != 0 ]; then
    abort;
    return 1;
  fi;
  cd ..;
fi;

echo "\nGetting build information...";
cd split_img;
imgtype=`cat *-imgtype`;
case $imgtype in
  KRNL) ;;
  AOSP_VDNR) vendor=vendor_;;
  *)
    if [ -f *-kernel ]; then
      kernel=`ls *-kernel`;               echo "kernel = $kernel";
      kernel="split_img/$kernel";
    fi;
  ;;
esac;
if [ "$original" ]; then
  ramdisk=`ls *-*ramdisk.cpio*`;          echo "${vendor}ramdisk = $ramdisk";
  ramdisk="split_img/$ramdisk";
else
  ramdisk="ramdisk-new.cpio$compext";
fi;
case $imgtype in
  KRNL) rsz=$($bb wc -c < ../"$ramdisk"); echo "ramdisk_size = $rsz";;
  OSIP)                                   echo "cmdline = $(cat *-*cmdline)";;
  U-Boot)
    name=`cat *-name`;                    echo "name = $name";
    arch=`cat *-arch`;
    os=`cat *-os`;
    type=`cat *-type`;
    comp=`cat *-comp`;                    echo "type = $arch $os $type ($comp)";
    [ "$comp" == "uncompressed" ] && comp=none;
    addr=`cat *-addr`;                    echo "load_addr = $addr";
    ep=`cat *-ep`;                        echo "entry_point = $ep";
  ;;
  *)
    if [ -f *-second ]; then
      second=`ls *-second`;               echo "second = $second";
      second=(--second "split_img/$second");
    fi;
    if [ -f *-dtb ]; then
      dtb=`ls *-dtb`;                     echo "dtb = $dtb";
      dtb=(--dtb "split_img/$dtb");
    fi;
    if [ -f *-recovery_dtbo ]; then
      recoverydtbo=`ls *-recovery_dtbo`;  echo "recovery_dtbo = $recoverydtbo";
      recoverydtbo=(--recovery_dtbo "split_img/$recoverydtbo");
    fi;
    if [ -f *-cmdline ]; then
      cmdname=`ls *-*cmdline`;
      cmdline=`cat *-*cmdline`;           echo "${vendor}cmdline = $cmdline";
      cmd=("split_img/$cmdname"@cmdline);
    fi;
    if [ -f *-board ]; then
      board=`cat *-board`;                echo "board = $board";
    fi;
    if [ -f *-base ]; then
      base=`cat *-base`;                  echo "base = $base";
    fi;
    if [ -f *-pagesize ]; then
      pagesize=`cat *-pagesize`;          echo "pagesize = $pagesize";
    fi;
    if [ -f *-kernel_offset ]; then
      kerneloff=`cat *-kernel_offset`;    echo "kernel_offset = $kerneloff";
    fi;
    if [ -f *-ramdisk_offset ]; then
      ramdiskoff=`cat *-ramdisk_offset`;  echo "ramdisk_offset = $ramdiskoff";
    fi;
    if [ -f *-second_offset ]; then
      secondoff=`cat *-second_offset`;    echo "second_offset = $secondoff";
    fi;
    if [ -f *-tags_offset ]; then
      tagsoff=`cat *-tags_offset`;        echo "tags_offset = $tagsoff";
    fi;
    if [ -f *-dtb_offset ]; then
      dtboff=`cat *-dtb_offset`;          echo "dtb_offset = $dtboff";
    fi;
    if [ -f *-os_version ]; then
      osver=`cat *-os_version`;           echo "os_version = $osver";
    fi;
    if [ -f *-os_patch_level ]; then
      oslvl=`cat *-os_patch_level`;       echo "os_patch_level = $oslvl";
    fi;
    if [ -f *-header_version ]; then
      hdrver=`cat *-header_version`;      echo "header_version = $hdrver";
    fi;
    if [ -f *-hashtype ]; then
      hashtype=`cat *-hashtype`;          echo "hashtype = $hashtype";
      hashtype="--hashtype $hashtype";
    fi;
    if [ -f *-dt ]; then
      dttype=`cat *-dttype`;
      dt=`ls *-dt`;                       echo "dt = $dt";
      rpm=("split_img/$dt",rpm);
      dt=(--dt "split_img/$dt");
    fi;
    if [ -f *-unknown ]; then
      unknown=`cat *-unknown`;            echo "unknown = $unknown";
    fi;
    if [ -f *-header ]; then
      header=`ls *-header`;
      header="split_img/$header";
    fi;
  ;;
esac;
cd ..;

if [ -f split_img/*-mtktype ]; then
  mtktype=`cat split_img/*-mtktype`;
  echo "\nGenerating MTK headers...\n";
  echo "Using ramdisk type: $mtktype";
  $bin/mkmtkhdr --kernel "$kernel" --$mtktype "$ramdisk" >/dev/null;
  if [ $? != 0 ]; then
    abort;
    return 1;
  fi;
  $bb mv -f "$($bb basename "$kernel")-mtk" kernel-new.mtk;
  $bb mv -f "$($bb basename "$ramdisk")-mtk" $mtktype-new.mtk;
  kernel=kernel-new.mtk;
  ramdisk=$mtktype-new.mtk;
fi;

if [ -f split_img/*-sigtype ]; then
  outname=unsigned-new.img;
else
  outname=image-new.img;
fi;

[ "$dttype" == "ELF" ] && repackelf=1;
if [ "$imgtype" == "ELF" ] && [ ! "$header" -o ! "$repackelf" ]; then
  imgtype=AOSP;
  echo "\nWarning: ELF format without RPM detected; will be repacked using AOSP format!";
fi;

echo "\nBuilding image...\n";
echo "Using format: $imgtype\n";
case $imgtype in
  AOSP_VNDR) $bin/mkbootimg --vendor_ramdisk "$ramdisk" "${dtb[@]}" --vendor_cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff --tags_offset $tagsoff --dtb_offset $dtboff --os_version "$osver" --os_patch_level "$oslvl" --header_version $hdrver --vendor_boot $outname;;
  AOSP) $bin/mkbootimg --kernel "$kernel" --ramdisk "$ramdisk" "${second[@]}" "${dtb[@]}" "${recoverydtbo[@]}" --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff --second_offset "$secondoff" --tags_offset "$tagsoff" --dtb_offset "$dtboff" --os_version "$osver" --os_patch_level "$oslvl" --header_version "$hdrver" $hashtype "${dt[@]}" -o $outname;;
  AOSP-PXA) $bin/pxa-mkbootimg --kernel "$kernel" --ramdisk "$ramdisk" "${second[@]}" --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff --second_offset "$secondoff" --tags_offset "$tagsoff" --unknown $unknown "${dt[@]}" -o $outname;;
  ELF) $bin/elftool pack -o $outname header="$header" "$kernel" "$ramdisk",ramdisk "${rpm[@]}" "${cmd[@]}" >/dev/null;;
  KRNL) $bin/rkcrc -k "$ramdisk" $outname;;
  OSIP)
    mkdir split_img/.temp 2>/dev/null;
    for i in bootstub cmdline.txt hdr kernel parameter sig; do
      cp -f split_img/*-*$($bb basename $i .txt | $bb sed -e 's/hdr/header/') split_img/.temp/$i 2>/dev/null;
    done;
    cp -f "$ramdisk" split_img/.temp/ramdisk.cpio.gz;
    $bin/mboot -d split_img/.temp -f $outname;
  ;;
  U-Boot)
    part0="$kernel";
    case $type in
      Multi) part1=(:"$ramdisk");;
      RAMDisk) part0="$ramdisk";;
    esac;
    $bin/mkimage -A $arch -O $os -T $type -C $comp -a $addr -e $ep -n "$name" -d "$part0""${part1[@]}" $outname >/dev/null;
  ;;
  *) echo "\nUnsupported format."; abort; return 1;;
esac;
if [ $? != 0 ]; then
  abort;
  return 1;
fi;

rm -rf split_img/.temp;

if [ -f split_img/*-sigtype ]; then
  sigtype=`cat split_img/*-sigtype`;
  if [ -f split_img/*-avbtype ]; then
    avbtype=`cat split_img/*-avbtype`;
  fi;
  if [ -f split_img/*-blobtype ]; then
    blobtype=`cat split_img/*-blobtype`;
  fi;
  echo "Signing new image...\n";
  echo "Using signature: $sigtype $avbtype$avbtxt$blobtype\n";
  [ ! "$avbkey" ] && avbkey="$bin/avb/verity";
  case $sigtype in
    AVBv1)
      dalvikvm -Xnodex2oat -Xnoimage-dex2oat -cp $bin/boot_signer-dexed.jar com.android.verity.BootSignature /$avbtype unsigned-new.img "$avbkey.pk8" "$avbkey.x509."* image-new.img 2>/dev/null \
        || dalvikvm -Xnoimage-dex2oat -cp $bin/boot_signer-dexed.jar com.android.verity.BootSignature /$avbtype unsigned-new.img "$avbkey.pk8" "$avbkey.x509."* image-new.img 2>/dev/null;
    ;;
    BLOB)
      $bb printf '-SIGNED-BY-SIGNBLOB-\00\00\00\00\00\00\00\00' > image-new.img;
      $bin/blobpack blob.tmp $blobtype unsigned-new.img >/dev/null;
      cat blob.tmp >> image-new.img;
      rm -f blob.tmp;
    ;;
    CHROMEOS) $bin/futility vbutil_kernel --pack image-new.img --keyblock $bin/chromeos/kernel.keyblock --signprivate $bin/chromeos/kernel_data_key.vbprivk --version 1 --vmlinuz unsigned-new.img --bootloader $bin/chromeos/empty --config $bin/chromeos/empty --arch arm --flags 0x1;;
    DHTB)
      $bin/dhtbsign -i unsigned-new.img -o image-new.img >/dev/null;
      rm -f split_img/*-tailtype 2>/dev/null;
    ;;
    NOOK*) cat split_img/*-master_boot.key unsigned-new.img > image-new.img;;
  esac;
  if [ $? != 0 ]; then
    abort;
    return 1;
  fi;
fi;

if [ -f split_img/*-lokitype ]; then
  lokitype=`cat split_img/*-lokitype`;
  echo "Loki patching new image...\n";
  echo "Using type: $lokitype\n";
  $bb mv -f image-new.img unlokied-new.img;
  if [ -f aboot.img ]; then
    $bin/loki_tool patch $lokitype aboot.img unlokied-new.img image-new.img >/dev/null;
    if [ $? != 0 ]; then
      echo "Patching failed.";
      abort;
      return 1;
    fi;
  else
    echo "Device aboot.img required in script directory to find Loki patch offset.";
    abort;
    return 1;
  fi;
elif [ -f split_img/*-microloader.bin ]; then
  echo "Amonet patching new image...\n";
  cp -f image-new.img unamonet-new.img;
  cp -f split_img/*-microloader.bin microloader.tmp;
  $bb dd bs=1024 count=1 conv=notrunc if=unamonet-new.img of=head.tmp 2>/dev/null;
  $bb dd bs=1024 seek=1 conv=notrunc if=head.tmp of=image-new.img 2>/dev/null;
  $bb dd conv=notrunc if=microloader.tmp of=image-new.img 2>/dev/null;
  rm -f head.tmp microloader.tmp;
fi;

if [ -f split_img/*-tailtype ]; then
  tailtype=`cat split_img/*-tailtype`;
  echo "Appending footer...\n";
  echo "Using type: $tailtype\n";
  case $tailtype in
    Bump) $bb printf '\x41\xA9\xE4\x67\x74\x4D\x1D\x1B\xA4\x29\xF2\xEC\xEA\x65\x52\x79' >> image-new.img;;
    SEAndroid) $bb printf 'SEANDROIDENFORCE' >> image-new.img;;
  esac;
fi;

if [ "$origsize" -a -f split_img/*-origsize ]; then
  filesize=`cat split_img/*-origsize`;
  echo "Padding to original size...\n";
  cp -f image-new.img unpadded-new.img;
  $bb truncate -s $filesize image-new.img;
fi;

echo "Done!";
return 0;

