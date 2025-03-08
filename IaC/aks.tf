resource "azurerm_kubernetes_cluster" "aks_cluster_thesis_hdm_25" {
  name                = "thesis-aks-cluster-hdm-25"
  location            = azurerm_resource_group.rg-thesis.location
  resource_group_name = azurerm_resource_group.rg-thesis.name
  dns_prefix          = "thesisaks"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
  }

  aci_connector_linux {
    subnet_name = azurerm_subnet.aci_subnet.name
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = "keda"
}





resource "helm_release" "ic_agent_scaledobject" {
  name       = "ic-agent-scaledobject"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = "keda"
  values     = [file("ic-agent-keda-values.yaml")]
}



# resource "helm_release" "co_agent_scaledobject" {
#   name       = "co-agent-scaledobject"
#   repository = "https://kedacore.github.io/charts"
#   chart      = "keda"
#   namespace  = "keda"
#   set {
#     name  = "scaledObjects[0].triggers[0].type"
#     value = "azure-servicebus"
#   }
#   set {
#     name  = "scaledObjects[0].triggers[0].metadata.queueName"
#     value = azurerm_servicebus_queue.output-queue.name
#   }
#   set {
#     name  = "scaledObjects[0].triggers[0].connection"
#     value = azurerm_servicebus_queue_authorization_rule.output-queue-connection-string.primary_connection_string
#   }
# }

# resource "kubernetes_service" "ci_agent_service" {
#   metadata {
#     name = "ci-agent-service"
#   }

#   spec {
#     selector = {
#       app = "ci-agent"
#     }

#     port {
#       port        = 80
#       target_port = 5001 
#     }

#     type = "LoadBalancer"
#   }
# }