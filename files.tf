locals {
  talos = {
    version = "v1.11.2"    schematic_id = "6dc34cdf0c3e4d831503770479378c845d2ce131540075527bddf1261747e023"
  }
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.node_name

  file_name = "talos-${local.talos.version}-minimal-amd64.iso"
  url       = "https://factory.talos.dev/image/${local.talos.schematic_id}/${local.talos.version}/nocloud-amd64.iso"
  overwrite = false
}
