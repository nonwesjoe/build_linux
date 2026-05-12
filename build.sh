#!/bin/bash
echo "Downloading linux kernel"
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
tar -xf linux-6.6.tar.xz
cd linux-6.6
# 配置（选择要编译哪些功能）
make defconfig    
make -j$(nproc)
cd ..
echo "内核编译完成 arch/x86/boot/bzImage"

echo "Downloading Alpine Linux Mini Rootfs..."
wget -qO alpine.tar.gz https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.1-x86_64.tar.gz

echo "Extracting Alpine Rootfs..."
rm -rf alpine_rootfs
mkdir alpine_rootfs
tar -xf alpine.tar.gz -C alpine_rootfs --no-same-owner

echo "Configuring init script..."
cat << 'INIT' > alpine_rootfs/init
#!/bin/sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "=========================================="
echo " Welcome to Alpine Linux (initramfs)!"
echo " Package manager 'apk' is ready to use."
echo "=========================================="

exec /bin/sh
INIT
chmod +x alpine_rootfs/init

# echo "Copying DNS resolver to enable internet access inside OS..."
# cp /etc/resolv.conf alpine_rootfs/etc/resolv.conf
echo "Packing Alpine Rootfs into initramfs (forcing root ownership)..."
# We use the kernel's built-in tool to force all files to be owned by root (uid=0, gid=0)
# This bypasses the need for sudo/fakeroot when building the rootfs!

cd linux-6.6 && usr/gen_initramfs.sh -u squash -g squash -o ../alpine_initramfs.cpio ../alpine_rootfs/
cd ..

echo "Done! alpine_initramfs.cpio has been generated."
