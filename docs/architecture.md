# Architecture

## Core split

`mickey-platform` is the platform repo. It provisions Proxmox guests and applies baseline host and guest configuration.

It deliberately does not deploy the main runtime stack. The primary runtime stack stays separate so platform lifecycle and service lifecycle are not mixed into one repo.

## Host and VM responsibilities

### Proxmox host

- owns virtualization
- owns the `bulk` directory datastore on the 4 TB disk
- does not run Samba
- does not run Traefik, Portainer, Dashy, or Grafana

### Control VM

- tiny Ubuntu Server guest
- operator and automation landing point
- installs `terraform`, `ansible`, `sops`, and related tooling
- safe to shut down when not in use

### Main desktop VM

- main Ubuntu Desktop workstation
- later target for the separate `mickey-infra` service stack
- exports Samba from `/srv/share`
- receives a `2 TiB` data disk from the Proxmox `bulk` datastore
- starts from the same Ubuntu 24.04 cloud-init base as the control VM
- becomes the desktop role when `ansible-desktop` installs the GUI stack and XRDP

## Storage model

- NVMe: Proxmox OS and fast VM disks
- HDD: one ext4-backed Proxmox directory datastore named `bulk`
- `mickey-main` gets a `2 TiB` virtual disk from `bulk`
- remaining `bulk` capacity stays available for backups, ISOs, templates, and future VM disks

## Why Samba is in the desktop VM

Samba is kept out of the Proxmox host to avoid coupling file serving to the hypervisor. The share moves with the guest boundary, which makes backup, restore, migration, and host maintenance cleaner.
