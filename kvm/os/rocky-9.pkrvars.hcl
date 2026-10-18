os_name      = "rocky"
os_version   = "9"
os_family    = "rhel"
default_user = "rocky"

iso_url      = "https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.8-x86_64-minimal.iso"
iso_checksum = "file:https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.8-x86_64-minimal.iso.CHECKSUM"

# Menu isolinux (BIOS): <up> chọn "Install Rocky Linux" thay vì "Test this media", <tab> để sửa cmdline.
boot_wait = "5s"
boot_command = [
  "<up><wait><tab><wait>",
  " inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<enter>",
]
