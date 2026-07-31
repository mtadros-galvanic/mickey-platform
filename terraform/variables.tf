variable "proxmox_api_url" {
  description = "Proxmox API endpoint."
  type        = string
}

variable "proxmox_api_token" {
  description = "Full Proxmox API token string."
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Allow insecure TLS when talking to Proxmox."
  type        = bool
  default     = false
}

variable "proxmox_node_name" {
  description = "Target Proxmox node name."
  type        = string
}

variable "proxmox_ssh_username" {
  description = "PAM account used for Proxmox operations that require SFTP, such as uploading cloud-init snippets."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_file" {
  description = "Private key used for Proxmox SFTP operations."
  type        = string
  default     = "~/.ssh/mickey"
}

variable "vm_bridge" {
  description = "Bridge name used by guest network devices."
  type        = string
  default     = "vmbr0"
}

variable "fast_datastore_id" {
  description = "Datastore used for fast guest disks."
  type        = string
}

variable "cloud_init_datastore_id" {
  description = "Datastore used for cloud-init media."
  type        = string
}

variable "cloud_init_snippets_datastore_id" {
  description = "Snippet-capable datastore used for custom cloud-init vendor data."
  type        = string
  default     = "bulk"
}

variable "bulk_datastore_id" {
  description = "Datastore used for large-capacity guest disks."
  type        = string
  default     = "bulk"
}

variable "gateway_ipv4" {
  description = "IPv4 gateway used by provisioned guests."
  type        = string
}

variable "dns_servers" {
  description = "Recursive DNS servers configured through cloud-init."
  type        = list(string)
}

variable "search_domain" {
  description = "DNS search domain applied through cloud-init."
  type        = string
  default     = "galvanic.local"
}

variable "vm_admin_user" {
  description = "Bootstrap login user created through cloud-init."
  type        = string
  default     = "galvanic"
}

variable "vm_admin_password_hash" {
  description = "Optional password hash applied to provisioned guest VMs."
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "SSH public keys injected through cloud-init."
  type        = list(string)
}

variable "common_vm_tags" {
  description = "Tags applied to every VM."
  type        = list(string)
  default     = ["terraform", "mickey-platform"]
}

variable "cpu_type" {
  description = "CPU type passed to Proxmox."
  type        = string
  default     = "host"
}

variable "ansible_inventory_output_path" {
  description = "Generated Ansible inventory path."
  type        = string
  default     = "../ansible/inventory/hosts.generated.yml"
}

variable "ansible_ssh_private_key_file" {
  description = "Private key path used by Ansible after provisioning."
  type        = string
  default     = "~/.ssh/mickey"
}

variable "vms" {
  description = "Guest VM definitions keyed by guest name."
  type = map(object({
    clone_template_name   = string
    role                  = string
    consul_client         = optional(bool, false)
    network_mode          = optional(string, "static")
    guest_agent_interface = optional(string, "eth0")
    vm_id                 = number
    cpu_cores             = number
    memory_mb             = number
    memory_balloon_mb     = optional(number)
    os_disk_gb            = number
    os_disk_datastore_id  = optional(string)
    os_disk_iothread      = optional(bool)
    lan_ipv4_cidr         = optional(string)
    started               = optional(bool, true)
    on_boot               = optional(bool, true)
    tags                  = optional(list(string), [])
    extra_disks = optional(list(object({
      datastore_id = string
      interface    = string
      size_gb      = number
      iothread     = optional(bool, false)
    })), [])
    usb_devices = optional(list(object({
      host    = optional(string)
      mapping = optional(string)
      usb3    = optional(bool)
    })), [])
  }))

  validation {
    condition = alltrue([
      for vm in values(var.vms) :
      contains(["static", "dhcp"], vm.network_mode)
    ])
    error_message = "Each VM network_mode must be either 'static' or 'dhcp'."
  }

  validation {
    condition = alltrue([
      for vm in values(var.vms) :
      vm.network_mode == "dhcp"
      ? vm.lan_ipv4_cidr == null
      : try(length(trimspace(vm.lan_ipv4_cidr)) > 0, false)
    ])
    error_message = "Static VMs require lan_ipv4_cidr; DHCP VMs must omit it."
  }

  validation {
    condition = alltrue([
      for vm in values(var.vms) :
      vm.network_mode != "dhcp" || vm.started
    ])
    error_message = "DHCP VMs must start during initial provisioning so the QEMU guest agent can publish their address."
  }
}
