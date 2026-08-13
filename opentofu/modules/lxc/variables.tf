variable "template_file_id" {
  type = string
}

variable "proxmox_node" {
  description = "Target Proxmox node"
  type        = string
}

variable "hostname" {
  description = "LXC hostname"
  type        = string
}

variable "ip_address" {
  description = "Static IP address (CIDR will be applied in main.tf)"
  type        = string
}

variable "gateway_ip" {
  description = "Gateway IP for cloud-init networking"
  type        = string
}

variable "mac_address" {
  description = "MAC address for predictable DHCP/switch binding"
  type        = string
}

variable "dns_servers" {
  description = "DNS resolvers for LXC containers (ordered list)"
  type        = list(string)
}
variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory_mb" {
  description = "RAM allocation in MB"
  type        = number
}

variable "disk_size_gb" {
  description = "Root disk size in GB"
  type        = number
}

variable "ssh_pub_key" {
  description = "SSH public key injected at boot"
  type        = string
  sensitive   = true
}

variable "network_bridge" {
  description = "Proxmox bridge name (e.g., vmbr0, vmbr1)"
  type        = string
}

variable "storage_pool" {
  description = "Storage pool for rootfs"
  type        = string
}

variable "use_cloud_init_template" {
  description = "Set to true if using a cloud-init compatible base image"
  type        = bool
  default     = false
}
