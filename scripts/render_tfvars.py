#!/usr/bin/env python3

import json
import pathlib
import sys

import yaml


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: render_tfvars.py <decrypted-secrets-yaml>", file=sys.stderr)
        return 2

    secrets_path = pathlib.Path(sys.argv[1])
    data = yaml.safe_load(secrets_path.read_text(encoding="utf-8")) or {}

    terraform = data.get("terraform", {})
    guests = data.get("guests", {})

    tfvars = {
        "proxmox_api_url": terraform["proxmox_api_url"],
        "proxmox_api_token": terraform["proxmox_api_token"],
        "proxmox_tls_insecure": bool(terraform.get("proxmox_tls_insecure", False)),
        "ssh_public_keys": guests["ssh_public_keys"],
    }

    json.dump(tfvars, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
