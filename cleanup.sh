#!/bin/bash
# AIK-Linux/cleanup: reset working directory
# osm0sis @ xda-developers

case $1 in
  --help) echo "usage: cleanup.sh"; exit 1;
esac;

case $(uname -s) in
  Darwin|Macintosh)
    readlink() { perl -MCwd -e 'print Cwd::abs_path shift' "$2"; }
  ;;
esac;

aik="${BASH_SOURCE:-$0}";
aik="$(dirname "$(readlink -f "$aik")")";

cd "$aik";
sudo rm -rf ramdisk split_img *new.*;
echo "Working directory cleaned.";
exit 0;

