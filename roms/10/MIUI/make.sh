#!/bin/bash

systempath=$1
LOCALDIR=$2
device=$3
thispath=`cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd`

# build.prop
echo "ro.bluetooth.library_name=libbluetooth_qti.so" >> $1/build.prop

# drop finddevice, needs to be done before copying system files
rm -rf $1/priv-app/FindDevice

# Copy system files
rsync -ra $thispath/system/ $systempath

#fix systemui crash because of FOD
echo "ro.hardware.fp.fod=true" >> $1/build.prop
echo "persist.vendor.sys.fp.fod.location.X_Y=445,1260" >> $1/build.prop
echo "persist.vendor.sys.fp.fod.size.width_height=190,190" >> $1/build.prop
#echo "DEVICE_PROVISIONED=1" >> $1/build.prop

if [ "$device" == "channel" ]; then
    sed -i 's/persist.miui.density_v2=440/persist.miui.density_v2=274/' $1/build.prop
    sed -i 's/ro.sf.lcd_density=440/ro.sf.lcd_density=274/' $1/build.prop
    echo "" >> $1/build.prop
    echo "# OpenGL version" >> $1/build.prop
    echo "ro.opengles.version=196610" >> $1/build.prop
    cp $LOCALDIR/devices/channel/MIUI/channel.xml $1/etc/device_features/channel.xml
fi

# drop dirac
rm -rf $1/priv-app/DiracAudioControlService
# drop FingerprintExtensionService
rm -rf $1/app/FingerprintExtensionService
# drop nfc
rm -rf $1/app/NQNfcNci

cat $thispath/rw-system.add.sh >> $1/bin/rw-system.sh

sed -i 's/<bool name="support_round_corner">true/<bool name="support_round_corner">false/' $1/etc/device_features/*

#sed -i "/miui.notch/d" $1/build.prop

# Wifi fix
cp -fpr $thispath/bin/* $1/bin/
cat $thispath/rw-system.add.sh >> $1/bin/rw-system.sh
