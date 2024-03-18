
arch := riscv
misa := rv32ima
prj := zerocore_dual
platform := fpga/ZeroCore_dual
cross_compile := riscv32-unknown-linux-gnu-
root_dir := $(shell pwd)
RISCV := $(root_dir)/install

#path
opensbi_src_dir := $(root_dir)/opensbi
uboot_src_dir := $(root_dir)/u-boot-2023.10
linux_src_dir := $(root_dir)/linux-5.8

#Compile option
sbi-mk := PLATFORM=$(platform) CROSS_COMPILE=$(cross_compile)
sbi-mk += FW_FDT_PATH=$(RISCV)/$(prj).dtb

OBJCOPY     := $(cross_compile)objcopy
#SD card
SDDEVICE := /dev/sdb

all: $(RISCV)/fw_payload.bin


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
	make -C $(uboot_src_dir) ARCH=$(arch) CROSS_COMPILE=$(cross_compile) -j4

$(linux_src_dir)/vmlinux: 
	make -C $(linux_src_dir) ARCH=$(arch) CROSS_COMPILE=$(cross_compile) -j4

$(RISCV)/image: $(linux_src_dir)/vmlinux
	$(OBJCOPY) -O binary -R .note -R .comment -S $< $@

# SD COPY
sd_part1 = $(shell lsblk $(SDDEVICE) -no PATH | head -2 | tail -1)
sd_part2 = $(shell lsblk $(SDDEVICE) -no PATH | head -3 | tail -1)
fwpayload_sectorstart := 2048
fwpayload_sectorsize = $(shell ls -l --block-size=512 $(RISCV)/fw_payload.bin | cut -d " " -f5)
fwpayload_sectorend = $(shell echo $(fwpayload_sectorstart)+$(fwpayload_sectorsize) | bc)
image_sectorstart := 512M

image: $(RISCV)/image

format-sd: 
	sgdisk --clear -g --new=1:$(fwpayload_sectorstart):$(fwpayload_sectorend) --new=2:$(image_sectorstart):0 --typecode=1:3000 --typecode=2:8300 $(SDDEVICE)

copy-sd: format-sd
	dd if=$(RISCV)/fw_payload.bin of=$(sd_part1) status=progress oflag=sync bs=1M

clean:
	rm -rf $(RISCV)/fw_payload.* $(RISCV)/u-boot.bin
	make -C u-boot-2023.10 clean
	make -C opensbi distclean
	

