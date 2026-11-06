#!/bin/bash

set -e

while getopts "a:s:c:" opt; do
  case $opt in
    a)
		BTCADDRESS="$OPTARG"
	;;
    s)
		SSHKEY="$OPTARG"
	;;
	c)
		if [[ "$OPTARG" != "amd64" && "$OPTARG" != "arm64" ]]; then
			echo "-c must be amd64 or arm64"
			exit 0
		fi
		
		if [ "$OPTARG" = "amd64" ]; then
			URL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.7.0-amd64-netinst.iso
			SHASUM="ef04d0276850d70e4aaec0b55003628660e9631b26e35215a70ab3c8c707294a4b12731bc73c75a932902f703a7c278310ca99df28d6b36fb06d5618d8d0f678  debian-13.7.0-amd64-netinst.iso"
			ISOISTDIR=amd
			ARCH=amd64
		fi

		if [ "$OPTARG" = "arm64" ]; then
			URL=https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-13.7.0-arm64-netinst.iso
			SHASUM="cff08e2f29c2846f0503fe57ad1085b5067f29acab444acdf7cdf5b10f2a11140a0e87828e4ffeb9828d188053690467ebe50151c142551d6053fc3288808b86  debian-13.7.0-arm64-netinst.iso"
			ISOISTDIR=a64
			ARCH=arm64
		fi
	;;
	*)
		echo "build.sh [args]"
		echo "'-c [amd64/arm64]' required, specify which CPU architecture that should be built. (Required)"
		echo "'-a <bitcoin address>' if set, this address will be automatically configured as 'pool_address' for DATUM Gateway"
		echo "'-s \"<SSH pubkey>\"' if set, this public key will be allowed for ssh connections for the 'box' user. Password login will be disabled."
		exit 1
	;;
  esac
done

if [ "$1" = "clean" ]; then
   sudo rm -rf build
   rm -f DATUM-box-*.iso
   exit 0
fi

mkdir build
cd build

wget $URL
echo $SHASUM | sha512sum -c

xorriso -osirrox on -indev debian-13.7.0-$ARCH-netinst.iso -extract / debianfiles
chmod +w -R debianfiles/install.$ISOISTDIR/
gunzip debianfiles/install.$ISOISTDIR/initrd.gz
cp ../preseed.cfg ../post_config.sh ../happen_bashrc ../menu.sh ../late_command.sh ../factory.sh .

if [ "$BTCADDRESS" ]; then
	sed -i "6i echo \"set datum-gateway/bitcoin-address $BTCADDRESS\" | debconf-communicate" post_config.sh
fi

if [ "$SSHKEY" ]; then
	echo 'in-target sed -i -E "/^#?PasswordAuthentication/c\PasswordAuthentication no" /etc/ssh/sshd_config' >> late_command.sh
	echo 'in-target mkdir -p /home/box/.ssh' >> late_command.sh
	echo "in-target sh -c \"echo '$SSHKEY' > /home/box/.ssh/authorized_keys\"" >> late_command.sh
fi

echo preseed.cfg | cpio -H newc -o -A -F debianfiles/install.$ISOISTDIR/initrd
echo post_config.sh | cpio -H newc -o -A -F debianfiles/install.$ISOISTDIR/initrd
echo menu.sh | cpio -H newc -o -A -F debianfiles/install.$ISOISTDIR/initrd
echo happen_bashrc | cpio -H newc -o -A -F debianfiles/install.$ISOISTDIR/initrd
echo late_command.sh | cpio -H newc -o -A -F debianfiles/install.$ISOISTDIR/initrd
echo factory.sh | cpio -H newc -o -A -F debianfiles/install.$ISOISTDIR/initrd
gzip debianfiles/install.$ISOISTDIR/initrd
chmod -w -R debianfiles/install.$ISOISTDIR/

if [ "$ARCH" = "amd64" ]; then
chmod +w debianfiles/isolinux/isolinux.cfg
cat > debianfiles/isolinux/isolinux.cfg << 'EOF'
default auto
timeout 1
prompt 0

label auto
  menu label ^Automated Install
  kernel /install.amd/vmlinuz
  append initrd=/install.amd/initrd.gz auto=true priority=critical --- quiet
