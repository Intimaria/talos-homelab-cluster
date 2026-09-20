## PROXMOX ##

variable "proxmox_api_endpoint" {
  type = string
}

variable "minio_endpoint" {
  type        = string
  description = "MinIO S3 endpoint for Terraform state backend"
}

variable "node_name" {
  type    = string
  default = "proxmox"
}

variable "vm_bridge" {
  type    = string
  default = "vmbr1"
}

variable "disk_store" {
  type    = string
  default = "local-lvm"
}

variable "iso_store_path" {
  type    = string
  default = "local:iso/talos-metal-amd64.iso"
}

## TALOS CLUSTER ##

variable "cluster_name" {
  type = string
}

variable "default_gateway" {
  type = string
}

variable "cluster_vip" {
  type        = string
  description = "Virtual IP for the Talos control plane HA endpoint"
}

variable "controlplane_ips" {
  type        = list(string)
  description = "List of IP addresses for control plane nodes. Minimum 1, recommend 3 for HA."

  validation {
    condition     = length(var.controlplane_ips) == 1 || length(var.controlplane_ips) >= 3
    error_message = "Control plane count must be 1 (single) or 3+ (HA). 2 nodes is not recommended."
  }
}

variable "worker_ips" {
  type        = list(string)
  description = "List of IP addresses for worker nodes"
  default     = []
}

variable "controlplane_cpu_cores" {
  type    = number
  default = 2
}

variable "controlplane_memory_mb" {
  type    = number
  default = 4096
}

variable "controlplane_disk_size_gb" {
  type    = number
  default = 20
}

variable "worker_cpu_cores" {
  type    = number
  default = 3
}

variable "worker_memory_mb" {
  type    = number
  default = 2048
}

variable "worker_disk_size_gb" {
  type    = number
  default = 20
}
