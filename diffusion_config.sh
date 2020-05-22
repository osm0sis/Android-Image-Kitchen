# Diffusion Installer Config
# osm0sis @ xda-developers

INST_NAME="Android Image Kitchen - Mobile Installer Script";
AUTH_NAME="osm0sis @ xda-developers";

USE_ARCH=true
USE_ZIP_OPTS=false

custom_zip_opts() {
  return # stub
}

custom_target() {
  # ensure no old install leftovers remain
  rm -rf /data/local/AIK-mobile;
}

custom_install() {
  ui_print "Using architecture: $ARCH";
  cd binarch;
  # work around scenarios where toybox's limited tar would be used (old Magisk Manager PATH issue, TWRPs without busybox)
  tar -xzf xz.tar.gz $ARCH/xz;
  set_perm 0 0 755 $ARCH/xz;
  $ARCH/xz -dc $ARCH.tar.xz | tar -x;
  cd ..;
  ui_print " ";
  ui_print "Installing AIK-mobile to /data/local/AIK-mobile ...";
  cp -f binarch/$ARCH/* /data/local/AIK-mobile/bin;
  cp -f module.prop /data/local/AIK-mobile/bin;
  set_perm_recursive 0 0 0755 0755 /data/local/AIK-mobile;
  set_perm_recursive 0 0 0755 0644 /data/local/AIK-mobile/bin/avb /data/local/AIK-mobile/bin/chromeos;
  set_perm 0 0 0644 /data/local/AIK-mobile/authors.txt /data/local/AIK-mobile/bin/androidbootimg.magic /data/local/AIK-mobile/bin/boot_signer-dexed.jar /data/local/AIK-mobile/bin/magic /data/local/AIK-mobile/bin/module.prop;
  ui_print "Installing Helper Script to $BIN/aik ...";
  mkdir -p $BIN;
  cp -pf /data/local/AIK-mobile/bin/aik $BIN/aik;
}

custom_postinstall() {
  return # stub
}

custom_uninstall() {
  return # stub
}

custom_postuninstall() {
  return # stub
}

custom_cleanup() {
  return # stub
}

custom_exitmsg() {
  ui_print " ";
  ui_print "Run 'aik' from the commandline when booted";
  ui_print "then 'unpackimg.sh -.img' to get started.";
  ui_print "Or, copy an .img and run from an explorer app.";
}

# additional custom functions


