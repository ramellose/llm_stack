#!/usr/bin/env bash
set -euo pipefail

# Align with your Ansible variables
PYTHON_VERSION="${PYTHON_VERSION:-3}"
VENV_PATH="${VENV_PATH:-/opt/ansible_venv}"
TARGET_USER="${TARGET_USER:-admin}"
PYTHON_BIN="python${PYTHON_VERSION}"

# Anchor paths to script location
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../ansible"
INVENTORY_DIR="${ANSIBLE_DIR}/inventory"
CONFIG_DIR="${INVENTORY_DIR}/group_vars/controller_hosts"
CONFIG_FILE="${CONFIG_DIR}/config.yml"
VAULT_FILE="${CONFIG_DIR}/vault.yml"
SERVICE_VAULT_FILE="${INVENTORY_DIR}/group_vars/all/vault.yml"

echo "Bootstrapping Ansible in venv: ${VENV_PATH}"

# 1. Install system dependencies (Debian/DietPi)
if ! command -v "${PYTHON_BIN}" &>/dev/null || ! dpkg -s "${PYTHON_BIN}-venv" &>/dev/null; then
  echo "Installing system packages..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq "${PYTHON_BIN}" "${PYTHON_BIN}-venv" pipx
fi

# 2. Create venv if missing
if [ ! -f "${VENV_PATH}/bin/activate" ]; then
  echo "Creating venv at ${VENV_PATH}..."
  sudo "${PYTHON_BIN}" -m venv "${VENV_PATH}"
  sudo chown -R "${TARGET_USER}:${TARGET_USER}" "${VENV_PATH}"
  echo "Installing Ansible into venv..."
  sudo -u "${TARGET_USER}" "${VENV_PATH}/bin/pip" install -q --upgrade pip
  sudo -u "${TARGET_USER}" "${VENV_PATH}/bin/pip" install -q ansible
fi

# 3. Bootstrap configuration
echo "Bootstrapping inventory..."
cat > "${INVENTORY_DIR}/inventory.ini" <<EOF
[controller_hosts]
127.0.0.1 ansible_connection=local ansible_user=${TARGET_USER}

[localhost]
127.0.0.1
EOF

# 3.a Skip if already initialized
if [[ -f "${CONFIG_FILE}" && -f "${VAULT_FILE}" && -f "${SERVICE_VAULT_FILE}" ]]; then
  echo "Configuration & vault already exist. Skipping interactive setup."
  exec sudo -u "${TARGET_USER}" env ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
    "ansible-playbook" -i "${INVENTORY_DIR}/inventory.ini" "${ANSIBLE_DIR}/playbooks/bootstrap_inventory.yml" "$@"
fi

# 3.b Get configuration and secrets
echo "Initializing configuration & vault (secrets never written to disk)..."
# Secure prompts (no echo, trimmed)
read -r -p "Controller static IP: " CONTROLLER_IP
read -r -p "LLM static IP: " LLM_IP
read -r -p "Proxmox static IP: " PROXMOX_IP
read -r -p "Proxmox node name: " PROXMOX_NAME
read -s -p "Cloudflare token: " CF_TOKEN; echo
read -s -p "Vaultwarden secret: " VWD_SECRET; echo
read -s -p "Proxmox API token: " PX_TOKEN; echo
read -r -p "Base domain: " BASE_DOMAIN
read -r -p "Gateway IP: " GW_IP
read -r -p "Subnet range: " SUBNET_RANGE

# Pass as a single JSON blob to avoid env-var sprawl
EXTRA_VARS=$(jq -n \
  --arg ci "${CONTROLLER_IP}" \
  --arg li "${LLM_IP}" \
  --arg pi "${PROXMOX_IP}" \
  --arg pa "${PROXMOX_NAME}" \
  --arg cn "${CF_TOKEN}" \
  --arg vn "${VWD_SECRET}" \
  --arg pn "${PX_TOKEN}" \
  --arg bd "${BASE_DOMAIN}" \
  --arg gw "${GW_IP}" \
  --arg sn "${SUBNET_RANGE}" \
  '{controller_static_ip: $ci, llm_static_ip: $li, proxmox_static_ip: $pi, proxmox_node_name: $pa,
    stack_cloudflare_token: $cn, stack_vaultwarden_secret: $vn, stack_proxmox_api_token: $pn,
    base_domain: $bd, gateway_ip: $gw, subnet_range: $sn}')

# 4. Hand off bootstrapping to Ansible
echo "Handing off to bootstrap_inventory.yml..."
exec sudo -u "${TARGET_USER}" env ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
  "ansible-playbook" \
  -i "${INVENTORY_DIR}/inventory.ini" \
  --extra-vars "${EXTRA_VARS}" \
  "${ANSIBLE_DIR}/playbooks/bootstrap_inventory.yml" "$@"
