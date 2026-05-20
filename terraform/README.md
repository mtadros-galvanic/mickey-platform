# Terraform

This root module provisions the Mickey guest VMs in Proxmox and renders a generated Ansible inventory.

## Scope

- clone and create guest VMs declared in one keyed VM map
- currently provision `mickey-infra`, `mickey-erp`, `mickey-thud`, `mickey-scarthgap`, and `mickey-brimstone` from the committed prod inputs
- attach optional extra disks and USB passthrough devices declared on those guests
- inject SSH keys and static network configuration through cloud-init
- render `ansible/inventory/hosts.generated.yml`, including role groups and `consul_client_vms`

## Prerequisites

- Proxmox is already installed and reachable at its current target address
- the `bulk` datastore already exists
- each template name resolves to exactly one existing Proxmox template on the target node
- the templates are cloud-init capable and have the guest agent enabled
- the guest SSH public key corresponds to `~/.ssh/mickey`, which is also the default private key path rendered into the generated Ansible inventory
- the `2 TiB` share disk cutover from `mickey-main` to `mickey-infra` is handled manually outside Terraform

## Usage

```bash
make tf-init
make tf-plan
make tf-apply
```
