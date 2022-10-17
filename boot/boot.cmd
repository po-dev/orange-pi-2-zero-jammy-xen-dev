# DO NOT EDIT THIS FILE
#
# Please edit /boot/orangepiEnv.txt to set supported parameters
#
#
# default values

setenv load_addr "0x46000000"
setenv kernel_addr_r "0x40080000"
setenv xen_addr_r 0x45000000
setenv fdt_addr 0x44000000
setenv overlay_error "false"
setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv rootfstype "ext4"
setenv console "both"
setenv docker_optimizations "on"
setenv bootlogo "false"

ext4load mmc 0 ${kernel_addr_r} orangepiz2/Image;
ext4load mmc 0 ${fdt_addr} orangepiz2/sun50i-h616-orangepi-zero2.dtb;
ext4load mmc 0 ${xen_addr_r} orangepiz2/xen.efi;

fdt addr ${fdt_addr} 0x40000
fdt resize
fdt chosen
fdt set /chosen \#address-cells <1>
fdt set /chosen \#size-cells <1>
fdt mknod /chosen module@0
fdt set /chosen/module@0 compatible "xen,linux-zimage" "xen,multiboot-module"
fdt set /chosen/module@0 reg <${kernel_addr_r} 0x02000000>
fdt set /chosen/module@0 bootargs "console=hvc0 ro root=/dev/mmcblk0p1 rootwait clk_ignore_unused"

setenv bootargs "console=dtuart dtuart=/soc/serial@5000000 root=/dev/mmcblk0p1 rootwait dom0_mem=128M"

#echo "does xen boot here?"
#booti ${xen_addr_r} - ${fdt_addr}


# Print boot source
itest.b *0x10028 == 0x00 && echo "U-boot loaded from SD"
itest.b *0x10028 == 0x02 && echo "U-boot loaded from eMMC or secondary SD"
itest.b *0x10028 == 0x03 && echo "U-boot loaded from SPI"

echo "Boot script loaded from ${devtype}"

if test -e ${devtype} ${devnum} ${prefix}orangepiEnv.txt; then
	load ${devtype} ${devnum} ${load_addr} ${prefix}orangepiEnv.txt
	env import -t ${load_addr} ${filesize}
fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=ttyS0,115200 console=tty1"; fi
if test "${console}" = "serial"; then setenv consoleargs "console=ttyS0,115200"; fi
if test "${bootlogo}" = "true"; then setenv consoleargs "bootsplash.bootfile=bootsplash.orangepi ${consoleargs}"; fi

# get PARTUUID of first partition on SD/eMMC it was loaded from
# mmc 0 is always mapped to device u-boot (2016.09+) was loaded from
if test "${devtype}" = "mmc"; then part uuid mmc 0:1 partuuid; fi

setenv bootargs "root=${rootdev} rootwait rootfstype=${rootfstype} ${consoleargs} consoleblank=0 loglevel=${verbosity} ubootpart=${partuuid} usb-storage.quirks=${usbstoragequirks} ${extraargs} ${extraboardargs}"

if test "${docker_optimizations}" = "on"; then setenv bootargs "${bootargs} cgroup_enable=memory swapaccount=1"; fi

load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
fdt addr ${fdt_addr_r}
fdt resize 65536
for overlay_file in ${overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/allwinner/overlay/${overlay_prefix}-${overlay_file}.dtbo; then
		echo "Applying kernel provided DT overlay ${overlay_prefix}-${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done
for overlay_file in ${user_overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}overlay-user/${overlay_file}.dtbo; then
		echo "Applying user provided DT overlay ${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done
if test "${overlay_error}" = "true"; then
	echo "Error applying DT overlays, restoring original DT"
	load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
else
	if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/allwinner/overlay/${overlay_prefix}-fixup.scr; then
		echo "Applying kernel provided DT fixup script (${overlay_prefix}-fixup.scr)"
		source ${load_addr}
	fi
	if test -e ${devtype} ${devnum} ${prefix}fixup.scr; then
		load ${devtype} ${devnum} ${load_addr} ${prefix}fixup.scr
		echo "Applying user provided fixup script (fixup.scr)"
		source ${load_addr}
	fi
fi

if test "${ethernet_phy}" = "rtl8211f"; then
        fdt set /soc/ethernet@5020000 allwinner,rx-delay-ps <3100>
        fdt set /soc/ethernet@5020000 allwinner,tx-delay-ps <700>
fi

if test "${ethernet_phy}" = "yt8531c"; then
        fdt set /soc/ethernet@5020000 allwinner,rx-delay-ps <0>
        fdt set /soc/ethernet@5020000 allwinner,tx-delay-ps <600>
fi

load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}Image
echo "OOOOOOOOO check what boots here! OOOOOOOOO fdt_addr spam"
booti ${xen_addr_r} ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr} ${xen_addr_r}

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
