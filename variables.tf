## PROXMOX ## 

variable "proxmox_api_endpoint" {
  type     = string
  default  = "https://192.168.1.60:8006"
}

variable "node_name"      { 
  type = string  
  default = "proxmox" 
}

variable "vm_bridge"      { 
  type = string  
  default = "vmbr1" 
}

variable "disk_store"     { 
  type = string  
  default = "local-lvm" 
}

variable "iso_store_path" { 
  type = string  
  default = "local:iso/talos-metal-amd64.iso" 
}

## TALOS CLUSTER ## 

variable "cluster_name" {
  type    = string
  default = "homelab"
}

variable "default_gateway" {
  type    = string
  default = "10.50.0.1"
}

variable "talos_cp_01_ip_addr" {
  type    = string
  default = "10.50.0.2"
  description = "First control plane IP (used as cluster endpoint)"
}

# Control plane nodes configuration
variable "controlplane_count" {
  type        = number
  default     = 1
  description = "Number of control plane nodes (1 or 3+ for HA)"
  
  validation {
    condition     = var.controlplane_count == 1 || var.controlplane_count >= 3
    error_message = "Control plane count must be 1 (single) or 3+ (HA). 2 nodes is not recommended."
  }
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

variable "talos_worker_01_ip_addr" {
  type    = string
  default = "10.50.0.3"
  description = "DEPRECATED: Use worker_count and worker_base_ip instead. Kept for backward compatibility."
}


variable "talos_cp_01_hostname" {
  type    = string
  default = "talos-cp-01"
}

# Worker nodes configuration
variable "worker_count" {
  type        = number
  default     = 1
  description = "Number of worker nodes to create"
}

variable "worker_base_ip" {
  type        = string
  default     = "10.50.0"
  description = "Base IP for worker nodes (will append .3, .4, .5, etc.)"
}

variable "worker_cpu_cores" {
  type    = number
  default = 1
}

variable "worker_memory_mb" {
  type    = number
  default = 2048
}

variable "worker_disk_size_gb" {
  type    = number
  default = 20
}