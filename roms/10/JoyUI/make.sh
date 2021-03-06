#!/bin/bash

systempath=$1
LOCALDIR=$2
device=$3
thispath=`cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd`

# Add BlackShark things
cp -fpr $thispath/lib/* $1/lib/
cp -fpr $thispath/lib64/* $1/lib64/
cp -fpr $thispath/etc/* $1/etc/
cp -fpr $thispath/bin/* $1/bin/
cp -fpr $thispath/product/* $1/product/

# Drop SetupWizard
rm -rf $1/priv-app/ZsSetupWizard
# Force provision on build.prop and forceprovision.rc
echo "DEVICE_PROVISIONED=1" >> $1/build.prop

# Set locale to en-US
sed -i 's/zh-CN/en-US/g' $1/build.prop

# Prevent .dataservices crashes
rm -rf $1/priv-app/dpmserviceapp/

# Custom Manifest   
python $thispath/../../../scripts/custom_manifest.py $thispath/../../../tmp/manifest.xml $thispath/manifest.xml $1/etc/vintf/manifest.xml
cp -fpr $thispath/../../../tmp/manifest.xml $1/etc/vintf/manifest.xml

# Device specific patches

if [ "$device" == "channel" ]; then
    sed -i 's/persist.miui.density_v2=440/persist.miui.density_v2=274/' $1/build.prop
    sed -i 's/ro.sf.lcd_density=440/ro.sf.lcd_density=274/' $1/build.prop
    echo "" >> $1/build.prop
    echo "# OpenGL version" >> $1/build.prop
    echo "ro.opengles.version=196610" >> $1/build.prop
    cp $LOCALDIR/devices/channel/MIUI/channel.xml $1/etc/device_features/channel.xml
fi
