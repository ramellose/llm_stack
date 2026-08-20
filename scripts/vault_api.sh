#!/usr/bin/env bash
set -euo pipefail

# Get configuration and secrets
echo "Provide API keys (obtained from your vaultwarden admin account):"
read -r -p "Host name [controller_node_1]: " HOST_NAME
HOST_NAME="${HOST_NAME:-controller_node_1}"
read -r -p "Client ID: " CLIENT_ID
read -r -s -p "Client secret: " CLIENT_SECRET
echo

# Set up dir
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../ansible"
cd "$ANSIBLE_DIR"
VAULT_FILE="${ANSIBLE_DIR}/inventory/host_vars/${HOST_NAME}/vault.yml"
mkdir -p "$(dirname "$VAULT_FILE")"

# Exit on existing API key
if grep -q 'vault_bw_client_id' "$VAULT_FILE" 2>/dev/null; then
  echo "vault_bw_client_id already present in $VAULT_FILE — aborting to avoid duplicate." >&2
  exit 1
fi

# Encrypt using ansible vault
ENCRYPTED_ID=$(printf '%s' "$CLIENT_ID" | ansible-vault encrypt_string --stdin-name 'vault_bw_client_id')
ENCRYPTED_SECRET=$(printf '%s' "$CLIENT_SECRET" | ansible-vault encrypt_string --stdin-name 'vault_bw_client_secret')

echo "Writing to ${VAULT_FILE}..."
{
  printf '%s\n' "$ENCRYPTED_ID"
  printf '%s\n' "$ENCRYPTED_SECRET"
} >> "$VAULT_FILE"
