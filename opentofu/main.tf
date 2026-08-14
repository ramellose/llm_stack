terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.63.0"
    }
  }

  backend "local" {
    path = "state/terraform.tfstate"
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = trimspace(var.proxmox_api_token)
  insecure  = var.proxmox_insecure

  ssh {
    username     = "root"
    private_key  = var.ssh_public_key
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_lxc_template" {
  content_type = "vztmpl"
  datastore_id = "iso-store"
  node_name    = var.proxmox_node
  url          = "http://download.proxmox.com/images/system/ubuntu-26.04-standard_26.04-1_amd64.tar.zst"
}

# Storage & template references
module "storage" {
  source       = "./modules/storage"
  proxmox_node = var.proxmox_node
}

locals {
  network_map = {
    for idx, w in var.stack_network : w.hostname => {
      hostname       = w.hostname
      ip_address     = cidrhost(var.subnet_range, 230 + idx)
      mac_address    = format("b2:00:00:00:00:%02x", idx + 1)
      cpu_cores      = w.cpu_cores
      memory_mb      = w.memory_mb
      disk_size_gb   = w.disk_size_gb
      base_domain    = var.base_domain
    }
  }
}

module "stack_network" {
  source       = "./modules/lxc"
  for_each     = local.network_map

  template_file_id = proxmox_virtual_environment_download_file.ubuntu_lxc_template.id
  proxmox_node   = var.proxmox_node
  hostname       = each.value.hostname
  ip_address     = each.value.ip_address
  mac_address    = each.value.mac_address
  gateway_ip     = var.gateway_ip
  dns_servers    = var.dns_servers
  cpu_cores      = each.value.cpu_cores
  memory_mb      = each.value.memory_mb
  disk_size_gb   = each.value.disk_size_gb
  ssh_pub_key    = var.ssh_public_key
  network_bridge = var.network_bridge
  storage_pool   = module.storage.rootfs_pool
}

locals {
  services_map = {
    for idx, w in var.stack_services : w.hostname => {
      hostname       = w.hostname
      ip_address     = cidrhost(var.subnet_range, 235 + idx)
      mac_address    = format("c2:00:00:00:00:%02x", idx + 1)
      cpu_cores      = w.cpu_cores
      memory_mb      = w.memory_mb
      disk_size_gb   = w.disk_size_gb
      base_domain    = var.base_domain
    }
  }
}

module "stack_service" {
  source       = "./modules/lxc"
  for_each     = local.services_map

  template_file_id = proxmox_virtual_environment_download_file.ubuntu_lxc_template.id
  proxmox_node   = var.proxmox_node
  hostname       = each.value.hostname
  ip_address     = each.value.ip_address
  mac_address    = each.value.mac_address
  gateway_ip     = var.gateway_ip
  dns_servers    = var.dns_servers
  cpu_cores      = each.value.cpu_cores
  memory_mb      = each.value.memory_mb
  disk_size_gb   = each.value.disk_size_gb
  ssh_pub_key    = var.ssh_public_key
  network_bridge = var.network_bridge
  storage_pool   = module.storage.rootfs_pool
}
