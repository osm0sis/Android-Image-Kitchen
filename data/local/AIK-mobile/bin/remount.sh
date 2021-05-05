#!/system/bin/sh
# AIK-mobile/remount: reload current unpacked ramdisk
# osm0sis @ xda-developers

case $1 in
  --help) echo "usage: remount.sh [--mount-only|--umount-only]"; return 1;
esac;

case $0 in
  *.sh) rd="$0";;
     *) rd="$(lsof -p $$ 2>/dev/null | grep -o '/.*remount.sh$')";;
esac;
rd="$(dirname "$(readlink -f "$rd")")";
cd "$rd"; cd ..;
aik="$(pwd)";
bin="$aik/bin";

bb=$bin/busybox;
chmod -R 755 $bin $aik/*.sh;
chmod 644 $bin/magic $bin/androidbootimg.magic $bin/boot_signer-dexed.jar $bin/module.prop $bin/ramdisk.img $bin/avb/* $bin/chromeos/*;

[ ! -f $bb ] && bb=busybox;

su=sh;
$bb ps | $bb grep -v grep | $bb grep -q zygote && su="su -mm";

--mount-only() {
  $bb mount | $bb grep -q " $aik/ramdisk " && return 0;
  $su -c "$bb mount -t ext4 -o rw,noatime $aik/split_img/.aik-ramdisk.img $aik/ramdisk" 2>/dev/null;
  if [ $? != 0 ]; then
    minorx=1;
    [ -e /dev/block/loop1 ] && minorx=$(ls -l /dev/block/loop1 | $bb awk '{ print $6 }');
    i=0;
    while [ $i -lt 64 ]; do
      loop=/dev/block/loop$i;
      $bb mknod $loop b 7 $((i * minorx)) 2>/dev/null;
      $bb losetup $loop $aik/split_img/.aik-ramdisk.img 2>/dev/null;
      $bb losetup $loop | $bb grep -q .aik-ramdisk.img && break;
      i=$((i + 1));
    done;
    $su -c "$bb mount -t ext4 -o loop,noatime $loop $aik/ramdisk";
    if [ $? != 0 ]; then
      $bb losetup -d $loop 2>/dev/null;
      return 1;
    fi;
  fi;
}

--umount-only() {
  loop=$($bb mount | $bb grep $aik/ramdisk | $bb cut -d" " -f1);
  $su -c "$bb umount $aik/ramdisk";
  $bb losetup -d $loop 2>/dev/null || true;
}

if [ "$1" ]; then
  $1 || return 1;
else
  if ! $bb mount | $bb grep -q " $aik/ramdisk "; then
    --mount-only || return 1;
  else
    --umount-only;
  fi;
  echo "Working ramdisk remounted.";
fi;

return 0;

