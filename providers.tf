# File: providers.tf

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

  }
}
