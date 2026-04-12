locals {
  vm_definitions = {
    (var.control_vm.name) = merge(var.control_vm, {
      role       = "control"
      extra_disks = []
    })

    (var.desktop_vm.name) = merge(var.desktop_vm, {
      role = "desktop"
      extra_disks = [
        {
          datastore_id = var.bulk_datastore_id
          interface    = "scsi1"
          size_gb      = var.desktop_vm.data_disk_gb
        }
      ]
    })
  }

  template_names = toset([
    for vm in values(local.vm_definitions) : vm.clone_template_name
  ])

  inventory_hosts = {
    for host_key, vm in local.vm_definitions :
    host_key => {
      ansible_host = split("/", vm.lan_ipv4_cidr)[0]
      ansible_user = var.vm_admin_user
      role         = vm.role
    }
  }
}
