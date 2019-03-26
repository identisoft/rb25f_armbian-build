#!/bin/bash
# Copyright (c) 2019 Impro Technologies support@im**.net
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.


if [[ $EUID != 0 ]]; then
	echo "This script requires root privileges, trying to use sudo"
	sudo "./build.sh" "$@"
	exit $?
fi

Overlay_Dir="$(pwd)"

source build/lib/general.sh

if [[ ! -f ../build/.ignore_changes ]]; then
	display_alert "This script will try to update" "" ""
	git pull 
	CHANGED_FILES=$(git diff --name-only)
	if [[ -n $CHANGED_FILES ]]; then
		display_alert "Can't update since you made changes to: ${CHANGED_FILES}" "" "wrn"
		echo -e "Press \e[0;33m<Ctrl-C>\x1B[0m to abort, \e[0;33m<Enter>\x1B[0m to ignore and continue"
		read
	fi
else
	display_alert "ignore_changes enabled, skipping update" "" "wrn"
fi
 
display_alert "Checking Build Directory" "" ""
if [ ! -d "../build" ]; then
	mkdir ../build
fi

if [[ -d ../build/lib ]]; then
	rm -fr ../build/lib
	rm -fr ../build/config
	rm -fr ../build/packages
	rm -fr ../build/patch
	rm -fr ../build/userpatches/atf
	rm -f ../build/userpatches/customize-image.sh
	rm -fr ../build/userpatches/kernel
	rm -fr ../build/userpatches/misc
	rm -fr ../build/userpatches/u-boot
	rm -fr ../build/userpatches/overlay/boot
	rm -fr ../build/userpatches/overlay/conf
	rm -fr ../build/userpatches/overlay/etc
	rm -fr ../build/userpatches/overlay/lib
	rm -fr ../build/userpatches/overlay/u-boot
	rm -fr ../build/userpatches/overlay/usr
	rm -fr ../build/userpatches/overlay/var
	rm -fr ../build/*.sh
fi

cp -a build/lib ../build
cp -a build/config ../build
cp -a build/packages ../build
cp -a build/patch ../build
cp -a build/userpatches ../build
cp -a build/*.sh ../build
if [[ ! -f ../build/config-default.conf ]]; then
	cp -a build/config-default.conf ../build
fi

cp -a build/LICENSE ../build

cd ../build
if [ -d "output/patch" ]; then
	sudo rm -r output/patch
fi
display_alert "Starting build" "" "info"
./compile.sh "$Overlay_Dir"


