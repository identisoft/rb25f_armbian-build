# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build/

# Main program

if [[ $(basename $0) == main.sh ]]; then
	echo "Please use build.sh from the Eureka-Image-Build directory to start the build process"
	exit -1
fi

# default umask for root is 022 so parent directories won't be group writeable without this
# this is used instead of making the chmod in prepare_host() recursive
umask 002

# destination
DEST=$SRC/output

TTY_X=$(($(stty size | awk '{print $2}')-6)) # determine terminal width
TTY_Y=$(($(stty size | awk '{print $1}')-6)) # determine terminal height

# if language not set, set to english
[[ -z $LANGUAGE ]] && export LANGUAGE="en_US:en"

# default console if not set
[[ -z $CONSOLE_CHAR ]] && export CONSOLE_CHAR="UTF-8"

[[ -z $FORCE_CHECKOUT ]] && FORCE_CHECKOUT=yes

get_product_issue

# Load libraries
source $SRC/lib/debootstrap-ng.sh 					# System specific install
source $SRC/lib/image-helpers.sh						# helpers for OS image building
source $SRC/lib/distributions.sh 						# System specific install
source $SRC/lib/compilation.sh 							# Patching and compilation of kernel, uboot, ATF
source $SRC/lib/makeboarddeb.sh 						# Create board support package
source $SRC/lib/general.sh									# General functions
source $SRC/lib/chroot-buildpackages.sh			# Building packages in chroot

