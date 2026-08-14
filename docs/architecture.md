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

## Future extensions

- Molecule test scenarios for roles
- Forgejo CI integrations
- Status monitor
- Firewall configuration
