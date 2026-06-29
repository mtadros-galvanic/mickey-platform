# mickey-platform

Platform lifecycle repo for `mickey`.

This repo owns:

- Proxmox host baseline for `mickey`
- repeatable Proxmox cloud-init template creation
- Proxmox VM provisioning through Terraform
- manual import workflow for the legacy Windows 7 Xilinx VM
- generated Ansible inventory for provisioned guests
- guest bootstrap for the infra, ERP, build, and utility VMs
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
- Legacy Ubuntu 18 build VM `mickey-thud`: `10.25.1.199`
- Ubuntu Server 22 build VM `mickey-scarthgap`: `10.25.1.210`
- Ubuntu Server 22 build VM `mickey-brimstone`: `10.25.1.190`
- Ubuntu Server 26 utility VM `mickey-at4`: `10.25.1.211`
- Ubuntu Server 26 utility VM `mickey-tmp`: `10.25.1.212`
- Ubuntu Server 26 utility VM `mickey-controller`: `10.25.1.214`
- Legacy Windows 7 ISE VM `mickey-ise7`: `VMID 703` on `bulk`
- 500 GB NVMe: Proxmox OS plus `local-lvm` VM storage
- 2 TB Kingston NVMe: physical passthrough to `mickey-infra` for the `mickey-shared-fast` Samba export
- 4 TB HDD: Proxmox bulk datastore
- the `2 TiB` Samba data disk is reattached manually from `mickey-main` to `mickey-infra` during cutover and exported from `/srv/share`
- `mickey-thud` keeps its `400 GB` OS/build disk on `bulk`, can receive targeted USB passthrough devices, and stays powered off unless needed
- the build guests are capacity-planned for explicit use and are not intended to all run heavy builds at the same time

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
Optional guest SSH client files can be placed under `ansible/files/ssh/<inventory_hostname>/`. During `make ansible-build-thud`, `make ansible-build-scarthgap`, or `make ansible-build-brimstone`, private keys from that directory are copied into the guest user's `~/.ssh/` directory, while `config` is installed as `~/.ssh/config.d/mickey-managed.conf` and included from `~/.ssh/config` so VM-local SSH entries are preserved. `.pub` files are ignored.
Ubuntu guests share a common Ansible base layer in `ansible/tasks/bootstrap-vm-base.yml`: standard VM packages, GitHub CLI, pinned Herdr, pinned D2, bootstrap admin user, hostname, and local hosts mapping. Role-specific package vars extend the shared `mickey_vm_base_apt_packages` list, and `ansible/tasks/configure-vm-admin-tooling.yml` provides the shared Consul/Codex/dotfiles layer after guest-specific mounts are ready.
Managed Linux hosts receive the standalone Codex CLI through `https://chatgpt.com/codex/install.sh`, wrapped by the Mickey launcher so `CODEX_HOME`, shared auth, and Codex skills stay consistent. The guest bootstrap still installs a pinned user-local Node toolchain for compatibility and other tooling: `mickey-thud` stays on `Node 16.20.2`, while `mickey-infra`, `mickey-erp`, `mickey-scarthgap`, `mickey-brimstone`, the utility VMs, and `mickey-pve` use `Node 24.15.0`. PM2 and Mermaid CLI are installed from the managed Node/npm toolchain as pinned exact-version wrappers. On Node 24 hosts, pnpm uses Corepack shims for `pnpm 11.5.2`; Thud keeps the compatibility wrapper for `pnpm 8.15.9`, `PM2 6.0.14`, and Mermaid CLI `10.9.1`, while the other Linux hosts use `PM2 7.0.1` and Mermaid CLI `11.15.0`. Each VM points pnpm at a host-specific fast shared store under `/mnt/mickey-shared-fast/admin/pnpm/hosts/<hostname>/store`. Codex skills use a local `skills/` directory on each host: global skills are symlinked from `/mnt/mickey-shared-fast/admin/codex/skills`, and host-private skills are symlinked from `/mnt/mickey-shared-fast/admin/codex/hosts/<hostname>/skills`. The managed global MCP baseline currently adds `galvanic-ui` at `http://galvanic-ui.mickey.galvanic.com/mcp`. The shared `mickey-share` path is `/mnt/mickey-share` on every Linux guest, with `mickey-infra` exposing that path as a bind-mounted alias of its local `/srv/share` filesystem. When `/mnt/mickey-share/admin/codex/galvanic/auth.json` exists, the guest bootstrap points local Codex auth at that shared file. The Proxmox host baseline also prepares `/mnt/mickey-share` as a CIFS automount to `mickey-infra`, while still keeping Samba itself off the hypervisor.
The generated inventory now also exposes `consul_client_vms`, which is the set
of guests that should run a local Consul agent and accept project-owned service
definitions under `/etc/consul.d/`.
For `mickey-thud`, `mickey-scarthgap`, and `mickey-brimstone`, the build bootstrap additionally syncs the required GitHub build repos under `~/Projects`, installs manual `mickey-share-mount` and `mickey-share-umount` helpers for the `mickey-infra` Samba share, installs a `mickey-yocto-fetch-diagnose` helper for source-specific fetch testing, and installs `mickey-throttle-yocto` plus matching systemd units for lowering active Yocto build priority when a build VM needs to stay interactive. The throttle timer is off by default for build VMs and enabled for `mickey-scarthgap`. `mickey-scarthgap` also mounts its dedicated Kingston NVMe partition at `/mnt/yocto-local` so BitBake `TMPDIR` stays on local POSIX storage while shared downloads, sstate, ccache, and artifacts remain under `/mnt/mickey-shared-fast`.

