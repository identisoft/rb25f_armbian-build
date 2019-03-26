# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build/

build_firmware()
{
	display_alert "Merging and packaging linux firmware" "@host" "info"

	local plugin_repo="http://github.com/identisoft/rb25f_linux_firmware.git"
	local plugin_dir="armbian-firmware${FULL}"
	[[ -d $SRC/cache/sources/$plugin_dir ]] && rm -rf $SRC/cache/sources/$plugin_dir
	
	if [[ $Build_Type == "release" ]]; then
		fetch_from_repo "http://github.com/identisoft/rb25f_armbian-firmware.git" "armbian-firmware" "tag:$product_issue" "cache/sources" "no" "yes"
	else
		fetch_from_repo "http://github.com/identisoft/rb25f_armbian-firmware.git" "armbian-firmware" "branch:master" "cache/sources" "no" "no"
	fi
	if [[ -n $FULL ]]; then
		if [[  $Build_Type == "release" ]]; then
			fetch_from_repo "$plugin_repo" "$plugin_dir/lib/firmware.git" "tag:$product_issue" "cache/sources" "no" "yes"
		else
			fetch_from_repo "$plugin_repo" "$plugin_dir/lib/firmware.git" "branch:master" "cache/sources" "no" "no"
		fi
	fi
	mkdir -p $SRC/cache/sources/$plugin_dir/lib/firmware
	# overlay our firmware
	cp -R $SRC/cache/sources/armbian-firmware/* $SRC/cache/sources/$plugin_dir/lib/firmware

	# cleanup what's not needed for sure
	rm -rf $SRC/cache/sources/$plugin_dir/lib/firmware/{amdgpu,amd-ucode,radeon,nvidia,matrox,.git}
	cd $SRC/cache/sources/$plugin_dir

	# set up control file
	mkdir -p DEBIAN
	cat <<-END > DEBIAN/control
	Package: armbian-firmware${FULL}
	Version: $REVISION
	Architecture: all
	Maintainer: $MAINTAINER <$MAINTAINERMAIL>
	Installed-Size: 1
	Replaces: linux-firmware, firmware-brcm80211, firmware-samsung, firmware-realtek, armbian-firmware${REPLACE}
	Section: kernel
	Priority: optional
	Description: Linux firmware${FULL}
	END

	cd $SRC/cache/sources
	# pack
	mv armbian-firmware${FULL} armbian-firmware${FULL}_${REVISION}_all
	fakeroot dpkg -b armbian-firmware${FULL}_${REVISION}_all >> $DEST/debug/install.log 2>&1
	mv armbian-firmware${FULL}_${REVISION}_all armbian-firmware${FULL}
	mv armbian-firmware${FULL}_${REVISION}_all.deb $DEST/debs/ || display_alert "Failed moving firmware package" "" "wrn"
}

FULL=""
REPLACE="-full"
[[ ! -f $DEST/debs/armbian-firmware_${REVISION}_all.deb ]] && build_firmware
FULL="-full"
REPLACE=""
[[ ! -f $DEST/debs/armbian-firmware${FULL}_${REVISION}_all.deb ]] && build_firmware

# install basic firmware by default
install_deb_chroot "$DEST/debs/armbian-firmware_${REVISION}_all.deb"
