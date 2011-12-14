#!/bin/bash

set -x

INITRAMFS="/home/bryan/kj6kernel/initramfs_root/"

setup ()
{
    if [ x = "x$ANDROID_BUILD_TOP" ] ; then
        echo "Android build environment must be configured"
        exit 1
    fi
    . "$ANDROID_BUILD_TOP"/build/envsetup.sh

    KERNEL_DIR="$(dirname "$(readlink -f "$0")")"
    BUILD_DIR="$KERNEL_DIR/build"
    MODULES=$(find ${BUILD_DIR} -name '*.ko')

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
    rm -fr "$target_dir"
    #mkdir -p "$target_dir/usr"
    mkdir -p "$target_dir"
    #cp "$KERNEL_DIR/usr/"*.list "$target_dir/usr"
    #sed "s|usr/|$KERNEL_DIR/usr/|g" -i "$target_dir/usr/"*.list
    mka -C "$KERNEL_DIR" O="$target_dir" ARCH=arm aries_${target}_defconfig CONFIG_INITRAMFS_SOURCE="${INITRAMFS}" HOSTCC="$CCACHE gcc"
    mka -C "$KERNEL_DIR" O="$target_dir" ARCH=arm HOSTCC="$CCACHE gcc" CONFIG_INITRAMFS_SOURCE="${INITRAMFS}" CROSS_COMPILE="$CCACHE $CROSS_PREFIX" zImage modules
    WHEREWASI="$(pwd)"
    cd "${INITRAMFS}"
    mkdir tmp
    cd tmp
    unlzma -c ../compressed_voodoo_initramfs.tar.lzma | tar xf -
    cd ${WHEREWASI}
    cp ${MODULES} ${INITRAMFS}tmp/lib/modules/
    cd ${INITRAMFS}tmp
    tar cf ../compressed_voodoo_initramfs.tar *
    cd ..
    rm -rf ${INITRAMFS}compressed_voodoo_initramfs.tar.lzma ${INITRAMFS}tmp
    lzma compressed_voodoo_initramfs.tar
    cd ${WHEREWASI}
    rm -rf ${target_dir}/usr/{built-in.o,initramfs_data.{o,cpio*}}
    mka -C "$KERNEL_DIR" O="$target_dir" ARCH=arm HOSTCC="$CCACHE gcc" CONFIG_INITRAMFS_SOURCE="${INITRAMFS}" CROSS_COMPILE="$CCACHE $CROSS_PREFIX" zImage
    cp "$target_dir"/arch/arm/boot/zImage $ANDROID_BUILD_TOP/device/samsung/$target/kernel
    cp ${MODULES} ${ANDROID_BUILD_TOP}/device/samsung/$target
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
