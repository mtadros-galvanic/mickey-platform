# mickey-platform

Platform lifecycle repo for `mickey`.

This repo owns:

- Proxmox host baseline for `mickey`
- repeatable Proxmox cloud-init template creation
- Proxmox VM provisioning through Terraform
- generated Ansible inventory for provisioned guests
- guest bootstrap for the control, desktop, and build VMs
- local SOPS-managed secrets for Proxmox, guest bootstrap, and Samba

This repo does not own the main runtime service stack. The desktop VM is prepared so the separate `mickey-infra` repo can later deploy Traefik, Portainer, Dashy, Grafana, and future Consul there.

## Target Topology

- Proxmox host: `10.25.1.101`
- Main Ubuntu Desktop VM `mickey-main`: `10.25.1.84`
- Control Ubuntu Server VM `mickey-control`: `10.25.1.103`
- Legacy Ubuntu 18 build VM `mickey-thud`: `10.25.1.105`
- NVMe: Proxmox OS plus fast VM storage
- 4 TB HDD: Proxmox bulk datastore
- `mickey-main` gets a `2 TiB` virtual data disk from `bulk` and exports Samba from `/srv/share`
- `mickey-thud` keeps its `400 GB` OS/build disk on `bulk` and stays powered off unless needed

## Repo Layout

```text
ansible/    Host baseline plus guest bootstrap playbooks
docs/       Short runbooks and architecture notes
envs/prod/  Tracked non-secret environment values
scripts/    Thin wrappers for Terraform, Ansible, and secret rendering
secrets/    SOPS templates and secret shape documentation
terraform/  Proxmox provisioning and generated inventory output
```

Optional host-only SSH keys can be tracked under `ansible/files/authorized_keys/<inventory_hostname>`. Those files are merged with the shared `guests.ssh_public_keys` list during guest bootstrap.
Optional guest SSH client files can be placed under `ansible/files/ssh/<inventory_hostname>/`. During `make ansible-build`, `config` and private keys from that directory are copied into the guest user's `~/.ssh/` directory, while `.pub` files are ignored.
For `mickey-thud`, the build bootstrap also installs a pinned user-local Node 16 toolchain, installs the Codex CLI, and syncs the required GitHub build repos under `~/Projects`. Codex authentication remains a manual post-step.

## Operator Flow

1. Build the Ubuntu 24.04 Proxmox templates with `make templates`.
2. Build the Ubuntu 18.04 server template with `make templates-bionic` if you want to provision `mickey-thud`. This target uses the Proxmox API instead of host SSH.
3. Adjust [envs/prod/terraform.tfvars](/home/mtadros/Projects/POC/mickey-platform/envs/prod/terraform.tfvars) only if you intentionally change the default template names, node name, or datastore IDs.
4. Copy [secrets/prod.sops.example.yaml](/home/mtadros/Projects/POC/mickey-platform/secrets/prod.sops.example.yaml) to `secrets/prod.sops.yaml`, replace placeholder values, and encrypt it with `sops`.
5. Run `make tf-init`.
6. Run `make ansible-host WIPE_CONFIRM=true` after Proxmox is installed to switch the host to the no-subscription Proxmox repositories, wipe `/dev/sda`, create the ext4-backed `bulk` datastore, and register it with Proxmox.
7. Run `make tf-plan` and `make tf-apply` to create the guest VMs.
8. Run `make ansible-control`.
9. Run `make ansible-desktop`.
10. Run `make ansible-build` for `mickey-thud` and future build-focused guests.

The template build intentionally keeps the default desktop template on the same Ubuntu 24.04 cloud-image base as the server template. The main GUI stack is applied later by the desktop Ansible playbook, which keeps template creation fast and repeatable.

The host baseline is intentionally guarded. It verifies that `/dev/sda` matches the expected 4 TB Seagate model and refuses to repartition the disk unless `WIPE_CONFIRM=true` is provided.

## Supported Commands

- `make templates`
- `make templates-bionic`
- `make tf-init`
- `make tf-plan`
- `make tf-apply`
- `make ansible-host`
- `make ansible-control`
- `make ansible-desktop`
- `make ansible-build`

See [docs/architecture.md](/home/mtadros/Projects/POC/mickey-platform/docs/architecture.md) for the design intent and operational boundaries.
