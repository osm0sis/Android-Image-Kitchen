#!/system/bin/sh
# AIK-mobile/remount: reload current unpacked ramdisk
# osm0sis @ xda-developers

case $0 in
  *.sh) rd="$0";;
     *) rd="$(lsof -p $$ 2>/dev/null | grep -o '/.*remount.sh$')";;
esac;
rd="$(dirname "$(readlink -f "$rd")")";
cd "$rd"; cd ..;
aik="$(pwd)";
bin="$aik/bin";

bb=$bin/busybox;

if [ ! -f $bb ]; then
  bb=busybox;
fi;

test "$($bb ps | $bb grep zygote | $bb grep -v grep)" && su="su -mm" || su=sh;

if [ ! "$($bb mount | $bb grep " $aik/ramdisk ")" ]; then
  $su -c "$bb mount -t ext4 -o rw,noatime $aik/split_img/.aik-ramdisk.img $aik/ramdisk" 2>/dev/null;
  if [ $? != "0" ]; then
    for i in 0 1 2 3 4 5 6 7; do
      loop=/dev/block/loop$i;
      $bb mknod $loop b 7 $i 2>/dev/null;
      $bb losetup $loop $aik/split_img/.aik-ramdisk.img 2>/dev/null;
      test "$($bb losetup $loop | $bb grep $aik)" && break;
    done;
    $su -c "$bb mount -t ext4 -o loop,noatime $loop $aik/ramdisk" || return 1;
  fi;
else
  loop=$($bb mount | $bb grep $aik/ramdisk | $bb cut -d" " -f1);
  $su -c "$bb umount $aik/ramdisk";
  $bb losetup -d $loop 2>/dev/null;
fi;

echo "Working ramdisk remounted.";
return 0;

