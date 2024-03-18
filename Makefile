
arch := riscv
misa := rv32ima
prj := zerocore_dual
platform := fpga/ZeroCore_dual
cross_compile := riscv32-unknown-linux-gnu-
root_dir := $(shell pwd)
RISCV := $(root_dir)/install

#path
opensbi_src_dir := $(root_dir)/opensbi
uboot_src_dir := $(root_dir)/u-boot
linux_src_dir := $(root_dir)/linux-5.8

#Compile option
sbi-mk := PLATFORM=$(platform) CROSS_COMPILE=$(cross_compile)
sbi-mk += FW_FDT_PATH=$(RISCV)/$(prj).dtb

OBJCOPY     := $(cross_compile)objcopy
#SD card
SDDEVICE := /dev/sdb

#uImage
UIMAGE_LOAD_ADDRESS := 80400000
UIMAGE_ENTRY_POINT := 80400000
MKIMAGE := $(uboot_src_dir)/tools/mkimage

#config
buildroot_defconfig := $(root_dir)/configs/buildroot_defconfig

all: $(RISCV)/fw_payload.bin


config: make -C buildroot defconfig BR2_DEFCONFIG=$(buildroot_defconfig)

$(RISCV) :
	mkdir -p $(RISCV)

$(RISCV)/dtb :
	cp u-boot-2023.10/arch/riscv/dts/$(prj).dtb $(RISCV)/$(prj).dtb

$(RISCV)/fw_payload.bin: $(RISCV)/u-boot.bin $(RISCV)/dtb
	make -C opensbi FW_PAYLOAD_PATH=$< $(sbi-mk)
	cp opensbi/build/platform/$(platform)/firmware/fw_payload.elf $(RISCV)/fw_payload.elf
	cp opensbi/build/platform/$(platform)/firmware/fw_payload.bin $(RISCV)/fw_payload.bin

uboot-config:
	make -C $(uboot_src_dir) ARCH=$(arch) CROSS_COMPILE=$(cross_compile) menuconfig

linux-config:
	make -C $(linux_src_dir) ARCH=$(arch) CROSS_COMPILE=$(cross_compile) menuconfig

$(RISCV)/u-boot.bin: $(uboot_src_dir)/u-boot.bin
	mkdir -p $(RISCV)
	cp $< $@
	cp $(uboot_src_dir)/u-boot $(RISCV)/u-boot

$(uboot_src_dir)/u-boot.bin:
	make -C $(uboot_src_dir) Zerocore_defconfig
	make -C $(uboot_src_dir) ARCH=$(arch) CROSS_COMPILE=$(cross_compile) -j4

$(linux_src_dir)/vmlinux: 
	make -C $(linux_src_dir) ARCH=$(arch) CROSS_COMPILE=$(cross_compile) -j4
	
$(RISCV)/vmlinux: $(buildroot_defconfig) $(RISCV) config
	make -C buildroot -j4
	cp buildroot/output/images/vmlinux $@
	
$(RISCV)/image: $(RISCV)/vmlinux
	$(OBJCOPY) -O binary -R .note -R .comment -S $< $@
	
$(RISCV)/uImage: $(RISCV)/image
	$(MKIMAGE) -A riscv -O linux -T kernel -C none -a $(UIMAGE_LOAD_ADDRESS) -e $(UIMAGE_ENTRY_POINT) -n "zerocore linux kernel" -d $< $@

# SD COPY
sd_part1 = $(shell lsblk $(SDDEVICE) -no PATH | head -2 | tail -1)
sd_part2 = $(shell lsblk $(SDDEVICE) -no PATH | head -3 | tail -1)
fwpayload_sectorstart := 2048
fwpayload_sectorsize = $(shell ls -l --block-size=512 $(RISCV)/fw_payload.bin | cut -d " " -f5)
fwpayload_sectorend = $(shell echo $(fwpayload_sectorstart)+$(fwpayload_sectorsize) | bc)
image_sectorstart := 512M

image: $(RISCV)/image
uImage: $(RISCV)/uImage

format-sd: 
	sgdisk --clear -g --new=1:$(fwpayload_sectorstart):$(fwpayload_sectorend) --new=2:$(image_sectorstart):0 --typecode=1:3000 --typecode=2:8300 $(SDDEVICE)

copy-sd: format-sd
	dd if=$(RISCV)/fw_payload.bin of=$(sd_part1) status=progress oflag=sync bs=1M

clean:
	rm -rf $(RISCV)/fw_payload.* $(RISCV)/u-boot.bin
	make -C u-boot clean
	make -C opensbi distclean
	

