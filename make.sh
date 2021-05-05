#!/bin/bash

# Project OEM-GSI Porter by Erfan Abdi <erfangplus@gmail.com>

usage()
{
echo "Usage: $0 <Path to Firmware partitions:> <Firmware type> <Output type> <device> [Output Dir]"
    echo -e "\tPath to GSI Firmware partitions:: Mount GSI and set mount point"
    echo -e "\tFirmware type: Firmware mode"
    echo -e "\tOutput type: AB or Aonly"
    echo -e "\tOutput Dir: set output dir"
}

if [ "$3" == "" ]; then
    echo "ERROR: Enter all needed parameters"
    usage
    exit 1
fi

LOCALDIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd`
sourcepath=$1
romtype=$2
outputtype=$3
device=$4

echo "sourcepath: $sourcepath"
echo "romtype: $romtype"
echo "outputtype: $outputtype"
echo "device: $device"

if [[ $romtype == *":"* ]]; then
    romtypename=`echo "$romtype" | cut -d ":" -f 2`
    romtype=`echo "$romtype" | cut -d ":" -f 1`
else
    romtypename=$romtype
fi

flag=false
roms=("$LOCALDIR"/roms/*/*)
for dir in "${roms[@]}"
do
    rom=`echo "$dir" | rev | cut -d "/" -f 1 | rev`
    if [ "$rom" == "$romtype" ]; then
        flag=true
    fi
done
if [ "$flag" == "false" ]; then
    echo "$romtype is not supported rom, supported roms:"
    for dir in "${roms[@]}"
    do
        ver=`echo "$dir" | rev | cut -d "/" -f 2 | rev`
        rom=`echo "$dir" | rev | cut -d "/" -f 1 | rev`
        echo "$rom for Android $ver"
    done
    exit 1
fi
flag=false
case "$outputtype" in
    *"AB"*) flag=true ;;
    *"Aonly"*) flag=true ;;
esac
if [ "$flag" == "false" ]; then
    echo "$outputtype is not supported type, supported types:"
    echo "AB"
    echo "Aonly"
    exit 1
fi

# Setup source system partition
systempath=$sourcepath
if [[ -e "$sourcepath/mounted.txt" ]]; then
    systempath=$sourcepath/system
fi

# Detect Source type, AB or not
sourcetype="Aonly"
if [[ -e "$sourcepath/system" ]]; then
    sourcetype="AB"
fi

tempdirname="tmp"
tempdir="$LOCALDIR/$tempdirname"
systemdir="$tempdir/system"
toolsdir="$LOCALDIR/tools"
romsdir="$LOCALDIR/roms"
prebuiltdir="$LOCALDIR/prebuilt"
scriptsdir="$LOCALDIR/scripts"

echo "Create Temp dir"
rm -rf $tempdir
mkdir -p "$systemdir"

if [ "$sourcetype" == "Aonly" ]; then
    echo "Warning: Aonly source detected, using P AOSP ramdisk"
    cd "$systemdir"
    tar xf "$prebuiltdir/ABrootDir.tar"
    cd "$LOCALDIR"
    echo "Making copy of source rom to temp"
    ( cd "$systempath" ; sudo tar cf - . ) | ( cd "$systemdir/system" ; sudo tar xf - )
    cd "$LOCALDIR"
    sed -i "/ro.build.system_root_image/d" "$systemdir/system/build.prop"
    sed -i "/ro.build.ab_update/d" "$systemdir/system/build.prop"
    echo "ro.build.system_root_image=false" >> "$systemdir/system/build.prop"
else
    echo "Making copy of source rom to temp"
    ( cd "$systempath" ; sudo tar cf - . ) | ( cd "$systemdir" ; sudo tar xf - )
    if [[ -e "$sourcepath/mounted.txt" ]]; then
        for p in `cat "$sourcepath/mounted.txt"`; do
            [[ $p = system ]] && continue
            [[ $p = vendor ]] && continue
            if [[ -L "$systemdir/system/$p" ]]; then
                rm -rf "$systemdir/system/$p"
                mkdir "$systemdir/system/$p"
                rm -rf "$systemdir/$p"
                ln -s "/system/$p" "$systemdir/$p"
                ( cd "$sourcepath/$p" ; sudo tar cf - . ) | ( cd "$systemdir/system/$p" ; sudo tar xf - )
            fi
        done
    fi
    cd "$LOCALDIR"
    sed -i "/ro.build.system_root_image/d" "$systemdir/system/build.prop"
    sed -i "/ro.build.ab_update/d" "$systemdir/system/build.prop"
    echo "ro.build.system_root_image=true" >> "$systemdir/system/build.prop"
fi

# Detect is the src treble ro.treble.enabled=true
istreble=`cat $systemdir/system/build.prop | grep ro.treble.enabled | cut -d "=" -f 2`
if [[ ! "$istreble" == "true" ]]; then
    echo "The source is not treble supported"
    exit 1
fi

# Detect Source API level
if grep -q ro.build.version.release_or_codename $systemdir/system/build.prop; then
    sourcever=`grep ro.build.version.release_or_codename $systemdir/system/build.prop | cut -d "=" -f 2`
else
    sourcever=`grep ro.build.version.release $systemdir/system/build.prop | cut -d "=" -f 2`
fi
if [ $(echo $sourcever | cut -d "." -f 2) == 0 ]; then
    sourcever=$(echo $sourcever | cut -d "." -f 1)
fi
flag=false
case "$sourcever" in
    *"9"*) flag=true ;;
    *"10"*) flag=true ;;
    *"11"*) flag=true ;;
    *"S"*) flag=true ;;
esac
if [ "$flag" == "false" ]; then
    echo "$sourcever is not supported"
    exit 1
fi

# Detect rom folder again
if [[ ! -d "$romsdir/$sourcever/$romtype" ]]; then
    echo "$romtype is not supported rom for android $sourcever"
    exit 1
fi

# Detect arch
if [[ ! -f "$systemdir/system/lib64/libandroid.so" ]]; then
    echo "32bit source detected, weird flex but ok!"
    # do something here?
fi

# Debloat
$romsdir/$sourcever/$romtype/debloat.sh "$systemdir/system" 2>/dev/null
$romsdir/$sourcever/$romtype/$romtypename/debloat.sh "$systemdir/system" 2>/dev/null

# Resign to AOSP keys
if [[ ! -e $romsdir/$sourcever/$romtype/$romtypename/DONTRESIGN ]]; then
    if [[ ! -e $romsdir/$sourcever/$romtype/DONTRESIGN ]]; then
        echo "Resigning to AOSP keys"
        ispython2=`python -c 'import sys; print("%i" % (sys.hexversion<0x03000000))'`
        if [ $ispython2 -eq 0 ]; then
            python2=python2
        else
            python2=python
        fi
        $python2 $toolsdir/ROM_resigner/resign.py "$systemdir/system" $toolsdir/ROM_resigner/AOSP_security > $tempdir/resign.log
        $prebuiltdir/resigned/make.sh "$systemdir/system" 2>/dev/null
    fi
fi

# Start patching
echo "Patching started..."
$scriptsdir/fixsymlinks.sh "$systemdir/system" 2>/dev/null
$scriptsdir/nukeABstuffs.sh "$systemdir/system" 2>/dev/null
#$prebuiltdir/vendor_vndk/make$sourcever.sh "$systemdir/system" 2>/dev/null
$prebuiltdir/$sourcever/make.sh "$systemdir/system" "$romsdir/$sourcever/$romtype" 2>/dev/null
$prebuiltdir/$sourcever/makeroot.sh "$systemdir" "$romsdir/$sourcever/$romtype" 2>/dev/null
$prebuiltdir/common/make.sh "$systemdir/system" "$romsdir/$sourcever/$romtype" 2>/dev/null
$romsdir/$sourcever/$romtype/make.sh "$systemdir/system" "$LOCALPATH" "$device" 2>/dev/null
$romsdir/$sourcever/$romtype/makeroot.sh "$systemdir" 2>/dev/null
if [ ! "$romtype" == "$romtypename" ]; then
    $romsdir/$sourcever/$romtype/$romtypename/make.sh "$systemdir/system" 2>/dev/null
    $romsdir/$sourcever/$romtype/$romtypename/makeroot.sh "$systemdir" 2>/dev/null
fi
if [ "$outputtype" == "Aonly" ] && [ ! "$romtype" == "$romtypename" ]; then
    $romsdir/$sourcever/$romtype/$romtypename/makeA.sh "$systemdir/system" 2>/dev/null
fi
if [ "$outputtype" == "Aonly" ]; then
    $prebuiltdir/$sourcever/makeA.sh "$systemdir/system" 2>/dev/null
    $romsdir/$sourcever/$romtype/makeA.sh "$systemdir/system" 2>/dev/null
fi

# Device specific stuff

if [ "$device" == "channel" ]; then
    echo "device: channel"
    cp "devices/channel/init.channel.rc" "$systemdir/etc/init.channel.rc" 2>/dev/null
    cp "prebuilt/10/overlay/treble-overlay-moto-g7play.apk" "$systemdir/product/overlay/treble-overlay-moto-g7play.apk" 2>/dev/null
fi

# Fixing environ
if [ "$outputtype" == "Aonly" ]; then
    if [[ ! $(ls "$systemdir/system/etc/init/" | grep *environ*) ]]; then
        echo "Generating environ.rc"
        echo "# AUTOGENERATED FILE BY ERFANGSI TOOLS" > "$systemdir/system/etc/init/init.treble-environ.rc"
        echo "on init" >> "$systemdir/system/etc/init/init.treble-environ.rc"
        cat "$systemdir/init.environ.rc" | grep BOOTCLASSPATH >> "$systemdir/system/etc/init/init.treble-environ.rc"
        cat "$systemdir/init.environ.rc" | grep SYSTEMSERVERCLASSPATH >> "$systemdir/system/etc/init/init.treble-environ.rc"
    fi
fi

date=`date +%Y%m%d`
outputname="$romtypename-$outputtype-$sourcever-$date-amygrace.tk"
outputimagename="$outputname".img
outputtextname="$outputname".txt
if [ "$5" == "" ]; then
    echo "Create out dir"
    outdirname="out"
    outdir="$LOCALDIR/$outdirname"
    mkdir -p "$outdir"
else
    outdir="$5"
fi
output="$outdir/$outputimagename"
outputinfo="$outdir/$outputtextname"

$scriptsdir/getinfo.sh "$systemdir/system" > "$outputinfo"

if [[ $(grep "ro.build.display.id" $systemdir/system/build.prop) ]]; then
    displayid="ro.build.display.id"
elif [[ $(grep "ro.system.build.id" $systemdir/system/build.prop) ]]; then
    displayid="ro.system.build.id"
elif [[ $(grep "ro.build.id" $systemdir/system/build.prop) ]]; then
    displayid="ro.build.id"
fi
displayid2=$(echo "$displayid" | sed 's/\./\\./g')
bdisplay=$(grep "$displayid" $systemdir/system/build.prop | sed 's/\./\\./g; s:/:\\/:g; s/\,/\\,/g; s/\ /\\ /g')
sed -i "s/$bdisplay/$displayid2=Ported\.by\.Amy/" $systemdir/system/build.prop

# Getting system size and add approximately 5% on it just for free space
systemsize=`du -sk $systemdir | awk '{$1*=1024;$1=int($1*1.05);printf $1}'`
bytesToHuman() {
    b=${1:-0}; d=''; s=0; S=(Bytes {K,M,G,T,P,E,Z,Y}iB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]}"
}
echo "Raw Image Size: $(bytesToHuman $systemsize)" >> "$outputinfo"

tree $systemdir >> "tree.txt"

echo "Creating Image: $outputimagename"
# Use ext4fs to make image in P or older!
if [ "$sourcever" == "9" ]; then
    useold="--old"
fi
$scriptsdir/mkimage.sh $systemdir $outputtype $systemsize $output $useold > $tempdir/mkimage.log

echo "Remove Temp dir"
rm -rf "$tempdir"
