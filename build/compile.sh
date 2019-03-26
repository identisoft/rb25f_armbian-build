# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build/

#!/bin/bash

SRC="$(dirname "$(realpath "${BASH_SOURCE}")")"
# fallback for Trusty
[[ -z "${SRC}" ]] && SRC="$(pwd)"
Overlay_Dir=$1

# check for whitespace in $SRC and exit for safety reasons
grep -q "[[:space:]]" <<<"${SRC}" && { echo "\"${SRC}\" contains whitespace. Not supported. Aborting." >&2 ; exit 1 ; }

cd $SRC

source $SRC/lib/general.sh

# source build configuration file
display_alert "Reading Configuration" "" "info"
source $SRC/config-default.conf

if [[ $Build_Type == "release" ]]; then
	if [[ -z $GithubUser ]] || [[ -z $GithubPass ]]; then
		display_alert "Github Username and Password not set, disabling github tag creation" "" "wrn"
	fi
	if [[ -z $GitTokenName ]] || [[ -z $GitTokenPass ]]; then
		display_alert "Gitlab Token not set, disabling gitlab tag creation" "" "wrn"
	fi
fi

source $SRC/lib/main.sh
