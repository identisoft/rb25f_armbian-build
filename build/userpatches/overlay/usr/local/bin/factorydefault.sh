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
# Reset credentials and enable ssh in case it was switched off
#-------------------------------------------------------------------------
echo -e "masterkey\nmasterkey" | passwd -q &

# Enable possibly disabled services
systemctl enable ssh &
systemctl enable serial-getty@ttyS0 &
systemctl enable discovery &

#-------------------------------------------------------------------------
# Discovery Cleanup - Add Discovery cleanup here
#-------------------------------------------------------------------------
# systemctl stop discovery.service # This script stops running if triggered by discovery, and discovery exits
rm -f /etc/discoveryd.conf  # Delete the conf file and the app will recreate the default file

#-------------------------------------------------------------------------
# IPLWall Cleanup - Add IPLWall cleanup here
#-------------------------------------------------------------------------
#systemctl stop iplwall.service
rm -f /usr/local/eureka/iplwall/cVars
rm -f /usr/local/eureka/iplwall/upa
rm -f /usr/local/eureka/iplwall/tables.db

#-------------------------------------------------------------------------
# Lumidigm Cleanup - Add Lumidigm cleanup here
#-------------------------------------------------------------------------
rm -rf /usr/local/HID_Global/Lumidigm/var/lib/IDDB

#-------------------------------------------------------------------------
# hbserver Cleanup - Add hbserver cleanup here
#-------------------------------------------------------------------------
rm -f /usr/local/eureka/hbserver/UsersConfig.json
rm -f /usr/local/eureka/hbserver/primary.sqlite
rm -f /usr/local/eureka/hbserver/certificates/*.pem

#-------------------------------------------------------------------------
# System Cleanup
#-------------------------------------------------------------------------
rm -f /var/log/apt/*
rm -f /var/log/mosquitto/*
rm -f /var/log/ntpstats/*
rm -f /var/log/sysstat/*
rm -f /var/log/unattended-upgrades/*
find /var/log -maxdepth 1 -type f -delete  # Should not do this unless the platform is rebooted

rm -f /var/log.hdd/apt/*
rm -f /var/log.hdd/mosquitto/*
rm -f /var/log.hdd/ntpstats/*
rm -f /var/log.hdd/sysstat/*
rm -f /var/log.hdd/unattended-upgrades/*
find /var/log.hdd -maxdepth 1 -type f -delete  # Should not do this unless the platform is rebooted

rm -rf .Trash-0
rm -rf /lost+found/*
rm -rf /var/tmp/*
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

#-------------------------------------------------------------------------
# Filesystem
#-------------------------------------------------------------------------
/sbin/fstrim /
/bin/sync
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Finish Off
#-------------------------------------------------------------------------
cat /dev/null > ~/.bash_history && history -c
#sleep 5
reboot &
exit 0
#-------------------------------------------------------------------------

