#!/bin/sh
# AIK-Linux/cleanup: reset working directory
# osm0sis @ xda-developers

aik="$(cd "$(dirname "$0")"; pwd)";

cd "$aik";
if [ -d ramdisk ] && [ `stat -c %U ramdisk/* | head -n 1` = "root" ]; then
  sudo=sudo;
fi;
$sudo rm -rf ramdisk split_img *new.*;
echo "Working directory cleaned.";
exit 0;

