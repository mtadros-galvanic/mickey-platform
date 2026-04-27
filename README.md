# mickey-platform

Platform lifecycle repo for `mickey`.

This repo owns:

- Proxmox host baseline for `mickey`
- repeatable Proxmox cloud-init template creation
- Proxmox VM provisioning through Terraform
- manual import workflow for the legacy Windows 7 Xilinx VM
- generated Ansible inventory for provisioned guests
- guest bootstrap for the infra, ERP, and build VMs
- host-level Consul client baseline for app-facing VMs
- local SOPS-managed secrets for Proxmox, guest bootstrap, and Samba

This repo does not own the main runtime service stack. The `mickey-infra` guest
is prepared so the separate `mickey-infra` repo can deploy Traefik, the Consul
server, Grafana, and the observability stack there. App-facing VMs get a local
Consul client from this repo so application repos can register themselves
without central infra edits.

## Target Topology

- Proxmox host: `10.25.1.207`
- Ubuntu Server infra VM `mickey-infra`: `10.25.1.206`
- Ubuntu Server ERP VM `mickey-erp`: `10.25.1.208`
- Legacy Ubuntu 18 build VM `mickey-thud`: `10.25.1.105`
- Ubuntu Server 22 build VM `mickey-scarthgap`: `10.25.1.210`
- Legacy Windows 7 ISE VM `mickey-ise7`: `VMID 703` on `bulk`
- NVMe: Proxmox OS plus fast VM storage
- 4 TB HDD: Proxmox bulk datastore
- the `2 TiB` Samba data disk is reattached manually from `mickey-main` to `mickey-infra` during cutover and exported from `/srv/share`
- `mickey-thud` keeps its `400 GB` OS/build disk on `bulk`, can receive targeted USB passthrough devices, and stays powered off unless needed
- `mickey-thud` and `mickey-scarthgap` are mutually exclusive build guests and are not intended to run at the same time

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
Optional guest SSH client files can be placed under `ansible/files/ssh/<inventory_hostname>/`. During `make ansible-build-thud` or `make ansible-build-scarthgap`, `config` and private keys from that directory are copied into the guest user's `~/.ssh/` directory, while `.pub` files are ignored.
Managed Linux hosts receive a pinned user-local Node toolchain for Codex. `mickey-thud` stays on `Node 16.20.2`, while `mickey-infra`, `mickey-erp`, `mickey-scarthgap`, and `mickey-pve` use `Node 24.15.0`. The shared `mickey-share` path is `/mnt/mickey-share` on every Linux guest, with `mickey-infra` exposing that path as a bind-mounted alias of its local `/srv/share` filesystem. When `/mnt/mickey-share/admin/codex/galvanic/auth.json` exists, the guest bootstrap points local Codex auth at that shared file. The Proxmox host baseline also prepares `/mnt/mickey-share` as a CIFS automount to `mickey-infra`, while still keeping Samba itself off the hypervisor.
The generated inventory now also exposes `consul_client_vms`, which is the set
of guests that should run a local Consul agent and accept project-owned service
definitions under `/etc/consul.d/`.
For `mickey-thud` and `mickey-scarthgap`, the build bootstrap additionally syncs the required GitHub build repos under `~/Projects`, installs manual `mickey-share-mount` and `mickey-share-umount` helpers for the `mickey-infra` Samba share, and installs a `mickey-yocto-fetch-diagnose` helper for source-specific fetch testing.

## Operator Flow

1. Build the Ubuntu 24.04 server template with `make templates`.
2. Build the Ubuntu 18.04 server template with `make templates-bionic` if you want to provision `mickey-thud`.
3. Build the Ubuntu 22.04 server template with `make templates-jammy` before you introduce `mickey-scarthgap`.
4. Adjust [envs/prod/terraform.tfvars](/home/mtadros/Projects/POC/mickey-platform/envs/prod/terraform.tfvars) only if you intentionally change the default template names, node name, or datastore IDs.
5. If the Proxmox host is still on `10.25.1.101`, run `make proxmox-reip` for a dry run and `make proxmox-reip REIP_APPLY=1` to move it to `10.25.1.207` with an automatic rollback timer.
6. Copy [secrets/prod.sops.example.yaml](/home/mtadros/Projects/POC/mickey-platform/secrets/prod.sops.example.yaml) to `secrets/prod.sops.yaml`, replace placeholder values, and encrypt it with `sops`.
7. Run `make tf-init`.
8. Run `make ansible-host WIPE_CONFIRM=true` after Proxmox is installed to switch the host to the no-subscription Proxmox repositories, wipe `/dev/sda`, create the ext4-backed `bulk` datastore, register it with Proxmox, and prepare the host-side `mickey-share` automount.
9. Run `make tf-plan` and `make tf-apply` to create the currently active guest VMs.
10. During the cutover, manually detach the `2 TiB` data disk from `mickey-main` and reattach it to `mickey-infra`.
11. Run `make ansible-infra` after the share disk is attached.
12. Run `make ansible-erp` for `mickey-erp`. This now includes the local Consul client baseline.
13. Run `make ansible-build-thud` for `mickey-thud` when you need the legacy Ubuntu 18 build guest. This keeps its Codex Node runtime on `16.20.2` and includes the local Consul client baseline.
14. Run `make ansible-build-scarthgap` for `mickey-scarthgap` when you want the modern build guest. This keeps its Codex Node runtime on `24.15.0` and includes the local Consul client baseline.
15. Seed `/mnt/mickey-share/admin/codex/galvanic/auth.json` once from an already-authenticated machine if you want shared Codex login across the Linux guests.
16. On `mickey-thud`, use `sudo mickey-share-mount` and `sudo mickey-share-umount` when you need temporary access to `mickey-infra`'s `/srv/share`.
17. On `mickey-thud`, use `mickey-yocto-fetch-diagnose` to compare slow Yocto fetches against a known-fast control download before changing BitBake mirror settings.
18. Run `make ise7-import` if you want the legacy Windows 7 Xilinx VM imported from the local VMware source tree. This path is manual by design: it converts the active VMware branch into a local qcow2, uploads that image through the Proxmox API, and imports it onto `bulk`.

The current template flow is server-only. `mickey-infra` now uses the same Ubuntu 24.04 server cloud image as future server guests, which keeps template creation fast and repeatable.

The host baseline is intentionally guarded. It verifies that `/dev/sda` matches the expected 4 TB Seagate model and refuses to repartition the disk unless `WIPE_CONFIRM=true` is provided. The `mickey-share` client mount is configured during the same playbook run and only attempts an immediate first mount when the infra VM's Samba endpoint is reachable.

## Supported Commands

- `make templates`
- `make templates-bionic`
- `make templates-jammy`
- `make tf-init`
- `make tf-plan`
- `make tf-apply`
- `make ansible-host`
- `make ansible-infra`
- `make ansible-erp`
- `make ansible-build-thud`
- `make ansible-build-scarthgap`
- `make ise7-import`

See [docs/architecture.md](/home/mtadros/Projects/POC/mickey-platform/docs/architecture.md) for the design intent and operational boundaries.
See [docs/windows-7-ise.md](/home/mtadros/Projects/POC/mickey-platform/docs/windows-7-ise.md) for the Windows 7 import and post-boot runbook.
