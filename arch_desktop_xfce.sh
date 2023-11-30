#FIXME: Everything

# Ensure German keyboard layout & timezone
sudo loadkeys de-latin1
sudo localectl set-keymap de
sudo timedatectl set-timezone Europe/Berlin

# System update
echo "Updating the system..."
sudo pacman --disable-download-timeout --needed --noconfirm -Syu

# Install Xorg
sudo pacman --disable-download-timeout --needed --noconfirm -S xorg xorg-drivers

# Install LightDM and Xfce
sudo pacman --disable-download-timeout --needed --noconfirm -S light-locker lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings xfce4

# Set dark theme
xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"
xfce4-settings-manager --reload

# Install additional applications
sudo pacman --disable-download-timeout --needed --noconfirm -S mousepad network-manager-applet ristretto thunar-archive-plugin thunar-media-tags-plugin xarchiver xfce4-artwork xfce4-cpugraph-plugin xfce4-mount-plugin xfce4-notifyd xfce4-pulseaudio-plugin xfce4-screenshooter xfce4-taskmanager xfce4-whiskermenu-plugin

# Configure LightDM service
sudo systemctl enable --now lightdm.service

# Clean up
sudo pacman --noconfirm -Rns $(pacman -Qdtq)
