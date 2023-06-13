#!/bin/bash
# Ensure this script is run as root
if [ "$EUID" != "0" ]; then
    echo "Please run as root" >&2
    exit 1
fi

# Set a few bash options
cd "$(dirname "$(realpath "$0")")"
set -ex

# Create a temp dir
tmp=$(mktemp -d)
mkdir "$tmp/iso"

# Mount the boot iso into our temp dir
mount rhel-9.2-x86_64-boot.iso "$tmp/iso"

# Create a directory for our new ISO
mkdir "$tmp/new"

# Copy the contents of the boot ISO to our new directory
cp -a "$tmp/iso/" "$tmp/new/"

# Unmount the boot ISO
umount "$tmp/iso"

# Copy our customized files into the new ISO directory
cp ks.cfg "$tmp/new/iso/"
cp isolinux.cfg "$tmp/new/iso/isolinux/"
cp grub.cfg "$tmp/new/iso/EFI/BOOT/"
cp -r ostree "$tmp/new/iso/"

# Push directory of new ISO for later commands
pushd "$tmp/new/iso"

# Create our new ISO
mkisofs -o ../rhde-ztp.iso -b isolinux/isolinux.bin -J -R -l -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e images/efiboot.img -no-emul-boot -graft-points -joliet-long -V "RHEL-9-2-0-BaseOS-x86_64" .
isohybrid --uefi ../rhde-ztp.iso
implantisomd5 ../rhde-ztp.iso

# Return to previous directory
popd

# Cleanup and give user ownership of ISO
mv "$tmp/new/rhde-ztp.iso" ./
rm -rf "$tmp"
chown $(stat -c '%U:%G' .) ./rhde-ztp.iso