# compress and remove old logs
mkdir -p $DEST/debug
(cd $DEST/debug && tar -czf logs-$(<timestamp).tgz *.log) > /dev/null 2>&1
rm -f $DEST/debug/*.log > /dev/null 2>&1
date +"%d_%m_%Y-%H_%M_%S" > $DEST/debug/timestamp
# delete compressed logs older than 7 days
(cd $DEST/debug && find . -name '*.tgz' -mtime +7 -delete) > /dev/null

if [[ $PROGRESS_DISPLAY == none ]]; then
	OUTPUT_VERYSILENT=yes
elif [[ $PROGRESS_DISPLAY == dialog ]]; then
	OUTPUT_DIALOG=yes
fi
if [[ $PROGRESS_LOG_TO_FILE != yes ]]; then unset PROGRESS_LOG_TO_FILE; fi

SHOW_WARNING=yes

if [[ $USE_CCACHE != no ]]; then
	CCACHE=ccache
	export PATH="/usr/lib/ccache:$PATH"
	# private ccache directory to avoid permission issues when using build script with "sudo"
	# see https://ccache.samba.org/manual.html#_sharing_a_cache for alternative solution
	[[ $PRIVATE_CCACHE == yes ]] && export CCACHE_DIR=$SRC/cache/ccache
else
	CCACHE=""
fi

# Check and install dependencies, directory structure and settings
prepare_host

source $SRC/config/boards/${BOARD}.conf
LINUXFAMILY="${BOARDFAMILY}"

[[ -z $KERNEL_TARGET ]] && exit_with_error "Board configuration does not define valid kernel config"

source $SRC/lib/configuration.sh

# Create a Revision and build date Files 
mkdir -p $SRC/userpatches/overlay/sources
touch $SRC/userpatches/overlay/sources/buildrevision
touch $SRC/userpatches/overlay/sources/buildepoch
touch $SRC/userpatches/overlay/sources/builddate.sh
echo "Filesystem_Version $REVISION" | tee $SRC/userpatches/overlay/sources/buildrevision
date +"%s" | tee $SRC/userpatches/overlay/sources/buildepoch
date +"sudo echo %s seconds from epoch, %c" | tee $SRC/userpatches/overlay/sources/builddate.sh

# optimize build time with 100% CPU usage
CPUS=$(grep -c 'processor' /proc/cpuinfo)
CTHREADS="-j$(($CPUS + $CPUS/2))"

start=`date +%s`

[[ $CLEAN_LEVEL == *sources* ]] && cleaning "sources"

# ignore updates help on building all images - for internal purposes
# fetch_from_repo <url> <dir> <ref> <subdir_flag>
if [[ $IGNORE_UPDATES != yes ]]; then
	display_alert "Downloading sources" "" "info"
	if [[ $Build_Type == "release" ]]; then
		fetch_from_repo "$SPLSOURCE" "SPLSOURCEDIR" "$SPLBRANCH" "no" "no"
		fetch_from_repo "$BOOTSOURCE" "$BOOTDIR" "$BOOTBRANCH" "no" "yes"
		fetch_from_repo "$KERNELSOURCE" "$KERNELDIR" "$KERNELBRANCH" "no" "yes"
		fetch_from_repo "$ATFSOURCE" "$ATFDIR" "$ATFBRANCH" "no" "yes"
		fetch_from_repo "http://github.com/identisoft/rb25f_sunxi-tools" "sunxi-tools" "tag:$product_issue" "no" "yes"
	else
		fetch_from_repo "$SPLSOURCE" "$SPLSOURCEDIR" "$SPLBRANCH" "no" "no"
		fetch_from_repo "$BOOTSOURCE" "$BOOTDIR" "$BOOTBRANCH" "no" "no"
		fetch_from_repo "$KERNELSOURCE" "$KERNELDIR" "$KERNELBRANCH" "no" "no"
		fetch_from_repo "$ATFSOURCE" "$ATFDIR" "$ATFBRANCH" "no" "no"
		fetch_from_repo "http://github.com/identisoft/rb25f_sunxi-tools" "sunxi-tools" "branch:master" "no" "no"
	fi
fi


IMAGE_TYPE=HID

compile_sunxi_tools

BOOTSOURCEDIR=$BOOTDIR
LINUXSOURCEDIR=$KERNELDIR
[[ -n $ATFSOURCE ]] && ATFSOURCEDIR=$ATFDIR

# define package names
DEB_BRANCH=${BRANCH//default}
# if not empty, append hyphen
DEB_BRANCH=${DEB_BRANCH:+${DEB_BRANCH}-}
CHOSEN_UBOOT=linux-u-boot-${DEB_BRANCH}${BOARD}
CHOSEN_KERNEL=linux-image-${DEB_BRANCH}${LINUXFAMILY}
CHOSEN_ROOTFS=linux-${RELEASE}-root-${DEB_BRANCH}${BOARD}
CHOSEN_KSRC=linux-source-${BRANCH}-${LINUXFAMILY}

for option in $(tr ',' ' ' <<< "$CLEAN_LEVEL"); do
	[[ $option != sources ]] && cleaning "$option"
done

# Compile u-boot if packed .deb does not exist
if [[ ! -f $DEST/images/felboot/bin/bl31.bin ]] || [[ ${FORCE_ATF_REBUILD} == "yes" ]]; then
	if [[ ${SKIP_ATF_BUILD} != yes ]]; then
  		compile_atf
  	fi
fi

if [[ ! -f $DEST/debs/${CHOSEN_UBOOT}_${REVISION}_${ARCH}.deb ]] || [[ $Force_Uboot_Rebuild == "yes" ]]; then
	if [[ -n $ATFSOURCE ]]; then
		compile_atf
	fi
	compile_uboot
fi

# Compile SPL and u-boot for fel booting
if [[ ! -f $DEST/images/felboot/bin/sunxi-spl.bin ]] || [[ ${FORCE_SPL_REBUILD} == "yes" ]]; then
#	if [[ ${SKIP_SPL_BUILD} != yes ]]; then 
		compile_spl
#	fi
fi

if [[ ! -f $DEST/images/felboot/bin/u-boot.bin ]] || [[ ${FORCE_FEL_UBOOT_REBUILD} == "yes" ]]; then 
#	if [[ ${SKIP_FEL_UBOOT_BUILD} != yes ]]; then
		compile_fel_uboot
#	fi
fi

# Compile kernel if packed .deb does not exist
if [[ ! -f $DEST/debs/${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb ]] || [[ $Force_Kernel_Rebuild == "yes" ]]; then
	compile_kernel
fi

echo "product_issue=$product_issue" > /$SRC/userpatches/overlay/etc/product_issue
overlayfs_wrapper "cleanup"

# extract kernel version from .deb package
VER=$(dpkg --info $DEST/debs/${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb | grep Descr | awk '{print $(NF)}')
VER="${VER/-$LINUXFAMILY/}"

# create board support package
[[ -n $RELEASE && ! -f $DEST/debs/$RELEASE/${CHOSEN_ROOTFS}_${REVISION}_${ARCH}.deb ]] && create_board_package

# build additional packages
[[ $EXTERNAL_NEW == compile ]] && chroot_build_packages

debootstrap_ng

# hook for function to run after build, i.e. to change owner of $SRC
# NOTE: this will run only if there were no errors during build process
[[ $(type -t run_after_build) == function ]] && run_after_build || true


end=`date +%s`
runtime=$(((end-start)/60))
display_alert "Runtime" "$runtime min" "info"
