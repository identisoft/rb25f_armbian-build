# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build/

# common options
REVISION="5.57$SUBREVISION" # all boards have same revision
ROOTPWD="masterkey"
MAINTAINER="Impro Technologies" # deb signature
MAINTAINERMAIL="www.impro.net" # deb signature
TZDATA=`cat /etc/timezone` # Timezone for target is taken from host or defined here.
EXIT_PATCHING_ERROR="yes" # exit patching if failed
HOST="RB25F" # Uncouple hostname from board-id because the same board may have different branding
ROOTFSCACHE_VERSION=4
CHROOT_CACHE_VERSION=6
ROOTFS_CACHE_MAX=16 # max number of rootfs cache, older ones will be cleaned up

ROOTFS_TYPE=ext4 # default rootfs type is ext4

MAINLINE_KERNEL_SOURCE='http://github.com/identisoft/rb25f_linux.git'
MAINLINE_KERNEL_DIR='linux'

MAINLINE_UBOOT_SOURCE='http://github.com/identisoft/rb25f_u-boot.git'
MAINLINE_UBOOT_DIR='u-boot'

# Let's set default data if not defined in board configuration above
[[ -z $OFFSET ]] && OFFSET=4 # offset to 1st partition (we use 4MiB boundaries by default)
ARCH=armhf
KERNEL_IMAGE_TYPE=zImage
SERIALCON=ttyS0

# set unique mounting directory
SDCARD="$SRC/.tmp/rootfs-${BRANCH}-${BOARD}-${RELEASE}"
MOUNT="$SRC/.tmp/mount-${BRANCH}-${BOARD}-${RELEASE}"
DESTIMG="$SRC/.tmp/image-${BRANCH}-${BOARD}-${RELEASE}"

[[ ! -f $SRC/config/sources/$LINUXFAMILY.conf ]] && \
	exit_with_error "Sources configuration not found" "$LINUXFAMILY"

source $SRC/config/sources/$LINUXFAMILY.conf

[[ -n $ATFSOURCE && -z $ATF_USE_GCC ]] && exit_with_error "Error in configuration: ATF_USE_GCC is unset"
[[ -z $UBOOT_USE_GCC ]] && exit_with_error "Error in configuration: UBOOT_USE_GCC is unset"
[[ -z $KERNEL_USE_GCC ]] && exit_with_error "Error in configuration: KERNEL_USE_GCC is unset"

[[ -z $KERNEL_COMPILER ]] && KERNEL_COMPILER="aarch64-linux-gnu-"
[[ -z $UBOOT_COMPILER ]] && UBOOT_COMPILER="aarch64-linux-gnu-"
ATF_COMPILER="aarch64-linux-gnu-"
[[ -z $INITRD_ARCH ]] && INITRD_ARCH=arm64
QEMU_BINARY="qemu-aarch64-static"
ARCHITECTURE=arm64

BOOTCONFIG_VAR_NAME=BOOTCONFIG_${BRANCH^^}
[[ -n ${!BOOTCONFIG_VAR_NAME} ]] && BOOTCONFIG=${!BOOTCONFIG_VAR_NAME}
[[ -z $LINUXCONFIG ]] && LINUXCONFIG="linux-${LINUXFAMILY}-${BRANCH}"
[[ -z $BOOTPATCHDIR ]] && BOOTPATCHDIR="u-boot-$LINUXFAMILY"
[[ -z $KERNELPATCHDIR ]] && KERNELPATCHDIR="$LINUXFAMILY-$BRANCH"

DISTRIBUTION="Debian"

#TODO Go through these for Final package selection
# Essential packages
PACKAGE_LIST="bc bridge-utils build-essential cpufrequtils device-tree-compiler figlet fbset fping \
	fake-hwclock psmisc ntp parted rsync sudo curl linux-base dialog \
	ncurses-term python3-apt sysfsutils toilet u-boot-tools \
	usbutils console-setup unicode-data openssh-server initramfs-tools \
	ca-certificates resolvconf expect iptables automake \
	bison flex libwrap0-dev libssl-dev libnl-3-dev libnl-genl-3-dev \
	gdbserver libjson-c3 libmosquitto1 libmosquittopp1 libuuid1 \
	mosquitto-clients ntpdate strace libusb-1.0-0-dev beep memtool socat"

# Non-essential packages
PACKAGE_LIST_ADDITIONAL="armbian-firmware alsa-utils iotop iozone3 stress sysbench screen \
	vim pciutils evtest htop pv lsof apt-transport-https libfuse2 libdigest-sha-perl \
	libproc-processtable-perl aptitude dnsutils f3 haveged vlan sysstat bash-completion \
	hostapd git ethtool unzip ifenslave command-not-found libpam-systemd iperf3 \
	software-properties-common libnss-myhostname f2fs-tools avahi-autoipd iputils-arping qrencode libpcap0.8 tcpdump \
	libnss-resolve libpython2.7 sqlite3 libwbclient0 samba-libs python-samba samba-common samba-common-bin \
	winbind libnss-winbind libpam-winbind libcups2 gpgv gnupg2
	libavahi-client3 libtalloc2 libtdb1 libtevent0 libldb1 python-crypto python-ldb python-tdb \
	python-talloc libnss-mdns base-files"

PACKAGE_LIST_RELEASE="man-db less kbd net-tools netcat-openbsd gnupg2 dirmngr"

#DEBIAN_MIRROR='httpredir.debian.org/debian'
DEBIAN_MIRROR='debian.mirror.ac.za/debian'
#UBUNTU_MIRROR='ports.ubuntu.com/'

APT_MIRROR=$DEBIAN_MIRROR

[[ -n $APT_PROXY_ADDR ]] && display_alert "Using custom apt-cacher-ng address" "$APT_PROXY_ADDR" "info"

# Base system dependencies
DEBOOTSTRAP_LIST="locales,gnupg,ifupdown,apt-transport-https,ca-certificates"
DEBOOTSTRAP_COMPONENTS="main"

# Build final package list after possible override
PACKAGE_LIST="$PACKAGE_LIST $PACKAGE_LIST_RELEASE $PACKAGE_LIST_ADDITIONAL"

cat <<-EOF >> $DEST/debug/output.log

## BUILD SCRIPT ENVIRONMENT

Repository: $(git remote get-url $(git remote 2>/dev/null) 2>/dev/null)
Version: $(git describe --match=d_e_a_d_b_e_e_f --always --dirty 2>/dev/null)

Host OS: $(lsb_release -sc)
Host arch: $(dpkg --print-architecture)
Host system: $(uname -a)
Virtualization type: $(systemd-detect-virt)

## Build script directories
Build directory is located on:
$(findmnt -o TARGET,SOURCE,FSTYPE,AVAIL -T $SRC)

Build directory permissions:
$(getfacl -p $SRC)

Temp directory permissions:
$(getfacl -p $SRC/.tmp)

## BUILD CONFIGURATION

Build target:
Board: $BOARD
Branch: $BRANCH

Kernel configuration:
Repository: $KERNELSOURCE
Branch: $KERNELBRANCH
Config file: $LINUXCONFIG

U-boot configuration:
Repository: $BOOTSOURCE
Branch: $BOOTBRANCH
Config file: $BOOTCONFIG

Partitioning configuration:
Root partition type: $ROOTFS_TYPE
Boot partition type: ${BOOTFS_TYPE:-(none)}
User provided boot partition size: ${BOOTSIZE:-0}
Offset: $OFFSET

CPU configuration:
$CPUMIN - $CPUMAX with $GOVERNOR
EOF
