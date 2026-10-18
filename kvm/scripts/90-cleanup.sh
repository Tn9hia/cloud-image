#!/usr/bin/env bash
# Generalize template: xoá mọi thứ gắn với VM build để mỗi VM clone ra là một instance mới.
set -euxo pipefail

# --- Package cache -----------------------------------------------------------
case "${OS_FAMILY}" in
  debian)
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y autoremove --purge
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    ;;
  rhel)
    dnf clean all
    rm -rf /var/cache/dnf/*
    ;;
esac

# --- Network của VM build ----------------------------------------------------
# cloud-init sẽ render lại network config theo MAC/metadata của VM mới.
rm -f /etc/netplan/*.yaml
rm -f /etc/NetworkManager/system-connections/*
rm -f /etc/sysconfig/network-scripts/ifcfg-*
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -rf /var/lib/dhcp/* /var/lib/dhclient/* /var/lib/NetworkManager/*
if [ ! -L /etc/resolv.conf ]; then
  : > /etc/resolv.conf
fi

# --- cloud-init state --------------------------------------------------------
cloud-init clean --logs --seed
rm -rf /var/lib/cloud/*
rm -f /etc/sudoers.d/90-cloud-init-users
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf

# --- Định danh máy -----------------------------------------------------------
truncate -s 0 /etc/machine-id
if [ -f /var/lib/dbus/machine-id ] && [ ! -L /var/lib/dbus/machine-id ]; then
  rm -f /var/lib/dbus/machine-id
fi
rm -f /var/lib/systemd/random-seed
rm -f /etc/ssh/ssh_host_*
echo "localhost" > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1   localhost localhost.localdomain
::1         localhost ip6-localhost ip6-loopback
EOF

# --- Thu hồi quyền truy cập dùng lúc build -----------------------------------
rm -f /etc/ssh/sshd_config.d/01-packer-build.conf
usermod -p '!' root
rm -rf /root/.ssh

# Installer log + kickstart chứa build password dạng plaintext.
rm -rf /var/log/installer /var/log/anaconda
rm -f /root/anaconda-ks.cfg /root/original-ks.cfg

# --- Log, tmp, history -------------------------------------------------------
journalctl --rotate || true
journalctl --vacuum-time=1s || true
rm -rf /var/log/journal/*
find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' -o -name '*-[0-9]*' \) -delete
find /var/log -type f -exec truncate -s 0 {} +
rm -rf /tmp/* /var/tmp/*
rm -f /root/.bash_history /root/.lesshst /root/.viminfo

# --- SELinux label cho file tạo trong lúc build ------------------------------
if command -v restorecon >/dev/null 2>&1; then
  restorecon -R /etc /root /var/lib /var/log || true
fi

# --- Giải phóng block trống để qcow2 nén nhỏ ---------------------------------
fstrim -av || true
sync
