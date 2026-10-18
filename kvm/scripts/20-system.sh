#!/usr/bin/env bash
# Tinh chỉnh OS cho môi trường KVM cloud (OpenStack + CloudStack).
set -euxo pipefail

KERNEL_ARGS="console=tty0 console=ttyS0,115200n8 no_timer_check"

case "${OS_FAMILY}" in
  debian)
    # Console ra serial để xem được log boot (nova console-log / CloudStack console).
    cat > /etc/default/grub.d/50-cloud.cfg <<EOF
GRUB_TIMEOUT=1
GRUB_TIMEOUT_STYLE=countdown
GRUB_CMDLINE_LINUX_DEFAULT="${KERNEL_ARGS}"
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --speed=115200"
EOF
    update-grub
    ;;

  rhel)
    # Installer build initramfs ở chế độ hostonly => chỉ có driver của VM build (virtio-scsi).
    # Clone ra chạy virtio-blk (mặc định của Nova/CloudStack) sẽ không boot được, nên phải build generic.
    cat > /etc/dracut.conf.d/90-cloud.conf <<'EOF'
hostonly="no"
hostonly_cmdline="no"
EOF
    dracut --force --regenerate-all

    sed -ri 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    sed -ri "s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"${KERNEL_ARGS}\"/" /etc/default/grub
    grubby --update-kernel=ALL --remove-args="rhgb quiet crashkernel" --args="${KERNEL_ARGS}"
    grub2-mkconfig -o /boot/grub2/grub.cfg

    # Tránh route zeroconf 169.254.0.0/16 đè lên route tới metadata service.
    grep -q '^NOZEROCONF=' /etc/sysconfig/network 2>/dev/null || echo 'NOZEROCONF=yes' >> /etc/sysconfig/network

    systemctl enable qemu-guest-agent.service || true
    ;;
esac

if [ "${PLATFORM}" = "cloudstack" ]; then
  # CloudStack dynamic scaling (hot-add CPU/RAM): tự online CPU/memory được cắm nóng.
  cat > /etc/udev/rules.d/80-hotplug-cpu-mem.rules <<'EOF'
SUBSYSTEM=="cpu", ACTION=="add", TEST=="online", ATTR{online}=="0", ATTR{online}="1"
SUBSYSTEM=="memory", ACTION=="add", TEST=="state", ATTR{state}=="offline", ATTR{state}="online"
EOF
fi
