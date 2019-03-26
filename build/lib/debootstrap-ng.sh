# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build/

# Functions:
# debootstrap_ng
# create_rootfs_cache
# prepare_partitions
# create_image

# debootstrap_ng
#
debootstrap_ng()
{
	display_alert "Starting rootfs and image building process for" "$BOARD $RELEASE" "info"

	# trap to unmount stuff in case of error/manual interruption
	trap unmount_on_exit INT TERM EXIT

	# stage: clean and create directories
	rm -rf $SDCARD $MOUNT
	mkdir -p $SDCARD $MOUNT $DEST/images $SRC/cache/rootfs

	# stage: verify tmpfs configuration and mount
	# default maximum size for tmpfs mount is 1/2 of available RAM
	# CLI needs ~1.2GiB+ (Xenial CLI), Desktop - ~2.8GiB+ (Xenial Desktop w/o HW acceleration)
	# calculate and set tmpfs mount to use 2/3 of available RAM
	local phymem=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 1024 * 2 / 3 )) # MiB
	local tmpfs_max_size=1500; 
	if [[ $FORCE_USE_RAMDISK == no ]]; then	local use_tmpfs=no
	elif [[ $FORCE_USE_RAMDISK == yes || $phymem -gt $tmpfs_max_size ]]; then
		local use_tmpfs=yes
	fi
	[[ -n $FORCE_TMPFS_SIZE ]] && phymem=$FORCE_TMPFS_SIZE

	[[ $use_tmpfs == yes ]] && mount -t tmpfs -o size=${phymem}M tmpfs $SDCARD

	# stage: prepare basic rootfs: unpack cache or create from scratch
	create_rootfs_cache

	# stage: install kernel and u-boot packages
	# install distribution and board specific applications
	install_distribution_specific
	install_common

	# install additional applications
	[[ $EXTERNAL == yes ]] && install_external_applications

	# install locally built packages
	#[[ $EXTERNAL_NEW == compile ]] && chroot_installpackages_local

	# install from apt.armbian.com
	[[ $EXTERNAL_NEW == prebuilt ]] && chroot_installpackages "yes"

	# stage: user customization script
	# NOTE: installing too many packages may fill tmpfs mount
	customize_image

	# clean up / prepare for making the image
	umount_chroot "$SDCARD"
	display_alert "Moving upgrade package files" "" ""
	
	cp $SRC/output/debs/linux-dtb-next-eureka_${REVISION}_arm64.deb $SRC/output/images
	mv $SRC/output/images/linux-dtb-next-eureka_${REVISION}_arm64.deb $SRC/output/images/linux-dtb-next-rb25f_${product_issue}_arm64.deb
	cp $SRC/output/debs/linux-image-next-eureka_${REVISION}_arm64.deb $SRC/output/images
	mv $SRC/output/images/linux-image-next-eureka_${REVISION}_arm64.deb $SRC/output/images/linux-image-next-rb25f_${product_issue}_arm64.deb
	cp $SRC/output/debs/linux-u-boot-next-rb25f_${REVISION}_arm64_upgrade.deb $SRC/output/images
	mv $SRC/output/images/linux-u-boot-next-rb25f_${REVISION}_arm64_upgrade.deb $SRC/output/images/linux-u-boot-next-rb25f_${product_issue}_arm64.deb

	post_debootstrap_tweaks
	prepare_partitions
	create_image

	# stage: unmount tmpfs
	[[ $use_tmpfs = yes ]] && umount $SDCARD

	rm -rf $SDCARD

	# remove exit trap
	trap - INT TERM EXIT
} #############################################################################

