# Install yay for access to the AUR ecosystem
mkdir ~/tools
cd ~/tools
git clone https://aur.archlinux.org/yay.git
makepkg -si
yay --version


# Pacman software
TOOLS="dmidecode git gparted rkhunter wget"
for Tool in $TOOLS; do
    sudo pacman --disable-download-timeout --noconfirm -Sy $Tool
done


# AUR software
TOOLS="chkrootkit secure-delete"
for Tool in $TOOLS; do
    sudo yay --disable-download-timeout --noconfirm -Sy $Tool
done
