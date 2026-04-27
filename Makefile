ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SECRETS_FILE ?= $(ROOT)secrets/prod.sops.yaml
TFVARS_FILE ?= $(ROOT)envs/prod/terraform.tfvars
ANSIBLE_BASE_INVENTORY ?= $(ROOT)ansible/inventory/hosts.yml
ANSIBLE_GENERATED_INVENTORY ?= $(ROOT)ansible/inventory/hosts.generated.yml
WIPE_CONFIRM ?= false
HOST_ANSIBLE_EXTRA_VARS ?=
REIP_APPLY ?= 0

.PHONY: templates templates-bionic templates-jammy templates-resolute proxmox-reip tf-init tf-plan tf-apply ansible-host ansible-infra ansible-erp ansible-utility ansible-control ansible-desktop ansible-build ansible-build-thud ansible-build-scarthgap ise7-import

templates:
	BUILD_DESKTOP_TEMPLATE=0 "$(ROOT)scripts/build-proxmox-templates.sh"

templates-bionic:
	TEMPLATE_ID=9002 \
	TEMPLATE_NAME=ubuntu-18-04-server-cloudinit \
	CLOUD_IMAGE_FILE_NAME=ubuntu-18.04-server-cloudimg-amd64.qcow2 \
	UBUNTU_CLOUD_IMAGE_URL=https://cloud-images.ubuntu.com/releases/bionic/release/ubuntu-18.04-server-cloudimg-amd64.img \
	"$(ROOT)scripts/build-proxmox-template-via-api.sh"

templates-jammy:
	TEMPLATE_ID=9003 \
	TEMPLATE_NAME=ubuntu-22-04-server-cloudinit \
	CLOUD_IMAGE_FILE_NAME=jammy-server-cloudimg-amd64.qcow2 \
	UBUNTU_CLOUD_IMAGE_URL=https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img \
	"$(ROOT)scripts/build-proxmox-template-via-api.sh"

templates-resolute:
	TEMPLATE_ID=9004 \
	TEMPLATE_NAME=ubuntu-26-04-server-cloudinit \
	CLOUD_IMAGE_FILE_NAME=ubuntu-26.04-server-cloudimg-amd64.qcow2 \
	UBUNTU_CLOUD_IMAGE_URL=https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-amd64.img \
	"$(ROOT)scripts/build-proxmox-template-via-api.sh"

proxmox-reip:
	APPLY=$(REIP_APPLY) "$(ROOT)scripts/reip-proxmox-host.sh"

tf-init:
	terraform -chdir="$(ROOT)terraform" init

tf-plan:
	"$(ROOT)scripts/run-terraform.sh" plan

tf-apply:
	"$(ROOT)scripts/run-terraform.sh" apply

ansible-host:
	ANSIBLE_EXTRA_VARS="mickey_bulk_disk_wipe_confirm=$(WIPE_CONFIRM) $(HOST_ANSIBLE_EXTRA_VARS)" "$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/proxmox-host.yml" "$(ANSIBLE_BASE_INVENTORY)"

ansible-infra:
	"$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/infra-vm.yml" "$(ANSIBLE_BASE_INVENTORY)" "$(ANSIBLE_GENERATED_INVENTORY)"

ansible-erp:
	"$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/erp-vm.yml" "$(ANSIBLE_BASE_INVENTORY)" "$(ANSIBLE_GENERATED_INVENTORY)"

ansible-utility:
	"$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/utility-vm.yml" "$(ANSIBLE_BASE_INVENTORY)" "$(ANSIBLE_GENERATED_INVENTORY)"

ansible-desktop:
	$(MAKE) ansible-infra

ansible-control:
	@echo "mickey-control is no longer part of the active topology" >&2
	@exit 1

ansible-build:
	@echo "use make ansible-build-thud or make ansible-build-scarthgap" >&2
	@exit 1

ansible-build-thud:
	"$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/build-thud-vm.yml" "$(ANSIBLE_BASE_INVENTORY)" "$(ANSIBLE_GENERATED_INVENTORY)"

ansible-build-scarthgap:
	"$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/build-scarthgap-vm.yml" "$(ANSIBLE_BASE_INVENTORY)" "$(ANSIBLE_GENERATED_INVENTORY)"

ise7-import:
	"$(ROOT)scripts/import-win7-ise-vm.sh"
