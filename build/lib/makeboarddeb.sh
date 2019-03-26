# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build/

# Create board support packages
#
# Functions:
# create_board_package
create_board_package()
{
	display_alert "Creating board support package" "$BOARD $BRANCH" "info"

	local destination=$SRC/.tmp/${RELEASE}/${CHOSEN_ROOTFS}_${REVISION}_${ARCH}
	rm -rf $destination
	mkdir -p $destination/DEBIAN

	# Replaces: base-files is needed to replace /etc/update-motd.d/ files on Xenial
	# Replaces: unattended-upgrades may be needed to replace /etc/apt/apt.conf.d/50unattended-upgrades
	# (distributions provide good defaults, so this is not needed currently)
	# Depends: linux-base is needed for "linux-version" command in initrd cleanup script
	cat <<-EOF > $destination/DEBIAN/control
	Package: linux-${RELEASE}-root-${DEB_BRANCH}${BOARD}
	Version: $REVISION
	Architecture: $ARCH
	Maintainer: $MAINTAINER <$MAINTAINERMAIL>
	Installed-Size: 1
	Section: kernel
	Priority: optional
	Depends: bash, linux-base, u-boot-tools, initramfs-tools
	Provides: armbian-bsp
	Conflicts: armbian-bsp
	Suggests: armbian-config
	Replaces: zram-config, base-files, armbian-tools-$RELEASE
	Recommends: bsdutils, parted, python3-apt, util-linux, toilet
	Description: Armbian tweaks for $RELEASE on $BOARD ($BRANCH branch)
	EOF

	# set up pre install script
	cat <<-EOF > $destination/DEBIAN/preinst
	#!/bin/sh
	[ "\$1" = "upgrade" ] && touch /var/run/.reboot_required
	[ -d "/boot/bin.old" ] && rm -rf /boot/bin.old
	[ -d "/boot/bin" ] && mv -f /boot/bin /boot/bin.old
	if [ -L "/etc/network/interfaces" ]; then
		cp /etc/network/interfaces /etc/network/interfaces.tmp
		rm /etc/network/interfaces
		mv /etc/network/interfaces.tmp /etc/network/interfaces
	fi
	# disable deprecated services
	systemctl disable armhwinfo.service log2ram.service >/dev/null 2>&1
	#
	[ -f "/etc/profile.d/activate_psd_user.sh" ] && rm /etc/profile.d/activate_psd_user.sh
	[ -f "/etc/profile.d/check_first_login.sh" ] && rm /etc/profile.d/check_first_login.sh
	[ -f "/etc/profile.d/check_first_login_reboot.sh" ] && rm /etc/profile.d/check_first_login_reboot.sh
	[ -f "/etc/profile.d/ssh-title.sh" ] && rm /etc/profile.d/ssh-title.sh
	#
	[ -f "/etc/update-motd.d/10-header" ] && rm /etc/update-motd.d/10-header
	[ -f "/etc/update-motd.d/30-sysinfo" ] && rm /etc/update-motd.d/30-sysinfo
	[ -f "/etc/update-motd.d/35-tips" ] && rm /etc/update-motd.d/35-tips
	[ -f "/etc/update-motd.d/40-updates" ] && rm /etc/update-motd.d/40-updates
	[ -f "/etc/update-motd.d/98-autoreboot-warn" ] && rm /etc/update-motd.d/98-autoreboot-warn
	[ -f "/etc/update-motd.d/99-point-to-faq" ] && rm /etc/update-motd.d/99-point-to-faq
	# Remove Ubuntu junk
	[ -f "/etc/update-motd.d/50-motd-news" ] && rm /etc/update-motd.d/50-motd-news
	[ -f "/etc/update-motd.d/80-esm" ] && rm /etc/update-motd.d/80-esm
	[ -f "/etc/update-motd.d/80-livepatch" ] && rm /etc/update-motd.d/80-livepatch
	# Remove distro unattended-upgrades config
	[ -f "/etc/apt/apt.conf.d/50unattended-upgrades" ] && rm /etc/apt/apt.conf.d/50unattended-upgrades
	#
	[ -f "/etc/apt/apt.conf.d/02compress-indexes" ] && rm /etc/apt/apt.conf.d/02compress-indexes
	[ -f "/etc/apt/apt.conf.d/02periodic" ] && rm /etc/apt/apt.conf.d/02periodic
	[ -f "/etc/apt/apt.conf.d/no-languages" ] && rm /etc/apt/apt.conf.d/no-languages
	[ -f "/etc/cron.daily/log2ram" ] && rm /etc/cron.daily/log2ram
	[ -f "/etc/default/log2ram.dpkg-dist" ] && rm /etc/default/log2ram.dpkg-dist
	[ -f "/etc/init.d/armhwinfo" ] && rm /etc/init.d/armhwinfo
	[ -f "/etc/logrotate.d/armhwinfo" ] && rm /etc/logrotate.d/armhwinfo
	[ -f "/etc/init.d/firstrun" ] && rm /etc/init.d/firstrun
	[ -f "/etc/init.d/resize2fs" ] && rm /etc/init.d/resize2fs
	[ -f "/lib/systemd/system/firstrun-config.service" ] && rm /lib/systemd/system/firstrun-config.service
	[ -f "/lib/systemd/system/firstrun.service" ] && rm /lib/systemd/system/firstrun.service
	[ -f "/lib/systemd/system/log2ram.service" ] && rm /lib/systemd/system/log2ram.service
	[ -f "/lib/systemd/system/resize2fs.service" ] && rm /lib/systemd/system/resize2fs.service
	[ -f "/usr/lib/armbian/apt-updates" ] && rm /usr/lib/armbian/apt-updates
	[ -f "/usr/lib/armbian/firstrun-config.sh" ] && rm /usr/lib/armbian/firstrun-config.sh
	[ -f "/usr/sbin/log2ram" ] && rm /usr/sbin/log2ram
	[ -f "/usr/share/log2ram/LICENSE" ] && rm -r /usr/share/log2ram
	# make a backup since we are unconditionally overwriting this on update
	[ -f "/etc/default/cpufrequtils" ] && cp /etc/default/cpufrequtils /etc/default/cpufrequtils.dpkg-old
	dpkg-divert --package linux-${RELEASE}-root-${DEB_BRANCH}${BOARD} --add --rename \
		--divert /etc/mpv/mpv-dist.conf /etc/mpv/mpv.conf
	exit 0
	EOF

	chmod 755 $destination/DEBIAN/preinst

	# postrm script
	cat <<-EOF > $destination/DEBIAN/postrm
	#!/bin/sh
	if [ remove = "\$1" ] || [ abort-install = "\$1" ]; then
		dpkg-divert --package linux-${RELEASE}-root-${DEB_BRANCH}${BOARD} --remove --rename \
			--divert /etc/mpv/mpv-dist.conf /etc/mpv/mpv.conf
		systemctl disable armbian-hardware-monitor.service armbian-hardware-optimize.service armbian-zram-config.service armbian-ramlog.service >/dev/null 2>&1
	fi
	exit 0
	EOF

	chmod 755 $destination/DEBIAN/postrm

	# set up post install script
	cat <<-EOF > $destination/DEBIAN/postinst
	#!/bin/sh
	[ ! -f "/etc/network/interfaces" ] && cp /etc/network/interfaces.default /etc/network/interfaces
	ln -sf /var/run/motd /etc/motd
	rm -f /etc/update-motd.d/00-header /etc/update-motd.d/10-help-text
	if [ -f "/boot/bin/$BOARD.bin" ] && [ ! -f "/boot/script.bin" ]; then ln -sf bin/$BOARD.bin /boot/script.bin >/dev/null 2>&1 || cp /boot/bin/$BOARD.bin /boot/script.bin; fi
	rm -f /usr/local/bin/h3disp /usr/local/bin/h3consumption
	if [ ! -f "/etc/default/armbian-motd" ]; then
		mv /etc/default/armbian-motd.dpkg-dist /etc/default/armbian-motd
	fi
	if [ ! -f "/etc/default/armbian-ramlog" ]; then
		mv /etc/default/armbian-ramlog.dpkg-dist /etc/default/armbian-ramlog
	fi
	if [ ! -f "/etc/default/armbian-zram-config" ]; then
		mv /etc/default/armbian-zram-config.dpkg-dist /etc/default/armbian-zram-config
	fi

	systemctl --no-reload enable armbian-hardware-monitor.service armbian-hardware-optimize.service armbian-zram-config.service armbian-ramlog.service >/dev/null 2>&1
	exit 0
	EOF

	chmod 755 $destination/DEBIAN/postinst

	# copy common files from a premade directory structure
	rsync -a $SRC/packages/bsp/common/* $destination/

	# trigger uInitrd creation after installation, to apply
	# /etc/initramfs/post-update.d/99-uboot
	cat <<-EOF > $destination/DEBIAN/triggers
	activate update-initramfs
	EOF

	# configure MIN / MAX speed for cpufrequtils
	cat <<-EOF > $destination/etc/default/cpufrequtils
	# WARNING: this file will be replaced on board support package (linux-root-...) upgrade
	ENABLE=true
	MIN_SPEED=$CPUMIN
	MAX_SPEED=$CPUMAX
	GOVERNOR=$GOVERNOR
	EOF

	# armhwinfo, firstrun, armbianmonitor, etc. config file
	cat <<-EOF > $destination/etc/armbian-release
	# PLEASE DO NOT EDIT THIS FILE
	BOARD=$BOARD
	BOARD_NAME="$BOARD_NAME"
	BOARDFAMILY=${BOARDFAMILY}
	VERSION=$REVISION
	LINUXFAMILY=$LINUXFAMILY
	BRANCH=$BRANCH
	ARCH=$ARCHITECTURE
	IMAGE_TYPE=$IMAGE_TYPE
	BOARD_TYPE=$BOARD_TYPE
	INITRD_ARCH=$INITRD_ARCH
	KERNEL_IMAGE_TYPE=$KERNEL_IMAGE_TYPE
	EOF

	# this is required for NFS boot to prevent deconfiguring the network on shutdown
	[[ $RELEASE == xenial || $RELEASE == stretch || $RELEASE == bionic ]] && sed -i 's/#no-auto-down/no-auto-down/g' $destination/etc/network/interfaces.default

	# install copy of boot script & environment file
	local bootscript_src=${BOOTSCRIPT%%:*}
	local bootscript_dst=${BOOTSCRIPT##*:}

	mkdir -p $destination/usr/share/armbian/
	cp $SRC/config/bootscripts/$bootscript_src $destination/usr/share/armbian/$bootscript_dst
	[[ -n $BOOTENV_FILE && -f $SRC/config/bootenv/$BOOTENV_FILE ]] && \
		cp $SRC/config/bootenv/$BOOTENV_FILE $destination/usr/share/armbian/armbianEnv.txt
	# add configuration for setting uboot environment from userspace with: fw_setenv fw_printenv

	# add some summary to the image
	fingerprint_image "$destination/etc/rb25f.txt"

	# fixing permissions (basic), reference: dh_fixperms
	find $destination -print0 2>/dev/null | xargs -0r chown --no-dereference 0:0
	find $destination ! -type l -print0 2>/dev/null | xargs -0r chmod 'go=rX,u+rw,a-s'

	# create board DEB file
	display_alert "Building package" "$CHOSEN_ROOTFS" "info"
	fakeroot dpkg-deb -b $destination ${destination}.deb >> $DEST/debug/install.log 2>&1
	mkdir -p $DEST/debs/$RELEASE/
	mv ${destination}.deb $DEST/debs/$RELEASE/
	# cleanup
	rm -rf $destination
}
