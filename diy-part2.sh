#!/bin/bash
# diy-part2.sh - Runs AFTER feeds install
# Apply HY3000 device support patches

echo ">>> Copying HY3000 DTS..."
cp -f patches/mt7981b-philips-hy3000.dts target/linux/mediatek/dts/

echo ">>> Applying HY3000 profile patch..."
git apply --check patches/001-add-hy3000-profile.patch 2>/dev/null
if [ $? -ne 0 ]; then
    echo ">>> Patch doesn't apply cleanly, applying with fuzzing..."
    git apply --3way patches/001-add-hy3000-profile.patch || {
        echo ">>> Falling back to manual patching..."

        # filogic.mk - add device definition after cmcc_rax3000m
        sed -i '/^TARGET_DEVICES += cmcc_rax3000m$/a\
\
define Device/philips_hy3000\
  DEVICE_VENDOR := PHILIPS\
  DEVICE_MODEL := HY3000\
  DEVICE_DTS := mt7981b-philips-hy3000\
  DEVICE_DTS_DIR := ..\/dts\
  DEVICE_DTC_FLAGS := --pad 4096\
  DEVICE_DTS_LOADADDR := 0x43f00000\
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware f2fsck mkf2fs\
  KERNEL_LOADADDR := 0x44000000\
  KERNEL := kernel-bin | gzip\
  KERNEL_INITRAMFS := kernel-bin | lzma | \\\
\tfit lzma $$$$(KDIR)\/image-$$$$(firstword $$$$(DEVICE_DTS)).dtb with-initrd | pad-to 64k\
  KERNEL_INITRAMFS_SUFFIX := -recovery.itb\
  IMAGES := sysupgrade.itb\
  IMAGE_SIZE := $$$$(shell expr 64 + $$$$(CONFIG_TARGET_ROOTFS_PARTSIZE))m\
  IMAGE\/sysupgrade.itb := append-kernel | \\\
\t fit gzip $$$$(KDIR)\/image-$$$$(firstword $$$$(DEVICE_DTS)).dtb external-static-with-rootfs | \\\
\t pad-rootfs | append-metadata\
  ARTIFACTS := gpt.bin bl31-uboot.fip preloader.bin\
  ARTIFACT\/gpt.bin := mt798x-gpt emmc\
  ARTIFACT\/bl31-uboot.fip := mt7981-bl31-uboot philips_hy3000\
  ARTIFACT\/preloader.bin  := mt7981-bl2 emmc-ddr4\
endef\
TARGET_DEVICES += philips_hy3000' target/linux/mediatek/image/filogic.mk

        # 02_network - add lan/wan config
        sed -i '/qihoo,360t7|\\$/a\\tphilips,hy3000|\\' \
            target/linux/mediatek/filogic/base-files/etc/board.d/02_network

        # platform.sh - add upgrade support (platform_do_upgrade)
        sed -i '/cmcc,rax3000m|\\$/a\\tphilips,hy3000|\\' \
            target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh

        # uboot-envtools
        sed -i '/cmcc,rax3000m)$/a\philips,hy3000)' \
            package/boot/uboot-tools/uboot-envtools/files/mediatek_filogic

        echo ">>> Manual patching done."
    }
else
    git apply patches/001-add-hy3000-profile.patch
    echo ">>> Patch applied cleanly."
fi

# Set default hostname
sed -i 's/ImmortalWrt/HY3000/g' package/base-files/files/bin/config_generate

echo ">>> HY3000 device support added successfully!"
