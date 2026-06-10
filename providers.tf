terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.85.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_endpoint
  insecure  = true
  api_token = data.sops_file.secrets.data["proxmox_api_token"]
  
  ssh {
    agent    = false
    username = "root"
    password = data.sops_file.secrets.data["proxmox_ssh_password"]
  }
}

provider "kubernetes" {
  host                   = talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.host
  client_certificate     = base64decode(talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.ca_certificate)
}
