resource "kubernetes_deployment" "ic_agent" {
  metadata {
    name   = "ic-agent"
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
            name  = "INPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING"
            value = azurerm_storage_account.hdm-25-stg-input-storage-acc.primary_connection_string
          }
          env {
            name  = "INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME"
            value = azurerm_storage_container.input-container.name
          }
          env {
            name  = "INPUT_SERVICE_BUS_CONNECTION_STRING"
            value = azurerm_servicebus_queue_authorization_rule.input-queue-connection-string.primary_connection_string
          }
          env {
            name  = "INPUT_SERVICE_BUS_QUEUE_NAME"
            value = azurerm_servicebus_queue.input-queue.name
          }

          # Manuelle Konfigurationen
          env {
            name  = "COMPRESSION_PERCENTAGE"
            value = "80" # 80% Qualität (20% Kompression)
          }
          env {
            name  = "MAX_MESSAGE_COUNT"
            value = "5" # 5 Nachrichten pro Verarbeitung
          }

          # Output-Konfiguration (bereits vorhanden)
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
            messageCount = "5" # Scale when there are 5 or more messages
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

resource "kubernetes_manifest" "azure_servicebus_auth" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "azure-servicebus-auth"
      namespace = "default"
    }
    spec = {
      secretTargetRef = [
        {
          parameter = "connection"
          name      = "servicebus-connection-secret"
          key       = "connection-string"
        }
      ]
    }
  }

   depends_on = [helm_release.keda]
}

# Kubernetes Secret für die Service Bus Connection
resource "kubernetes_secret" "servicebus_connection_secret" {
  metadata {
    name      = "servicebus-connection-secret"
    namespace = "default"
  }

  data = {
    "connection-string" = azurerm_servicebus_queue_authorization_rule.input-queue-connection-string.primary_connection_string
  }
}