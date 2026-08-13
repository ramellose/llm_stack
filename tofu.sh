#!/usr/bin/env bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENTOFU_DIR="${SCRIPT_DIR}/opentofu"
CONFIG_FILE="${SCRIPT_DIR}/config.tfvars"
ANSIBLE_INVENTORY_DIR="${SCRIPT_DIR}/ansible/inventory"
STATE_FILE="${OPENTOFU_DIR}/state/terraform.tfstate"
BACKUP_DIR="${OPENTOFU_DIR}/state/backups"
LOG_FILE="${SCRIPT_DIR}/deploy.log"

set -a
source "${OPENTOFU_DIR}/.env"
set +a

# Logging helper
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# Pre-flight checks
preflight() {
  if ! command -v tofu &>/dev/null; then
    log "ERROR: OpenTofu not found. Install it first."
    exit 1
  fi
  mkdir -p "$BACKUP_DIR" "$ANSIBLE_INVENTORY_DIR"
  if [ ! -f "$OPENTOFU_DIR/.terraform.lock.hcl" ]; then
    log "WARNING: .terraform.lock.hcl missing. Running tofu init..."
    cd "$OPENTOFU_DIR"
    tofu init
  fi
}

# State backup
backup_state() {
  if [ -f "$STATE_FILE" ]; then
    cp "$STATE_FILE" "${BACKUP_DIR}/terraform.tfstate.$(date '+%Y%m%d%H%M%S')".bak
    log "State backed up."
  fi
}

# Generate dynamic inventory for Ansible
generate_inventory() {
  log "Generating Ansible inventory from OpenTofu outputs..."
  cd "$OPENTOFU_DIR"
  tofu output -json ansible_inventory | jq '.' \
    > "${ANSIBLE_INVENTORY_DIR}/tofu_generated.json"
  log "Inventory written to ${ANSIBLE_INVENTORY_DIR}/tofu_generated.json"
}

generate_ansible_vars() {
  log "Rendering Ansible group vars from OpenTofu state..."
  cd "$OPENTOFU_DIR"
  
  # Write global Ansible group_vars
  mkdir -p "${ANSIBLE_INVENTORY_DIR}/group_vars/all"
  tofu output -json network_configuration \
    > "${ANSIBLE_INVENTORY_DIR}/group_vars/all/network_configuration.json"
  log "Ansible network vars written to ${ANSIBLE_INVENTORY_DIR}/group_vars/all/network_configuration.yml"
  
  # Write networkservices group vars
  mkdir -p "${ANSIBLE_INVENTORY_DIR}/group_vars/networkservices"
  tofu output -json ansible_service_vars | jq '.' \
    > "${ANSIBLE_INVENTORY_DIR}/group_vars/networkservices/vars.json"

  log "Ansible DNS vars written to ${ANSIBLE_INVENTORY_DIR}/group_vars/networkservices/vars.json"

  for host in $(tofu output -json services_by_host | jq -r 'keys[]'); do
  mkdir -p "${ANSIBLE_INVENTORY_DIR}/host_vars/${host}"
  tofu output -json services_by_host \
    | jq --arg h "$host" '{services_on_host: .[$h]}' \
    > "${ANSIBLE_INVENTORY_DIR}/host_vars/${host}/vars.json"
  done

  log "Ansible host vars written to ${ANSIBLE_INVENTORY_DIR}/host_vars/<host>/vars.json"
}

# Main dispatcher
case "${1:-help}" in
  init)
    log "Initializing OpenTofu..."
    cd "$OPENTOFU_DIR"
    tofu init -input=false -var-file="$CONFIG_FILE"
    ;;
  plan)
    preflight
    log "Running tofu plan..."
    cd "$OPENTOFU_DIR"
    tofu plan -input=false -no-color -var-file="$CONFIG_FILE" | tee -a "$LOG_FILE"
    ;;
  apply)
    preflight
    backup_state
    log "Running tofu apply..."
    cd "$OPENTOFU_DIR"
    tofu apply -auto-approve -input=false -no-color -var-file="$CONFIG_FILE" | tee -a "$LOG_FILE"
    generate_inventory
    generate_ansible_vars
    log "OpenTofu apply complete."
    ;;
  state-backup)
    backup_state
    ;;
  inventory)
    generate_inventory
    generate_ansible_vars
    ;;
  help|*)
    echo "Usage: $0 {init|plan|apply|state-backup|inventory}"
    echo "  init          - Download providers and initialize state"
    echo "  plan          - Preview changes without applying"
    echo "  apply         - Apply infrastructure + generate Ansible inventory"
    echo "  state-backup  - Create manual state backup"
    echo "  inventory     - Rebuild Ansible inventory from current outputs"
    ;;
esac
