#!/bin/bash
# GPU Passthrough Configuration Script for Proxmox LXC
# Usage: ./gpu-passthrough.sh <container_id>

if [ -z "$1" ]; then
    echo "Usage: $0 <container_id>"
    exit 1
fi

CTID=$1
CONFIG="/etc/pve/lxc/${CTID}.conf"

if [ ! -f "$CONFIG" ]; then
    echo "Error: Container $CTID config not found at $CONFIG"
    exit 1
fi

echo "Detecting NVIDIA device numbers..."

# Get unique major device numbers (convert hex to decimal)
MAJOR_NVIDIA=$((16#$(stat -c '%t' /dev/nvidia0 2>/dev/null)))
MAJOR_UVM=$((16#$(stat -c '%t' /dev/nvidia-uvm 2>/dev/null)))
MAJOR_CAPS=$((16#$(stat -c '%t' /dev/nvidia-caps/nvidia-cap1 2>/dev/null)))

if [ "$MAJOR_NVIDIA" -eq 0 ]; then
    echo "Error: NVIDIA devices not found. Is the driver loaded?"
    exit 1
fi

echo "Detected device numbers:"
echo "  nvidia: $MAJOR_NVIDIA"
echo "  nvidia-uvm: $MAJOR_UVM"
echo "  nvidia-caps: $MAJOR_CAPS"

# Check if already configured
if grep -q "lxc.cgroup2.devices.allow.*nvidia" "$CONFIG" || grep -q "lxc.mount.entry:.*nvidia" "$CONFIG"; then
    echo "Warning: GPU passthrough config found in $CONFIG"
    read -p "Remove old config and reconfigure? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    # Remove old GPU config
    sed -i '/# GPU Passthrough/d' "$CONFIG"
    sed -i '/lxc.cgroup2.devices.allow: c [0-9]*:\* rwm/d' "$CONFIG"
    sed -i '/lxc.mount.entry:.*nvidia/d' "$CONFIG"
fi

# Backup config
cp "$CONFIG" "${CONFIG}.backup-$(date +%Y%m%d-%H%M%S)"

# Add cgroup device permissions
echo "" >> "$CONFIG"
echo "# GPU Passthrough - Auto-configured $(date)" >> "$CONFIG"
echo "lxc.cgroup2.devices.allow: c $MAJOR_NVIDIA:* rwm" >> "$CONFIG"
[ "$MAJOR_UVM" -gt 0 ] && echo "lxc.cgroup2.devices.allow: c $MAJOR_UVM:* rwm" >> "$CONFIG"
[ "$MAJOR_CAPS" -gt 0 ] && echo "lxc.cgroup2.devices.allow: c $MAJOR_CAPS:* rwm" >> "$CONFIG"

# Add mount entries
echo "lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file" >> "$CONFIG"
echo "lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file" >> "$CONFIG"
echo "lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file" >> "$CONFIG"
[ -e /dev/nvidia-modeset ] && echo "lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file" >> "$CONFIG"
echo "lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file" >> "$CONFIG"
[ -e /dev/nvidia-caps/nvidia-cap1 ] && echo "lxc.mount.entry: /dev/nvidia-caps/nvidia-cap1 dev/nvidia-caps/nvidia-cap1 none bind,optional,create=file" >> "$CONFIG"
[ -e /dev/nvidia-caps/nvidia-cap2 ] && echo "lxc.mount.entry: /dev/nvidia-caps/nvidia-cap2 dev/nvidia-caps/nvidia-cap2 none bind,optional,create=file" >> "$CONFIG"

echo ""
echo "✓ GPU passthrough configured for container $CTID"
echo ""
echo "Restart container:"
echo "  pct stop $CTID && pct start $CTID"
