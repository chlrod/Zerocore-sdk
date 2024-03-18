# Zerocore-sdk

## Requirments
Requirements Ubuntu
```
sudo apt-get install autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev libusb-1.0-0-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev device-tree-compiler pkg-config libexpat-dev
```

# Opensbi+Uboot
generate fw_payload.bin
```
make all
```
copy fw_payload.bin to sd card
```
sudo make copy-sd
```

# Linux
generate Linux image
```
make uImage
```
for copy uImage to sd card
```
sudo mount /dev/sdx2 /mnt
sudo cp ./install/uImage /mnt
sudo umount /mnt
sync
```

