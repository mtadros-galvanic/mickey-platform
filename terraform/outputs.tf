output "generated_inventory_path" {
  description = "Generated Ansible inventory path."
  value       = local_file.ansible_inventory.filename
}

output "infra_vm_ip" {
  description = "Infra VM LAN IP, when present in the active topology."
  value       = try(local.inventory_hosts["mickey-infra"].ansible_host, null)
}

output "guest_vm_ips" {
  description = "All guest VM LAN IPs keyed by guest name."
  value = {
    for host_key, host in local.inventory_hosts :
    host_key => host.ansible_host
  }
}
