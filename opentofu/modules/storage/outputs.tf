output "rootfs_pool" {
  value       = local.resolved_rootfs
  description = "Resolved storage pool for root filesystems"
}

output "iso_pool" {
  value       = local.resolved_iso
  description = "Resolved storage pool for ISO/cloud-init templates"
}

output "template_ready" {
  value       = var.enable_template_cache
  description = "Indicates whether base OS templates are expected to exist"
}
