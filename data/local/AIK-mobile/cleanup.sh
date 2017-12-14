#!/system/bin/sh
# AIK-mobile/cleanup: reset working directory
# osm0sis @ xda-developers

case $1 in
  --help) echo "usage: cleanup.sh"; return 1;
esac;

case $0 in
  *.sh) aik="$0";;
     *) aik="$(lsof -p $$ 2>/dev/null | grep -o '/.*cleanup.sh$')";;
esac;
aik="$(dirname "$(readlink -f "$aik")")";
bin="$aik/bin";

bb=$bin/busybox;

if [ ! -f $bb ]; then
  bb=busybox;
fi;

cd "$aik";
loop=$($bb mount | $bb grep $aik/ramdisk | $bb cut -d" " -f1);
su -mm -c "$bb umount $aik/ramdisk" 2>/dev/null;
$bb losetup -d $loop 2>/dev/null;

rm -rf ramdisk split_img *new.*;

echo "Working directory cleaned.";
return 0;

