in-target sed -i "/^deb[[:space:]]\+cdrom:/d" /etc/apt/sources.list 2>/dev/null
in-target apt-get update
in-target apt-get install -y bitcoin-knots/trixie-backports datum-gateway/trixie-backports curl/trixie-backports magic-wormhole openvpn unzip

# Create user for factory (deleted upon first config)
in-target useradd -m -G sudo -s /bin/bash -U factory
in-target sh -c "echo 'factory:factory' | chpasswd"

cat happen_bashrc >> /target/home/box/.bashrc
touch /target/home/box/need_config
cp factory.sh /target/usr/local/bin/
cp post_config.sh /target/usr/local/bin/
cp menu.sh /target/usr/local/bin/

echo -e "\nWelcome in your DATUM Box! \nTo open the datum box menu please type \"menu\" and press enter." > /target/etc/motd
