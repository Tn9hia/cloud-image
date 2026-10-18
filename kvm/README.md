# cloud-image / kvm

Build template qcow2 bằng Packer (builder `qemu`) cho hypervisor KVM. **Mỗi platform có image riêng** (`openstack`, `cloudstack`): cùng base OS, cùng script, chỉ khác phần cấu hình cloud-init và một số tinh chỉnh riêng.

| OS | var file |
|---|---|
| Ubuntu 24.04 | `os/ubuntu-24.04.pkrvars.hcl` |
| Ubuntu 22.04 | `os/ubuntu-22.04.pkrvars.hcl` |
| Rocky Linux 9 | `os/rocky-9.pkrvars.hcl` |

## Yêu cầu build host

- Linux có KVM (`/dev/kvm`), user build nằm trong group `kvm`
- Packer >= 1.10, `qemu-system-x86`, `qemu-utils`
- Có internet (tải ISO, package update)

## Build

```bash
export PKR_VAR_build_password='Doi-Pass-Build-123'   # tuỳ chọn, chỉ chữ/số/-/_

make init
make validate OS=ubuntu-24.04 PLATFORM=openstack
make build    OS=ubuntu-24.04 PLATFORM=cloudstack
make build-all          # mọi tổ hợp OS x PLATFORM
```

Kết quả nằm trong `output/<os>-<version>-<platform>-<YYYYMMDD>/`, gồm file `.qcow2` và `.qcow2.sha256`. File `output/manifest.json` ghi lại các lần build.

Debug: `PACKER_LOG=1 make build OS=rocky-9 PLATFORM=openstack`, hoặc đặt `headless = false` / kết nối VNC theo port Packer in ra.

## Cấu trúc

```
kvm/
├── packer.pkr.hcl        # required plugins
├── variables.pkr.hcl     # biến
├── locals.pkr.hcl        # tên image, render template http + cloud-init
├── sources.pkr.hcl       # source "qemu" "kvm"
├── build.pkr.hcl         # provisioners + post-processors
├── os/*.pkrvars.hcl      # ISO, boot_command, default_user theo từng distro
├── http/
│   ├── ubuntu/user-data.pkrtpl   # autoinstall (subiquity)
│   └── rocky/ks.cfg.pkrtpl       # kickstart
├── files/cloud-init/
│   ├── openstack.cfg.pkrtpl      # -> /etc/cloud/cloud.cfg.d/99_openstack.cfg
│   └── cloudstack.cfg.pkrtpl     # -> /etc/cloud/cloud.cfg.d/99_cloudstack.cfg
└── scripts/
    ├── 00-base.sh        # update + cài cloud-init, growpart, qemu-guest-agent
    ├── 10-cloud-init.sh  # datasource, module frequency, dọn config installer
    ├── 20-system.sh      # grub serial console, dracut generic, hotplug CPU/RAM (cloudstack)
    └── 90-cleanup.sh     # generalize: machine-id, host key, network, log, khoá root
```

## Quyết định thiết kế

### Layout disk
- BIOS (SeaBIOS, machine `pc`): giống mặc định của Nova và CloudStack KVM.
- GPT gồm 2 partition: `[1] bios_grub 1M` và `[2] /`. Không LVM, không swap. Root nằm ở partition cuối nên `growpart` nới ra được ngay khi disk offering/flavor lớn hơn template.
- Build trên `virtio-scsi` có bật discard, sau đó `fstrim` và `qemu-img convert -c` để file qcow2 nhỏ nhất có thể.
- Rocky: dùng dracut với `hostonly="no"`. Nếu không làm vậy, initramfs chỉ chứa driver virtio-scsi của VM build, và VM clone chạy virtio-blk sẽ không boot được.

### Khác biệt giữa 2 platform

| | OpenStack | CloudStack |
|---|---|---|
| `datasource_list` | `[ ConfigDrive, OpenStack, None ]` | `[ ConfigDrive, CloudStack, None ]` |
| `ssh_pwauth` (mặc định) | `false`, chỉ login bằng key | `true`, cần cho tính năng password |
| Module `set_passwords`, `ssh` | Mặc định (once-per-instance) | `always` (file `98_module_frequency.cfg`) |
| Host key | cloud-init tự sinh lại khi có instance mới | `ssh_deletekeys: false` + bootcmd xoá host key khi instance-id đổi |
| Hotplug CPU/RAM udev rule | Không | Có (dynamic scaling) |

Muốn đổi `ssh_pwauth` khác mặc định thì truyền `-var ssh_pwauth=true|false`.

