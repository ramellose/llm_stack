# Proxmox storage pools are managed outside OpenTofu to avoid destructive block device operations.
# This module standardizes pool references and ensures downstream modules consume consistent targets.
# Prerequisite: Verify pool names match exactly what is listed in Proxmox > Datacenter > Storage.

locals {
  resolved_rootfs = var.rootfs_pool
  resolved_iso    = var.iso_pool
}
