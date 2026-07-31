locals {
  vm_definitions = {
    for vm_name, vm in var.vms :
    vm_name => merge({
      role                 = "extra"
      consul_client        = false
      os_disk_datastore_id = var.fast_datastore_id
      os_disk_iothread     = false
      started              = true
      on_boot              = true
      memory_balloon_mb    = null
      tags                 = []
      extra_disks          = []
      usb_devices          = []
      admin_password_hash  = var.vm_admin_password_hash
      name                 = vm_name
    }, vm)
  }

  template_names = toset([
    for vm in values(local.vm_definitions) : vm.clone_template_name
  ])

  dhcp_ipv4_candidates = {
    for host_key, vm in local.vm_definitions :
    host_key => flatten([
      for interface_index, interface_name in proxmox_virtual_environment_vm.mickey[host_key].network_interface_names :
      interface_name == vm.guest_agent_interface ? [
        for address in try(proxmox_virtual_environment_vm.mickey[host_key].ipv4_addresses[interface_index], []) :
        address
        if address != "127.0.0.1" && !startswith(address, "169.254.")
      ] : []
    ])
    if vm.network_mode == "dhcp"
  }

  inventory_hosts = {
    for host_key, vm in local.vm_definitions :
    host_key => {
      ansible_host          = vm.network_mode == "dhcp" ? one(local.dhcp_ipv4_candidates[host_key]) : split("/", vm.lan_ipv4_cidr)[0]
      ansible_user          = var.vm_admin_user
      role                  = vm.role
      network_mode          = vm.network_mode
      guest_agent_interface = vm.guest_agent_interface
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

  inventory_extra_groups = {
    consul_client_vms = sort([
      for host_key, vm in local.vm_definitions :
      host_key
      if vm.consul_client
    ])
  }

  inventory_all_groups = merge(
    local.inventory_groups,
    {
      for group_name, hosts in local.inventory_extra_groups :
      group_name => hosts
      if length(hosts) > 0
    }
  )

  inventory_group_names = sort(keys(local.inventory_all_groups))
}
