load mmc 0:1 0x51000000 /boot/Image
load mmc 0:1 0x4E000000 /boot/initrd
load mmc 0:1 0x48000000 /boot/xen
load mmc 0:1 0x46000000 /boot/sun50i-h616-orangepi-zero2.dtb
fdt addr 0x46000000
fdt resize
fdt set /chosen \#address-cells <0x2>
fdt set /chosen \#size-cells <0x2>
fdt set /chosen xen,xen-bootargs "console=dtuart dtuart=serial0 dom0_mem=128M dom0_max_vcpus=1 bootscrub=0 vwfi=native sched=null  "
fdt mknod /chosen dom0
fdt set /chosen/dom0 compatible  "xen,linux-zimage" "xen,multiboot-module" "multiboot,module"
fdt set /chosen/dom0 reg <0x0 0x51000000 0x0 0x52da1cc0>
fdt set /chosen xen,dom0-bootargs "console=hvc0 earlycon=xen earlyprintk=xen clk_ignore_unused root=/dev/ram0"
fdt mknod /chosen dom0-ramdisk
fdt set /chosen/dom0-ramdisk compatible  "xen,linux-initrd" "xen,multiboot-module" "multiboot,module"
fdt set /chosen/dom0-ramdisk reg <0x0 0x4E000000 0x0 0x502ff600>
setenv fdt_high 0xffffffffffffffff
booti 0x48000000 - 0x46000000
