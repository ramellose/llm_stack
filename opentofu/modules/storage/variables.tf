variable "proxmox_node" {
  description = "Target Proxmox node for storage validation"
  type        = string
}

variable "rootfs_pool" {
  description = "Primary storage pool for LXC/VM root disks (e.g., local-lvm, zfs-01)"
  type        = string
  default     = "local-lvm"
}

variable "iso_pool" {
  description = "Storage pool for ISO images and cloud-init templates"
  type        = string
  default     = "local"
}

variable "enable_template_cache" {
  description = "If true, module expects base OS templates to be pre-seeded in iso_pool"
  type        = bool
  default     = true
}
