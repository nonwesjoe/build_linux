#!/bin/bash
echo "Checking and installing required tools..."
# We use sudo here so the user will be prompted if missing
if ! dpkg -s grub-efi-amd64-bin &> /dev/null || ! command -v xorriso &> /dev/null || ! command -v grub-mkrescue &> /dev/null || ! command -v mtools &> /dev/null; then
    echo "Installing grub-pc-bin, grub-efi-amd64-bin, xorriso and mtools..."
    sudo apt update
    sudo apt install -y grub-pc-bin grub-efi-amd64-bin xorriso mtools
fi

echo "Creating ISO directory structure..."
rm -rf iso
mkdir -p iso/boot/grub

echo "Copying Kernel and Initramfs..."
cp linux-6.6/arch/x86/boot/bzImage iso/boot/
cp alpine_initramfs.cpio iso/boot/

echo "Creating GRUB configuration..."
cat << 'CFG' > iso/boot/grub/grub.cfg
set timeout=5
set default=0

menuentry "My Powerful Alpine Linux" {
    linux /boot/bzImage console=tty0 quiet
    initrd /boot/alpine_initramfs.cpio
}
CFG

echo "Building the ISO image..."
grub-mkrescue -o simple-linux.iso iso/

if [ $? -eq 0 ]; then
    echo "ISO created successfully: simple-linux.iso"
    echo "You can now load this ISO file into VMware or VirtualBox!"
else
    echo "Failed to create ISO."
fi
