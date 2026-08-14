# Security 

## Secrets
### Ansible vault

During bootstrapping, an Ansible vault password is generated and used to encrypt secrets. 
This password is stored on the controller host. It is advisable to store the password in a safe location in case you need to decrypt the vault content. 

While having the vault password on the controller host is convenient, it is also a security risk. It is strongly advised to secure the host so that the password cannot be extracted. In production settings, JIT access is more appropriate. 

### Proxmox API token

The Proxmox API token used by OpenTofu has a very broad scope. This is necessary because OpenTofu needs to be able to delete and create containers. It is strongly recommended to use a dedicated Proxmox host for this stack, as a compromised token could be used to delete unrelated containers. 

### Cloudflare API token

Currently, the Cloudflare API token is written to a `.env` file used by the `networkservices` container. 
This means the token can be compromised; it is strongly recommended to use a scoped token with limited permissions to limit the blast radius of a leaked token. 

## Segmentation

This stack has been designed to facilitate deployment of MCP services on dedicated LXCs and/or VMs. 
The resulting segmentation drastically limits the blast radius of compromised services and supports integration of conventional network hardening measures. 

A proof of concept showing how this supports sandboxed code execution is in progress. 
