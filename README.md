# 简易 Linux 操作系统制作与启动指南
- 简单命令构建：./build.sh 下载和编译linux内核和alpine的rootfs
- 简单命令运行: ./run.sh 使用qemu运行这个操作系统
- 简单iso创建: ./make_iso.sh 创建iso，vmware可以运行
## 1. 所需组件与工具
制作一个功能强大的 Linux 操作系统，主要需要以下三个核心组件和相关编译工具：

*   **Linux 内核 (Kernel)**：操作系统的核心，负责硬件管理、内存分配和进程调度。
*   **Alpine Linux (Root Filesystem)**：我们使用 Alpine Linux 的 Mini Rootfs 作为根文件系统。Alpine 体积小巧且自带完整的包管理器 (`apk`)，非常适合构建轻量且强大的自定义系统。
*   **编译与打包工具**：`gcc`, `make`, `bison`, `flex`, `libelf-dev`, `libssl-dev`（用于编译内核）；`qemu-system-x86_64`（用于快速测试启动）；`grub-pc-bin`, `grub-efi-amd64-bin`, `xorriso`, `mtools`（用于制作标准 ISO 镜像）。

---

## 2. 编译与制作流程

### 2.1 编译 Linux 内核
1. 下载 Linux 内核源码（如 `linux-6.6`）。
2. 生成默认配置并编译：
   ```bash
   make defconfig
   make -j$(nproc) bzImage
   ```
   编译完成后，内核镜像将生成在 `arch/x86/boot/bzImage`。

### 2.2 制作根文件系统 (Alpine initramfs)
为了简化构建过程并解决权限问题，我们提供了 `build_alpine_rootfs.sh` 脚本来自动化构建：

1. **下载并解压 Alpine Mini Rootfs**：从官方获取压缩包并解压到一个目录中。
2. **编写初始化脚本 `init`**（PID为1的守护进程）：
   ```bash
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
   ```
   赋予执行权限：`chmod +x init`
3. **配置网络**：将宿主机的 `/etc/resolv.conf` 复制到 Alpine 目录中，使得系统启动后可以直接连接外网并使用 `apk` 安装软件。
4. **打包为 `cpio` 格式**：使用 Linux 内核自带的 `gen_initramfs.sh` 工具进行打包。该工具的 `-u squash -g squash` 参数能够巧妙地将所有文件的所有权强制映射为 `root:root`，从而免去了在构建时对 `sudo` 权限的依赖。
   ```bash
   linux-6.6/usr/gen_initramfs.sh -u squash -g squash -o alpine_initramfs.cpio alpine_rootfs/
   ```

---

## 3. 启动操作系统 (使用 QEMU 模拟器)
使用 QEMU 模拟器可以直接通过内核文件和内存盘 (initramfs) 启动系统，无需制作磁盘镜像，这在开发测试阶段非常高效。

你可以直接运行项目目录下的 `run.sh` 脚本：
```bash
qemu-system-x86_64 \
    -kernel linux-6.6/arch/x86/boot/bzImage \
    -initrd alpine_initramfs.cpio \
    -append "console=ttyS0 quiet" \
    -nographic \
    -m 512M
```
启动后你将进入 Alpine 系统环境，可以测试网络并使用 `apk add` 安装想要的软件包。

---

## 4. 制作可在 VMware/真实物理机启动的 ISO 镜像

为了在虚拟机或物理机上启动，我们需要引入 **Bootloader (引导加载程序)**。本指南使用 GRUB，并制作同时支持传统 BIOS 和现代 UEFI 启动的 **混合镜像 (Hybrid ISO)**。

### 4.1 准备制作工具
执行自动打包脚本 `make_iso.sh` 时会自动检查依赖。你需要安装以下工具：
```bash
sudo apt update
sudo apt install grub-pc-bin grub-efi-amd64-bin xorriso mtools -y
```

### 4.2 构建 ISO 目录结构与生成镜像
你可以直接运行 `make_iso.sh`，脚本的工作原理如下：
1. **创建基础工作目录**：建立 `iso/boot/grub`。
2. **拷贝内核和根文件系统**：将 `bzImage` 和 `alpine_initramfs.cpio` 放入 `iso/boot/`。
3. **编写 GRUB 配置文件 (grub.cfg)**：
   ```cfg
   set timeout=5
   set default=0

   menuentry "My Powerful Alpine Linux" {
       linux /boot/bzImage console=tty0 quiet
       initrd /boot/alpine_initramfs.cpio
   }
   ```
4. **生成 ISO 镜像**：
   ```bash
   grub-mkrescue -o simple-linux.iso iso/
   ```

生成的 `simple-linux.iso` 就可以被直接刻录到 U 盘，或者作为虚拟机的光驱镜像进行启动了。

---

## 5. 常见物理机启动问题排查

如果将 ISO 刷入 U盘 后，在真实电脑上无法启动，通常有以下原因：

### 5.1 缺少 UEFI 支持
确保你安装了 `grub-efi-amd64-bin` 依赖，并且使用了更新后的 `make_iso.sh` 重新打包。这样生成的镜像才会同时兼容旧机器的 BIOS 和新机器的 UEFI。

### 5.2 缺少物理机硬件驱动 (内核黑屏/卡死)
如果物理机成功看到了 GRUB 菜单，但在选择启动后，**屏幕一直黑屏或者卡住不动**，这是因为我们的 Linux 内核目前是 `make defconfig` 默认编译的。
*   `defconfig` 会涵盖绝大多数基础配置，但在部分独立显卡、或者比较新的屏幕控制器上，可能会因为缺乏显卡驱动或 `Framebuffer` 支持而无法向屏幕输出文字。
*   **解决方案**：你可以进入内核源码目录执行 `make menuconfig`，在 `Device Drivers` -> `Graphics support` 中检查是否开启了 `EFI-based Framebuffer Support` 以及 `Simple framebuffer support`。
*   此外，如果有接键盘无法输入的情况，也可能是缺少对应 USB 驱动（如 xHCI 等）。你可以将物理机的当前 Ubuntu 系统配置拷贝过来作为基础（`cp /boot/config-$(uname -r) .config`）再编译，这样内核会大很多，但兼容性会跟你的宿主机一样强。