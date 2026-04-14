# `make templates` creates these default Ubuntu 24.04 template names on Proxmox.
# `make templates-bionic` creates the Ubuntu 18.04 template used by mickey-thud.
# The host baseline playbook must create the `bulk` datastore before Terraform
# can attach the desktop VM data disk there.

proxmox_node_name       = "pve"
vm_bridge               = "vmbr0"
fast_datastore_id       = "local-lvm"
cloud_init_datastore_id = "local-lvm"
bulk_datastore_id       = "bulk"
gateway_ipv4            = "10.25.1.1"
dns_servers             = ["10.25.1.21", "1.1.1.1"]
search_domain           = "galvanic.local"
vm_admin_user           = "galvanic"
cpu_type                = "host"
common_vm_tags          = ["terraform", "mickey-platform", "mickey"]

control_vm = {
  clone_template_name = "ubuntu-24-04-server-cloudinit"
  name                = "mickey-control"
  vm_id               = 701
  cpu_cores           = 2
  memory_mb           = 4096
  os_disk_gb          = 40
  lan_ipv4_cidr       = "10.25.1.103/24"
  tags                = ["automation", "control"]
}

desktop_vm = {
  clone_template_name = "ubuntu-24-04-desktop-cloudinit"
  name                = "mickey-main"
  vm_id               = 700
  cpu_cores           = 10
  memory_mb           = 49152
  os_disk_gb          = 220
  data_disk_gb        = 2048
  lan_ipv4_cidr       = "10.25.1.84/24"
  tags                = ["desktop", "runtime", "samba"]
}

extra_vms = {
  thud = {
    clone_template_name  = "ubuntu-18-04-server-cloudinit"
    name                 = "mickey-thud"
    role                 = "build"
    vm_id                = 702
    cpu_cores            = 4
    memory_mb            = 16384
    os_disk_gb           = 400
    os_disk_datastore_id = "bulk"
    lan_ipv4_cidr        = "10.25.1.105/24"
    started              = false
    on_boot              = false
    tags                 = ["build", "yocto", "ubuntu-18"]
  }
}
