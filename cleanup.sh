#!/bin/bash
# AIK-Linux/cleanup: reset working directory
# osm0sis @ xda-developers

case $1 in
  --help) echo "usage: cleanup.sh [--quiet]"; exit 1;
esac;

case $(uname -s) in
  Darwin|Macintosh)
    statarg="-f %Su";
    readlink() { perl -MCwd -e 'print Cwd::abs_path shift' "$2"; }
  ;;
  *) statarg="-c %U";;
esac;

aik="${BASH_SOURCE:-$0}";
aik="$(dirname "$(readlink -f "$aik")")";

cd "$aik";
if [ -d ramdisk ] && [ "$(stat $statarg ramdisk | head -n 1)" = "root" -o ! "$(find ramdisk 2>&1 | cpio -o >/dev/null 2>&1; echo $?)" -eq "0" ]; then
  sudo=sudo;
fi;

$sudo rm -rf ramdisk split_img *new.* || exit 1;

case $1 in
  --quiet) ;;
  *) echo "Working directory cleaned.";;
esac;
exit 0;

