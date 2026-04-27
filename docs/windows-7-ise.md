# Windows 7 ISE VM

## Purpose

`mickey-ise7` is the legacy Windows 7 guest used for Xilinx ISE 14.7 and Digilent JTAG work on `mickey`.

It is intentionally not managed by Terraform:

- the source is an existing VMware guest, not a cloud-init image
- the guest depends on preserving a legacy Windows environment
- the Xilinx and Digilent installers still run inside the guest after the import

## Source branch

The default import path uses the currently active VMware branch:

- base: `Win7.vmdk`
- parent snapshot: `Win7-000011.vmdk`
- current child: `Win7-000002.vmdk`

The resolver script identifies the active branch. The importer then converts that branch locally into a single qcow2 before uploading it to Proxmox.

## Import Command

Run from the repo root:

```bash
make ise7-import
```

Useful overrides:

```bash
make ise7-import \
  PROXMOX_NODE_NAME=pve \
  IMPORT_DATASTORE_ID=local \
  VM_DISK_DATASTORE_ID=bulk \
  VMWARE_SOURCE_DIR=/home/mtadros/vm \
  SOURCE_DESCRIPTOR=Win7-000002.vmdk \
  VM_ID=703 \
  VM_NAME=mickey-ise7
```

Dry-run the chain resolution and target values first:

```bash
make ise7-import DRY_RUN=1
```

Leave the imported VM stopped after creation:

```bash
make ise7-import START_VM=0
```

## Imported VM Shape

- VMID: `703`
- name: `mickey-ise7`
- uploaded import file: `local:import/mickey-ise7-current.qcow2`
- storage: `bulk`
- firmware: `SeaBIOS`
- machine type: `pc-i440fx-10.1`
- SCSI controller: `lsi`
- network model: `e1000`
- memory: `8192 MiB`
- cores: `4`
- disk: `100 GiB`

## Post-Boot Guest Steps

After the import succeeds and Windows boots:

1. Confirm Windows boots cleanly without entering repair loops.
2. Remove VMware Tools if they are still installed.
3. Enable RDP so the guest can be used without relying on the Proxmox console.
4. Install Xilinx ISE 14.7 in the guest.
5. Pass through the Digilent cable from Proxmox to the guest.
6. Install the Xilinx cable drivers and, if required, the Digilent runtime/plugin.
7. Validate the cable in `iMPACT`.

## Operational Notes

- The script does not require SSH access to the Proxmox host. It uses the Proxmox API token from `secrets/prod.sops.yaml`, local `qemu-img`, and a temporary Terraform workspace.
- VMware split VMDK extents cannot be uploaded directly through the Proxmox import API. The script converts the resolved chain locally into `~/.cache/mickey-ise7/Win7-current.qcow2` first.
- The uploaded qcow2 remains on `local:import` after the import. This is useful for retries, but it does consume Proxmox local storage until you delete it.
- The target VM disk size defaults to the source image virtual size so Terraform does not try to shrink the imported disk.
- If the target VMID already exists with the same VM name, the script exits successfully without changing it. Destroying and rebuilding an existing VM is still a manual operator step.