## Operator Flow

1. Build the Ubuntu 24.04 server template with `make templates`.
2. Build the Ubuntu 18.04 server template with `make templates-bionic` if you want to provision `mickey-thud`.
3. Build the Ubuntu 22.04 server template with `make templates-jammy` before you provision `mickey-scarthgap` or `mickey-brimstone`.
4. Build the Ubuntu 26.04 server template with `make templates-resolute` before you provision the utility VMs.
5. Adjust [envs/prod/terraform.tfvars](envs/prod/terraform.tfvars) only if you intentionally change the default template names, node name, or datastore IDs.
6. If the Proxmox host is still on `10.25.1.101`, run `make proxmox-reip` for a dry run and `make proxmox-reip REIP_APPLY=1` to move it to `10.25.1.207` with an automatic rollback timer.
7. Copy [secrets/prod.sops.example.yaml](secrets/prod.sops.example.yaml) to `secrets/prod.sops.yaml`, replace placeholder values, and encrypt it with `sops`.
8. Run `make tf-init`.
9. Run `make ansible-host WIPE_CONFIRM=true` after Proxmox is installed to switch the host to the no-subscription Proxmox repositories, wipe `/dev/sda`, create the ext4-backed `bulk` datastore, register it with Proxmox, and prepare the host-side `mickey-share` automount.
10. Run `make tf-plan` and `make tf-apply` to create the currently active guest VMs.
11. During the cutover, manually detach the `2 TiB` data disk from `mickey-main` and reattach it to `mickey-infra`.
12. Run `make ansible-infra` after the share disk is attached.
13. Run `make ansible-erp` for `mickey-erp`. This now includes the local Consul client baseline.
14. Run `make ansible-utility` for the utility VMs. This installs their base packages, Codex tooling, `mickey-share` automounts, and optional project sync.
15. Run `make ansible-build-thud` for `mickey-thud` when you need the legacy Ubuntu 18 build guest. This keeps its Codex Node runtime on `16.20.2` and includes the local Consul client baseline.
16. Run `make ansible-build-scarthgap` for `mickey-scarthgap` when you want the modern build guest. This keeps its Codex Node runtime on `24.15.0` and includes the local Consul client baseline.
17. Run `make ansible-build-brimstone` for `mickey-brimstone` when you want the brimstone build guest with only `brimestone` and `Protech` under `~/Projects`.
18. Seed `/mnt/mickey-share/admin/codex/galvanic/auth.json` once from an already-authenticated machine if you want shared Codex login across the Linux guests.
19. On a build VM, use `sudo mickey-share-mount` and `sudo mickey-share-umount` when you need temporary access to `mickey-infra`'s `/srv/share`.
20. On a build VM, use `mickey-yocto-fetch-diagnose` to compare slow Yocto fetches against a known-fast control download before changing BitBake mirror settings.
21. Run `make ise7-import` if you want the legacy Windows 7 Xilinx VM imported from the local VMware source tree. This path is manual by design: it converts the active VMware branch into a local qcow2, uploads that image through the Proxmox API, and imports it onto `bulk`.

The current template flow is server-only. `mickey-infra` now uses the same Ubuntu 24.04 server cloud image as future server guests, which keeps template creation fast and repeatable.

The host baseline is intentionally guarded. It verifies that `/dev/sda` matches the expected 4 TB Seagate model and refuses to repartition the disk unless `WIPE_CONFIRM=true` is provided. The `mickey-share` client mount is configured during the same playbook run and only attempts an immediate first mount when the infra VM's Samba endpoint is reachable.

## Supported Commands

- `make templates`
- `make templates-bionic`
- `make templates-jammy`
- `make templates-resolute`
- `make tf-init`
- `make tf-plan`
- `make tf-apply`
- `make ansible-host`
- `make ansible-infra`
- `make ansible-erp`
- `make ansible-utility`
- `make ansible-build-thud`
- `make ansible-build-scarthgap`
- `make ansible-build-brimstone`
- `make ise7-import`

See [docs/architecture.md](docs/architecture.md) for the design intent and operational boundaries.
See [docs/windows-7-ise.md](docs/windows-7-ise.md) for the Windows 7 import and post-boot runbook.
