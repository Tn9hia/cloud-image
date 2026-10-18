source "qemu" "kvm" {
  vm_name          = "${local.image_name}.qcow2"
  output_directory = "${var.output_dir}/${local.image_name}"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # i440fx + SeaBIOS: giống mặc định của Nova và CloudStack KVM.
  machine_type = "pc"
  accelerator  = var.accelerator
  cpu_model    = "host" # Rocky/RHEL 9 yêu cầu x86-64-v2, qemu64 mặc định không đủ
  cpus         = var.cpus
  memory       = var.memory

  format             = "qcow2"
  disk_size          = var.disk_size
  disk_interface     = "virtio-scsi"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = true
  net_device         = "virtio-net"

  headless         = var.headless
  vnc_bind_address = "127.0.0.1"

  http_content = local.http_contents[var.os_family]
  boot_wait    = var.boot_wait
  boot_command = var.boot_command

  communicator           = "ssh"
  ssh_username           = "root"
  ssh_password           = var.build_password
  ssh_timeout            = "60m"
  ssh_handshake_attempts = 200

  shutdown_command = "shutdown -P now"
  shutdown_timeout = "10m"
}
