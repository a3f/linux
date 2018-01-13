#!/bin/bash

set -e

BRANCH=`git rev-parse --abbrev-ref HEAD`
KERNEL=${KERNEL:-kernel-$(date "+%Y-%m-%d_%H-%M-%S")}
NOBUILD="${NOBUILD:-false}"
NOMODINSTALL="${NOMODINSTALL:-false}"

if [[ $BRANCH =~ ^rpi-.*$ ]]; then
    export ARCH=arm
    if [[ -z "$CROSS_COMPILE" && `arch` != 'armv7l' ]] ; then
          if command -v arm-none-linux-gnueabihf-gcc &>/dev/null ; then
            export CROSS_COMPILE=arm-none-linux-gnueabihf-
        elif command -v arm-none-linux-gnueabi-gcc &>/dev/null ; then
            export CROSS_COMPILE=arm-none-linux-gnueabi-
        elif command -v arm-linux-gnueabihf-gcc &>/dev/null ; then
            export CROSS_COMPILE=arm-linux-gnueabihf-
        elif command -v arm-linux-gnueabi-gcc &>/dev/null ; then
            export CROSS_COMPILE=arm-linux-gnueabi-
        elif command -v arm-none-eabi-gcc &>/dev/null ; then
            export CROSS_COMPILE=arm-none-eabi-
        elif command -v arm-eabi-gcc &>/dev/null ; then
            export CROSS_COMPILE=arm-eabi-
        else
            echo ERROR: can\'t find suitable cross compiler. Please set CROSS_COMPILE manually in the environment
        fi
    fi

    echo Building Raspberry Pi $KERNEL with "prefix='$CROSS_COMPILE'"

    ## Pi 1 or Compute Module
    #make bcmrpi_defconfig
    # Pi 2/3
    #make bcm2709_defconfig

    # Optional: configure custom kernel options
    #make menuconfig

    $NOBUILD || make -j`nproc` zImage modules dtbs

    TEMP=$(mktemp -d) || exit 1
    mkdir -p $TEMP/target/boot/overlays/
    sudo chown -R root:root $TEMP/target
    sudo make ARCH=$ARCH INSTALL_MOD_PATH=/tmp/target/ modules_install
    $NOMODINSTALL || sudo make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=$TEMP/target/ modules_install
    sudo scripts/mkknlimg arch/arm/boot/zImage $TEMP/target/boot/$KERNEL.img
    sudo cp arch/arm/boot/dts/*.dtb $TEMP/target/boot
    sudo cp arch/arm/boot/dts/overlays/*.dtb* $TEMP/target/boot/overlays/
    sudo cp arch/arm/boot/dts/overlays/README $TEMP/target/boot/overlays/
    sudo sh -c "echo 'echo kernel=$KERNEL.img >>/boot/config.txt' >> $TEMP/target/boot/append_config"

    cd $TEMP/target
    sudo chmod +x boot/append_config
    sudo tar pczf ../$KERNEL.tgz .

    cd $TEMP
    ls $KERNEL.tgz
    echo scp $TEMP/$KERNEL.tgz rpi:~
fi
