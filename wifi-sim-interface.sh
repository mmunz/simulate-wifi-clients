#!/bin/sh
# This script can emulate up to seven Clients.[1] Each of these can
# log into an open access point, optionally accept a splash/captive
# portal page end then endlessly download a file using wget to
# produce some network load.

# This script was written for and tested with ath9k on OpenWrt
# Attitude Adjustment. It is just a quick hack, but maybe it will
# be useful for you.

# [1] Seven seems to be the limitation for ath9k

# Copyright: 2013 Manuel Munz (freifunk at somakoma dot de)
# Released into the public domain.

### All configuration is done here

# The essid of the access point that you want to join
ESSID="Open Access Point"
# The captive portal page accept link. Leave empty to not use this
SPLASHPAGE=""
# Url to download from
TESTURL="http://www.speedtest.qsc.de/10MB.qsc"

### End of config

# We need the real wget, not just the busybox one.
[ -z "$(wget --help |grep 'GNU Wget')" ] && {
	echo "This script needs the real wget. not just the one from busybox."
	echo "Install it with opkg install wget"
	exit 1
}

# Is /etc/udhcpc.user in place?
[ -f /etc/udhcpc.user ] || {
	echo "Please copy the udhcpc.user script to /etc/udhcpc.user."
	exit 1
}

NUMBER=$1

[ $NUMBER -gt 0 ] 2> /dev/null && [ $NUMBER -lt 8 ] 2> /dev/null || {
	echo "Usage error. Argument 1 must be a number between 1 and 7."
	echo "This argument tells the script which interface number to use."
	exit 1
}

[ -x /usr/sbin/ip ] || {
	echo "This script needs iproute2."
	echo "Install it with opkg install ip"
	exit 1
}


DEV="wisim$NUMBER"

ifconfig wisim$NUMBER &> /dev/null && {
	echo "Interface $DEV already exists."
	echo "You can bring it down with iw dev $DEV del"
	exit 1
}



create_mac() {
	echo "00:11:22:33:44:$(printf '%02x' $1)"
}


echo $NUMBER > /tmp/wisim-table

iw phy phy0 interface add $DEV type station && echo "Created interface $DEV"
ifconfig $DEV hw ether $(create_mac $NUMBER) && echo "Changed mac of $DEV to $(create_mac $NUMBER)"
ifconfig $DEV up && echo "Brought Interface $DEV up"
iw dev $DEV connect "$ESSID" && echo "Connected to Access Point $ESSID"
udhcpc -p /var/run/udhcpc-$DEV.pid -s /lib/netifd/dhcp.script -t 0 -i $DEV -C 2> /dev/null

ip=`ifconfig  $DEV | grep "inet addr" | awk '{ print $2}' | cut -d ":" -f 2`

[ -n "$SPLASHPAGE" ] && {
	wget --bind-address $ip -q "$SPLASHPAGE" -O /dev/null && echo "Accepted splash"
}

while [ ! -f /tmp/wisim-stop ]; do
	wget --bind-address $ip $TESTURL -O /dev/null
	sleep 5
done

ifconfig $DEV down && echo "Brought $DEV down."
iw dev $DEV del && echo "Deleted interface $DEV."
ip rule del lookup $NUMBER
echo "wisim stopped"


