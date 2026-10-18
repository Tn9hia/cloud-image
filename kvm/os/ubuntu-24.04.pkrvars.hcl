os_name      = "ubuntu"
os_version   = "24.04"
os_family    = "debian"
default_user = "ubuntu"

iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04.5-live-server-amd64.iso"
iso_checksum = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"

boot_wait = "5s"
boot_command = [
  "c<wait3>",
  "linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter><wait3>",
  "initrd /casper/initrd<enter><wait3>",
  "boot<enter>",
]
