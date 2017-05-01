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

cd "$aik";
rm -rf ramdisk split_img *new.*;
echo "Working directory cleaned.";
return 0;

