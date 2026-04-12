# `make templates` creates these default template names on Proxmox.
# The host baseline playbook must create the `bulk` datastore before Terraform
# can attach the desktop VM data disk there.

proxmox_node_name        = "pve"
vm_bridge                = "vmbr0"
fast_datastore_id        = "local-lvm"
cloud_init_datastore_id  = "local-lvm"
bulk_datastore_id        = "bulk"
gateway_ipv4             = "10.25.1.1"
dns_servers              = ["10.25.1.21", "1.1.1.1"]
search_domain            = "galvanic.local"
vm_admin_user            = "galvanic"
cpu_type                 = "host"
common_vm_tags           = ["terraform", "mickey-platform", "mickey"]

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
