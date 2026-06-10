# Talos Kubernetes Cluster on Proxmox

This repository contains Terraform/OpenTofu configuration for deploying a scalable Talos Linux Kubernetes cluster on Proxmox VE.

## Architecture

- **Infrastructure as Code**: OpenTofu (Terraform-compatible)
- **Kubernetes Distribution**: Talos Linux v1.11.2
- **Platform**: Proxmox VE (single node, non-ZFS)
- **Network**: DMZ (10.50.0.0/24) via pfSense with Tailscale access
- **State Backend**: MinIO (S3-compatible)
- **Secrets**: SOPS with age encryption

## Requirements

- OpenTofu or Terraform installed
- SOPS with age encryption configured
- Proxmox VE server with API access
- MinIO or S3-compatible storage for state
- `kubectl` for Kubernetes management
- (Optional) `talosctl` for Talos-specific management
- (Optional) `direnv` for automatic environment loading
- **pfSense with Tailscale** for secure DMZ access (see Tailscale Setup below)

### Tailscale on pfSense Setup

**Setup steps:**

```bash
# 1. Install Tailscale package on pfSense
#    Navigate to: System → Package Manager → Available Packages
#    Search for "Tailscale" and click Install

# 2. Generate auth key in Tailscale admin console
#    Go to: https://login.tailscale.com/admin/settings/keys
#    Click "Generate auth key" (use default settings)
#    Copy the generated key

# 3. Configure Tailscale on pfSense
#    VPN → Tailscale → Authentication
#    - Paste auth key in "Pre-authentication Key"
#    - Click Save
#    
#    VPN → Tailscale → Settings
#    - Check "Enable Tailscale"
#    - Click Save
#    
#    VPN → Tailscale → Settings → Routing
#    - Under "Advertised Routes", add your DMZ subnet (e.g., 10.50.0.0/24)
#    - Click Save

# 4. Approve pfSense in Tailscale admin console
#    Navigate to: https://login.tailscale.com/admin/machines
#    Find your pfSense device and click the three dots:
#    - Click "Approve"
#    - Click "Disable key expiry"
#    - Click "Edit route settings"
#    - Check the DMZ subnet under "Subnet routes"

# 5. Configure your laptop to accept routes
tailscale up --accept-routes

# 6. Test connectivity
ping <dmz-gateway-ip>      # Should reach pfSense on DMZ interface
```

**Optional: Split DNS for internal hostnames**
- In Tailscale admin: DNS → Nameservers → Add nameserver → Custom
- Enter pfSense's internal IP as nameserver
- Enable "Restrict to domain" and enter your internal domain (e.g., `home.lab`)
- Now you can access hosts by hostname: `k8s-cp1.home.lab`

## How-to

### 1. Clone and Setup

```bash
git clone <your-repo>
cd talos-tofu

# Copy and configure credentials
cp .envrc.s3creds.example .envrc.s3creds
# Edit .envrc.s3creds with your MinIO credentials

# create an age key and save it in .age/keys.txt
sudo apt install age
mkdir .age
age-keygen > .age/keys.txt
# The `.sops.yaml` file contains the age public key used for encryption. Update it with your public key

# Edit and encrypt your secrets 
vim secrets.sops.example.yaml
sops -i -e secrets.sops.example.yaml
mv secrets.sops.example.yaml secrets.sops.yaml

# Copy and configure terraform variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual values

# Allow direnv (if using)
direnv allow .
```

### 2. Configure Variables

Edit `terraform.tfvars` with your environment-specific values:

```hcl
# Proxmox
proxmox_api_endpoint = "https://<proxmox-ip>:8006"
node_name            = "proxmox"
vm_bridge            = "vmbr1"        # DMZ network bridge
disk_store           = "local-lvm"

# Network
cluster_name    = "homelab"
default_gateway = "<dmz-gateway-ip>"  # pfSense DMZ interface IP

# Scalability
controlplane_count = 1  # 1 or 3+ for HA
worker_count       = 1  # Scale as needed
```

**Note:** Variable definitions are in `variables.tf`, but your actual values go in `terraform.tfvars` (which is gitignored).

### 3. Deploy the Cluster

```bash
# Initialize
tofu init

# Review plan
tofu plan

# Deploy
tofu apply

# Save configs
tofu output -raw kubeconfig > .kubeconfig
tofu output -raw talosconfig > .talosconfig

direnv reload # The configuration path is set in .envrc
```

### 4. Verify Cluster

```bash
# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -A

# Cluster info
kubectl cluster-info
```

## IP Allocation

This setup uses static IPs with a specific allocation scheme:

| Resource | IP Offset | Example (10.50.0.0/24) |
|----------|-----------|------------------------|
| Gateway (pfSense) | .1 | 10.50.0.1 |
| Control Plane 1 | .2 | 10.50.0.2 (API endpoint) |
| Workers | .3+ | 10.50.0.3, 10.50.0.4, 10.50.0.5 |
| Additional CPs (HA) | .11+ | 10.50.0.11, 10.50.0.12, 10.50.0.13 |

**Note:** Update the subnet range in `variables.tf` to match your DMZ network configuration.

## Scaling the Cluster

### Add More Workers

```bash
# Update variable
tofu apply -var="worker_count=3"
```

### High Availability (3 Control Planes)

```bash
tofu apply -var="controlplane_count=3" -var="worker_count=3"
```

This creates (example with 10.50.0.0/24):
- Control Planes: `.2`, `.11`, `.12` (e.g., 10.50.0.2, 10.50.0.11, 10.50.0.12)
- Workers: `.3`, `.4`, `.5` (e.g., 10.50.0.3, 10.50.0.4, 10.50.0.5)

