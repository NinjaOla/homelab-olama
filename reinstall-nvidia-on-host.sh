#!/bin/bash
# Reinstall NVIDIA driver on Proxmox host after kernel update
# Usage: ./reinstall-nvidia-host.sh [driver_version]

DRIVER_VERSION=${1:-580.95.05}
DRIVER_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run"
KERNEL=$(uname -r)

echo "==================================="
echo "NVIDIA Host Driver Reinstaller"
echo "==================================="
echo "Kernel: $KERNEL"
echo "Driver: $DRIVER_VERSION"
echo ""

# Install kernel headers
echo "==> Installing kernel headers..."
apt update -qq
apt install -y pve-headers-${KERNEL}

# Download driver if not present
if [ ! -f "NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run" ]; then
    echo "==> Downloading NVIDIA driver..."
    wget -q --show-progress ${DRIVER_URL}
    chmod +x NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run
else
    echo "==> Driver already downloaded"
fi

# Install driver
echo "==> Installing NVIDIA driver..."
./NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run --silent --dkms

# Update initramfs
echo "==> Updating initramfs..."
update-initramfs -u -k all

echo ""
echo "✓ Installation complete!"
echo ""
echo "Reboot required. Reboot now? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    reboot
else
    echo "Remember to reboot manually: reboot"
fi
