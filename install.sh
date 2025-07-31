#!/bin/bash
# Debian Trixie Minimal Desktop Base Setup Script
# Run as regular user with sudo privileges

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "Do not run this script as root. Run as regular user with sudo privileges."
    exit 1
fi

# Set base directory variable
BASE_DIR="$HOME/base_tty"

# Verify we're on Debian Trixie
if ! grep -q "trixie" /etc/debian_version 2>/dev/null; then
    log_warn "This script is designed for Debian Trixie. Continue anyway? [y/N]"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] || exit 1
fi

log_info "Starting Debian Trixie minimal desktop setup..."

# ============================================================================
# STEP 1: System Update and Basic Dependencies
# ============================================================================
log_info "Updating system packages..."
sudo apt update && sudo apt upgrade -y

log_info "Installing basic development tools..."
sudo apt install -y git build-essential curl wget

# ============================================================================
# STEP 2: Create Directory Structure
# ============================================================================
log_info "Creating directory structure..."
mkdir -p "$HOME"/{src,.local/bin,.config}

# ============================================================================
# STEP 3: Move Base Configuration Files
# ============================================================================
log_info "Setting up base configuration files..."
# Move user configs
mv "$BASE_DIR/.vimrc" "$HOME/"
mv "$BASE_DIR/.bashrc" "$HOME/"
mv "$BASE_DIR/.blerc" "$HOME/"

# Setup root configuration
sudo mv "$BASE_DIR/.root/.config" /root/

# Copy user configs to root
sudo cp "$HOME/.bashrc" /root/
sudo cp "$HOME/.vimrc" /root/
sudo cp "$HOME/.blerc" /root/

# ============================================================================
# STEP 4: Setup zram Swap
# ============================================================================
log_info "Setting up zram swap..."
sudo apt install -y util-linux zstd

# Load zram module
sudo modprobe zram num_devices=1

# Create systemd service
sudo tee /etc/systemd/system/zram-swap.service > /dev/null << 'EOF'
[Unit]
Description=zram swap
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/zram-swap
ExecStop=/sbin/swapoff /dev/zram0
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create swap script
sudo tee /usr/local/bin/zram-swap > /dev/null << 'EOF'
#!/bin/bash
modprobe zram num_devices=1
echo zstd > /sys/block/zram0/comp_algorithm
echo 8G > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 100 /dev/zram0
EOF

sudo chmod +x /usr/local/bin/zram-swap

# Enable and start zram swap
sudo systemctl daemon-reload
sudo systemctl enable zram-swap.service
sudo systemctl start zram-swap.service

log_info "zram swap configured: 8GB with zstd compression"

# ============================================================================
# STEP 5: Install Essential Packages
# ============================================================================
log_info "Installing essential packages..."
sudo apt install -y \
    btop \
    cliphist \
    fastfetch \
    fbset \
    fonts-terminus \
    network-manager \
    nftables \
    openssh-client \
    pkexec \
    psmisc \
    tar \
    tlp \
    tlp-rdw \
    unzip \
    vim \
    zip

# ============================================================================
# STEP 6: Setup BLE.sh (Bash Line Editor)
# ============================================================================
log_info "Installing BLE.sh..."
cd "$HOME/src"

log_info "Cloning BLE.sh repository..."
git clone https://github.com/akinomyoga/ble.sh.git

cd ble.sh
log_info "Building BLE.sh..."
make

log_info "Installing BLE.sh system-wide..."
sudo make install PREFIX=/usr/local

log_info "BLE.sh installed to /usr/local/share/blesh/"

# ============================================================================
# STEP 7: Configure Network and Services
# ============================================================================
log_info "Configuring NetworkManager..."
sudo sed -i 's/managed=false/managed=true/g' /etc/NetworkManager/NetworkManager.conf

# Setup minimal network interfaces
sudo tee /etc/network/interfaces > /dev/null << 'EOF'
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback
EOF

# Remove motd
sudo rm -rf /etc/motd

# Enable services
sudo systemctl enable NetworkManager
sudo systemctl enable tlp.service

# ============================================================================
# STEP 8: Setup nftables Firewall
# ============================================================================
log_info "Configuring nftables firewall..."
sudo tee /etc/nftables.conf > /dev/null << 'EOF'
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        iif "lo" accept
        ct state established,related accept
        ip protocol icmp accept
        ip6 nexthdr ipv6-icmp accept
        udp sport 67 udp dport 68 accept
        udp sport 53 accept
        tcp sport 53 accept
        udp sport 123 accept
        counter drop
    }
    
    chain forward {
        type filter hook forward priority filter; policy drop;
    }
    
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
EOF

sudo systemctl enable nftables
sudo systemctl start nftables
sudo nft -f /etc/nftables.conf

log_info "nftables firewall configured and enabled"

# ============================================================================
# STEP 9: Bootloader Setup (Optional)
# ============================================================================
log_warn "Bootloader replacement (GRUB -> systemd-boot) requires manual intervention."
log_warn "Run the following commands manually after reviewing:"
echo "sudo apt install -y systemd-boot"
echo "sudo bootctl install"
echo "sudo apt purge --allow-remove-essential -y grub* shim-signed ifupdown nano os-prober vim-tiny zutty"
echo "sudo apt autoremove --purge -y"
echo "sudo efibootmgr  # Note the GRUB entry number"
echo "sudo efibootmgr -b <BOOT_ID> -B  # Replace <BOOT_ID> with GRUB entry"

# ============================================================================
# STEP 10: Final Status
# ============================================================================
log_info "Base system setup completed successfully!"
log_info "Installed components:"
echo "  ✓ zram swap (8GB, zstd compression)"
echo "  ✓ Essential packages and tools"
echo "  ✓ BLE.sh (enhanced bash)"
echo "  ✓ NetworkManager configuration"
echo "  ✓ nftables firewall"
echo "  ✓ TLP power management"

log_warn "Next steps:"
echo "  1. Reboot to ensure all services start correctly"
echo "  2. Install systemd-boot (manual step above)"
echo "  3. Install qtile and suckless tools"
echo "  4. Configure Python development environment"

log_info "Reboot recommended. Reboot now? [y/N]"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    sudo reboot
fi
