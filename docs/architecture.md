# Architecture 

Objective: reproducible and secure bootstrapping of a LLM stack, designed for portability and auditability. 

## Components

- **Controller host**: Runs Ansible and OpenTofu for: 
    - LXC provisioning
    - Network configuration
    - Ansible inventory generation
    - Service provisioning
- **LLM host**: Servers LLMs using `llama.cpp`
- **Proxmox host**: Deploys services using LXCs and VMs (pending)

## Secrets lifecycle

- Controller host bootstraps Vaultwarden instance
- Service deployment playbooks retrieve and store secrets in Vaultwarden
- Objective: zero-persistence of secrets on disk 

## Service architecture

### networkservices

Deploys Caddy and Unbound to enable access of services through a proxy. 
Templated Caddyfile uses OpenTofu-generated JSON files for variables (IP, service name) in combination with a static `services/vars.yml` configuration dict. 

### services

_Currently limited to Docker services._

Service definition is included in the static `services/vars.yml` configuration dict; OpenTofu JSON outputs are used to orchestrate deployment on provisioned LXCs. The configuration dict contains version information, directory information and non-standard Caddy options. 

## Human users / pidev

One development LXC per human user, so each person runs the [pi](https://pi.dev/) coding agent harness in an isolated container against the local llama host.

- **Source of truth**: `ansible/inventory/group_vars/services/humans.yml` (list of users; optional `pidev: { cpu, ram, disk }` sizing overrides).
- **Provisioning**: `scripts/provision_users.sh <user> [...]` is the top-level entrypoint. It merges new users into `humans.yml` and then runs the idempotent chain:
  1. `playbooks/secrets_lifecycle.yml` — Vaultwarden account per human
  2. `playbooks/deploy_forgejo.yml` — Forgejo account + `humans` team
  3. `playbooks/provision_pidev.yml` — per-user ed25519 keypair on the controller (`/home/admin/.ssh/pidev/id_ed25519_<user>`), OpenTofu LXC creation (`stack_pidev`), private key stored in the user's Vaultwarden account as item `pidev-ssh-key-<user>` (with a `~/.ssh/config` snippet in the notes)
  4. `playbooks/hardening.yml` — hardens the new LXC (creates `admin`, disables password/root login) and regenerates `post_harden.yml`, which brings the `pidev` group into the default inventory
  5. `playbooks/deploy_pidev.yml` — adds the user's key to `admin`'s `authorized_keys` and installs the pi harness (Node.js, pi-coding-agent, pi-llama-cpp, `auth.json`/`settings.json` pointing at the llama host)
- **Conventions**: hostname `pidev_<user>`, IP `cidrhost(subnet_range, 240 + idx)` (after network `230+` and services `235+`), MAC `d2:00:00:00:00:<idx+1>`. Both the default (controller) key and the per-user key are injected via cloud-init at creation.
- **End user flow**: log into Vaultwarden, copy the key to `~/.ssh/id_pidev`, copy the notes into `~/.ssh/config`, `ssh pidev` (see the agent harness page in `roles/pages/files/agent_harness.md.j2`).

## Future extensions

- Molecule test scenarios for roles
- Forgejo CI integrations
- Status monitor
- Firewall configuration
