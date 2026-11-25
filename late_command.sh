cat > /target/etc/apt/preferences.d/ocean.pref << EOF
Package: bitcoin-core datum-gateway ocean-scripts
Pin: release o=ocean
Pin-Priority: 1001
EOF

cat > /target/etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

cat > /target/etc/apt/apt.conf.d/99-force-confold << EOF
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
}
EOF

cat > /target/etc/apt/apt.conf.d/52unattended-upgrades-local << 'EOF'
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=${distro_codename},label=Debian";
        "origin=Debian,codename=${distro_codename},label=Debian-Security";
        "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";

	"o=OCEAN,a=${distro_codename}"
};
EOF

in-target sed -i "/^deb[[:space:]]\+cdrom:/d" /etc/apt/sources.list 2>/dev/null
in-target apt-get update
in-target apt-get install -y bitcoin-core datum-gateway ocean-scripts unattended-upgrades

# Create user for factory (deleted upon first config)
in-target useradd -m -G sudo -s /bin/bash -U factory
in-target sh -c "echo 'factory:factory' | chpasswd"

cat happen_bashrc >> /target/home/box/.bashrc
touch /target/home/box/need_config
cp factory.sh /target/usr/local/bin/
cp post_config.sh /target/usr/local/bin/
cp policy-rc.d /target/usr/local/share/policy-rc.d

echo -e "\nWelcome in your DATUM Box! \nTo open the datum box menu please type \"menu\" and press enter." > /target/etc/motd
