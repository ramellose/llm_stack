#!/usr/bin/env bash
set -euo pipefail

# Provision human users end-to-end:
#   1. add them to ansible/inventory/group_vars/services/humans.yml
#   2. Vaultwarden account            (playbooks/secrets_lifecycle.yml)
#   3. Forgejo account + teams        (playbooks/deploy_forgejo.yml)
#   4. Open WebUI account + vault pw  (playbooks/deploy_openwebui.yml)
#   5. pidev LXC + vault SSH key      (playbooks/provision_pidev.yml)
#   6. harden LXC + refresh inventory (playbooks/hardening.yml)
#   7. install pi harness             (playbooks/deploy_pidev.yml)
#
# Requires a bootstrapped and already-hardened stack (post_harden.yml must
# exist). All steps are idempotent, so re-running is safe and composes with
# the individual playbooks.
#
# Usage: ./scripts/provision_users.sh <user1> [user2 ...]

TARGET_USER="${TARGET_USER:-admin}"
VENV_PATH="${VENV_PATH:-/opt/ansible_venv}"

# Anchor paths to script location
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
ANSIBLE_DIR="${REPO_DIR}/ansible"
PLAYBOOKS_DIR="${ANSIBLE_DIR}/playbooks"
HUMANS_FILE="${ANSIBLE_DIR}/inventory/group_vars/services/humans.yml"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <user1> [user2 ...]" >&2
  exit 1
fi

run_playbook() {
  echo "==> ansible-playbook $*"
  sudo -u "${TARGET_USER}" env ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
    "ansible-playbook" "$@"
}

# 1. Ensure each user has an entry in humans.yml (idempotent merge)
for user in "$@"; do
  echo "==> Ensuring ${user} in ${HUMANS_FILE}"
  HUMANS_FILE="${HUMANS_FILE}" "${VENV_PATH}/bin/python" - "${user}" <<'PYEOF'
import os
import sys

import yaml
from pathlib import Path

user = sys.argv[1]
path = Path(os.environ["HUMANS_FILE"])
doc = yaml.safe_load(path.read_text()) or {}

# humans.yml is a group-vars file: a `humans:` mapping key holding the user
# list (a bare list is tolerated for robustness).
is_mapping = isinstance(doc, dict)
data = doc.get("humans", []) if is_mapping else doc
if not isinstance(data, list):
    raise SystemExit(f"HUMANS_FILE malformed: expected a list of users, got {type(data).__name__}")

entry = {
    "name": user,
    "description": "Human user",
    "forgejo": {
        "user": user,
        "org": "platform",
        "role": "member",
        "teams": ["humans"],
    },
}

if any(isinstance(e, dict) and e.get("name") == user for e in data):
    print(f"    {user} already present, skipping")
else:
    data.append(entry)
    out = {"humans": data} if is_mapping else data
    path.write_text(yaml.safe_dump(out, sort_keys=False, default_flow_style=False))
    print(f"    added {user}")
PYEOF
done

# 2. Vaultwarden account per human (idempotent; 400 if already registered)
run_playbook "${PLAYBOOKS_DIR}/secrets_lifecycle.yml"

# 3. Forgejo users, vault passwords, team membership (idempotent)
run_playbook "${PLAYBOOKS_DIR}/deploy_forgejo.yml"

# 4. Open WebUI accounts (admin + per-human), vault passwords (idempotent)
run_playbook "${PLAYBOOKS_DIR}/deploy_openwebui.yml"

# 5. Per-user SSH keys + OpenTofu LXC creation + vault SSH-key items
run_playbook "${PLAYBOOKS_DIR}/provision_pidev.yml"

# 6. Harden new LXCs (as root, controller key), create admin user,
#    regenerate post_harden.yml so the `pidev` group enters the default inventory
run_playbook \
  "${PLAYBOOKS_DIR}/hardening.yml" \
  -i "${ANSIBLE_DIR}/inventory/static_hosts.yml" \
  -i "${ANSIBLE_DIR}/inventory/tofu_generated.json"

# 7. Per-user key in admin's authorized_keys + pi harness install
run_playbook "${PLAYBOOKS_DIR}/deploy_pidev.yml"

echo
echo "Done. For each new user (${*}):"
echo "  1. Log into Vaultwarden"
echo "     - 'openwebui-password-<user>' -> Open WebUI account (chat.<base_domain>)"
echo "     - 'forgejo-password-<user>'   -> Forgejo account"
echo "     - 'pidev-ssh-key-<user>'      -> SSH key for the pidev LXC"
echo "  2. Save the key to ~/.ssh/id_pidev (chmod 600) and copy the notes into ~/.ssh/config"
echo "  3. ssh pidev"
