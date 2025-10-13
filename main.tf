# File: main.tf

data "sops_file" "secrets" {
  source_file = "secrets.sops.yaml"
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
