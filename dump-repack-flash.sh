#!/bin/bash
# by François SIMOND, 2011
#
# License: WTFPL
#
# See comments and README for description and requirements

OUTDIR=output/
OUTIMG=insecure-bootimage.img

BASE_DIR=`dirname $(readlink -f $0)`

# setup nvflash bootloader
cd $BASE_DIR/nvflashtf
./nvflash \
	--bct transformer.bct \
	--setbct \
	--configfile flash.cfg \
	--bl bootloader.bin \
	--odmdata 0x300d8011 \
	--sbk 0x1682CCD8 0x8A1A43EA 0xA532EEB6 0xECFE1D98 \
	--sync

cd $BASE_DIR

# setup output directory
rm -rf $OUTDIR && mkdir -p $OUTDIR && cd $OUTDIR || exit 1

# read the kernel directly from the device
nvflash -r --read 6 kernel

# unpack the kernel
bootunpack kernel
mkdir -p "ramdisk" && cd "ramdisk"
gunzip -c "../kernel-ramdisk.cpio.gz" | cpio -i

# "open" default.prop
sed s/ro\.secure=.*/ro.secure=0/ default.prop \
	| sed s/persist\.service\.adb\.enable=.*/persist.service.adb.enable=1/ \
	> default.prop-insecure
mv default.prop-insecure default.prop

# build a new initramfs
find | fakeroot cpio -o -H newc | gzip -9 > ../insecure-initramfs.cpio.gz
cd -

# make a new bootimage
mkbootimg \
	--kernel kernel-kernel.gz \
	--ramdisk insecure-initramfs.cpio.gz \
	-o $OUTIMG || exit 1

# flash the new insecure kernel on the device and also boot!
nvflash -r --download 6 $OUTIMG --go

cd $BASE_DIR
ln -f output/$OUTIMG
ln -f output/kernel original-kernel.img

ls -lh *.img
