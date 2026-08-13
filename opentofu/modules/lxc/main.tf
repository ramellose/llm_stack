resource "proxmox_virtual_environment_container" "this" {
  node_name    = var.proxmox_node
  unprivileged = true

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id    = var.storage_pool
    size            = var.disk_size_gb
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "ubuntu"

  }

  network_interface {
    name        = "eth0"
    bridge      = var.network_bridge
    mac_address = var.mac_address
  }
  
  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = "${var.ip_address}/24"
        gateway = var.gateway_ip
      }
    }

    dns {
      servers = var.dns_servers
    }
    
    user_account {
      keys = [trimspace(var.ssh_pub_key)]
    }
  }




  features {
    nesting = true
  }

}
