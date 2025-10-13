resource "talos_machine_secrets" "machine_secrets" {}

data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = [var.talos_cp_01_ip_addr]
}

data "talos_machine_configuration" "machineconfig_cp" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_cp_01_ip_addr}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          image = "factory.talos.dev/installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.11.2"
          disk  = "/dev/vda"
        }
        network = {
          nameservers = [var.default_gateway]  # pfSense DNS
        }
      }
    })
  ]
}

data "talos_machine_configuration" "machineconfig_worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_cp_01_ip_addr}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          image = "factory.talos.dev/installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.11.2"
          disk  = "/dev/vda"
        }
        network = {
          nameservers = [var.default_gateway]  # pfSense DNS
        }
      }
    })
  ]
}

# Control plane and worker configuration apply resources moved to controlplanes.tf and workers.tf

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on           = [talos_machine_configuration_apply.controlplanes_config_apply[0]]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = var.talos_cp_01_ip_addr  # Bootstrap first CP
}

data "talos_cluster_health" "health" {
  depends_on           = [
    talos_machine_bootstrap.bootstrap, 
    talos_machine_configuration_apply.controlplanes_config_apply,
    talos_machine_configuration_apply.workers_config_apply
  ]
  client_configuration = data.talos_client_configuration.talosconfig.client_configuration
  control_plane_nodes  = local.controlplane_ips
  worker_nodes         = local.worker_ips
  endpoints            = data.talos_client_configuration.talosconfig.endpoints
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap, data.talos_cluster_health.health]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = var.talos_cp_01_ip_addr
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.talosconfig.talos_config
  sensitive = true
}

