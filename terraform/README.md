# Terraform

This root module provisions the two Mickey guest VMs in Proxmox and renders a generated Ansible inventory.

## Scope

- clone and create `mickey-control`
- clone and create `mickey-main`
- attach a `2 TiB` data disk on the `bulk` datastore to `mickey-main`
- inject SSH keys and static network configuration through cloud-init
- render `ansible/inventory/hosts.generated.yml`

## Prerequisites

- Proxmox is already installed on the `mickey` node
- the `bulk` datastore already exists
- each template name resolves to exactly one existing Proxmox template on the target node
- the templates are cloud-init capable and have the guest agent enabled
- the guest SSH public key corresponds to `~/.ssh/mickey`, which is also the default private key path rendered into the generated Ansible inventory

## Usage

```bash
make tf-init
make tf-plan
make tf-apply
```
