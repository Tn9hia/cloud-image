#!/usr/bin/env bash
# Update OS và cài các package cần cho image cloud.
set -euxo pipefail

case "${OS_FAMILY}" in
  debian)
    export DEBIAN_FRONTEND=noninteractive
    APT="apt-get -y -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

    # Lần boot đầu sau autoinstall, cloud-init + unattended-upgrades có thể đang giữ lock apt.
    cloud-init status --wait >/dev/null 2>&1 || true
    systemctl stop unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer || true

    $APT update
    $APT dist-upgrade
    $APT install \
      cloud-init \
      cloud-guest-utils \
      qemu-guest-agent \
      openssh-server \
      ca-certificates \
      curl
    ;;

  rhel)
    dnf -y update
    dnf -y install \
      cloud-init \
      cloud-utils-growpart \
      gdisk \
      qemu-guest-agent \
      tar \
      curl
    ;;

  *)
    echo "Unsupported OS_FAMILY: ${OS_FAMILY}" >&2
    exit 1
    ;;
esac
