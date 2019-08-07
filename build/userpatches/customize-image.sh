#!/bin/bash

# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build

# arguments: $RELEASE $LINUXFAMILY $BOARD $KERNELVERSION
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
Kernel_Version=$4


Main() {
	Src_Dir="/tmp/overlay"
	cd /
	cd /
	cp -rv "$Src_Dir"/etc /
	cp -rv "$Src_Dir"/usr /

	# Copy Revision File
	cd /root
	
	install_fixup_script
	apt install -y winbind libnss-winbind libpam-winbind --fix-missing

	cd /
	
	
	#Network Fixes
	rm /etc/resolv.conf
	rm /etc/resolvconf/resolv.conf.d/head
	touch /etc/resolv.conf
	touch /etc/resolvconf/resolv.conf.d/head
	cd /
} # Main

Main "$@"
