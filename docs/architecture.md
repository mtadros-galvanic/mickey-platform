# Architecture

## Core split

`mickey-platform` is the platform repo. It provisions Proxmox guests and applies baseline host and guest configuration.

It deliberately does not deploy the main runtime stack. The primary runtime stack stays separate so platform lifecycle and service lifecycle are not mixed into one repo.

## Host and VM responsibilities

### Proxmox host

- owns virtualization
- owns the `bulk` directory datastore on the 4 TB disk
- can mount `mickey-infra`'s `mickey-share` as a client at `/mnt/mickey-share`
- does not run Samba
- does not run Traefik, Grafana, or the Consul server

### Infra VM

- Ubuntu 24.04 server guest
- target for the separate `mickey-infra` service stack
- runs the platform Traefik stack and the Consul server from the separate `mickey-infra` repo
- exports Samba from `/srv/share`
- receives the existing `2 TiB` share disk through a manual cutover reattach from `mickey-main`
- stays separate from the Proxmox host so file serving and service runtime are not coupled to the hypervisor

### ERP VM

- Ubuntu 24.04 server guest
- reserved for future ERP-specific workloads
- receives a host-level Consul client from `mickey-platform`
- included in the active prod Terraform inputs

### Legacy build VM

- Ubuntu 18.04 guest for legacy Yocto and related build work
- named `mickey-thud`
- sized for intermittent use: `4 vCPU`, `16 GiB` RAM, `400 GiB` disk
- keeps its main disk on `bulk` instead of the NVMe-backed datastore
- keeps local build trees on the guest filesystem instead of pushing active Yocto work onto the Samba share
- can mount `mickey-infra`'s `mickey-share` manually at `/mnt/mickey-share` when selected artifacts need to move between VMs
- receives a host-level Consul client from `mickey-platform`
- can receive targeted USB passthrough devices through Terraform when a build or provisioning workflow needs raw removable media access
- is provisioned but intentionally left powered off and disabled from boot by default

### Scarthgap build VM

- Ubuntu 22.04 guest reserved for future newer Yocto work
- planned as the successor build VM to `mickey-thud`
- sized as a second build slot, not an always-on parallel build host
- receives a host-level Consul client from `mickey-platform`
- is intentionally treated as mutually exclusive with `mickey-thud` for capacity planning

### Brimstone build VM

- Ubuntu 22.04 guest for Brimstone-specific build work
- named `mickey-brimstone`
- sized like `mickey-scarthgap`: `4 vCPU`, `20 GiB` RAM with ballooning, `500 GiB` disk
- keeps its main disk on `bulk`
- receives a host-level Consul client from `mickey-platform`
- syncs only the `brimestone` and `Protech` project trees during bootstrap

### Utility VMs

- Ubuntu 26.04 server guests
- named `mickey-at4`, `mickey-tmp`, and `mickey-controller`
- receive the utility baseline instead of the app-facing Consul client baseline
- mount `mickey-infra`'s Samba share at `/mnt/mickey-share`
- mount the fast shared workspace path when configured
- install the pinned Node 24 Codex toolchain and managed admin dotfiles
- `mickey-controller` can receive a synced copy of the controller's local `~/Projects/mickey` tree

### Legacy Windows ISE VM

- imported from an existing VMware Windows 7 source tree instead of a cloud-init template
- named `mickey-ise7`
- keeps its disk on `bulk`
- import workflow converts the active VMware VMDK chain into one qcow2 locally, then uploads that qcow2 through the Proxmox API
- exists for Xilinx ISE 14.7 and Digilent cable workflows that do not fit the Ubuntu guest automation model
- remains a manual guest lifecycle because it depends on a preserved legacy Windows environment and in-guest vendor installers

## Storage model

- NVMe: Proxmox OS and fast VM disks
- HDD: one ext4-backed Proxmox directory datastore named `bulk`
- `mickey-infra` receives the existing `2 TiB` share disk during the manual cutover
- `mickey-thud` keeps its `400 GiB` disk on `bulk`
- `mickey-scarthgap` and `mickey-brimstone` keep their `500 GiB` build disks on `bulk`
- `mickey-ise7` imports its legacy Windows disk onto `bulk`
- remaining `bulk` capacity stays available for backups, ISOs, templates, and future VM disks

## Why Samba is in the infra VM

Samba is kept out of the Proxmox host to avoid coupling file serving to the hypervisor. The share stays on a guest boundary, which makes backup, restore, migration, and host maintenance cleaner.

The Proxmox host can still consume that share as an SMB client when an operator needs the same files locally, without turning the hypervisor into the system of record for the share.

The build VM uses that share as an operator-invoked transfer point rather than a permanent dependency. That keeps `mickey-thud` boot and build behavior independent from `mickey-infra` while still allowing selective artifact exchange.

## Service discovery split

`mickey-infra` owns the shared Traefik instance and the Consul server.

`mickey-platform` owns the base Consul client install on app-facing VMs.

Application repos are expected to own their own service definitions and drop
them onto the local VM under `/etc/consul.d/` so Traefik can discover them
through Consul Catalog.
