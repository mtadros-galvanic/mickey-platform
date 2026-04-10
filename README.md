# mickey-platform

Platform lifecycle repo for `mickey`.

This repo owns:

- Proxmox host baseline for `mickey`
- Proxmox VM provisioning through Terraform
- generated Ansible inventory for provisioned guests
- guest bootstrap for the small control VM and the main Ubuntu Desktop VM
- local SOPS-managed secrets for Proxmox, guest bootstrap, and Samba

This repo does not own the main runtime service stack. The desktop VM is prepared so the separate `mickey-infra` repo can later deploy Traefik, Portainer, Dashy, Grafana, and future Consul there.

## Target Topology

- Proxmox host: `10.25.1.101`
- Main Ubuntu Desktop VM `mickey-main`: `10.25.1.84`
- Control Ubuntu Server VM `mickey-control`: `10.25.1.103`
- NVMe: Proxmox OS plus fast VM storage
- 4 TB HDD: Proxmox bulk datastore
- `mickey-main` gets a `2 TiB` virtual data disk from `bulk` and exports Samba from `/srv/share`

## Repo Layout

```text
ansible/    Host baseline plus guest bootstrap playbooks
docs/       Short runbooks and architecture notes
envs/prod/  Tracked non-secret environment values
scripts/    Thin wrappers for Terraform, Ansible, and secret rendering
secrets/    SOPS templates and secret shape documentation
terraform/  Proxmox provisioning and generated inventory output
```

## Operator Flow

1. Adjust [envs/prod/terraform.tfvars](/home/mtadros/Projects/POC/mickey-platform/envs/prod/terraform.tfvars) to match the actual Proxmox node name, template names, and datastore IDs.
2. Copy [secrets/prod.sops.example.yaml](/home/mtadros/Projects/POC/mickey-platform/secrets/prod.sops.example.yaml) to `secrets/prod.sops.yaml`, replace placeholder values, and encrypt it with `sops`.
3. Run `make tf-init`.
4. Run `make ansible-host` after Proxmox is installed to create and register the `bulk` datastore on the 4 TB disk.
5. Run `make tf-plan` and `make tf-apply` to create the control and desktop VMs.
6. Run `make ansible-control`.
7. Run `make ansible-desktop`.

## Supported Commands

- `make tf-init`
- `make tf-plan`
- `make tf-apply`
- `make ansible-host`
- `make ansible-control`
- `make ansible-desktop`

See [docs/architecture.md](/home/mtadros/Projects/POC/mickey-platform/docs/architecture.md) for the design intent and operational boundaries.
# mickey-platform
