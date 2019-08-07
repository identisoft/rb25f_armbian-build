#!/bin/bash
# This script sets the hostname to include the MAC address.

HOSTNAME_FULL=$(</etc/hostname)
HOSTNAME=$(/usr/bin/head -n 1 /etc/hostname)
MAC_PREFIX=$(/usr/local/bin/get_mac | awk '{print substr($1,0,9)}')
if [ "$HOSTNAME_FULL" != "$HOSTNAME" ]; then
  echo "$HOSTNAME" > /etc/hostname
fi

if [ -z "$HOSTNAME" ] || [ "$HOSTNAME" == "127.0.0" ] || [ "$HOSTNAME" == "RB25F-" ]; then
	if [ $MAC_PREFIX == "00:1A:6E" ]; then #Impro mac addr
		HOSTNAME="HRB910"
	else
	  HOSTNAME="RB25F"
	fi
fi
IP="$(/usr/local/bin/get_ipv4)"
MAC="$(/usr/local/bin/get_mac)"
MAC="${MAC//:/}"
# MAC="${MAC:4}" # This would be fixed address

FA="$(/usr/local/bin/get_fixed_address)"
BCAST="$(/usr/local/bin/get_ipv4_broadcast)"
CURR_DATE=$(date)

if [ "$MAC_PREFIX" == "00:1A:6E" ]; then #Impro mac addr
	HOSTNAME_NEW="HRB910-"$MAC""
else
	HOSTNAME_NEW="RB25F-"$MAC""
fi

if [ ! "$HOSTNAME" == "$HOSTNAME_NEW" ]; then
  HOSTNAME_START=$(echo "$HOSTNAME" | cut -c 1-5)
  if [ "$HOSTNAME_START" == "RB25F" ]; then
    echo "Changing Hostname $HOSTNAME to $HOSTNAME_NEW"
    echo "$HOSTNAME_NEW" > /etc/hostname
    /bin/hostname $HOSTNAME_NEW
    HOSTNAME=$HOSTNAME_NEW
  fi
fi

/bin/sed  -e 's/  / /g' /etc/hosts > hosts_tmp
/bin/sed  -i -e 's/  / /g' hosts_tmp
/bin/sed  -i -e 's/  / /g' hosts_tmp
/bin/sed  -i -e 's/  / /g' hosts_tmp
/bin/sed  -i -e 's/  / /g' hosts_tmp

HOSTNAME_OLD=$(cat hosts_tmp | grep  "127.0.0.1" | cut -d ' ' -f 3)
if [ ! "$HOSTNAME_OLD" == "$HOSTNAME" ]; then
    if [ ! -z "$HOSTNAME_OLD" ]; then
        echo Changing $HOSTNAME_OLD to $HOSTNAME in /etc/hosts file
        /bin/sed -i -e "s/ $HOSTNAME_OLD/ $HOSTNAME/g" /etc/hosts
     else
        echo Changing blank hostname to $HOSTNAME in /etc/hosts file
        /bin/sed -i -e "s/ localhost/ localhost $HOSTNAME/g" /etc/hosts
    fi
		sync
fi

echo "******************** iClass SE RB25F ********************"
echo "MAC Address is: $MAC"
echo "Fixed Address is: $FA"
echo "Hostname is: $HOSTNAME"
echo "IP Address when first started: $IP"
echo "Broadcast Address when first started: $BCAST"
echo "Date is: $CURR_DATE"
echo "*********************************************************"

MACHINE_ID_FILE="/root/machine_id.txt"
echo "******************** iClass SE RB25F ********************" >  $MACHINE_ID_FILE
echo "MAC Address is: $MAC"                                      >> $MACHINE_ID_FILE
echo "Fixed Address is: $FA"                                     >> $MACHINE_ID_FILE
echo "Hostname is: $HOSTNAME"                                    >> $MACHINE_ID_FILE
echo "IP Address when first started: $IP"                        >> $MACHINE_ID_FILE
echo "Broadcast Address when first started: $BCAST"              >> $MACHINE_ID_FILE
echo "Date is: $CURR_DATE"                                       >> $MACHINE_ID_FILE
echo "*********************************************************" >> $MACHINE_ID_FILE

rm -f /hosts_tmp

exit 0

