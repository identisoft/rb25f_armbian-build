# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build/

# Functions:
# install_common
# install_distribution_specific
# post_debootstrap_tweaks

install_common()
{
	display_alert "Applying common tweaks" "" "info"
	# define ARCH within global environment variables
	[[ -f $SDCARD/etc/environment ]] && echo "ARCH=${ARCH//hf}" >> $SDCARD/etc/environment

	# add dummy fstab entry to make mkinitramfs happy
	echo "/dev/mmcblk0p1 / $ROOTFS_TYPE defaults 0 1" >> $SDCARD/etc/fstab
	# required for initramfs-tools-core on Stretch since it ignores the / fstab entry
	echo "/dev/mmcblk0p2 /usr $ROOTFS_TYPE defaults 0 2" >> $SDCARD/etc/fstab
	
	# create modules file
	tr ' ' '\n' <<< "$MODULES_NEXT" > $SDCARD/etc/modules

	# remove default interfaces file if present
	# before installing board support package
	rm -f $SDCARD/etc/network/interfaces

	mkdir -p $SDCARD/selinux

	# remove Ubuntu's legal text
	[[ -f $SDCARD/etc/legal ]] && rm $SDCARD/etc/legal

	# console fix due to Debian bug
	sed -e 's/CHARMAP=".*"/CHARMAP="'$CONSOLE_CHAR'"/g' -i $SDCARD/etc/default/console-setup
	# change time zone data
	echo $TZDATA > $SDCARD/etc/timezone
	chroot $SDCARD /bin/bash -c "dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1"

	# set root password
	chroot $SDCARD /bin/bash -c "(echo $ROOTPWD;echo $ROOTPWD;) | passwd root >/dev/null 2>&1"

	# NOTE: this needs to be executed before family_tweaks
	local bootscript_src=${BOOTSCRIPT%%:*}
	local bootscript_dst=${BOOTSCRIPT##*:}
	cp $SRC/config/bootscripts/$bootscript_src $SDCARD/boot/$bootscript_dst

	[[ -n $BOOTENV_FILE && -f $SRC/config/bootenv/$BOOTENV_FILE ]] && \
		cp $SRC/config/bootenv/$BOOTENV_FILE $SDCARD/boot/armbianEnv.txt

	#TODO This should be removed later once we're actually running to new rtc
	# initial date for fake-hwclock
	date -u '+%Y-%m-%d %H:%M:%S' > $SDCARD/etc/fake-hwclock.data

	echo $HOST > $SDCARD/etc/hostname

	# set hostname in hosts file
	cat <<-EOF > $SDCARD/etc/hosts
	127.0.0.1   localhost $HOST
	::1         localhost $HOST ip6-localhost ip6-loopback
	fe00::0     ip6-localnet
	ff00::0     ip6-mcastprefix
	ff02::1     ip6-allnodes
	ff02::2     ip6-allrouters
	EOF

	# install kernel and u-boot packages
	install_deb_chroot "$DEST/debs/${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb"
	install_deb_chroot "$DEST/debs/${CHOSEN_UBOOT}_${REVISION}_${ARCH}.deb"

	install_deb_chroot "$DEST/debs/${CHOSEN_KERNEL/image/headers}_${REVISION}_${ARCH}.deb"

	if [[ -f $DEST/debs/armbian-firmware_${REVISION}_${ARCH}.deb ]]; then
		install_deb_chroot "$DEST/debs/armbian-firmware_${REVISION}_${ARCH}.deb"
	fi

	if [[ -f $DEST/debs/${CHOSEN_KERNEL/image/dtb}_${REVISION}_${ARCH}.deb ]]; then
		install_deb_chroot "$DEST/debs/${CHOSEN_KERNEL/image/dtb}_${REVISION}_${ARCH}.deb"
	fi

	# install board support package
	install_deb_chroot "$DEST/debs/$RELEASE/${CHOSEN_ROOTFS}_${REVISION}_${ARCH}.deb"

	# freeze armbian packages
	if [[ $BSPFREEZE == yes ]]; then
		display_alert "Freezing Armbian packages" "$BOARD" "info"
		chroot $SDCARD /bin/bash -c "apt-mark hold ${CHOSEN_KERNEL} ${CHOSEN_KERNEL/image/headers} \
			linux-u-boot-${BOARD}-${BRANCH} ${CHOSEN_KERNEL/image/dtb}" >> $DEST/debug/install.log 2>&1
	fi

	# enable additional services
	chroot $SDCARD /bin/bash -c "systemctl --no-reload enable armbian-firstrun.service armbian-firstrun-config.service armbian-zram-config.service armbian-hardware-optimize.service armbian-ramlog.service armbian-resize-filesystem.service armbian-hardware-monitor.service >/dev/null 2>&1"

	# Cosmetic fix [FAILED] Failed to start Set console font and keymap at first boot
	[[ -f $SDCARD/etc/console-setup/cached_setup_font.sh ]] && sed -i "s/^printf '.*/printf '\\\033\%\%G'/g" $SDCARD/etc/console-setup/cached_setup_font.sh
	[[ -f $SDCARD/etc/console-setup/cached_setup_terminal.sh ]] && sed -i "s/^printf '.*/printf '\\\033\%\%G'/g" $SDCARD/etc/console-setup/cached_setup_terminal.sh
	[[ -f $SDCARD/etc/console-setup/cached_setup_keyboard.sh ]] && sed -i "s/-u/-x'/g" $SDCARD/etc/console-setup/cached_setup_keyboard.sh

	# disable deprecated parameter
	sed '/.*$KLogPermitNonKernelFacility.*/,// s/.*/#&/' -i $SDCARD/etc/rsyslog.conf

	# enable getty on serial console
	chroot $SDCARD /bin/bash -c "systemctl --no-reload enable serial-getty@$SERIALCON.service >/dev/null 2>&1"

	# save initial armbian-release state
	cp $SDCARD/etc/armbian-release $SDCARD/etc/armbian-image-release

	# DNS fix. package resolvconf is not available everywhere
	if [ -d /etc/resolvconf/resolv.conf.d ]; then
		echo 'nameserver 1.1.1.1' > $SDCARD/etc/resolvconf/resolv.conf.d/head
	fi

	# premit root login via SSH for the first boot
	sed -i 's/#\?PermitRootLogin .*/PermitRootLogin yes/' $SDCARD/etc/ssh/sshd_config

	# enable PubkeyAuthentication. Enabled by default everywhere except on Jessie
	sed -i 's/#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' $SDCARD/etc/ssh/sshd_config
}

install_distribution_specific()
{
	display_alert "Applying distribution specific tweaks for" "$RELEASE" "info"
	[[ -f $SDCARD/etc/update-motd.d/10-uname ]] && rm $SDCARD/etc/update-motd.d/10-uname
	# DNS fix
	sed -i "s/#DNS=.*/DNS=8.8.8.8/g" $SDCARD/etc/systemd/resolved.conf
}

post_debootstrap_tweaks()
{
	# remove service start blockers and QEMU binary
	rm -f $SDCARD/sbin/initctl $SDCARD/sbin/start-stop-daemon
	chroot $SDCARD /bin/bash -c "dpkg-divert --quiet --local --rename --remove /sbin/initctl"
	chroot $SDCARD /bin/bash -c "dpkg-divert --quiet --local --rename --remove /sbin/start-stop-daemon"

	chroot $SDCARD /bin/bash -c 'echo "resolvconf resolvconf/linkify-resolvconf boolean true" | debconf-set-selections'
	mkdir -p $SDCARD/var/lib/resolvconf/
	:> $SDCARD/var/lib/resolvconf/linkified

	rm -f $SDCARD/usr/sbin/policy-rc.d $SDCARD/usr/bin/$QEMU_BINARY

	# reenable resolvconf managed resolv.conf
	ln -sf /run/resolvconf/resolv.conf $SDCARD/etc/resolv.conf
}
