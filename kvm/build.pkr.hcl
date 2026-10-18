build {
  name    = "kvm"
  sources = ["source.qemu.kvm"]

  provisioner "shell" {
    environment_vars = ["OS_FAMILY=${var.os_family}", "PLATFORM=${var.platform}"]
    script           = "${path.root}/scripts/00-base.sh"
  }

  provisioner "file" {
    content     = local.cloud_init_cfg
    destination = "/tmp/99_platform.cfg"
  }

  provisioner "shell" {
    environment_vars = ["OS_FAMILY=${var.os_family}", "PLATFORM=${var.platform}"]
    scripts = [
      "${path.root}/scripts/10-cloud-init.sh",
      "${path.root}/scripts/20-system.sh",
      "${path.root}/scripts/90-cleanup.sh",
    ]
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "${var.output_dir}/${local.image_name}/${local.image_name}.qcow2.{{.ChecksumType}}"
  }

  post-processor "manifest" {
    output     = "${var.output_dir}/manifest.json"
    strip_path = true
    custom_data = {
      image_name = local.image_name
      platform   = var.platform
      os_name    = var.os_name
      os_version = var.os_version
      disk_size  = var.disk_size
    }
  }
}
