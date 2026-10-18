# ---------------------------------------------------------------------------
# Platform – truyền qua -var platform=... (Makefile: PLATFORM=...)
# ---------------------------------------------------------------------------
variable "platform" {
  type        = string
  description = "Cloud platform đích: openstack | cloudstack. Mỗi platform một image riêng."

  validation {
    condition     = contains(["openstack", "cloudstack"], var.platform)
    error_message = "Variable platform must be one of: openstack, cloudstack."
  }
}

# ---------------------------------------------------------------------------
# OS – khai báo trong os/<distro>.pkrvars.hcl
# ---------------------------------------------------------------------------
variable "os_name" {
  type        = string
  description = "Tên distro, dùng để đặt tên image (ubuntu, rocky, ...)."
}

variable "os_version" {
  type        = string
  description = "Version distro (24.04, 9, ...)."
}

variable "os_family" {
  type        = string
  description = "Họ distro: debian | rhel. Quyết định file autoinstall/kickstart và nhánh xử lý trong scripts."

  validation {
    condition     = contains(["debian", "rhel"], var.os_family)
    error_message = "Variable os_family must be one of: debian, rhel."
  }
}

variable "iso_url" {
  type = string
}

variable "iso_checksum" {
  type        = string
  description = "Checksum ISO, hỗ trợ dạng file:<url> trỏ tới file SHA256SUMS/CHECKSUM."
}

variable "boot_wait" {
  type    = string
  default = "5s"
}

variable "boot_command" {
  type = list(string)
}

variable "default_user" {
  type        = string
  description = "User mặc định cloud-init tạo ra trên VM (nhận SSH key/password từ OpenStack/CloudStack)."
}

# ---------------------------------------------------------------------------
# VM build
# ---------------------------------------------------------------------------
variable "accelerator" {
  type        = string
  default     = "kvm"
  description = "kvm trên Linux build host. Dùng tcg nếu build host không có KVM (rất chậm)."
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

variable "disk_size" {
  type        = string
  default     = "10G"
  description = "Size root disk của template. Nên giữ nhỏ, cloud-init growpart sẽ nới ra theo disk offering/flavor."
}

variable "headless" {
  type    = bool
  default = true
}

variable "output_dir" {
  type    = string
  default = "output"
}

variable "build_password" {
  type        = string
  sensitive   = true
  default     = "Packer-Build-2026"
  description = "Password root tạm thời để Packer SSH vào lúc build, bị khoá ở bước cleanup. Chỉ dùng ký tự chữ/số/-/_ vì được nhúng vào shell và YAML. Override qua env PKR_VAR_build_password."
}

# ---------------------------------------------------------------------------
# Guest config
# ---------------------------------------------------------------------------
variable "timezone" {
  type    = string
  default = "Etc/UTC"
}

variable "ubuntu_mirror" {
  type        = string
  default     = "http://archive.ubuntu.com/ubuntu"
  description = "APT mirror cho Ubuntu (chỉ dùng khi os_family = debian)."
}

variable "ssh_pwauth" {
  type        = bool
  default     = null
  description = "Cho phép SSH bằng password. Để null thì theo platform: cloudstack = true (cần cho tính năng password), openstack = false (chỉ key)."
}

variable "disable_root" {
  type        = bool
  default     = true
  description = "true = không cho SSH thẳng root bằng key inject từ cloud (khuyến nghị)."
}
