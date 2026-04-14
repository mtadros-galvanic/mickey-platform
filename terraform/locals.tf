locals {
  built_in_vm_definitions = {
    (var.control_vm.name) = merge({
      role                 = "control"
      os_disk_datastore_id = var.fast_datastore_id
      started              = true
      on_boot              = true
      tags                 = []
      extra_disks          = []
      admin_password_hash  = null
    }, var.control_vm)

    (var.desktop_vm.name) = merge({
      role                 = "desktop"
      os_disk_datastore_id = var.fast_datastore_id
      started              = true
      on_boot              = true
      tags                 = []
      extra_disks          = []
      admin_password_hash  = null
      }, var.desktop_vm, {
      extra_disks = [
        {
          datastore_id = var.bulk_datastore_id
          interface    = "scsi1"
          size_gb      = var.desktop_vm.data_disk_gb
        }
      ]
    })
  }

  extra_vm_definitions = {
    for _, vm in var.extra_vms :
    vm.name => merge({
      role                 = "extra"
      os_disk_datastore_id = var.fast_datastore_id
      started              = true
      on_boot              = true
      tags                 = []
      extra_disks          = []
      admin_password_hash  = var.extra_vm_admin_password_hash
    }, vm)
  }

  vm_definitions = merge(local.built_in_vm_definitions, local.extra_vm_definitions)

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

  inventory_groups = {
    for role in toset([for vm in values(local.vm_definitions) : vm.role]) :
    "${role}_vms" => sort([
      for host_key, host in local.inventory_hosts :
      host_key
      if host.role == role
    ])
  }

  inventory_group_names = sort(keys(local.inventory_groups))
}
