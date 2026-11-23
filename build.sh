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
			URL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.8.0-amd64-netinst.iso
			SHASUM="825d85a068532854f81c2d99a1890d8dfa969beeafd2ace976d86fb22ca5a3b0e4012f8b681682e668db3b883bd5f4e3dcdbdb2685f945a27aef0230558eaadb  debian-13.8.0-amd64-netinst.iso"
			ISOISTDIR=amd
			ARCH=amd64
		fi

		if [ "$OPTARG" = "arm64" ]; then
			URL=https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-13.8.0-arm64-netinst.iso
			SHASUM="ae2dde2547b19238bab6f44e348c6e19880d9b4919a51839c488e63951170d3f50aaa6301e3e2c175664a9847c01d1a0f6374599449e6cbd712c755934b2766b  debian-13.8.0-arm64-netinst.iso"
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

xorriso -osirrox on -indev debian-13.8.0-$ARCH-netinst.iso -extract / debianfiles
chmod +w -R debianfiles/install.$ISOISTDIR/
gunzip debianfiles/install.$ISOISTDIR/initrd.gz
cp ../preseed.cfg ../post_config.sh ../happen_bashrc ../late_command.sh ../factory.sh .

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

chmod +w md5sum.txt
find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
chmod -w md5sum.txt
cd ..

if [ "$ARCH" = "amd64" ]; then
	dd if=debian-13.8.0-amd64-netinst.iso bs=1 count=432 of=isohdpfx.bin
	
	xorriso -as mkisofs \
		-r -V 'Debian 13.8.0 amd64 n' \
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
	dd if=debian-13.8.0-arm64-netinst.iso bs=512 skip=1427456 count=8192 of=efi.img
	
	xorriso -as mkisofs \
		-r -V 'Debian 13.8.0 arm64 n' \
		-o ../DATUM-box-arm64.iso \
		-J -joliet-long -cache-inodes \
		-e boot/grub/efi.img \
		-no-emul-boot \
		-append_partition 2 0xef efi.img \
		-partition_cyl_align all \
		debianfiles
fi