# create_rootfs_cache
#
# unpacks cached rootfs for $RELEASE or creates one
#
create_rootfs_cache()
{
	local packages_hash=$(get_package_list_hash)
	local cache_fname=$SRC/cache/rootfs/${RELEASE}-ng-$ARCH.$packages_hash.tar.lz4
	if [[ $Force_Rootfs_Rebuild == yes ]]; then
		display_alert "Forced rootfs rebuild is enabled - Clearing any previous rootfs" "" ""
		#if [[ -f $cache_fname ]]; then
			rm -rf $cache_fname
			cache_fname=""
		#fi
	fi
	local display_name=${RELEASE}-ng-$ARCH.${packages_hash:0:3}...${packages_hash:29}.tar.lz4
	if [[ -f $cache_fname && "$ROOT_FS_CREATE_ONLY" != "force" ]]; then
		local date_diff=$(( ($(date +%s) - $(stat -c %Y $cache_fname)) / 86400 ))
		display_alert "Extracting $display_name" "$date_diff days old" "info"
		pv -p -b -r -c -N "$display_name" "$cache_fname" | lz4 -dc | tar xp --xattrs -C $SDCARD/
	else
		display_alert "Creating new rootfs for" "$RELEASE" "info"

		# stage: debootstrap base system
		if [[ $NO_APT_CACHER != yes ]]; then
			# apt-cacher-ng apt-get proxy parameter
			local apt_extra="-o Acquire::http::Proxy=\"http://${APT_PROXY_ADDR:-localhost:3142}\""
			local apt_mirror="http://${APT_PROXY_ADDR:-localhost:3142}/$APT_MIRROR"
		else
			local apt_mirror="http://$APT_MIRROR"
		fi

		# fancy progress bars
		[[ -z $OUTPUT_DIALOG ]] && local apt_extra_progress="--show-progress -o DPKG::Progress-Fancy=1"

		display_alert "Installing base system" "Stage 1/2" "info"
		eval 'debootstrap --include=locales,gnupg,ifupdown ${PACKAGE_LIST_EXCLUDE:+ --exclude=${PACKAGE_LIST_EXCLUDE// /,}} \
			--arch=$ARCH --foreign $RELEASE $SDCARD/ $apt_mirror' \
			${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/debootstrap.log'} \
			${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Debootstrap (stage 1/2)..." $TTY_Y $TTY_X'} \
			${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

		[[ ${PIPESTATUS[0]} -ne 0 || ! -f $SDCARD/debootstrap/debootstrap ]] && exit_with_error "Debootstrap base system first stage failed"

		cp /usr/bin/$QEMU_BINARY $SDCARD/usr/bin/

		mkdir -p $SDCARD/usr/share/keyrings/
		cp /usr/share/keyrings/debian-archive-keyring.gpg $SDCARD/usr/share/keyrings/

		display_alert "Installing base system" "Stage 2/2" "info"
		eval 'chroot $SDCARD /bin/bash -c "/debootstrap/debootstrap --second-stage"' \
			${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/debootstrap.log'} \
			${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Debootstrap (stage 2/2)..." $TTY_Y $TTY_X'} \
			${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

		[[ ${PIPESTATUS[0]} -ne 0 || ! -f $SDCARD/bin/bash ]] && exit_with_error "Debootstrap base system second stage failed"

		mount_chroot "$SDCARD"

		# policy-rc.d script prevents starting or reloading services during image creation
		printf '#!/bin/sh\nexit 101' > $SDCARD/usr/sbin/policy-rc.d
		chroot $SDCARD /bin/bash -c "dpkg-divert --quiet --local --rename --add /sbin/initctl"
		chroot $SDCARD /bin/bash -c "dpkg-divert --quiet --local --rename --add /sbin/start-stop-daemon"
		printf '#!/bin/sh\necho "Warning: Fake start-stop-daemon called, doing nothing"' > $SDCARD/sbin/start-stop-daemon
		printf '#!/bin/sh\necho "Warning: Fake initctl called, doing nothing"' > $SDCARD/sbin/initctl
		chmod 755 $SDCARD/usr/sbin/policy-rc.d
		chmod 755 $SDCARD/sbin/initctl
		chmod 755 $SDCARD/sbin/start-stop-daemon

		# stage: configure language and locales
		display_alert "Configuring locales" "$DEST_LANG" "info"

		[[ -f $SDCARD/etc/locale.gen ]] && sed -i "s/^# $DEST_LANG/$DEST_LANG/" $SDCARD/etc/locale.gen
		eval 'LC_ALL=C LANG=C chroot $SDCARD /bin/bash -c "locale-gen $DEST_LANG"' ${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}
		eval 'LC_ALL=C LANG=C chroot $SDCARD /bin/bash -c "update-locale LANG=$DEST_LANG LANGUAGE=$DEST_LANG LC_MESSAGES=$DEST_LANG"' \
			${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

		if [[ -f $SDCARD/etc/default/console-setup ]]; then
			sed -e 's/CHARMAP=.*/CHARMAP="UTF-8"/' -e 's/FONTSIZE=.*/FONTSIZE="8x16"/' \
				-e 's/CODESET=.*/CODESET="guess"/' -i $SDCARD/etc/default/console-setup
			eval 'LC_ALL=C LANG=C chroot $SDCARD /bin/bash -c "setupcon --save"'
		fi

		# stage: create apt sources list
		create_sources_list "$RELEASE" "$SDCARD/"

		# stage: add armbian repository and install key
		echo "deb http://apt.armbian.com $RELEASE main ${RELEASE}-utils ${RELEASE}-desktop" > $SDCARD/etc/apt/sources.list.d/armbian.list

		cp $SRC/config/armbian.key $SDCARD
		eval 'chroot $SDCARD /bin/bash -c "cat armbian.key | apt-key add -"' \
			${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}
		rm -f $SDCARD/armbian.key

		# compressing packages list to gain some space
		echo "Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";" > $SDCARD/etc/apt/apt.conf.d/02compress-indexes
		echo "Acquire::Languages "none";" > $SDCARD/etc/apt/apt.conf.d/no-languages

		# add armhf arhitecture to arm64
		[[ $ARCH == arm64 ]] && eval 'LC_ALL=C LANG=C chroot $SDCARD /bin/bash -c "dpkg --add-architecture armhf"'

		# this should fix resolvconf installation failure in some cases
		chroot $SDCARD /bin/bash -c 'echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections'

		# stage: update packages list
		display_alert "Updating package list" "$RELEASE" "info"
		eval 'LC_ALL=C LANG=C chroot $SDCARD /bin/bash -c "apt-get -q -y $apt_extra update"' \
			${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/debootstrap.log'} \
			${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Updating package lists..." $TTY_Y $TTY_X'} \
			${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

		# stage: upgrade base packages from xxx-updates and xxx-backports repository branches
		display_alert "Upgrading base packages" "Armbian" "info"
		eval 'LC_ALL=C LANG=C chroot $SDCARD /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y -q \
			$apt_extra $apt_extra_progress upgrade"' \
			${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/debootstrap.log'} \
			${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Upgrading base packages..." $TTY_Y $TTY_X'} \
			${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

		# stage: install additional packages
		display_alert "Installing packages for" "Armbian" "info"
		eval 'LC_ALL=C LANG=C chroot $SDCARD /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt -y -q \
			$apt_extra $apt_extra_progress --no-install-recommends install $PACKAGE_LIST"' \
			${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/debootstrap.log'} \
			${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Installing Armbian system..." $TTY_Y $TTY_X'} \
			${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

		[[ ${PIPESTATUS[0]} -ne 0 ]] && exit_with_error "Installation of Armbian packages failed"

		# DEBUG: print free space
		echo -e "\nFree space:"
		eval 'df -h' ${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/debootstrap.log'}

		# stage: remove downloaded packages
		chroot $SDCARD /bin/bash -c "apt-get clean"

		# this is needed for the build process later since resolvconf generated file in /run is not saved
		rm -f $SDCARD/etc/resolv.conf
		echo 'nameserver 1.1.1.1' >> $SDCARD/etc/resolv.conf

		# stage: make rootfs cache archive
		display_alert "Ending debootstrap process and preparing cache" "$RELEASE" "info"
		sync
		# the only reason to unmount here is compression progress display
		# based on rootfs size calculation
		umount_chroot "$SDCARD"

		tar cp --xattrs --directory=$SDCARD/ --exclude='./dev/*' --exclude='./proc/*' --exclude='./run/*' --exclude='./tmp/*' \
			--exclude='./sys/*' . | pv -p -b -r -s $(du -sb $SDCARD/ | cut -f1) -N "$display_name" | lz4 -c > $cache_fname
	fi

	# used for internal purposes. Faster rootfs cache rebuilding
  if [[ -n "$ROOT_FS_CREATE_ONLY" ]]; then
		[[ $use_tmpfs = yes ]] && umount $SDCARD
		rm -rf $SDCARD
		# remove exit trap
		trap - INT TERM EXIT
        exit
	fi

	mount_chroot "$SDCARD"
} #############################################################################

# prepare_partitions
#
# creates image file, partitions and fs
# and mounts it to local dir
# FS-dependent stuff (boot and root fs partition types) happens here
#
prepare_partitions()
{
	display_alert "Preparing image file for rootfs" "$BOARD $RELEASE" "info"
	# possible partition combinations
	# /boot: none, ext4, ext2, fat (BOOTFS_TYPE)
	# root: ext4, btrfs, f2fs, nfs (ROOTFS_TYPE)

	# declare makes local variables by default if used inside a function
	# NOTE: mountopts string should always start with comma if not empty

	# array copying in old bash versions is tricky, so having filesystems as arrays
	# with attributes as keys is not a good idea
	declare -A parttype mkopts mkfs mountopts

	parttype[ext4]=ext4
	parttype[ext2]=ext2
	parttype[fat]=fat16
	parttype[f2fs]=ext4 # not a copy-paste error
	parttype[btrfs]=btrfs

	mkopts[fat]='-n BOOT'
	mkopts[ext2]='-q'

	mkfs[ext4]=ext4
	mkfs[ext2]=ext2
	mkfs[fat]=vfat
	mkfs[f2fs]=f2fs
	mkfs[btrfs]=btrfs

	mountopts[ext4]=',commit=2,errors=remount-ro'
	mountopts[btrfs]=',commit=600,compress=lzo'

	local rootpart=1
	BOOTSIZE=0

	# stage: calculate rootfs size
	local rootfs_size=$(du -sm $SDCARD/ | cut -f1) # MiB
	display_alert "Current rootfs size" "$rootfs_size MiB" "info"
	local imagesize=$(( $rootfs_size + $OFFSET + $BOOTSIZE )) # MiB
	local sdsize=$(bc -l <<< "scale=0; ((($imagesize * 1.15) / 1 + 0) / 4 + 1) * 4")
	# stage: create blank image
	display_alert "Creating blank image for rootfs" "$sdsize MiB" "info"
	dd if=/dev/zero bs=1M status=none count=$sdsize | pv -p -b -r -s $(( $sdsize * 1024 * 1024 )) | dd status=none of=${SDCARD}.raw
	# stage: calculate boot partition size
	local bootstart=$(($OFFSET * 2048))
	local rootstart=$(($bootstart + ($BOOTSIZE * 2048)))
	local bootend=$(($rootstart - 1))

	# stage: create partition table
	display_alert "Creating partitions" "${bootfs:+/boot: $bootfs }root: $ROOTFS_TYPE" "info"
	parted -s ${SDCARD}.raw -- mklabel msdos
	parted -s ${SDCARD}.raw -- mkpart primary ${parttype[$ROOTFS_TYPE]} ${rootstart}s -1s
	# stage: mount image
	# lock access to loop devices
	exec {FD}>/var/lock/armbian-debootstrap-losetup
	flock -x $FD

	LOOP=$(losetup -f)
	[[ -z $LOOP ]] && exit_with_error "Unable to find free loop device"

	check_loop_device "$LOOP"

	# NOTE: losetup -P option is not available in Trusty
	losetup $LOOP ${SDCARD}.raw

	# loop device was grabbed here, unlock
	flock -u $FD

	partprobe $LOOP

	# stage: create fs, mount partitions, create fstab
	rm -f $SDCARD/etc/fstab
	local rootdevice="${LOOP}p${rootpart}"
	display_alert "Creating rootfs" "$ROOTFS_TYPE"
	check_loop_device "$rootdevice"
	mkfs.${mkfs[$ROOTFS_TYPE]} ${mkopts[$ROOTFS_TYPE]} $rootdevice
	tune2fs -o journal_data_writeback $rootdevice > /dev/null
	mount ${fscreateopt} $rootdevice $MOUNT/
	local rootfs="UUID=$(blkid -s UUID -o value $rootdevice)"
	echo "$rootfs / ${mkfs[$ROOTFS_TYPE]} defaults,noatime,nodiratime${mountopts[$ROOTFS_TYPE]} 0 1" >> $SDCARD/etc/fstab
	echo "tmpfs /tmp tmpfs defaults,nosuid 0 0" >> $SDCARD/etc/fstab

	# stage: adjust boot script or boot environment
	echo "rootdev=$rootfs" >> $SDCARD/boot/armbianEnv.txt
	echo "rootfstype=$ROOTFS_TYPE" >> $SDCARD/boot/armbianEnv.txt

	# recompile .cmd to .scr if boot.cmd exists
	[[ -f $SDCARD/boot/boot.cmd ]] && \
		mkimage -C none -A arm -T script -d $SDCARD/boot/boot.cmd $SDCARD/boot/boot.scr > /dev/null 2>&1

} #############################################################################

# create_image
#
# finishes creation of image from cached rootfs
#
create_image()
{
	# stage: create file name
	local version="RB25F_${product_issue}_${DISTRIBUTION}_${RELEASE}_${BRANCH}_${VER/-$LINUXFAMILY/}"

	display_alert "Copying files to root directory"
	rsync -aHWXh --exclude="/boot/*" --exclude="/dev/*" --exclude="/proc/*" --exclude="/run/*" --exclude="/tmp/*" \
		--exclude="/sys/*" --info=progress2,stats1 $SDCARD/ $MOUNT/

	# stage: rsync /boot
	display_alert "Copying files to /boot directory"
	rsync -aHWXh --info=progress2,stats1 $SDCARD/boot $MOUNT

	# DEBUG: print free space
	display_alert "Free space:" "SD card" "info"
	eval 'df -h' ${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/debootstrap.log'}

	# stage: write u-boot
	write_uboot $LOOP

	# unmount /boot first, rootfs second, image file last
	sync
	[[ $BOOTSIZE != 0 ]] && umount -l $MOUNT/boot
	umount -l $MOUNT
	losetup -d $LOOP
	rm -rf --one-file-system $DESTIMG $MOUNT
	mkdir -p $DESTIMG
	cp $SDCARD/etc/rb25f.txt $DESTIMG
	mv ${SDCARD}.raw $DESTIMG/${version}.img

	mv $DESTIMG/${version}.img $DEST/images/${version}.img
	rm -rf $DESTIMG
	display_alert "Compressing" "$DEST/images/${version}.img" "info"
	gzip -f $DEST/images/${version}.img
	cd $DEST/images
	md5sum ${version}.img.gz > ${version}.md5

	display_alert "Done building" "$DEST/images/${version}.img.gz" "info"
} #############################################################################
