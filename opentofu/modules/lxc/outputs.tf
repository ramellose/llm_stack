output "id" {
  value       = proxmox_virtual_environment_container.this.id
  description = "Proxmox LXC ID"
}

output "hostname" {
  value       = var.hostname
  description = "LXC hostname"
}

output "ip_address" {
  value = replace(
    proxmox_virtual_environment_container.this.initialization[0].ip_config[0].ipv4[0].address,
    "/24", ""
  )
}

output "ssh_user" {
  value       = "root" # Default for Proxmox LXC provisioning
  description = "Initial SSH username"
}
