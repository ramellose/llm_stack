# llm_stack

IaC for a bootstrapped local LLM stack. This stack serves as a reproducible and offline-capable (after initial provisioning) environment for testing agents, pipeline orchestration, MCP servers and security boundaries.

<img width="150" height="159" align="right" alt="Photo of a small 3D-printed 10 inch server rack in teal and magenta. From top to bottom, the rack contains a travel router, two SBCs, a mini PC and a switch." src="https://github.com/user-attachments/assets/7775be03-d9b5-4d67-893b-9603d26f3682" />

Developed using readily available hardware:

- Controller SBC to handle bootstrapping and provisioning (2 GB RAM, 32 GB eMMC)
- Mini PC with Proxmox
- LLM server SBC (32 GB RAM, 128 GB eMMC)

Note that this is not a high-performance stack; for many use cases, running `llama.cpp` on a SBC is not practical. 

Briefly: 

- The controller SBC is provisioned with this repository, the configuration of the bare-metal hosts and the configuration of the stack
- OpenTofu automates LXC provisioning on the Proxmox host:
    - A `networkservices` host for deploying Caddy and Unbound
    - A `dockerservices` host for deploying Open WebUI, ntfy and Vaultwarden
- Ansible provisions and configures services on bare-metal and virtualized hosts
- A travel router provides offline WiFi; Unbound DNS resolves internal service domains without external dependencies

Structure: 

```
llm_stack/
├── ansible/
│   ├── inventory/
│   ├── playbooks/
│   └── roles/{caddy,docker_engine,docker_stack,hardening,llama_cpp,unbound}
├── opentofu/
|   ├── modules/{lxc,storage}
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── docs/
└── README.md
```

## Prerequisites

An improved initial configuration workflow is under development; this workflow includes setup of an Ansible vault for seeding the stack with required secrets. 

### Proxmox

OpenTofu needs an API key for the Proxmox host. 
The commands below can be used to create a service account and obtain an API key: 

```
pveum user add iac-controller@pam --comment "IaC Controller Service Account"
pveum acl modify /nodes/<node_name> --user iac-controller@pam --role PVEAdmin
pveum user token add iac-controller@pam iac-controller --privsep 1 --comment "OpenTofu & Ansible Automation"
pveum acl modify /nodes/<node_name> --token 'iac-controller@pam!iac-controller' --role PVEAdmin
```

### DNS overrides

This stack automatically creates public hostnames for deployed services, so they can be accessed using a domain rather than the IP address and port. 

Caddy has been set up to automatically obtain valid SSL certificates using Cloudflare for DNS challenges. This allows access to services using HTTPS, but it requires a domain that can be used to pass the DNS challenge. 
For this setup, the `ansible/inventory/group_vars/networkservices/vault.yml` file needs to contain an encrypted API token named `vault_cloudflare_api_token`. 

The stack's Unbound service automatically creates overrides for each service. For clients to use these overrides, the DNS server must be configured to point to the stack's Unbound service directly, or your existing DNS configuration needs to be adjusted to use the Unbound service as the authoritative DNS server for the domain. Most travel routers can be configured so that they resolve DNS through the Unbound service, enabling access to services through WiFi. 

### Bare-metal configuration

An initial `static_hosts.yml` file must be created with the IPs of the bare-metal hosts. 
Until the initial configuration workflow is available, Jinja2 templates are available for the configuration from the `prerequisites` folder. 

## Usage 


### 1. Provision infrastructure 

Provision LXCs with OpenTofu. The `tofu.sh` wrapper automatically creates variables and a host inventory required for the Ansible playbooks.  

```
cd llm_stack
./tofu.sh plan
./tofu.sh apply 
```

Check that the controller's Ansible setup can access the inventory: 

```
cd ansible
ansible-inventory -i inventory/ --list
ansible all -i inventory/ -m ping
```

### 2. Bootstrap and harden 

Run initial hardening to create a `post_harden.yml` default inventory, combining the static hosts and the provisioned LXCs:

```
ansible-playbook playbooks/hardening.yml -i inventory/static_hosts.yml -i inventory/tofu_generated.json
ansible all -m ping
```

### 3. Deploy services 

```
ansible-playbook playbooks/deploy_dns.yml
ansible-playbook playbooks/deploy_services.yml
ansible-playbook playbooks/provision_llama_cpp.yml
```


After this last step, you should be able to access services using your domain, e.g.:

- chat.<domain.org> - Open WebUI
- vaultwarden.<domain.org> - Vaultwarden
- ntfy.<domain.org> - ntfy

## Planned milestones

- Improved initial configuration workflow
- Prometheus and Grafana as Docker services
- Make Caddy DNS challenge optional for fully offline deployment
- Secrets provisioning using Vaultwarden
- Forgejo git server with automatically provisioned service accounts for agents
- Flexible deployment of MCP servers
- MCP server using Proxmox and Ansible for sandboxed code execution

Some of these milestones will likely be released as separate repositories. 

## Disclaimer

This project is an early WIP and relies heavily on specific infrastructure configurations. Moreover, it is an IaC playground for experimenting with infrastructure and automated provisioning for GenAI systems; this is not production-ready infrastructure. 
