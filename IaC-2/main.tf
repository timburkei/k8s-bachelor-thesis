terraform {
  required_providers {

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}



provider "kubernetes" {
  host                   = data.terraform_remote_state.infrastructure.outputs.kube_config["host"]
  client_certificate     = base64decode(data.terraform_remote_state.infrastructure.outputs.kube_config["client_certificate"])
  client_key             = base64decode(data.terraform_remote_state.infrastructure.outputs.kube_config["client_key"])
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infrastructure.outputs.kube_config["cluster_ca_certificate"])
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infrastructure.outputs.kube_config["host"]
    client_certificate     = base64decode(data.terraform_remote_state.infrastructure.outputs.kube_config["client_certificate"])
    client_key             = base64decode(data.terraform_remote_state.infrastructure.outputs.kube_config["client_key"])
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infrastructure.outputs.kube_config["cluster_ca_certificate"])
  }
}
