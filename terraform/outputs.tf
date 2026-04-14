output "generated_inventory_path" {
  description = "Generated Ansible inventory path."
  value       = local_file.ansible_inventory.filename
}

output "control_vm_ip" {
  description = "Control VM LAN IP."
  value       = local.inventory_hosts[var.control_vm.name].ansible_host
}

output "desktop_vm_ip" {
  description = "Desktop VM LAN IP."
  value       = local.inventory_hosts[var.desktop_vm.name].ansible_host
}

output "guest_vm_ips" {
  description = "All guest VM LAN IPs keyed by guest name."
  value = {
    for host_key, host in local.inventory_hosts :
    host_key => host.ansible_host
  }
}
