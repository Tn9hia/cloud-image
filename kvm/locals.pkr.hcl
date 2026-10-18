locals {
  build_date = formatdate("YYYYMMDD", timestamp())
  image_name = "${var.os_name}-${var.os_version}-${var.platform}-${local.build_date}"

  # File phục vụ qua HTTP server của Packer cho installer, mỗi os_family một bộ.
  http_contents = {
    debian = {
      "/meta-data" = ""
      "/user-data" = templatefile("${path.root}/http/ubuntu/user-data.pkrtpl", {
        build_password = var.build_password
        timezone       = var.timezone
        ubuntu_mirror  = var.ubuntu_mirror
      })
    }
    rhel = {
      "/ks.cfg" = templatefile("${path.root}/http/rocky/ks.cfg.pkrtpl", {
        build_password = var.build_password
        timezone       = var.timezone
      })
    }
  }

  ssh_pwauth = var.ssh_pwauth != null ? var.ssh_pwauth : var.platform == "cloudstack"

  cloud_init_cfg = templatefile("${path.root}/files/cloud-init/${var.platform}.cfg.pkrtpl", {
    default_user = var.default_user
    ssh_pwauth   = local.ssh_pwauth
    disable_root = var.disable_root
  })
}
