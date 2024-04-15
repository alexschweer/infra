# Start message
echo "[*] This script installs the Xen virtualisation infrastructure on Arch Linux."
echo "[!] ALERT: This script is potentially destructive. Use it on your own risk. Press any key to continue..."
read

# Global variables
echo "[*] Initialising global variables..."
TMP_XEN_CFG="/tmp/xen.cfg"
TMP_XEN_EFI="/tmp/xen.efi"
USER_NAME=$(whoami)
XEN_EFI="/boot/efi/EFI/xen.efi"

# Install required packages
echo "[*] Installing required packages..."
doas apk add bridge \
    bridge-utils \
    dmidecode \
    ebtables \
    libvirt \
    libvirt-daemon \
    netcat-openbsd \
    ovmf \
    seabios \
    spice-vdagent \
    virt-manager \
    virt-viewer \
    xen \
    xen-hypervisor \
    xen-qemu
sleep 2

# Enable modules
echo "[*] Enabling modules..."
echo "xen-blkback" | doas tee -a /etc/modules
echo "xen-netback" | doas tee -a /etc/modules
echo "tun" | doas tee -a /etc/modules

# Enable non-root access to libvirtd
echo "[*] Enabling libvirt access for user '$USER_NAME'..."

echo "[*] Granting non-root access to libvirt to the 'libvirt' group..."
echo "unix_sock_group = \"libvirt\"" | doas tee -a /etc/libvirt/libvirtd.conf
echo "unix_sock_rw_perms = \"0770\"" | doas tee -a /etc/libvirt/libvirtd.conf

echo "[*] Adding user '$USER_NAME' to the 'libvirt' group..."
doas adduser $(whoami) libvirt

echo "[*] Enabling the 'libvirtd' service..."
doas systemctl enable libvirtd.service

# Configure services
echo "[*] Configuring required services..."
doas rc-update add libvirt-guests default
doas rc-update add libvirtd default
doas rc-update add spice-vdagentd default
doas rc-update add xenconsoled default
doas rc-update add xendomains default 
doas rc-update add xenqemu default
doas rc-update add xenstored default
sleep 2

# Generate Xen configuration file
echo "[*] Generating the Xen configuration file '$TMP_XEN_CFG'..."

echo '[global]' | doas tee $TMP_XEN_CFG
echo 'default=alpine-linux' | doas tee -a $TMP_XEN_CFG
echo '' | doas tee -a $TMP_XEN_CFG
echo "[alpine-linux]" | doas tee -a $TMP_XEN_CFG
echo "options=console=vga flask=disabled iommu=verbose loglvl=all ucode=scan" | doas tee -a $TMP_XEN_CFG
echo "kernel=vmlinuz-lts $(cat /etc/kernel/cmdline)" | doas tee -a $TMP_XEN_CFG
echo "ramdisk=initramfs-lts" | doas tee -a $TMP_XEN_CFG
cat $TMP_XEN_CFG
sleep 3

# Generate Xen UKI
echo "[*] Generating a unified kernel image (UKI) of the Xen kernel..."
doas cp /usr/lib/efi/xen.efi $TMP_XEN_EFI

SECTION_PATH="$TMP_XEN_CFG"
SECTION_NAME=".config"
echo "[*] Writing '$SECTION_PATH' to the new $SECTION_NAME section..."
read -r -a OBJDUMP <<< $(objdump -h "$TMP_XEN_EFI" | grep .pad)
VMA=$(printf "%X" $((((0x${OBJDUMP[2]} + 0x${OBJDUMP[3]} + 4096 - 1) / 4096) * 4096)))
objcopy --add-section .config="$SECTION_PATH" --change-section-vma .config="$VMA" $TMP_XEN_EFI $TMP_XEN_EFI

SECTION_PATH="/boot/initramfs-linux-hardened.img"
SECTION_NAME=".initramfs"
echo "[*] Writing '$SECTION_PATH' to the new $SECTION_NAME section..."
read -r -a OBJDUMP <<< $(objdump -h $TMP_XEN_EFI | grep .config)
VMA=$(printf "%X" $((((0x${OBJDUMP[2]} + 0x${OBJDUMP[3]} + 4096 - 1) / 4096) * 4096)))
objcopy --add-section .config="$SECTION_PATH" --change-section-vma .config="$VMA" $TMP_XEN_EFI $TMP_XEN_EFI

SECTION_PATH="/boot/vmlinuz-linux-hardened"
SECTION_NAME=".kernel"
echo "[*] Writing '$SECTION_PATH' to the new $SECTION_NAME section..."
read -r -a OBJDUMP <<< $(objdump -h $TMP_XEN_EFI | grep .initramfs)
VMA=$(printf "%X" $((((0x${OBJDUMP[2]} + 0x${OBJDUMP[3]} + 4096 - 1) / 4096) * 4096)))
objcopy --add-section .config="$SECTION_PATH" --change-section-vma .config="$VMA" $TMP_XEN_EFI $TMP_XEN_EFI

#SECTION_PATH="/boot/xsm.cfg"
#SECTION_NAME=".xsm"
#echo "[*] Writing '$SECTION_PATH' to the new $SECTION_NAME section..."
#read -r -a OBJDUMP <<< $(objdump -h $TMP_XEN_EFI | grep .kernel)
#VMA=$(printf "%X" $((((0x${OBJDUMP[2]} + 0x${OBJDUMP[3]} + 4096 - 1) / 4096) * 4096)))
#objcopy --add-section .config="$SECTION_PATH" --change-section-vma .config="$VMA" $TMP_XEN_EFI $TMP_XEN_EFI

#SECTION_PATH=
#SECTION_NAME=".ucode"
#echo "[*] Writing '$SECTION_PATH' to the new $SECTION_NAME section..."
#read -r -a OBJDUMP <<< $(objdump -h $TMP_XEN_EFI | grep .pad)
#VMA=$(printf "%X" $((((0x${OBJDUMP[2]} + 0x${OBJDUMP[3]} + 4096 - 1) / 4096) * 4096)))
#objcopy --add-section .config="$SECTION_PATH" --change-section-vma .config="$VMA" $TMP_XEN_EFI $TMP_XEN_EFI

objdump -h $TMP_XEN_EFI
sleep 10

# Copy Xen UKI to EFI partition
echo "[*] Copying the Xen UKI to the EFI partition..."
doas cp $TMP_XEN_EFI $XEN_EFI

# Sign Xen UKI using sbctl
echo "[*] Signing the Xen UKI using sbctl..."
doas sbctl sign $XEN_EFI

# Create a UEFI boot entry
echo "[*] Creating a UEFI boot entry for Xen..."
doas efibootmgr --disk $DISK --part 1 --create --label 'xen' --load '\EFI\xen.efi' --unicode --verbose
doas efibootmgr -v

# Clean up
echo "[*] Cleaning up..."

echo "[*] Removing temporary files..."
doas shred --force --remove=wipesync --verbose --zero $TMP_XEN_CFG
doas shred --force --remove=wipesync --verbose --zero $TMP_XEN_EFI

echo "[*] Should this script be deleted? (yes/no)"
read delete_script

if [ "$delete_script" == "yes" ];
then
    echo "[*] Deleting the script..."
    shred --force --remove=wipesync --verbose --zero $(readlink -f $0)
elif [ "$delete_script" == "no" ];
then
    echo "[*] Skipping script deletion..."
else
    echo "[!] ALERT: Variable 'delete_script' is '$delete_script' but must be 'yes' or 'no'."
fi

# Stop message
echo "[*] Work done. Exiting..."
exit 0
