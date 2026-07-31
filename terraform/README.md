# Terraform

This root module provisions the Mickey guest VMs in Proxmox and renders a generated Ansible inventory.

## Scope

- clone and create guest VMs declared in one keyed VM map
- currently provision `mickey-infra`, `mickey-erp`, `mickey-thud`, `mickey-scarthgap`, `mickey-brimstone`, `mickey-at4`, `mickey-tmp`, `mickey-controller`, and `mickey-galvanic-website` from the committed prod inputs
- attach optional extra disks and USB passthrough devices declared on those guests
- inject SSH keys plus static or DHCP network configuration through cloud-init
- wait for DHCP guests to publish an IPv4 address through the QEMU guest agent and use the configured guest interface when rendering inventory
- render `ansible/inventory/hosts.generated.yml`, including role groups and `consul_client_vms`

## Prerequisites

- Proxmox is already installed and reachable at its current target address
- the `bulk` datastore already exists
- each template name resolves to exactly one existing Proxmox template on the target node
- the templates are cloud-init capable and have the guest agent enabled
- DHCP guests keep `guest_agent_interface` explicit so container and bridge addresses cannot be selected as the Ansible endpoint
- the guest SSH public key corresponds to `~/.ssh/mickey`, which is also the default private key path rendered into the generated Ansible inventory
- the `2 TiB` share disk cutover from `mickey-main` to `mickey-infra` is handled manually outside Terraform

## Usage

```bash
make tf-init
make tf-plan
make tf-apply
```

The normal apply refreshes guest-agent addresses before writing the generated
inventory. DHCP clients therefore do not need an address reservation, but the
guest agent must be running and the configured interface must publish exactly
one non-link-local IPv4 address.
