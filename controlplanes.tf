# Scalable control plane nodes using explicit list of IPs

resource "proxmox_virtual_environment_vm" "talos_controlplanes" {
  count = length(var.controlplane_ips)
  
  name        = "talos-cp-${format("%02d", count.index + 1)}"
  description = "Managed by Terraform"
  tags        = ["terraform", "talos", "controlplane"]
  node_name   = var.node_name
  on_boot     = true
  boot_order  = ["virtio0"]

  cpu {
    cores = var.controlplane_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.controlplane_memory_mb
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
    size         = var.controlplane_disk_size_gb
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.disk_store
    ip_config {
      ipv4 {
        address = "${var.controlplane_ips[count.index]}/24"
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

resource "talos_machine_configuration_apply" "controlplanes_config_apply" {
  count = length(var.controlplane_ips)
  
  depends_on                  = [proxmox_virtual_environment_vm.talos_controlplanes]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_cp.machine_configuration
  node                        = var.controlplane_ips[count.index]
}
