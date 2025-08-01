#!/bin/bash
# Debian Trixie Minimal Desktop Base Setup
# Run as regular user with sudo

set -e

# Check user
[[ $EUID -eq 0 ]] && { echo "Run as user, not root"; exit 1; }

# Update system
sudo apt update && sudo apt upgrade -y

# Install essentials
sudo apt install -y \
    build-essential \
    curl \
    gawk \
    wget \
    btop \
    fastfetch \
    fonts-terminus \
    network-manager \
    nftables \
    openssh-client \
    psmisc \
    tlp \
    tlp-rdw \
    vim \
    util-linux \
    zstd

# Create directories
mkdir -p $HOME/src
mkdir -p $HOME/.local/bin

# Move Configs
mv $HOME/base_tty/.vimrc $HOME/
mv $HOME/base_tty/.bashrc $HOME/
mv $HOME/base_tty/.blerc $HOME/
mv $HOME/base_tty/.config $HOME/
sudo mv $HOME/base_tty/.root/.config /root/
sudo cp $HOME/.bashrc /root/
sudo cp $HOME/.vimrc /root/
sudo cp $HOME/base_tty/tlp.conf /etc/

# Setup zram swap
sudo modprobe zram num_devices=1

sudo tee /etc/systemd/system/zram-swap.service >/dev/null <<EOF
[Unit]
Description=zram swap
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/zram-swap
ExecStop=/sbin/swapoff /dev/zram0

[Install]
WantedBy=multi-user.target
EOF

sudo tee /usr/local/bin/zram-swap >/dev/null <<EOF
#!/bin/bash
modprobe zram num_devices=1
echo zstd > /sys/block/zram0/comp_algorithm
echo 8G > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 100 /dev/zram0
EOF

sudo chmod +x /usr/local/bin/zram-swap
sudo systemctl enable --now zram-swap.service

# Install BLE.sh
cd "$HOME/src"
git clone https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install PREFIX=~/.local

# Configure network
sudo sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
sudo tee /etc/network/interfaces >/dev/null <<EOF
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback
EOF

# Setup firewall
sudo tee /etc/nftables.conf >/dev/null <<EOF
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
    chain input { type filter hook input priority filter; policy drop;
        iif "lo" accept
        ct state established,related accept
        ip protocol icmp accept
        ip6 nexthdr ipv6-icmp accept
        udp sport {53,67,123} accept
        tcp sport 53 accept
        udp sport 67 udp dport 68 accept
    }
    chain forward { type filter hook forward priority filter; policy drop; }
    chain output { type filter hook output priority filter; policy accept; }
}
EOF

# Enable services
sudo rm -f /etc/motd
sudo systemctl enable NetworkManager tlp nftables
sudo nft -f /etc/nftables.conf

echo "Installing systemd-boot..."
sudo apt install -y systemd-boot
sudo bootctl install

# Remove GRUB
sudo apt purge --allow-remove-essential -y grub* shim-signed ifupdown nano os-prober vim-tiny zutty
sudo apt autoremove --purge -y

echo "Enter GRUB boot ID to delete (check efibootmgr output):"
sudo efibootmgr
read -r BOOT_ID
sudo efibootmgr -b "$BOOT_ID" -B

echo "Setup complete. Reboot recommended."
