resource "kubernetes_deployment" "ic_agent" {
  metadata {
    name = "ic-agent"
    labels = { app = "ic-agent" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "ic-agent" } }

    template {
      metadata { labels = { app = "ic-agent" } }
      spec {
        container {
          image = "ghcr.io/timburkei/ic-agent:latest"
          name  = "ic-agent"

          env {
            name  = "OUTPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING"
            value = azurerm_storage_account.hdm-25-output-storage-acc.primary_connection_string
          }
          env {
            name  = "OUTPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME"
            value = azurerm_storage_container.output-container.name
          }
          env {
            name  = "OUTPUT_SERVICE_BUS_CONNECTION_STRING"
            value = azurerm_servicebus_queue_authorization_rule.output-queue-connection-string.primary_connection_string
          }
          env {
            name  = "OUTPUT_SERVICE_BUS_QUEUE_NAME"
            value = azurerm_servicebus_queue.output-queue.name
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "ic_agent_scaledobject" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "ic-agent-scaler"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        name = kubernetes_deployment.ic_agent.metadata[0].name
      }
      minReplicaCount = 1
      maxReplicaCount = 10
      triggers = [
        {
          type = "azure-servicebus"
          metadata = {
            queueName    = azurerm_servicebus_queue.input-queue.name
            messageCount = "5"  # Scale when there are 5 or more messages
          }
          authenticationRef = {
            name = "azure-servicebus-auth"
          }
        }
      ]
    }
  }
  depends_on = [helm_release.keda]
}

