#!/bin/bash
#-------------------------------------------------------------------------
#                 Copyright 2018 Impro Technologies (Pty) Ltd
#                 P.O. Box 15407, Westmead, 3605
#-------------------------------------------------------------------------
# Project		:	Eureka
# File name		:	factorydefault.sh
# Author		:	Rashid Motala
#-------------------------------------------------------------------------
# Description  : This script is called to factory default the unit.
#-------------------------------------------------------------------------

echo -e "\nFactory defaulting...\n"

#-------------------------------------------------------------------------
# If there is a watchdog running, it should be stopped here
#-------------------------------------------------------------------------
# systemctl stop watchdog

#-------------------------------------------------------------------------
# Discovery Cleanup - Add Discovery cleanup here
#-------------------------------------------------------------------------
# systemctl stop discovery.service # This script stops running if triggered by discovery, and discovery exits
rm -vf /etc/discoveryd.conf  # Delete the conf file and the app will recreate the default file

#-------------------------------------------------------------------------
# IPLWall Cleanup - Add IPLWall cleanup here
#-------------------------------------------------------------------------
systemctl stop iplwall.service
rm -vf /usr/local/eureka/iplwall/cVars
rm -vf /usr/local/eureka/iplwall/upa
rm -vf /usr/local/eureka/iplwall/tables.db

#-------------------------------------------------------------------------
# Lumidigm Cleanup - Add Lumidigm cleanup here
#-------------------------------------------------------------------------
rm -rvf /usr/local/HID_Global/Lumidigm/var/lib/IDDB

#-------------------------------------------------------------------------
# hbserver Cleanup - Add hbserver cleanup here
#-------------------------------------------------------------------------
rm -vf /usr/local/eureka/hbserver/UsersConfig.json
rm -vf /usr/local/eureka/hbserver/primary.sqlite

#-------------------------------------------------------------------------
# System Cleanup
#-------------------------------------------------------------------------
rm -vf /var/log/apt/*
rm -vf /var/log/mosquitto/*
rm -vf /var/log/ntpstats/*
rm -vf /var/log/sysstat/*
rm -vf /var/log/unattended-upgrades/*
find /var/log -maxdepth 1 -type f -delete  # Should not do this unless the platform is rebooted

rm -vf /var/log.hdd/apt/*
rm -vf /var/log.hdd/mosquitto/*
rm -vf /var/log.hdd/ntpstats/*
rm -vf /var/log.hdd/sysstat/*
rm -vf /var/log.hdd/unattended-upgrades/*
find /var/log.hdd -maxdepth 1 -type f -delete  # Should not do this unless the platform is rebooted

rm -rvf .Trash-0
rm -rvf /lost+found/*
rm -rvf /var/tmp/*
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Reset Networking
#-------------------------------------------------------------------------
cp /etc/network/interfaces.default /etc/network/interfaces
# No need to bring the networking interfaces down-up because we are going to reboot
#/etc/init.d/network-manager restart

# Remove dhcp leases
rm -f /var/lib/dhcp/*
#rm -f /var/lib/NetworkManager/*
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Reset credentials and enable ssh in case it was switched off
#-------------------------------------------------------------------------
echo -e "masterkey\nmasterkey" | passwd -q
systemctl enable ssh
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Filesystem
#-------------------------------------------------------------------------
/sbin/fstrim -v /
/bin/sync
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Finish Off
#-------------------------------------------------------------------------
cat /dev/null > ~/.bash_history && history -c
sleep 5
reboot &
exit 0
#-------------------------------------------------------------------------

