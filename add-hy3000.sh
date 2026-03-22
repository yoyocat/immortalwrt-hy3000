#!/bin/bash
# add-hy3000.sh - Add HY3000 device support to ImmortalWrt
set -e

WORKDIR="$1"
PATCHDIR="$2"
cd "$WORKDIR"

# Copy DTS
cp -f "$PATCHDIR/mt7981b-philips-hy3000.dts" target/linux/mediatek/dts/
echo "DTS copied."

# Try applying the patch file
if git apply --check "$PATCHDIR/001-add-hy3000-profile.patch" 2>/dev/null; then
    git apply "$PATCHDIR/001-add-hy3000-profile.patch"
    echo "Patch applied cleanly."
else
    echo "Patch doesn't apply, doing manual integration..."

    # 02_network
    if ! grep -q "philips,hy3000" target/linux/mediatek/filogic/base-files/etc/board.d/02_network; then
        sed -i '/qihoo,360t7|\\$/a\\tphilips,hy3000|\\' \
            target/linux/mediatek/filogic/base-files/etc/board.d/02_network
        echo "02_network patched."
    fi

    # platform.sh - all three functions
    if ! grep -q "philips,hy3000" target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh; then
        sed -i '/cmcc,rax3000m|\\$/a\\tphilips,hy3000|\\' \
            target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh
        echo "platform.sh patched."
    fi

    # uboot-envtools
    if ! grep -q "philips,hy3000" package/boot/uboot-tools/uboot-envtools/files/mediatek_filogic 2>/dev/null; then
        sed -i '/cmcc,rax3000m)$/a\philips,hy3000)' \
            package/boot/uboot-tools/uboot-envtools/files/mediatek_filogic 2>/dev/null || true
        echo "uboot-envtools patched."
    fi

    # filogic.mk - add device definition
    if ! grep -q "philips_hy3000" target/linux/mediatek/image/filogic.mk; then
        cat >> target/linux/mediatek/image/filogic.mk << 'DEVEOF'

define Device/philips_hy3000
  DEVICE_VENDOR := PHILIPS
  DEVICE_MODEL := HY3000
  DEVICE_DTS := mt7981b-philips-hy3000
  DEVICE_DTS_DIR := ../dts
  DEVICE_DTC_FLAGS := --pad 4096
  DEVICE_DTS_LOADADDR := 0x43f00000
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware f2fsck mkf2fs
  KERNEL_LOADADDR := 0x44000000
  KERNEL := kernel-bin | gzip
  KERNEL_INITRAMFS := kernel-bin | lzma | \
	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
  KERNEL_INITRAMFS_SUFFIX := -recovery.itb
  IMAGES := sysupgrade.itb
  IMAGE_SIZE := $$(shell expr 64 + $$(CONFIG_TARGET_ROOTFS_PARTSIZE))m
  IMAGE/sysupgrade.itb := append-kernel | \
	 fit gzip $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb external-static-with-rootfs | \
	 pad-rootfs | append-metadata
  ARTIFACTS := gpt.bin bl31-uboot.fip preloader.bin
  ARTIFACT/gpt.bin := mt798x-gpt emmc
  ARTIFACT/bl31-uboot.fip := mt7981-bl31-uboot philips_hy3000
  ARTIFACT/preloader.bin  := mt7981-bl2 emmc-ddr4
endef
TARGET_DEVICES += philips_hy3000
DEVEOF
        echo "filogic.mk patched."
    fi
fi

# Add U-Boot support pieces for flashable images
mkdir -p package/boot/uboot-mediatek/patches
mkdir -p package/boot/uboot-mediatek/files
mkdir -p package/boot/uboot-mediatek/env
mkdir -p package/boot/uboot-mediatek/configs
mkdir -p package/boot/uboot-mediatek/defenvs

cp -f "$PATCHDIR/471-add-philips_hy3000.patch" package/boot/uboot-mediatek/patches/
cp -f "$PATCHDIR/mt7981_philips_hy3000_defconfig" package/boot/uboot-mediatek/configs/
cp -f "$PATCHDIR/philips_hy3000_env" package/boot/uboot-mediatek/defenvs/

if [ -f package/boot/uboot-mediatek/Makefile ] && ! grep -q "mt7981_philips_hy3000" package/boot/uboot-mediatek/Makefile; then
    sed -i '/^define U-Boot\/mt7981_cmcc_rax3000m-nand-ddr4/a\\ndefine U-Boot/mt7981_philips_hy3000\n  NAME:=PHILIPS HY3000\n  BUILD_SUBTARGET:=filogic\n  BUILD_DEVICES:=philips_hy3000\n  UBOOT_CONFIG:=mt7981_philips_hy3000\n  UBOOT_IMAGE:=u-boot.fip\n  ENV_NAME:=philips_hy3000\n  BL2_BOOTDEV:=emmc\n  BL2_SOC:=mt7981\n  BL2_DDRTYPE:=ddr4\n  DEPENDS:=+trusted-firmware-a-mt7981-emmc-ddr4\nendef\n' package/boot/uboot-mediatek/Makefile || true
    sed -i '/mt7981_cmcc_rax3000m-nand-ddr4 \\/a\\tmt7981_philips_hy3000 \\' package/boot/uboot-mediatek/Makefile || true
fi

# Enable VETH
sed -i 's/# CONFIG_VETH is not set/CONFIG_VETH=m/' target/linux/generic/config-6.6

# Add iStore feed (use https with .git suffix for CI compatibility)
if ! grep -q istore feeds.conf.default; then
    echo 'src-git istore https://github.com/istoreos/istore.git;main' >> feeds.conf.default
fi

echo "=== Verification ==="
grep -c "philips" target/linux/mediatek/image/filogic.mk
ls target/linux/mediatek/dts/mt7981b-philips-hy3000.dts
grep VETH target/linux/generic/config-6.6
grep istore feeds.conf.default
ls package/boot/uboot-mediatek/patches/471-add-philips_hy3000.patch
ls package/boot/uboot-mediatek/configs/mt7981_philips_hy3000_defconfig
ls package/boot/uboot-mediatek/defenvs/philips_hy3000_env
echo "=== All done ==="
