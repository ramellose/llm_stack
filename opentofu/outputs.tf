output "ansible_inventory" {
  description = "Structured map for Ansible inventory export"
  value = {
    "all" = { 
      "children" = {
        "services" = {},
        "networkservices" = {},
        "pidev" = {}
        }
      },
    "services" = {
      "hosts" = {
        for name, lxc in module.stack_service : name => {
          "ansible_host" = lxc.ip_address
          "ansible_user" = "root"
          "role"         = "service"
        }
      }
    },
    "networkservices" = {
      "hosts" = {
        for name, lxc in module.stack_network : name => {
          "ansible_host" = lxc.ip_address
          "ansible_user" = "root"
          "role"         = "network"
        }
      }
    },
    "pidev" = {
      "hosts" = {
        for name, lxc in module.stack_pidev : name => {
          "ansible_host" = lxc.ip_address
          "ansible_user" = "root"
          "role"         = "pidev"
        }
      }
    }
  }
}

output "pidev_hosts" {
  description = "Pidev LXC metadata (id/ip/mac per hostname) for Ansible"
  value = {
    for name, lxc in module.stack_pidev : name => {
      id          = lxc.id
      ip_address  = lxc.ip_address
      mac_address = local.pidev_map[name].mac_address
    }
  }
}

locals {
  host_ip = merge(
    { for h, v in local.network_map  : h => v.ip_address },
    { for h, v in local.services_map : h => v.ip_address }
  )
}

locals {
  # Flatten host->services for Ansible group vars (network + services hosts)
  service_records = flatten([
    for host in concat(var.stack_network, var.stack_services) : [
      for svc in host.services : {
        service         = svc.service
        host            = host.hostname
        subdomain       = svc.subdomain
        target_ip       = svc.subdomain == null ? null : local.host_ip[host.hostname]
        target_port     = svc.target_port
        public_hostname = svc.subdomain == null ? null : "${svc.subdomain}.${var.base_domain}"
        url             = svc.subdomain == null ? null : "https://${svc.subdomain}.${var.base_domain}"
      }
    ]
  ])
}

output "ansible_service_vars" {
  description = "Ansible service records export"
  value = {
    proxied_services = {
      for rec in local.service_records : rec.service => rec if rec.subdomain != null
    }
  }
}

locals {
  # Records by host, for host_vars
  services_by_host = {
    for host in distinct([for rec in local.service_records : rec.host]) :
    host => [for rec in local.service_records : rec if rec.host == host]
  }
}

output "services_by_host" {
  value = local.services_by_host
}


locals {
  service_records_map = { for rec in local.service_records : rec.service => rec }
}

locals {
  caddy_host = one([
    for host in var.stack_network : host.hostname
    if length([for s in host.services : s if s.service == "caddy"]) > 0
  ])
}

output "network_configuration" {
  value = {
    gateway_ip = var.gateway_ip
    subnet_range = var.subnet_range
    ntfy_endpoint = local.service_records_map["ntfy"].url
    base_domain = var.base_domain
    }
}
