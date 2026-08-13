output "ansible_inventory" {
  description = "Structured map for Ansible inventory export"
  value = {
    "all" = { 
      "children" = {
        "services" = {},
        "networkservices" = {}
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
    }
  }
}

locals {
  # Flatten host->services for Ansible group vars
  service_records = flatten([
    for host in var.stack_services : [
      for svc in host.services : {
        service           = svc.service
        host              = host.hostname
        target_ip         = local.services_map[host.hostname].ip_address
        target_port       = svc.target_port
        public_hostname   = "${svc.subdomain}.${var.base_domain}"
        url               = "https://${svc.subdomain}.${var.base_domain}"
      }
    ]
  ])
}

output "ansible_service_vars" {
  description = "Ansible service records export"
  value = {
    proxied_services = {
      for rec in local.service_records : rec.service => rec
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

output "network_configuration" {
  value = {
    gateway_ip = var.gateway_ip
    subnet_range = var.subnet_range
    ntfy_endpoint = local.service_records_map["ntfy"].url
    base_domain = var.base_domain
  }
}
