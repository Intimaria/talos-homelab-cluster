

# Scalable worker nodes using count

locals {
  worker_ips = [for i in range(var.worker_count) : "${var.worker_base_ip}.${i + 3}"]
}

resource "proxmox_virtual_environment_vm" "talos_workers" {
  count = var.worker_count
  
  depends_on  = [proxmox_virtual_environment_vm.talos_controlplanes]
  name        = "talos-worker-${format("%02d", count.index + 1)}"
  description = "Managed by Terraform"
  tags        = ["terraform", "talos", "worker"]
  node_name   = var.node_name
  on_boot     = true
  boot_order  = ["scsi0"]

  cpu {
    cores = var.worker_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.worker_memory_mb
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = var.vm_bridge
  }

  disk {
    datastore_id = var.disk_store
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
    file_format  = "raw"
    interface    = "virtio0"
    size         = var.worker_disk_size_gb
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.disk_store
    ip_config {
      ipv4 {
        address = "${local.worker_ips[count.index]}/24"
        gateway = var.default_gateway
      }
      ipv6 {
        address = "dhcp"
      }
    }
    dns {
      servers = [var.default_gateway]
    }
  }
}

resource "talos_machine_configuration_apply" "workers_config_apply" {
  count = var.worker_count
  
  depends_on                  = [proxmox_virtual_environment_vm.talos_workers]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker.machine_configuration
  node                        = local.worker_ips[count.index]
}

# resource "proxmox_virtual_environment_vm" "talos_cp_01" {
#   name        = "talos-cp-01"
#   description = "Managed by Terraform"
#   tags        = ["terraform", "talos", "controlplane"]
#   node_name   = var.node_name
#   on_boot     = true
#   boot_order  = ["scsi0"]

#   cpu {
#     cores = 2
#     type = "x86-64-v2-AES" 
#   }

#   memory {
#     dedicated = 4096
#   }

#   agent {
#     enabled = true
#   }

#   network_device {
#     bridge = var.vm_bridge
#   }

#   disk {
#     datastore_id = var.disk_store
#     file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
#     file_format  = "raw"
#     interface    = "virtio0"
#     size         = 20
#   }

#   operating_system {
#     type = "l26" # Linux Kernel 2.6 - 5.X.
#   }

#   initialization {
#     datastore_id = var.disk_store
#     ip_config {
#       ipv4 {
#         address = "${var.talos_cp_01_ip_addr}/24"
#         gateway = var.default_gateway
#       }
#       ipv6 {
#         address = "dhcp"
#       }
#     }
#     dns {
#       servers = [var.default_gateway]  # pfSense DNS
#     }
#   }

# }

# resource "proxmox_virtual_environment_vm" "talos_worker_01" {
#   depends_on  = [proxmox_virtual_environment_vm.talos_cp_01]
#   name        = "talos-worker-01"
#   description = "Managed by Terraform"
#   tags        = ["terraform", "talos", "worker"]
#   node_name   = var.node_name
#   on_boot     = true
#   boot_order  = ["scsi0"]

#   cpu {
#     cores = 1
#     type = "x86-64-v2-AES"
#   }

#   memory {
#     dedicated = 2048
#   }

#   agent {
#     enabled = true
#   }

#   network_device {
#     bridge = var.vm_bridge
#   }

#   disk {
#     datastore_id = var.disk_store
#     file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
#     file_format  = "raw"
#     interface    = "virtio0"
#     size         = 20
#   }

#   operating_system {
#     type = "l26" # Linux Kernel 2.6 - 5.X.
#   }

#   initialization {
#     datastore_id = var.disk_store
#     ip_config {
#       ipv4 {
#         address = "${var.talos_worker_01_ip_addr}/24"
#         gateway = var.default_gateway
#       }
#       ipv6 {
#         address = "dhcp"
#       }
#     }
#     dns {
#       servers = [var.default_gateway]  # pfSense DNS
#     }
#   }
# }