## Network Configuration

### Static IPs vs DHCP

**Current setup uses Static IPs (recommended for Kubernetes):**

**Advantages of Static IPs:**
- Kubernetes API endpoint never changes
- Talos API always reachable at known address
- No DNS dependency
- TLS certificates remain valid
- Easier troubleshooting

**Using DHCP (Alternative):**

If you prefer DHCP, you'll need:

1. **DHCP Reservations** in pfSense for each node (MAC → IP mapping)
2. **Update initialization block** in `controlplanes.tf` and `workers.tf`:

```hcl
initialization {
  datastore_id = var.disk_store
  ip_config {
    ipv4 {
      address = "dhcp"  # Instead of static IP
    }
  }
  dns {
    servers = [var.default_gateway]
  }
}
```

3. **Either:**
   - Use a **load balancer** in front of control planes, OR
   - Accept that the API endpoint IP might change on reboot

**Note:** Even with DHCP, **control plane nodes should have stable IPs** (via reservations) since the cluster endpoint is hardcoded during bootstrap.

## Security

### Secrets Management

- **SOPS**: Encrypts sensitive data in `secrets.sops.yaml`
- **Age encryption**: Keys stored in `.age/keys.txt` (not committed)
- **Environment variables**: S3 credentials in `.envrc.s3creds` (not committed)

### Network Isolation

- DMZ isolated from home network
- Access via **Tailscale on pfSense** (secure, encrypted VPN access)
- pfSense firewall rules enforce isolation

### Access Architecture

This setup uses **Tailscale directly on pfSense** for secure access:

```
Your Laptop
    ↓ (Tailscale VPN - encrypted tunnel)
pfSense (Tailscale endpoint)
    ↓ (Routes to DMZ subnet)
Talos Cluster (Control Planes + Workers)
```

**How it works:**
1. pfSense has Tailscale package installed
2. pfSense advertises DMZ subnet route to Tailscale network
3. Your laptop accepts routes from Tailscale
4. Traffic to DMZ IPs automatically routes through pfSense via Tailscale
5. pfSense firewall rules enforce security policies


### pfSense Firewall Rules (DMZ Interface)

Minimal rules needed for DMZ isolation:

1. **Block DMZ → Home**: Block `<dmz-subnet>` → `<home-subnet>` (prevent lateral movement)
2. **Allow DMZ Inter-node**: Allow `<dmz-subnet>` → `<dmz-subnet>` (cluster communication)
3. **Allow DMZ → Internet**: Allow `<dmz-subnet>` → any (updates, container images)

**Note:** Management access comes through Tailscale VPN, not direct network access.

## Project Structure

```
.
├── backend.tf          # MinIO/S3 state backend
├── cluster.tf          # Talos cluster configuration
├── controlplanes.tf    # Control plane VMs (scalable)
├── workers.tf          # Worker VMs (scalable)
├── files.tf            # Talos ISO download
├── main.tf             # Provider configuration
├── variables.tf        # All configurable variables
├── providers.tf        # Provider versions
├── secrets.sops.yaml   # Encrypted secrets (committed)
├── .envrc              # Environment setup (committed)
├── .envrc.s3creds      # S3 credentials (NOT committed)
└── .kubeconfig         # Generated kubeconfig (NOT committed)
```

## Maintenance

### Updating Talos Version

1. Update `version` in `files.tf`
2. Update installer image in `cluster.tf` (both CP and worker configs)
3. Run `tofu apply`

### Backup Considerations

- **State**: Backed up to MinIO automatically
- **ETCD**: Use Talos backup commands or Velero
- **Kubeconfig**: Regenerate with `tofu output`

### Destroying the Cluster

```bash
tofu destroy
```
> [!warning]
> This will permanently delete all VMs and cluster data.

## Troubleshooting

### VMs not booting

Check Proxmox console for boot messages. Ensure:
- ISO is downloaded correctly
- Network bridge `vmbr1` exists
- Static IPs don't conflict with DHCP

### Cluster health check timeout

Nodes may take 5-10 minutes to fully boot, especially with many system extensions. Wait and retry:

```bash
tofu apply
```

### Can't connect to cluster

Verify Tailscale routing:

```bash
# From laptop (ensure you've accepted routes)
tailscale status  # Check connection to pfSense

# Test DMZ connectivity
ping <dmz-gateway-ip>      # pfSense DMZ interface
ping <control-plane-ip>    # Control plane

# If routes aren't working
tailscale up --accept-routes
```

**Common issues:**
- Routes not approved in Tailscale admin console
- `--accept-routes` not enabled on laptop
- pfSense Tailscale service not running

### Access denied errors

Ensure:
- MinIO credentials in `.envrc.s3creds` are correct
- Proxmox API token has proper permissions
- Tailscale subnet routes are approved in admin console

## Resources

- [Talos Linux Documentation](https://www.talos.dev/)
- [Proxmox Provider](https://github.com/bpg/terraform-provider-proxmox)
- [Talos on Proxmox Guide](https://www.talos.dev/v1.11/talos-guides/install/proxmox/)
- [Talos Image Factory](https://factory.talos.dev/)
- [Tailscale on pfSense Guide](https://davidisaksson.dev/posts/tailscale-on-pfsense/)
- [Talos Cluster on Proxmox with Terraform](https://olav.ninja/talos-cluster-on-proxmox-with-terraform) - Original guide this setup is based on

## License

GPLv3

