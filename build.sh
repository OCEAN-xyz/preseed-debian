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
			URL=https://cdimage.debian.org/mirror/cdimage/archive/13.5.0/amd64/iso-cd/debian-13.5.0-amd64-netinst.iso
			SHASUM="b2be60c555e328b4fa5ebb2d0e5c7ee6bc3eb4250c4dcfd3f78b8d9aec596efdf9f14f10a898c280eb252d50bbac91ea0a2bba29736df0d4985d50d4c8d77519  debian-13.5.0-amd64-netinst.iso"
			ISOISTDIR=amd
			ARCH=amd64
		fi

		if [ "$OPTARG" = "arm64" ]; then
			URL=https://cdimage.debian.org/mirror/cdimage/archive/13.5.0/arm64/iso-cd/debian-13.5.0-arm64-netinst.iso
			SHASUM="e81aa710007e5d6cf05da300431223a3f75ed7264f244cb374f59c50037f1d96056e378894768c710e6f165c621f3ad7ad0fbc0cc01084488d797788237d8b2b  debian-13.5.0-arm64-netinst.iso"
			ISOISTDIR=a64
			ARCH=arm64
		fi
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

xorriso -osirrox on -indev debian-13.5.0-$ARCH-netinst.iso -extract / debianfiles
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
chmod +w md5sum.txt
find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
chmod -w md5sum.txt
cd ..

if [ "$ARCH" = "amd64" ]; then
	dd if=debian-13.5.0-amd64-netinst.iso bs=1 count=432 of=isohdpfx.bin
	
	xorriso -as mkisofs \
		-r -V 'Debian 13.5.0 amd64 n' \
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
	dd if=debian-13.5.0-arm64-netinst.iso bs=512 skip=1427456 count=8192 of=efi.img
	
	xorriso -as mkisofs \
		-r -V 'Debian 13.5.0 arm64 n' \
		-o ../DATUM-box-arm64.iso \
		-J -joliet-long -cache-inodes \
		-e boot/grub/efi.img \
		-no-emul-boot \
		-append_partition 2 0xef efi.img \
		-partition_cyl_align all \
		debianfiles
fi