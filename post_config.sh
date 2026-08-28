#!/bin/bash

set -e

# Space for automatic config
#

function updateconfig {
	jq --argjson MAX_CLIENTS_PER_THREAD "$MAX_CLIENTS_PER_THREAD" '.stratum.max_clients_per_thread = $MAX_CLIENTS_PER_THREAD' /etc/datum-gateway/datum_gateway_config.json > /etc/datum-gateway/datum_gateway_config.json.tmp && mv /etc/datum-gateway/datum_gateway_config.json.tmp /etc/datum-gateway/datum_gateway_config.json
	jq --argjson MAX_THREADS "$MAX_THREADS" '.stratum.max_threads = $MAX_THREADS' /etc/datum-gateway/datum_gateway_config.json > /etc/datum-gateway/datum_gateway_config.json.tmp && mv /etc/datum-gateway/datum_gateway_config.json.tmp /etc/datum-gateway/datum_gateway_config.json
	jq --argjson MAX_CLIENTS "$MAX_CLIENTS" '.stratum.max_clients = $MAX_CLIENTS' /etc/datum-gateway/datum_gateway_config.json > /etc/datum-gateway/datum_gateway_config.json.tmp && mv /etc/datum-gateway/datum_gateway_config.json.tmp /etc/datum-gateway/datum_gateway_config.json
	jq --argjson VARDIFF_MIN "$VARDIFF_MIN" '.stratum.vardiff_min = $VARDIFF_MIN' /etc/datum-gateway/datum_gateway_config.json > /etc/datum-gateway/datum_gateway_config.json.tmp && mv /etc/datum-gateway/datum_gateway_config.json.tmp /etc/datum-gateway/datum_gateway_config.json
	jq --argjson WORK_UPDATE_SECONDS "$WORK_UPDATE_SECONDS" '.bitcoind.work_update_seconds = $WORK_UPDATE_SECONDS' /etc/datum-gateway/datum_gateway_config.json > /etc/datum-gateway/datum_gateway_config.json.tmp && mv /etc/datum-gateway/datum_gateway_config.json.tmp /etc/datum-gateway/datum_gateway_config.json
	sed -i -E "/^#?rpcthreads=/c\\rpcthreads=$RPCTHREADS" /etc/bitcoin/bitcoin.conf
	sed -i -E "/^#?rpcworkqueue=/c\\rpcworkqueue=$RPCWORKQUEUE" /etc/bitcoin/bitcoin.conf
	sed -i -E "/^#?maxmempool=/c\\maxmempool=$MAXMEMPOOL" /etc/bitcoin/bitcoin.conf
	sed -i -E "/^#?blockmaxsize=/c\\blockmaxsize=$BLOCKMAXSIZE" /etc/bitcoin/bitcoin.conf
	sed -i -E "/^#?blockmaxweight=/c\\blockmaxweight=$BLOCKMAXWEIGHT" /etc/bitcoin/bitcoin.conf
	sed -i -E "/^#?maxorphantx=/c\\maxorphantx=$BLOCKMAXWEIGHT" /etc/bitcoin/bitcoin.conf
	sed -i -E "/^#?maxorphantx=/c\\maxorphantx=$BLOCKMAXWEIGHT" /etc/bitcoin/bitcoin.conf
	sed -i -E "/^#?blockreconstructionextratxn=/c\\blockreconstructionextratxn=$BLOCKRECONSTRUCTIONEXTRATXN" /etc/bitcoin/bitcoin.conf
	sed -i -E "/^#?blockreconstructionextratxnsize=/c\\blockreconstructionextratxnsize=$BLOCKRECONSTRUCTIONEXTRATXNSIZE" /etc/bitcoin/bitcoin.conf
}

if ! command -v whiptail &> /dev/null; then
	echo "Whiptail is not installed, impossible to show post installation steps."
	echo "Please run \"sudo apt install whiptail -y\" then logout and login again"
	exit 1
fi

whiptail --msgbox "Thanks for mining with us!\nLet's do the last steps to configure your datum box." 0 0

PASSWORD="todo"

