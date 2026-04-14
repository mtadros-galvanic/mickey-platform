ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SECRETS_FILE ?= $(ROOT)secrets/prod.sops.yaml
TFVARS_FILE ?= $(ROOT)envs/prod/terraform.tfvars
ANSIBLE_BASE_INVENTORY ?= $(ROOT)ansible/inventory/hosts.yml
ANSIBLE_GENERATED_INVENTORY ?= $(ROOT)ansible/inventory/hosts.generated.yml
WIPE_CONFIRM ?= false
HOST_ANSIBLE_EXTRA_VARS ?=

.PHONY: templates templates-bionic tf-init tf-plan tf-apply ansible-host ansible-control ansible-desktop ansible-build

templates:
	"$(ROOT)scripts/build-proxmox-templates.sh"

templates-bionic:
	TEMPLATE_ID=9002 \
	TEMPLATE_NAME=ubuntu-18-04-server-cloudinit \
	CLOUD_IMAGE_FILE_NAME=ubuntu-18.04-server-cloudimg-amd64.qcow2 \
	UBUNTU_CLOUD_IMAGE_URL=https://cloud-images.ubuntu.com/releases/bionic/release/ubuntu-18.04-server-cloudimg-amd64.img \
	"$(ROOT)scripts/build-proxmox-template-via-api.sh"

tf-init:
	terraform -chdir="$(ROOT)terraform" init

tf-plan:
	"$(ROOT)scripts/run-terraform.sh" plan

tf-apply:
	"$(ROOT)scripts/run-terraform.sh" apply

ansible-host:
	ANSIBLE_EXTRA_VARS="mickey_bulk_disk_wipe_confirm=$(WIPE_CONFIRM) $(HOST_ANSIBLE_EXTRA_VARS)" "$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/proxmox-host.yml" "$(ANSIBLE_BASE_INVENTORY)"

ansible-control:
	"$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/control-vm.yml" "$(ANSIBLE_BASE_INVENTORY)" "$(ANSIBLE_GENERATED_INVENTORY)"

ansible-desktop:
	"$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/desktop-vm.yml" "$(ANSIBLE_BASE_INVENTORY)" "$(ANSIBLE_GENERATED_INVENTORY)"

ansible-build:
	"$(ROOT)scripts/run-ansible.sh" "$(ROOT)ansible/playbooks/build-vm.yml" "$(ANSIBLE_BASE_INVENTORY)" "$(ANSIBLE_GENERATED_INVENTORY)"
