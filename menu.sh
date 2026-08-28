#!/bin/bash

set -e

function logs {
	trap 'true' INT
	LOGSMENU="choice"
	while [ "$LOGSMENU" != "5." ]
	do
	LOGSMENU=$(whiptail --nocancel --title "Logs menu" --menu "" 0 0 0 "1." "Show Bitcoin Knots logs (follow)" \
																	   "2." "Show DATUM Gateway logs (follow)" \
																	   "3." "Show Bitcoin Knots logs (full)" \
																	   "4." "Show DATUM Gateway logs (full)" \
																	   "5." "Return to main menu" 3>&1 1>&2 2>&3)
	
	case $LOGSMENU in
		1.)
			journalctl -f -u bitcoin-knots || true
		;;
		
		2.)
			journalctl -f -u datum-gateway || true
		;;
		
		3.)
			journalctl -r -u bitcoin-knots || true
		;;
		
		4.)
			journalctl -r -u datum-gateway || true
		;;
	esac
	done
	trap - INT
}

function knots_settings {
	KNOTSMENU="choice"
	while [ "$KNOTSMENU" != "5." ]
	do
	KNOTSMENU=$(whiptail --nocancel --title "Bitcoin Knots settings" --menu "" 0 0 0 "1." "Start Bitcoin Knots" \
																					 "2." "Stop Bitcoin Knots" \
																					 "3." "Restart Bitcoin Knots" \
																					 "4." "Reconfigure Bitcoin Knots" \
																					 "5." "Return to main menu" 3>&1 1>&2 2>&3)
	
	case $KNOTSMENU in
		1.)
			systemctl start bitcoin-knots
			NEWT_COLORS="root=white,green" whiptail --msgbox "Bitcoin Knots has started" 0 0
		;;
		
		2.)
			systemctl stop bitcoin-knots
			NEWT_COLORS="root=white,green" whiptail --msgbox "Bitcoin Knots has stopped" 0 0
		;;
		
		3.)
			systemctl restart bitcoin-knots
			NEWT_COLORS="root=white,green" whiptail --msgbox "Bitcoin Knots has restarted" 0 0
		;;
		
		4.)
			dpkg-reconfigure bitcoin-knots
		;;
	esac
	done
}

function datum_settings {
	DATUMMENU="choice"
	while [ "$DATUMMENU" != "5." ]
	do
	DATUMMENU=$(whiptail --nocancel --title "DATUM settings" --menu "" 0 0 0 "1." "Start DATUM Gateway" \
																			 "2." "Stop DATUM Gateway" \
																			 "3." "Restart DATUM Gateway" \
																			 "4." "Reconfigure DATUM Gateway" \
																			 "5." "Return to main menu" 3>&1 1>&2 2>&3)
	
	case $DATUMMENU in
		1.)
			systemctl start datum-gateway
			NEWT_COLORS="root=white,green" whiptail --msgbox "DATUM Gateway has started" 0 0
		;;
		
		2.)
			systemctl stop datum-gateway
			NEWT_COLORS="root=white,green" whiptail --msgbox "DATUM Gateway has stopped" 0 0
		;;
		
		3.)
			systemctl restart datum-gateway
			NEWT_COLORS="root=white,green" whiptail --msgbox "DATUM Gateway has restarted" 0 0
		;;
		
		4.)
			dpkg-reconfigure datum-gateway
		;;
	esac
	done
}

function tool_menu {
	TOOLMENU="choice"
	while [ "$TOOLMENU" != "4." ]
	do
	TOOLMENU=$(whiptail --nocancel --title "Tools" --menu "" 0 0 0 "1." "AssumeUTXO (haf.ovh link)" \
																   "2." "AssumeUTXO (custom link)" \
																   "3." "Support bridge" \
																   "4." "Return to main menu" 3>&1 1>&2 2>&3)
	
	case $TOOLMENU in
		1.)
			whiptail --msgbox "Loading a snapshot will take some time, please be patient.\nOnce done, please consult the logs of Bitcoin Knots to see the sync progression." 0 0
			
			rm -rf /var/lib/bitcoin/snap/
			sudo -u bitcoin mkdir -p /var/lib/bitcoin/snap
			sudo -u bitcoin wget https://cdn.orangepill.ovh/utxo.dat -O /var/lib/bitcoin/snap/snapshot
			sudo -u bitcoin bitcoin-cli -conf=/etc/bitcoin/bitcoin.conf -rpcclienttimeout=0 loadtxoutset /var/lib/bitcoin/snap/snapshot
			rm -rf /var/lib/bitcoin/snap/
		;;
		
		2.)
			URL=$(whiptail --inputbox "Please enter the link to the UTXO snapshot:" 0 0 3>&1 1>&2 2>&3) || break
			whiptail --msgbox "Loading a snapshot will take some time, please be patient.\nOnce done, please consult the logs of Bitcoin Knots to see the sync progression." 0 0
			
			rm -rf /var/lib/bitcoin/snap/
			sudo -u bitcoin mkdir -p /var/lib/bitcoin/snap
			sudo -u bitcoin wget $URL -O /var/lib/bitcoin/snap/snapshot
			sudo -u bitcoin bitcoin-cli -conf=/etc/bitcoin/bitcoin.conf -rpcclienttimeout=0 loadtxoutset /var/lib/bitcoin/snap/snapshot
			rm -rf /var/lib/bitcoin/snap/
		;;
		
		3.)
			if [ -f /opt/ocean-support-bridge/bin/stop-bridge.sh ]; then
				/opt/ocean-support-bridge/bin/stop-bridge.sh || true
			fi
			
			if [ -d ~/.support ]; then
				if [ -f ~/.support/ocean-support-bridge-installer/ocean-support-bridge-uninstall.sh ]; then
					~/.support/ocean-support-bridge-installer/ocean-support-bridge-uninstall.sh
				fi
				rm -rf ~/.support
			fi
		
			whiptail --msgbox "This feature requires to be in contact with the OCEAN team and to have a support code." 0 0
			CODE=$(whiptail --inputbox "Please enter the code that the OCEAN team gave to you." 0 0 3>&1 1>&2 2>&3)
			mkdir -p ~/.support
			pushd ~/.support
			wormhole receive "$CODE"
			unzip *
			./ocean-support-bridge-installer/ocean-support-bridge-install.sh
			/opt/ocean-support-bridge/bin/start-bridge.sh
			whiptail --msgbox "Your device is ready to receive connections from OCEAN to troubleshoot your installation.\nClick on stop to interrupt the connection." --ok-button "STOP" 0 0
			/opt/ocean-support-bridge/bin/stop-bridge.sh || true
			./ocean-support-bridge-installer/ocean-support-bridge-uninstall.sh
			popd
			rm -rf ~/.support
		;;
	esac
	done
}

