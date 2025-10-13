# File: backend.tf

terraform {
  backend "s3" {
    bucket                      = "tofu-state"
    key                         = "talos-cluster/terraform.tfstate"
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
    endpoints = {
      s3 = "http://192.168.1.35:9000"
    }
  }
}


