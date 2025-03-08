terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.21.1"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.17.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscrition_id
}

/*
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)
  }
}*/

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "az"
    args        = [
      "aks", "get-credentials",
      "--resource-group", azurerm_kubernetes_cluster.aks_cluster.resource_group_name,
      "--name", azurerm_kubernetes_cluster.aks_cluster.name,
      "--admin",
      "--file", "-"
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "az"
      args        = [
        "aks", "get-credentials",
        "--resource-group", azurerm_kubernetes_cluster.aks_cluster.resource_group_name,
        "--name", azurerm_kubernetes_cluster.aks_cluster.name,
        "--admin",
        "--file", "-"
      ]
    }
  }
}

resource "azurerm_resource_group" "rg-thesis" {
  name     = "thesis-25-hdm-stuttgart"
  location = "westeurope"
}
