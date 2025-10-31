#!/bin/bash
set -euo pipefail

# =============================
# Ubuntu 22.04 VM (No-KVM Mode)
# =============================

clear
cat << "EOF"
================================================
  _    _  ____  _____ _____ _   _  _____ ____   ______     ________
 | |  | |/ __ \|  __ \_   _| \ | |/ ____|  _ \ / __ \ \   / /___  /
 | |__| | |  | | |__) || | |  \| | |  __| |_) | |  | \ \_/ /   / / 
 |  __  | |  | |  ___/ | | |   \ | | |_ |  _ <| |  | |\   /   / /  
 | |  | | |__| | |    _| |_| |\  | |__| | |_) | |__| | | |   / /__ 
 |_|  |_|\____/|_|   |_____|_| \_|\_____|____/ \____/  |_|  /_____|

                        MODIFY BY FAI                                             
              POWERED BY HOPINGBOYZ (No-KVM Edition)
================================================
EOF

# =============================
# Configurable Variables
# =============================
VM_DIR="$HOME/vms"
IMG_FILE="$VM_DIR/ubuntu22.img"
SEED_FILE="$VM_DIR/ubuntu22-seed.iso"
MEMORY=8096   # 8GB RAM (rekomendasi, bisa ubah)
CPUS=2
SSH_PORT=2222
DISK_SIZE=50G

mkdir -p "$VM_DIR"
cd "$VM_DIR"

# =============================
# VM Image Setup
# =============================

sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager cloud-image-utils

if [ ! -f "$IMG_FILE" ]; then
    echo "[INFO] VM image not found, creating new VM..."
    wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O "$IMG_FILE"
    qemu-img resize "$IMG_FILE" "$DISK_SIZE"

    # Cloud-init config with hostname = ubuntu22
    cat > user-data <<EOF
#cloud-config
hostname: ubuntu22
manage_etc_hosts: true
disable_root: false
ssh_pwauth: true
chpasswd:
  list: |
    root:root
  expire: false
growpart:
  mode: auto
  devices: ["/"]
  ignore_growroot_disabled: false
resize_rootfs: true
runcmd:
 - growpart /dev/vda 1 || true
 - resize2fs /dev/vda1 || true
 - sed -ri "s/^#?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
 - systemctl restart ssh
EOF

    cat > meta-data <<EOF
instance-id: iid-local01
local-hostname: ubuntu22
EOF

    cloud-localds "$SEED_FILE" user-data meta-data
    echo "[INFO] VM setup complete!"
else
    echo "[INFO] VM image found, skipping setup..."
fi

# =============================
# Start VM (No KVM)
# =============================
echo "[INFO] Starting VM in software-emulation mode (no KVM)..."
exec qemu-system-x86_64 \
    -m "$MEMORY" \
    -smp "$CPUS" \
    -cpu qemu64 \
    -machine accel=tcg \
    -drive file="$IMG_FILE",format=qcow2,if=virtio \
    -drive file="$SEED_FILE",format=raw,if=virtio \
    -boot order=c \
    -device virtio-net-pci,netdev=n0 \
    -netdev user,id=n0,hostfwd=tcp::"$SSH_PORT"-:22 \
    -nographic -serial mon:stdio
