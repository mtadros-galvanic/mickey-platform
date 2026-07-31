# DHCP guest discovery

Mickey supports DHCP guests without placing their leased addresses in source
control. Static guests continue to use `lan_ipv4_cidr`; a DHCP guest declares:

```hcl
network_mode          = "dhcp"
guest_agent_interface = "ens18"
```

## Discovery path

1. Proxmox cloud-init configures the guest NIC for DHCP.
2. A cloud-init vendor-data snippet installs and starts `qemu-guest-agent`
   before Ansible is available. This breaks the first-boot dependency cycle
   present in unmodified Ubuntu cloud images.
3. The Proxmox provider waits for an IPv4 address from the QEMU guest agent.
4. Terraform selects the address attached to `guest_agent_interface`. It does
   not select the first private address, so Docker bridges cannot become the
   Ansible endpoint.
5. The generated Ansible inventory records the discovered address, network
   mode, and guest interface.
6. DHCP Consul clients use the go-sockaddr `GetInterfaceIP` expression for
   `bind_addr` and `advertise_addr`. Consul resolves the current address when
   the service starts.
7. A systemd path unit watches systemd-networkd lease files and restarts Consul
   after an in-place DHCP lease change.

Terraform requires exactly one usable IPv4 address on the declared interface.
An absent or ambiguous address stops the apply instead of writing a misleading
inventory.

## DNS and routing

The DHCP lease is not published in Mickey's wildcard DNS. Browser names under
`*.mickey.galvanic.com` continue to resolve to `mickey-infra`, where Traefik
selects healthy backends from the Consul catalog. Services on a DHCP guest
should omit a hard-coded service address so Consul uses the node's advertised
address.

## Operations

Run `make tf-apply` before Ansible whenever a DHCP lease may have changed. If
GNU Make is not installed on the machine running Mickey, use
`./scripts/run-terraform.sh apply` instead. The apply refreshes guest-agent
data and rewrites `ansible/inventory/hosts.generated.yml` before the playbook
connects.

Ubuntu 26.04 cloud images can report a non-fatal first-boot cloud-init warning
when Proxmox network data requests an `eth0` rename after `ens18` is already
active. The operational interface remains `ens18`; Mickey deliberately uses
the interface name reported by the guest agent. Treat missing DHCP, a stopped
guest agent, or anything other than exactly one usable IPv4 address on that
configured interface as a failure.

For diagnostics:

```bash
ssh root@10.25.1.207 qm guest cmd 710 network-get-interfaces
terraform -chdir=terraform output guest_vm_ips
consul members
```
