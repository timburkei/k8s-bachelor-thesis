resource "kubernetes_deployment" "co_agent" {
  metadata {
    name = "co-agent"
    labels = { app = "co-agent" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "co-agent" } }

    template {
      metadata { labels = { app = "co-agent" } }
      spec {
        container {
          image = "ghcr.io/timburkei/co-agent:latest"
          name  = "co-agent"

          env {
            name  = "OUTPUT_SERVICE_BUS_CONNECTION_STRING"
            value = azurerm_servicebus_queue_authorization_rule.output-queue-connection-string.primary_connection_string
          }
          env {
            name  = "OUTPUT_SERVICE_BUS_QUEUE_NAME"
            value = azurerm_servicebus_queue.output-queue.name
          }
          env {
            name  = "AZURE_LOAD_TESTING_API_URL"
            value = var.azure_load_testing_api_url
          }
          env {
            name  = "MAX_MESSAGE_COUNT"
            value = "1"
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "co_agent_scaledobject" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "co-agent-scaler"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        name = kubernetes_deployment.co_agent.metadata[0].name
      }
      minReplicaCount = 1
      maxReplicaCount = 10
      triggers = [
        {
          type = "azure-servicebus"
          metadata = {
            queueName    = azurerm_servicebus_queue.output-queue.name
            messageCount = "5"  # Scale when there are 5 or more messages
          }
          authenticationRef = {
            name = "azure-servicebus-output-auth"
          }
        }
      ]
    }
  }
  depends_on = [helm_release.keda]
}

resource "kubernetes_secret" "azure_servicebus_output_auth" {
  metadata {
    name      = "azure-servicebus-output-auth"
    namespace = "default"
  }

  data = {
    connectionString = azurerm_servicebus_queue_authorization_rule.output-queue-connection-string.primary_connection_string
  }
}