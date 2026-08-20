# Prerequisites

An improved initial configuration workflow is under development; this workflow includes setup of an Ansible vault for seeding the stack with required secrets. 

**All bare-metal hosts must support passwordless sudo using an `admin` user.** The controller host must be able to access the bare-metal hosts through SSH. 

## Proxmox

OpenTofu needs an API key for the Proxmox host. 
The commands below can be used to create a service account and obtain an API key: 

```
pveum user add iac-controller@pam --comment "IaC Controller Service Account"
pveum acl modify /nodes/<node_name> --user iac-controller@pam --role Administrator
pveum user token add iac-controller@pam iac-controller --privsep 0 --comment "OpenTofu & Ansible Automation"
pveum acl modify /nodes/<node_name> --token 'iac-controller@pam!iac-controller' --role Administrator
pveum acl modify /storage/<iso-store> --token 'iac-controller@pam!iac-controller' --role Administrator
```

## DNS overrides

This stack automatically creates public hostnames for deployed services, so they can be accessed using a domain rather than the IP address and port. 

Caddy has been set up to automatically obtain valid SSL certificates using Cloudflare for DNS challenges. This allows access to services using HTTPS, but it requires a domain that can be used to pass the DNS challenge. 
For this setup, the `ansible/inventory/group_vars/networkservices/vault.yml` file needs to contain an encrypted API token named `vault_cloudflare_api_token`. 

The stack's Unbound service automatically creates overrides for each service. For clients to use these overrides, the DNS server must be configured to point to the stack's Unbound service directly, or your existing DNS configuration needs to be adjusted to use the Unbound service as the authoritative DNS server for the domain. Most travel routers can be configured so that they resolve DNS through the Unbound service, enabling access to services through WiFi. 

## Bare-metal configuration

An initial `static_hosts.yml` file must be created with the IPs of the bare-metal hosts. 
Until the initial configuration workflow is available, Jinja2 templates are available for the configuration from the `prerequisites` folder. 
