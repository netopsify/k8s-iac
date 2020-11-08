# References
# https://learn.hashicorp.com/tutorials/terraform/kubernetes-provider
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {
  config_path = "../../kubernetes-setup/admin.conf" // path to kubeconfig
}
