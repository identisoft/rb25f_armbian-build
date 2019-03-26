ARCH=arm64
KERNEL_IMAGE_TYPE=Image
BOOTDELAY=1

# Here we want to rename LINUXFAMILY from sun50iw1, sun50iw2, etc for next and dev branches
# since this doesn't affect any stable images don't add any backwards compatibility hacks
LINUXFAMILY=eureka


ATFSOURCE='http://github.com/identisoft/rb25f_arm-trusted-firmware-sunxi.git'
ATFDIR='arm-trusted-firmware-sunxi'
if [[ $Build_Type == "release" ]]; then
	ATFBRANCH="tag:$product_issue"
else
	ATFBRANCH="branch:master"
fi
ATF_PATCH_DIR='atf-rb25f'
ATF_USE_GCC='> 6.3'
ATF_TARGET_MAP='PLAT=sun50iw1p1 DEBUG=1 bl31;;build/sun50iw1p1/debug/bl31.bin'

BOOTSOURCE=$MAINLINE_UBOOT_SOURCE
BOOTDIR=$MAINLINE_UBOOT_DIR
if [[ $Build_Type == "release" ]]; then
	BOOTBRANCH="tag:${product_issue}"
else
	BOOTBRANCH="branch:master"
fi
BOOTPATCHDIR='u-boot-rb25f'
UBOOT_USE_GCC='> 7.0'
UBOOT_TARGET_MAP=';;spl/sunxi-spl.bin u-boot.itb'
BOOTSCRIPT='boot-sun50i-next.cmd:boot.cmd'

KERNELSOURCE=$MAINLINE_KERNEL_SOURCE
KERNELVERSION="4.14.59"
if [[ $Build_Type == "release" ]]; then
	KERNELBRANCH="tag:$product_issue"
else
	KERNELBRANCH="branch:master"
fi
KERNELDIR=$MAINLINE_KERNEL_DIR
KERNEL_USE_GCC='> 7.0'
KERNELPATCHDIR='kernel-rb25f'

write_uboot_platform()
{
	# default
	[[ -f $1/u-boot-with-dtb.bin ]] && dd if=$1/u-boot-with-dtb.bin of=$2 bs=1k seek=8 conv=fsync > /dev/null 2>&1 || true
	# mainline
	[[ -f $1/sunxi-spl.bin ]] && dd if=$1/sunxi-spl.bin of=$2 bs=8k seek=1 conv=fsync > /dev/null 2>&1
	[[ -f $1/u-boot.itb ]] && dd if=$1/u-boot.itb of=$2 bs=8k seek=5 conv=fsync > /dev/null 2>&1 || true
}

setup_write_uboot_platform()
{
	if grep -q "ubootpart" /proc/cmdline; then
		# mainline with new boot script
		local tmp=$(cat /proc/cmdline)
		tmp="${tmp##*ubootpart=}"
		tmp="${tmp%% *}"
		[[ -n $tmp ]] && local part=$(findfs PARTUUID=$tmp 2>/dev/null)
		[[ -n $part ]] && local dev=$(lsblk -n -o PKNAME $part 2>/dev/null)
		[[ -n $dev ]] && DEVICE="/dev/$dev"
	else
		# legacy or old boot script
		local tmp=$(cat /proc/cmdline)
		tmp="${tmp##*root=}"
		tmp="${tmp%% *}"
		[[ -n $tmp ]] && local part=$(findfs $tmp 2>/dev/null)
		[[ -n $part ]] && local dev=$(lsblk -n -o PKNAME $part 2>/dev/null)
		# do not try to write u-boot to USB devices
		[[ -n $dev && $dev == mmcblk* ]] && DEVICE="/dev/$dev"
	fi
}
