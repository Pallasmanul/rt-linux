
WORKDIR=./build
BOOTDIR=./boot
echo $WORKDIR

if [ ! -d "$WORKDIR" ]; then
    mkdir $WORKDIR
fi

if [ ! -d "$BOOTDIR" ]; then
    mkdir $BOOTDIR
fi

wget_resources() {
    wget -nc -P $WORKDIR $1 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "$1 download successful "
    else
        echo "$1 download fail , please check network connect"
    fi
}

unpack() {
    pack_type=`echo $1 | awk -F "." '{print $NF}'`

    if [ "$pack_type" = "bz2" ]; then
        tar -jxvf $1 > /dev/null
        if [ $? -eq 0 ]; then
            echo "$1 unpack successful"
        else
            echo "$1 unpack fial"
        fi
    fi

    if [ "$pack_type" = "gz" ]; then
        tar -zxvf $1 > /dev/null
        if [ $? -eq 0 ]; then
            echo "$1 unpack successful"
        else
            echo "$1 unpack fial"
        fi
    fi

    if [ "$pack_type" = "xz" ]; then
        xz -dk $1 > /dev/null
        if [ $? -eq 0 ]; then
            echo "$1 unpack successful"
        else
            echo "$1 unpack fial"
        fi
    fi

}


uboot_url=https://ftp.denx.de/pub/u-boot/u-boot-2024.01.tar.bz2
linux_url=https://git.kernel.org/pub/scm/linux/kernel/git/rt/linux-stable-rt.git/snapshot/linux-stable-rt-6.6.20-rt25.tar.gz
buildroot_url=https://buildroot.org/downloads/buildroot-2024.02.tar.gz
busybox_url=https://busybox.net/downloads/busybox-1.36.1.tar.bz2

wget_resources $uboot_url
wget_resources $linux_url
wget_resources $buildroot_url
wget_resources $busybox_url

uboot_tar_bz2=`echo ${uboot_url} | awk -F "/" '{print $NF}'`
linux_tar_gz=`echo ${linux_url} | awk -F "/" '{print $NF}'`
buildroot_tar_gz=`echo ${buildroot_url} | awk -F "/" '{print $NF}'`
busybox_tar_gz=`echo ${busybox_url} | awk -F "/" '{print $NF}'`


echo $uboot_tar_bz2
echo $linux_tar_gz
echo $buildroot_tar_gz
echo $busybox_tar_gz

unpack $WORKDIR/$uboot_tar_bz2
wait
unpack $WORKDIR/$linux_tar_gz
wait
unpack $WORKDIR/$buildroot_tar_gz
wait
unpack $WORKDIR/$busybox_tar_gz
wait

# for wsl compile buildroot
export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/sbin:/usr/local/bin
# buildroot host toolchain , used for compile other
export PATH=$PATH:/home/pallasmanul/environment/build/buildroot-2024.02/output/host/bin/


uboot_dir=`echo ${uboot_tar_bz2} | awk -F "." '{ for(i=1;i<=NF-2;i++) { print $i }}'`
linux_dir=`echo ${linux_tar_gz} | awk -F "." '{ for(i=1;i<=NF-2;i++) {print $i}}'`
buildroot_dir=`echo ${buildroot_tar_gz} | awk -F "." '{ for(i=1;i<=NF-2;i++) {print $i}}'`
busybox_dir=`echo ${busybox_tar_gz} | awk -F "." '{ for(i=1;i<=NF-2;i++) {print $i}}'`

uboot_dir=`echo ${uboot_dir} | tr '[:blank:]' '.'`
linux_dir=`echo ${linux_dir} | tr '[:blank:]' '.'`
buildroot_dir=`echo ${buildroot_dir} | tr '[:blank:]' '.'`
busybox_dir=`echo ${busybox_dir} | tr '[:blank:]' '.'`

cp ./uboot_suniv_boot_from_ram_with_internal_filesystem.config $WORKDIR/uboot_dir/
cp ./rtlinux_suniv.config $WORKDIR/linux_dir/
cp ./busybox_suniv.config $WORKDIR/busybox_dir/
cp ./buildroot_suniv.config $WORKDIR/buildroot_dir/

make -C $WORKDIR/uboot_dir/ ARCH=arm  CROSS_COMPILE=arm-none-eabi-
make -C $WORKDIR/linux_dir/ ARCH=arm  CROSS_COMPILE=arm-linux-gnueabi-
make -C $WORKDIR/busybox_dir/ ARCH=arm  CROSS_COMPILE=arm-linux-gnueabi-
make -C $WORKDIR/buildroot_dir/ ARCH=arm  CROSS_COMPILE=arm-none-eabi-

cp $WORKDIR/linux_dir/arch/arm/boot/zImage $BOOTDIR
cp $WORKDIR/linux_dir/arch/arm/boot/dts/allwinner/suniv-f1c100s-licheepi-nano.dtb
cp $WORKDIR/uboot_dir/u-boot-sunxi-with-spl.bin $BOOTDIR



# you need configure initramfs dir to busybox _install dir in linux menuconfig
# the prebuild_busybox is in ./ , you may want to use this


# write image to ram and boot from ram with internal busybox filesystem
#sunxi-fel -p  uboot u-boot-sunxi-with-spl.bin  write  0x80008000  zImage  write 0x80708000 suniv-f1c100s-licheepi-nano.dtb
#bootargs: mem=32M console=tty0 console=ttyS0,115200
#bootcmd: bootz 0x80008000 - 0x80708000


# write image to ram and boot from ram with spi flash filesystem
# 512K + 64K + 6M = 0x6A0000
# 0x6A0000 wirte file system
# sudo sunxi-fel -p spiflash-write 0x6a0000 rootfs.jffs2
# sunxi-fel -p  uboot u-boot-sunxi-with-spl.bin  write  0x80008000  zImage  write 0x80708000 suniv-f1c100s-licheepi-nano.dtb
#bootargs: console=tty0 console=ttyS0,115200 panic=5 rootwait root=/dev/mtdblock3 rw rootfstype=jffs2 mtdparts=spi0.0:512k(uboot)ro,64k(dtb),6M(kernel)ro,-(rootfs)
#bootcmd: bootz 0x80008000 - 0x80708000


# write image to spiflash and boot from spiflash with spi flash filesystem
# ./../buildroot-2024.02/output/host/bin/genimage  --inputpath .
#sunxi-fel -p  uboot u-boot-sunxi-with-spl.bin  write  0x80008000  zImage  write 0x80708000 suniv-f1c100s-licheepi-nano.dtb
#bootargs: console=tty0 console=ttyS0,115200 panic=5 rootwait root=/dev/mtdblock3 rw rootfstype=jffs2 mtdparts=spi0.0:512k(uboot)ro,64k(dtb),6M(kernel)ro,-(rootfs)
#bootcmd:  sf probe 0 50000000; sf read 0x80C00000 0x80000 0x4000; sf read 0x80008000 0x90000 0x500000; bootz 0x80008000 - 0x80C00000

