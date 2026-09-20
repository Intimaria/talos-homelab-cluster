resource "talos_machine_secrets" "machine_secrets" {}

data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = var.controlplane_ips
}

data "talos_machine_configuration" "machineconfig_cp" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        features = {
          rbac = true
        }
        install = {
          image = "factory.talos.dev/installer/${local.talos.schematic_id}:${local.talos.version}"
          disk  = "/dev/vda"
        }
        network = {
          nameservers = [var.default_gateway]
          interfaces = [{
            deviceSelector = { physical = true }
            vip            = { ip = var.cluster_vip }
          }]
        }
      }
    }),
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
      }
    })
  ]
}

data "talos_machine_configuration" "machineconfig_worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        features = {
          rbac = true
        }
        install = {
          image = "factory.talos.dev/installer/${local.talos.schematic_id}:${local.talos.version}"
          disk  = "/dev/vda"
        }
        network = {
          nameservers = [var.default_gateway]
        }
        # Required by local-path-provisioner (talos-base-services)
        kubelet = {
          extraMounts = [{
            destination = "/var/local-path-provisioner"
            type        = "bind"
            source      = "/var/local-path-provisioner"
            options     = ["bind", "rshared", "rw"]
          }]
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on           = [talos_machine_configuration_apply.controlplanes_config_apply]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = var.controlplane_ips[0]
}

data "talos_cluster_health" "health" {
  depends_on = [
    talos_machine_bootstrap.bootstrap,
    talos_machine_configuration_apply.controlplanes_config_apply,
    talos_machine_configuration_apply.workers_config_apply
  ]
  client_configuration = data.talos_client_configuration.talosconfig.client_configuration
  control_plane_nodes  = var.controlplane_ips
  worker_nodes         = var.worker_ips
  endpoints            = data.talos_client_configuration.talosconfig.endpoints
  # Nodes can't report Ready before the CNI exists (cni: none + Cilium via
  # helmfile), so only check Talos-level health (etcd, apid, kubelet up).
  skip_kubernetes_checks = true
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap, data.talos_cluster_health.health]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = var.controlplane_ips[0]
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.talosconfig.talos_config
  sensitive = true
}
