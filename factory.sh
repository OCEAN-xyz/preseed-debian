#!/bin/bash

set -e

if [ "$(id -u)" -ne 0 ]; then
	whiptail --msgbox "This script must be run with sudo." 0 0
	exit 1
fi

MENU="initial"
while [ "$MENU" != "6." ]
do
MENU=$(whiptail --nocancel --title "Factory menu" --menu "" 0 0 0 "1." "Check bitcoind sync" \
																  "2." "Check stratum endpoint" \
																  "3." "bitcoind logs" \
																  "4." "DATUM Gateway logs" \
																  "5." "Poweroff" \
																  "6." "Quit" 3>&1 1>&2 2>&3)

case $MENU in
	1.)
		if ! SYNC=$(sudo -u bitcoin bitcoin-cli -datadir=/var/lib/bitcoin getblockchaininfo); then
			NEWT_COLORS="root=white,red" whiptail --msgbox "Couldn't get the sync status, are you sure bitcoind is running?\nNote that bitcoind can take up to 120 seconds to start after the boot.\nYou can consult the logs of bitcoind in the menu." 0 0
		else
			if [ $(echo $SYNC | jq -r '.initialblockdownload') = "false" ]; then
				NEWT_COLORS="root=white,green" whiptail --msgbox "bitcoind is now fully synced!" 0 0
			else
				PERCENTAGE=$(echo $SYNC | jq -r '(.verificationprogress * 100 | floor | tostring) + "%"')
				whiptail --msgbox "bitcoind sync percentage: $PERCENTAGE" 0 0
			fi
		fi
	;;
	
	2.)
		if echo '{"id":1,"method":"mining.subscribe","params":[]}' | nc -q 10 127.0.0.1 23334 >/dev/null 2>&1; then
			NEWT_COLORS="root=white,green" whiptail --msgbox "DATUM Gateway is serving stratum work, good!" 0 0
		else
			NEWT_COLORS="root=white,red" whiptail --msgbox "DATUM Gateway isn't serving stratum work for now.\nbitcoind might be still syncing.\nYou can consult the logs of the gateway in the menu." 0 0
		fi
	;;
	
	3.)
		trap 'true' INT
		journalctl -f -u bitcoin-knots || true
		trap - INT
	;;
	
	4.)
		trap 'true' INT
		journalctl -f -u datum-gateway || true
		trap - INT
	;;
	
	5.)
		poweroff
	;;
esac
done