EOF
chmod -w debianfiles/isolinux/isolinux.cfg
fi

chmod +w debianfiles/boot/grub/grub.cfg
cat > debianfiles/boot/grub/grub.cfg << EOF
set default=0
set timeout=1

menuentry "Automated Install" {
    linux  /install.$ISOISTDIR/vmlinuz auto=true priority=critical --- quiet
    initrd /install.$ISOISTDIR/initrd.gz
}
EOF
chmod -w debianfiles/boot/grub/grub.cfg
cd debianfiles

chmod -R +w pool/main/a/apt/
rm -f pool/main/a/apt/*

wget http://security.debian.org/debian-security/pool/updates/main/a/apt/apt_3.0.4_$ARCH.deb	-O pool/main/a/apt/apt_3.0.4_$ARCH.deb
wget http://security.debian.org/debian-security/pool/updates/main/a/apt/apt-utils_3.0.4_$ARCH.deb -O pool/main/a/apt/apt-utils_3.0.4_$ARCH.deb
wget http://security.debian.org/debian-security/pool/updates/main/a/apt/apt-transport-https_3.0.4_all.deb -O pool/main/a/apt/apt-transport-https_3.0.4_all.deb
wget http://security.debian.org/debian-security/pool/updates/main/a/apt/libapt-pkg7.0_3.0.4_$ARCH.deb -O pool/main/a/apt/libapt-pkg7.0_3.0.4_$ARCH.deb

chmod -R -w pool/main/a/apt/

chmod -R +w pool/ dists/trixie/
find pool -name '*.udeb' > /tmp/udebs.list
tar --remove-files -cf /tmp/udebs.tar -T /tmp/udebs.list
apt-ftparchive packages pool/main > dists/trixie/main/binary-$ARCH/Packages
gzip -kn9f dists/trixie/main/binary-$ARCH/Packages
tar -xf /tmp/udebs.tar
mv dists/trixie/Release /tmp/trixie-Release.old
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="Debian" \
  -o APT::FTPArchive::Release::Label="Debian" \
  -o APT::FTPArchive::Release::Suite="stable" \
  -o APT::FTPArchive::Release::Version="13.7" \
  -o APT::FTPArchive::Release::Codename="trixie" \
  -o APT::FTPArchive::Release::Acquire-By-Hash="yes" \
  -o APT::FTPArchive::Release::Architectures="$ARCH" \
  -o APT::FTPArchive::Release::Components="main contrib" \
  -o APT::FTPArchive::Release::Description="Debian 13.7 Released 12 September 2026" \
  release dists/trixie > /tmp/trixie-Release
sed -i '1i No-Support-for-Architecture-all: Packages' /tmp/trixie-Release
mv /tmp/trixie-Release dists/trixie/Release

chmod -R -w pool/ dists/trixie/

chmod +w md5sum.txt
find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
chmod -w md5sum.txt
cd ..

if [ "$ARCH" = "amd64" ]; then
	dd if=debian-13.7.0-amd64-netinst.iso bs=1 count=432 of=isohdpfx.bin
	
	xorriso -as mkisofs \
		-r -V 'Debian 13.7.0 amd64 n' \
		-o ../DATUM-box-amd64.iso \
		-J -joliet-long -cache-inodes \
		-isohybrid-mbr isohdpfx.bin \
		-b isolinux/isolinux.bin -c isolinux/boot.cat \
		-boot-load-size 4 -boot-info-table -no-emul-boot \
		-eltorito-alt-boot \
		-e boot/grub/efi.img \
		-no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
		debianfiles
fi

if [ "$ARCH" = "arm64" ]; then
	dd if=debian-13.7.0-arm64-netinst.iso bs=512 skip=1427456 count=8192 of=efi.img
	
	xorriso -as mkisofs \
		-r -V 'Debian 13.7.0 arm64 n' \
		-o ../DATUM-box-arm64.iso \
		-J -joliet-long -cache-inodes \
		-e boot/grub/efi.img \
		-no-emul-boot \
		-append_partition 2 0xef efi.img \
		-partition_cyl_align all \
		debianfiles
fi