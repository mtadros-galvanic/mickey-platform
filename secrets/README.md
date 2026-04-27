# Secrets

This repo uses one SOPS-managed secret file per environment.

## Files

- `prod.sops.example.yaml`
  - plaintext example shape for production values
- `prod.sops.yaml`
  - the real encrypted secret file, created locally and committed only after encryption

## Structure

The secrets file is split into three namespaces:

- `terraform`
  - Proxmox API endpoint and token
- `guests`
  - SSH keys plus password hashes for the bootstrap login user
  - `admin_password_hash` is the preferred shared password hash for current guest bootstrap
  - the helper scripts and playbooks still accept older role-specific hashes as a fallback during the topology transition
- `samba`
  - Samba username and password for the `mickey-infra` share

## Workflow

1. Copy `prod.sops.example.yaml` to `prod.sops.yaml`.
2. Replace the placeholder values.
3. Encrypt the file with `sops` using the root `.sops.yaml` policy.
4. Run the `make` targets from the repo root.

The helper scripts decrypt secrets to temporary files only.
