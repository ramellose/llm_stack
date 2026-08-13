# --- Proxmox Connection ---
variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint (e.g., https://192.168.1.100:8006)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format: user@realm!token_id:token_secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Target Proxmox node name"
  type        = string
  default     = "proxmox"
}

# --- Network ---
variable "network_bridge" {
  description = "Proxmox network bridge for the stack (e.g., vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "gateway_ip" {
  description = "Gateway IP for cloud-init networking"
  type        = string
}

variable "subnet_range" {
  description = "IP range for VLAN"
  type        = string
}

variable "dns_servers" {
  description = "DNS resolvers for LXC containers (ordered list)"
  type        = list(string)
}

# --- SSH Key Injection ---
variable "ssh_public_key" {
  description = "Public SSH key to inject into all LXCs/VMs at birth"
  type        = string
  sensitive   = true
}

# --- Resource Defaults ---
variable "default_lxc_cpu" {
  description = "Default CPU cores for LXCs"
  type        = number
  default     = 2
}

variable "default_lxc_ram" {
  description = "Default RAM (MB) for LXCs"
  type        = number
  default     = 2048
}

variable "default_lxc_disk" {
  description = "Default disk size (GB) for LXCs"
  type        = number
  default     = 20
}

variable "default_vm_cpu" {
  description = "Default CPU cores for VMs"
  type        = number
  default     = 2
}

variable "default_vm_ram" {
  description = "Default RAM (MB) for VMs"
  type        = number
  default     = 8192
}

variable "default_vm_disk" {
  description = "Default disk size (GB) for VMs"
  type        = number
  default     = 40
}

variable "base_domain" {
  description = "Public domain for stack services"
  type        = string
}

variable "stack_network" {
  description = "Network services (DNS, proxy)"
  type = list(object({
    hostname     = string
    cpu_cores    = number
    memory_mb    = number
    disk_size_gb = number
    caddy = list(object( {
      service       = string
    }))
    unbound = list(object( {
      service       = string
    }))
  }))
  default = [
    { hostname = "networkservices01", cpu_cores = 2, memory_mb = 2048, disk_size_gb = 30,
      caddy = [
        { service = "caddy"}
      ], 
      unbound = [
        { service = "unbound"}
      ]
    }
  ]
}

variable "stack_services" {
  description = "Support services (storage, DB, etc)"
  type = list(object({
    hostname     = string
    cpu_cores    = number
    memory_mb    = number
    disk_size_gb = number
    services = list(object( {
      service       = string
      subdomain     = string
      target_port   = number
    }))
  }))
  default = [
    { hostname = "dockerservices01", cpu_cores = 2, memory_mb = 4096, disk_size_gb = 30,
      services = [
        { service = "openwebui", subdomain = "chat", target_port = 3002},
        { service = "uptime-kuma", subdomain = "status", target_port = 3001},
        { service = "ntfy", subdomain = "ntfy", target_port = 2586},
        { service = "vaultwarden", subdomain = "vaultwarden", target_port = 8000}
      ] 
    },
    { hostname = "forgejoserver", cpu_cores = 2, memory_mb = 4096, disk_size_gb = 30, 
      services = [
        { service = "forgejo", subdomain = "forgejo", target_port = 3000}
      ]
    }
  ]
}