### CloudStack: password và SSH key
Mặc định module `set_passwords` và `ssh` chỉ chạy ở lần boot đầu. Để nút **Reset Password** và **Reset SSH Key** trên CloudStack có tác dụng, script `10-cloud-init.sh` đọc module list của chính distro rồi sinh ra `98_module_frequency.cfg`, chuyển 2 module này sang `always`. Script không sed `/etc/cloud/cloud.cfg` vì đó là file của package, dễ conflict khi upgrade.

Đi kèm với thay đổi đó:
- `ssh_deletekeys: false`: nếu không đặt, host key bị sinh lại mỗi lần reboot.
- `bootcmd` + `cloud-init-per instance` xoá host key khi instance-id đổi. Nhờ vậy VM tạo từ snapshot vẫn có host key riêng, tránh lỗ hổng MITM mà docs CloudStack cảnh báo.
- `chpasswd.expire: false`.

Lưu ý khi vận hành image CloudStack (nên báo cho khách hàng):
1. **Password đặt qua user-data sẽ bị áp lại mỗi lần reboot**, vì `set_passwords` chạy `always`. Password do password server của VR cấp không bị ảnh hưởng, vì VR chỉ trả password một lần.
2. Nếu user-data của khách khai báo `bootcmd` riêng, list đó thay thế bootcmd của image. Hệ quả là VM tạo từ snapshot sẽ không tự sinh lại host key.
3. Network dùng **ConfigDrive provider** (không có VR): CloudStack ghi password vào config drive, nhưng datasource ConfigDrive của cloud-init không đọc phần này. Tính năng password chỉ chạy với network có VR.

## Upload image

### OpenStack (Glance)
```bash
IMG=output/ubuntu-24.04-openstack-20261019/ubuntu-24.04-openstack-20261019.qcow2
openstack image create "Ubuntu 24.04" \
  --disk-format qcow2 --container-format bare --file "$IMG" \
  --min-disk 10 --min-ram 512 \
  --property hw_disk_bus=scsi --property hw_scsi_model=virtio-scsi \
  --property hw_vif_model=virtio \
  --property hw_qemu_guest_agent=yes --property os_require_quiesce=yes \
  --property os_type=linux --property os_distro=ubuntu --property os_version=24.04
```
- Nếu Glance và Nova dùng Ceph RBD: convert sang raw trước (`qemu-img convert -O raw`) để clone COW nhanh.
- `hw_disk_bus=scsi` là tuỳ chọn, giúp TRIM/discard hoạt động. Bỏ property này thì Nova dùng virtio-blk, image vẫn boot bình thường.

### CloudStack
Đặt file qcow2 lên một HTTP server mà Secondary Storage VM truy cập được, sau đó:
```bash
cmk register template name="Ubuntu 24.04" displaytext="Ubuntu 24.04 (cloud-init)" \
  format=QCOW2 hypervisor=KVM zoneids=-1 ostypeid=<id> \
  url=http://repo.local/images/ubuntu-24.04-cloudstack-20261019.qcow2 \
  checksum="{SHA-256}$(cut -d' ' -f1 output/.../*.qcow2.sha256)" \
  passwordenabled=true sshkeyenabled=true isdynamicallyscalable=true \
  requireshvm=true ispublic=true \
  details[0].rootDiskController=scsi
```

## Checklist test sau khi deploy

Chung cho cả 2 image:

- [ ] `cloud-id` trả về đúng `openstack` / `cloudstack`; `cloud-init status --long` là `done`, không có lỗi
- [ ] Thời gian boot hợp lý (`cloud-init analyze show`), không bị treo chờ timeout metadata
- [ ] Disk lớn hơn template thì `/` tự nới (`df -h /`)
- [ ] Hostname, SSH key, network (DHCP và IP tĩnh qua ConfigDrive trên OpenStack) đều đúng
- [ ] Reboot nhiều lần: SSH host key fingerprint **không đổi**
- [ ] Tạo VM từ snapshot: host key **khác** VM gốc, `/etc/machine-id` khác
- [ ] `qemu-guest-agent` chạy (`virsh qemu-agent-command <dom> '{"execute":"guest-ping"}'`)
- [ ] `nova console-log` / console CloudStack thấy được log boot (serial ttyS0)

Riêng CloudStack:

- [ ] Reset Password và Reset SSH Key, rồi reboot VM, đều có tác dụng
- [ ] Scale CPU/RAM khi VM đang chạy, CPU và RAM mới được online

## Roadmap
- Hỗ trợ UEFI (hybrid BIOS + ESP) cho flavor/template dùng OVMF
- Ubuntu 26.04, Rocky/Alma 10 (yêu cầu CPU x86-64-v3)
- Hardening theo CIS, agent monitoring/backup nếu cần