while [ "$PASSWORD" != "$PASSWORD2" ]
do	
	PASSWORD=$(whiptail --nocancel --inputbox "For security reasons you must change the password of this server.\nPlease enter your new password:" 0 0 3>&1 1>&2 2>&3)
	PASSWORD2=$(whiptail --nocancel --inputbox "Please enter the password again:" 0 0 3>&1 1>&2 2>&3)
	
	if [ "$PASSWORD" != "$PASSWORD2" ]; then
		NEWT_COLORS="root=white,red" whiptail --msgbox "Both password didn't match, please try again." 0 0
	fi
	
	if [ "$PASSWORD" = "" ]; then
		NEWT_COLORS="root=white,red" whiptail --msgbox "Password must not be empty" 0 0
		PASSWORD="todo"
	fi
done

if echo "box:$PASSWORD" | chpasswd; then
	NEWT_COLORS="root=white,green" whiptail --msgbox "Password sucessfully changed!" 0 0
else
	NEWT_COLORS="root=white,red" whiptail --msgbox "Failed to change password." 0 0
fi

unset PASSWORD PASSWORD2

whiptail --msgbox "We will now proceed to the Bitcoin node and DATUM Gateway configuration." 0 0

SIZE=$(whiptail --nocancel --title "Mining size" --menu "Choose how much ASICs you will connect to this DATUM box.\nThe settings of DATUM Gateway will be adjusted accordingly.\nYou can also manually configure it." 0 0 0 "1." "10K machines" \
																																																							"2." "50k machines" \
																																																							"3." "Manual configuration" 3>&1 1>&2 2>&3)

case $SIZE in
	1.)
		MAX_CLIENTS_PER_THREAD=2000
		MAX_THREADS=10
		MAX_CLIENTS=20000
		VARDIFF_MIN=131072
		WORK_UPDATE_SECONDS=40
		RPCTHREADS=64
		RPCWORKQUEUE=64
		MAXMEMPOOL=1000
		BLOCKMAXSIZE=3985000
		BLOCKMAXWEIGHT=3985000
		BLOCKRECONSTRUCTIONEXTRATXN=1000000
		BLOCKRECONSTRUCTIONEXTRATXNSIZE=100
		MAXORPHANTX=50000
		updateconfig
	;;
	
	2.)
		MAX_CLIENTS_PER_THREAD=4096
		MAX_THREADS=24
		MAX_CLIENTS=98304
		VARDIFF_MIN=131072
		WORK_UPDATE_SECONDS=40
		RPCTHREADS=64
		RPCWORKQUEUE=64
		MAXMEMPOOL=1000
		BLOCKMAXSIZE=3985000
		BLOCKMAXWEIGHT=3985000
		BLOCKRECONSTRUCTIONEXTRATXN=1000000
		BLOCKRECONSTRUCTIONEXTRATXNSIZE=100
		MAXORPHANTX=50000
		updateconfig
		sed -i -E "/^LimitNOFILE=/c\\LimitNOFILE=131072" /usr/lib/systemd/system/datum-gateway.service
		systemctl daemon-reload
	;;
esac

if [ "$SIZE" = "3." ]; then
	if ! dpkg-reconfigure -plow bitcoin-knots datum-gateway; then
		NEWT_COLORS="root=white,red" whiptail --msgbox "Failed to reconfigure Bitcoin Knots and/or DATUM Gateway" 0 0
		exit 1
	fi
elif ! dpkg-reconfigure -pmedium bitcoin-knots datum-gateway; then
	NEWT_COLORS="root=white,red" whiptail --msgbox "Failed to reconfigure Bitcoin Knots and/or DATUM Gateway" 0 0
	exit 1
fi

if whiptail --title "Firewall" --nocancel --yesno "Enabling the firewall will only allow inbound connections from these ports:\n\n - 8333 (bitcoind P2P port)\n - 23334 (DATUM Gateway stratum port)\n - 7152 (DATUM Gateway WEB dashboard)\n - 22 (ssh)\n\nWould you like to enable firewall?" 0 0; then
	apt-get install ufw -y
	ufw allow 8333 comment "bitcoind P2P port"
	ufw allow 23334 comment "DATUM Gateway stratum port"
	ufw allow 7152 comment "DATUM Gateway WEB dashboard"
	ufw allow 22 comment "ssh"
	ufw enable
	whiptail --title "Check Firewall" --msgbox "You can consult the firewall rules anytime with the \"sudo ufw status\" command." 0 0
fi

whiptail --msgbox "Your datum box is now configured!" 0 0

if [ -f /home/box/need_config ]; then
	userdel -f -r factory
	rm /usr/local/bin/factory.sh
	rm /usr/local/bin/post_config.sh
	rm /home/box/need_config
fi

sudo menu.sh