function power {
	POWER="choice"
	while [ "$POWER" != "3." ]
	do
	POWER=$(whiptail --nocancel --title "Power" --menu "" 0 0 0 "1." "Reboot" \
																"2." "Poweroff" \
																"3." "Return to main menu" 3>&1 1>&2 2>&3)
	
	case $POWER in
		1.)
			reboot
		;;
		
		2.)
			poweroff
		;;
	esac
	done
}

if [ "$(id -u)" -ne 0 ]; then
	whiptail --msgbox "This script must be run with sudo." 0 0
	exit 1
fi

MENU="initial"
while [ "$MENU" != "9." ]
do
MENU=$(whiptail --nocancel --title "DATUM box menu" --menu "" 0 0 0 "1." "Show number of stratum workers" \
																	"2." "Show estimated hashrate" \
																	"3." "Check bitcoind template endpoint" \
																	"4." "Logs menu" \
																	"5." "Bitcoin Knots settings" \
																	"6." "DATUM Gateway settings" \
																	"7." "Tools" \
																	"8." "Power" \
																	"9." "Quit" 3>&1 1>&2 2>&3)

case $MENU in
	1.)
		if curl -sf -o /dev/null 127.0.0.1:7152; then
			NUMBER=$(curl -s 127.0.0.1:7152 | grep -A1 "Total Work Subscriptions" | tail -n 1 | sed 's/[^0-9]*//g')
			whiptail --msgbox "Number of connected clients: $NUMBER" 0 0
		else
			NEWT_COLORS="root=white,red" whiptail --msgbox "Failed to connect to the DATUM Gateway API.\nPlease consult the logs of the gateway." 0 0
		fi
	;;
	
	2.)
		if curl -sf -o /dev/null 127.0.0.1:7152; then
			NUMBER=$(curl -s 127.0.0.1:7152 | grep -A1 "Estimated Hashrate:" | tail -n 1 | sed 's/[^0-9\.?]*//g')
			whiptail --msgbox "Estimated Hashrate: $NUMBER Th/s" 0 0
		else
			NEWT_COLORS="root=white,red" whiptail --msgbox "Failed to connect to the DATUM Gateway API.\nPlease consult the logs of the gateway." 0 0
		fi
	;;
	
	3.)
		if [ -f /var/lib/bitcoin/.cookie ]; then
			if [ $(curl --user $(sudo -u bitcoin cat /var/lib/bitcoin/.cookie) --data-binary '{"jsonrpc": "1.0", "id": "curltest", "method": "getblocktemplate", "params": [{"rules": ["segwit"]}]}' -H 'content-type: text/plain;' -s http://127.0.0.1:8332/ | jq '.result | has("version")') = "true" ]; then
				NEWT_COLORS="root=white,green" whiptail --msgbox "bitcoind is serving block template, good!" 0 0
			elif [ $(curl --user $(sudo -u bitcoin cat /var/lib/bitcoin/.cookie) --data-binary '{"jsonrpc": "1.0", "id": "curltest", "method": "getblocktemplate", "params": [{"rules": ["segwit"]}]}' -H 'content-type: text/plain;' -s http://127.0.0.1:8332/ | jq '.error.code') = "-10" ]; then
				NEWT_COLORS="root=white,#FFA500" whiptail --msgbox "bitcoind is still still downloading the Bitcoin blockchain.\nbitcoind will start making block template once done." 0 0
			else
				NEWT_COLORS="root=white,red" whiptail --msgbox "bitcoind isn't serving block template, please check the Bitcoin Knots logs for more information." 0 0
			fi
		else
			NEWT_COLORS="root=white,red" whiptail --msgbox "No cookie file detected, are you sure bitcoind is running?" 0 0
		fi
	;;
	
	4.)
		logs
	;;
	
	5.)
		knots_settings
	;;
	
	6.)
		datum_settings
	;;
	
	7.)
		tool_menu
	;;
	
	8.)
		power
	;;
esac
done