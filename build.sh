#!/bin/bash

set -x

INITRAMFS_REAL="/home/bryan/cm7sgs4g/sgs4g_gb_initramfs"
INITRAMFS="/tmp/sgs4g_gb_initramfs"

setup ()
{
    if [ x = "x$ANDROID_BUILD_TOP" ] ; then
        echo "Android build environment must be configured"
        exit 1
    fi
    . "$ANDROID_BUILD_TOP"/build/envsetup.sh

    KERNEL_DIR="$(dirname "$(readlink -f "$0")")"
    BUILD_DIR="$KERNEL_DIR/build"

    if [ x = "x$NO_CCACHE" ] && ccache -V &>/dev/null ; then
        CCACHE=ccache
        CCACHE_BASEDIR="$KERNEL_DIR"
        CCACHE_COMPRESS=1
        CCACHE_DIR="$BUILD_DIR/.ccache"
        export CCACHE_DIR CCACHE_COMPRESS CCACHE_BASEDIR
    else
        CCACHE=""
    fi

    CROSS_PREFIX="$ANDROID_TOOLCHAIN/arm-eabi-"
}

build ()
{
    local target=$1
    echo "Building for $target"
    local target_dir="$BUILD_DIR/$target"
    local module
    cp -rf ${INITRAMFS_REAL} ${INITRAMFS}
    rm -rf ${INITRAMFS}/.git
    rm -fr "$target_dir"
    #mkdir -p "$target_dir/usr"
    mkdir -p "$target_dir"
    #cp "$KERNEL_DIR/usr/"*.list "$target_dir/usr"
    #sed "s|usr/|$KERNEL_DIR/usr/|g" -i "$target_dir/usr/"*.list
    mka -C "$KERNEL_DIR" O="$target_dir" ARCH=arm aries_${target}_defconfig CONFIG_INITRAMFS_SOURCE="${INITRAMFS}" HOSTCC="$CCACHE gcc"
    mka -C "$KERNEL_DIR" O="$target_dir" ARCH=arm HOSTCC="$CCACHE gcc" CONFIG_INITRAMFS_SOURCE="${INITRAMFS}" CROSS_COMPILE="$CCACHE $CROSS_PREFIX" zImage modules
    cp $(find ${BUILD_DIR} -name '*.ko') ${ANDROID_BUILD_TOP}/device/samsung/${target}/modules/
    cp $(find ${BUILD_DIR} -name '*.ko') ${INITRAMFS}/lib/modules/
    cp $(find ${BUILD_DIR} -name '*.ko') ${INITRAMFS_REAL}/lib/modules/
    rm -rf ${target_dir}/usr/{built-in.o,initramfs_data.{o,cpio*}}
    mka -C "$KERNEL_DIR" O="$target_dir" ARCH=arm HOSTCC="$CCACHE gcc" CONFIG_INITRAMFS_SOURCE="${INITRAMFS}" CROSS_COMPILE="$CCACHE $CROSS_PREFIX" zImage
    cp "$target_dir"/arch/arm/boot/zImage $ANDROID_BUILD_TOP/device/samsung/$target/kernel
}
    
setup

if [ "$1" = clean ] ; then
    rm -fr "$BUILD_DIR"/*
    exit 0
fi

targets=("$@")
if [ 0 = "${#targets[@]}" ] ; then
    #targets=(captivatemtd fascinatemtd galaxysmtd galaxysbmtd vibrantmtd)
    targets=(galaxys4g)
fi

START=$(date +%s)

for target in "${targets[@]}" ; do 
    build $target
done

END=$(date +%s)
ELAPSED=$((END - START))
E_MIN=$((ELAPSED / 60))
E_SEC=$((ELAPSED - E_MIN * 60))
printf "Elapsed: "
[ $E_MIN != 0 ] && printf "%d min(s) " $E_MIN
printf "%d sec(s)\n" $E_SEC
