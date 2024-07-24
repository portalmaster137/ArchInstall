INSTALL_VERSION="1.0.0"

clear
echo 'ArchInstaller v'$INSTALL_VERSION
echo '----------------------'
echo ' Made by Porta'
echo '----------------------'
echo 'Checking System...'
sleep 2
# Check if /sys/firmware/efi/fw_platform_size is 64
if [ -f /sys/firmware/efi/fw_platform_size ]; then
    if [ "$(cat /sys/firmware/efi/fw_platform_size)" != "64" ]; then
        echo '[-] /sys/firmware/efi/fw_platform_size is not 64, falling back to BIOS mode.'
        INSTALL_MODE="BIOS"
    else
        echo '[+] 64-bit UEFI firmware detected.'
        INSTALL_MODE="EFI"
    fi
else
    echo '[-] /sys/firmware/efi/fw_platform_size not found, falling back to BIOS mode.'
    INSTALL_MODE="BIOS"
fi

if [ "$INSTALL_MODE" == "BIOS" ]; then
   #todo implement BIOS mode
    echo '[-] BIOS mode is not supported yet.'
    exit 1
fi

# Check if the system is connected to the internet
if ! ping -c 1 google.com &> /dev/null; then
    echo '[X] No internet connection detected. Please connect to the internet and try again.'
    exit 1
fi

echo '[-] Setting up the system clock...'
timedatectl set-ntp true
sleep 2
lsblk
echo '[-] Please select the disk you want to install Arch Linux on (e.g. /dev/sda):'
read -r INSTALL_DISK
echo '[-] Are you sure you want to install Arch Linux on '$INSTALL_DISK'? (y/n)'
read -r CONFIRM_DISK

if [ "$CONFIRM_DISK" != "y" ]; then
    echo '[-] Installation aborted.'
    exit 1
fi

# Check if INSTALL_DISK is a valid block device
if [ ! -b "$INSTALL_DISK" ]; then
    echo '[-] '$INSTALL_DISK' is not a valid block device.'
    exit 1
fi

#Check for 16 GB of free space
if [ "$(df -g --output=avail "$INSTALL_DISK" | tail -n 1)" -lt 16 ]; then
    echo '[-] '$INSTALL_DISK' does not have enough free space.'
    exit 1
fi

echo '[+] Partitioning the disk...'
echo "label: gpt" | sfdisk "$INSTALL_DISK"
# Make a 1GB EFI partition, 4GB swap partition, and the rest as root partition
echo "1G,ef00,*" | sfdisk "$INSTALL_DISK"
echo "4G,8200" | sfdisk "$INSTALL_DISK"
echo ",8300" | sfdisk "$INSTALL_DISK"
echo '[+] Formatting the partitions...'
mkfs.fat -F32 "$INSTALL_DISK"1
mkswap "$INSTALL_DISK"2
mkfs.ext4 "$INSTALL_DISK"3
echo '[+] Mounting the partitions...'
mount "$INSTALL_DISK"3 /mnt
swapon "$INSTALL_DISK"2
mount --mkdir "$INSTALL_DISK"1 /mnt/boot
echo '[+] Disk partitioning and formatting complete.'
echo '[+] Installing Arch Linux...'
pacstrap -K /mnt base base-devel linux linux-firmware nano sudo efibootmgr grub networkmanager
echo '[+] Generating fstab...'
genfstab -U /mnt >> /mnt/etc/fstab
echo 'Please your zoneinfo timezone (e.g. Europe/Berlin):'
read -r TIMEZONE
arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
arch-chroot /mnt hwclock --systohc
echo 'Please enter your locale (e.g. en_US.UTF-8):'
read -r LOCALE
echo 'LANG='$LOCALE > /mnt/etc/locale.conf
arch-chroot /mnt locale-gen
echo 'Please enter your hostname:'
read -r HOSTNAME
echo $HOSTNAME > /mnt/etc/hostname
echo 'Please enter your root password:'
arch-chroot /mnt passwd
echo '[+] Configuring GRUB...'
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
echo '[+] Enabling NetworkManager...'
arch-chroot /mnt systemctl enable NetworkManager
echo '[+] Installation complete. Please reboot your system.'
