#!/system/bin/sh
# AIK-mobile/cleanup: reset working directory
# osm0sis @ xda-developers

case $0 in
  /system/bin/sh|sh)
    echo "Please run without using the source command.";
    echo "Example: sh ./cleanup.sh";
    return 1;;
esac;

cd "$PWD";
rm -rf ramdisk split_img *new.*;
echo "Working directory cleaned.";
return 0;

