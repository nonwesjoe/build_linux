#!/bin/bash
qemu-system-x86_64 -kernel linux-6.6/arch/x86/boot/bzImage \
    -initrd alpine_initramfs.cpio \
    -append "console=ttyS0 quiet" \
    -nographic \
    -m 512M
