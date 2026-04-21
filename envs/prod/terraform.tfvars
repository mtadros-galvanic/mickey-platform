# `make templates` creates the default Ubuntu 24.04 server template on Proxmox.
# `make templates-bionic` creates the Ubuntu 18.04 template used by mickey-thud.
# `make templates-jammy` creates the Ubuntu 22.04 template reserved for mickey-scarthgap.
# The host baseline playbook must create the `bulk` datastore before Terraform
# can attach guest disks there.

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

vms = {
  "mickey-infra" = {
    clone_template_name = "ubuntu-24-04-server-cloudinit"
    role                = "infra"
    vm_id               = 700
    cpu_cores           = 4
    memory_mb           = 16384
    os_disk_gb          = 220
    lan_ipv4_cidr       = "10.25.1.206/24"
    tags                = ["infra", "runtime", "samba"]
    extra_disks = [
      {
        datastore_id = "bulk"
        interface    = "scsi1"
        size_gb      = 2048
      }
    ]
  }

  "mickey-erp" = {
    clone_template_name = "ubuntu-24-04-server-cloudinit"
    role                = "erp"
    consul_client       = true
    vm_id               = 701
    cpu_cores           = 6
    memory_mb           = 24576
    os_disk_gb          = 160
    lan_ipv4_cidr       = "10.25.1.208/24"
    tags                = ["erp"]
  }

  "mickey-thud" = {
    clone_template_name  = "ubuntu-18-04-server-cloudinit"
    role                 = "build"
    consul_client        = true
    vm_id                = 702
    cpu_cores            = 4
    memory_mb            = 16384
    os_disk_gb           = 400
    os_disk_datastore_id = "bulk"
    lan_ipv4_cidr        = "10.25.1.105/24"
    on_boot              = false
    tags                 = ["build", "yocto", "ubuntu-18"]
  }

  "mickey-scarthgap" = {
    clone_template_name  = "ubuntu-22-04-server-cloudinit"
    role                 = "build"
    consul_client        = true
    vm_id                = 704
    cpu_cores            = 4
    memory_mb            = 16384
    os_disk_gb           = 400
    os_disk_datastore_id = "bulk"
    lan_ipv4_cidr        = "10.25.1.210/24"
    started              = false
    on_boot              = false
    tags                 = ["build", "yocto", "ubuntu-22"]
  }
}
