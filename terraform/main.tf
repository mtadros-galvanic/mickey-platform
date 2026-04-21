data "proxmox_virtual_environment_vms" "clone_template" {
  for_each  = local.template_names
  node_name = var.proxmox_node_name

  filter {
    name   = "name"
    values = [each.value]
  }

  filter {
    name   = "template"
    values = ["true"]
  }
}

locals {
  clone_template_matches = {
    for template_name, template_data in data.proxmox_virtual_environment_vms.clone_template :
    template_name => template_data.vms
  }

  clone_template_vm_ids = {
    for template_name, matches in local.clone_template_matches :
    template_name => matches[0].vm_id
    if length(matches) == 1
  }

  invalid_template_lookups = [
    for template_name, matches in local.clone_template_matches :
    format("%s(%d)", template_name, length(matches))
    if length(matches) != 1
  ]

  requested_vm_names = keys(local.vm_definitions)
}

check "clone_template_lookup" {
  assert {
    condition     = length(local.invalid_template_lookups) == 0
    error_message = "Expected exactly one template for each requested template on node '${var.proxmox_node_name}'. Invalid lookups: ${join(", ", local.invalid_template_lookups)}."
  }
}

check "unique_vm_names" {
  assert {
    condition     = length(local.requested_vm_names) == length(toset(local.requested_vm_names))
    error_message = "Every VM must have a unique name. Duplicate names found in the requested VM definitions."
  }
}

resource "proxmox_virtual_environment_vm" "mickey" {
  for_each = local.vm_definitions

  name          = each.value.name
  node_name     = var.proxmox_node_name
  vm_id         = each.value.vm_id
  started       = each.value.started
  on_boot       = each.value.on_boot
  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  tags          = sort(distinct(compact(concat(var.common_vm_tags, each.value.tags, [each.value.role]))))

  clone {
    vm_id = local.clone_template_vm_ids[each.value.clone_template_name]
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = each.value.memory_mb
  }

  disk {
    datastore_id = each.value.os_disk_datastore_id
    interface    = "scsi0"
    size         = each.value.os_disk_gb
  }

  dynamic "disk" {
    for_each = each.value.extra_disks
    content {
      datastore_id = disk.value.datastore_id
      interface    = disk.value.interface
      size         = disk.value.size_gb
    }
  }

  dynamic "usb" {
    for_each = each.value.usb_devices
    content {
      host    = try(usb.value.host, null)
      mapping = try(usb.value.mapping, null)
      usb3    = try(usb.value.usb3, null)
    }
  }

  network_device {
    bridge   = var.vm_bridge
    firewall = false
  }

  initialization {
    datastore_id = var.cloud_init_datastore_id

    user_account {
      username = var.vm_admin_user
      password = each.value.admin_password_hash
      keys     = var.ssh_public_keys
    }

    dns {
      servers = var.dns_servers
      domain  = var.search_domain
    }

    ip_config {
      ipv4 {
        address = each.value.lan_ipv4_cidr
        gateway = var.gateway_ipv4
      }
    }
  }

  lifecycle {
    # Template lineage is creation-time only for these long-lived guests.
    ignore_changes = [clone]
  }
}

resource "local_file" "ansible_inventory" {
  filename = abspath(var.ansible_inventory_output_path)
  content = templatefile("${path.module}/templates/ansible-inventory.yml.tftpl", {
    hosts                        = local.inventory_hosts
    groups                       = local.inventory_all_groups
    group_names                  = local.inventory_group_names
    ansible_ssh_private_key_file = pathexpand(var.ansible_ssh_private_key_file)
  })

  depends_on = [proxmox_virtual_environment_vm.mickey]
}
