ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SECRETS_FILE ?= $(ROOT)secrets/prod.sops.yaml
TFVARS_FILE ?= $(ROOT)envs/prod/terraform.tfvars
ANSIBLE_BASE_INVENTORY ?= $(ROOT)ansible/inventory/hosts.yml
ANSIBLE_GENERATED_INVENTORY ?= $(ROOT)ansible/inventory/hosts.generated.yml
WIPE_CONFIRM ?= false
HOST_ANSIBLE_EXTRA_VARS ?=

.PHONY: templates tf-init tf-plan tf-apply ansible-host ansible-control ansible-desktop

templates:
	"$(ROOT)scripts/build-proxmox-templates.sh"

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
