resource "kubernetes_deployment" "ci_agent" {
  metadata {
    name = "ci-agent"
  }

  spec {
    replicas = 2
    selector {
      match_labels = { app = "ci-agent" }
    }

    template {
      metadata {
        labels = { app = "ci-agent" }
      }

      spec {
        container {
          image = "ghcr.io/timburkei/ci-agent:latest"
          name  = "ci-agent"

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
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "ci_agent_hpa" {
  metadata {
    name = "ci-agent-hpa"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.ci_agent.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type               = "Utilization"
          average_utilization = 50
        }
      }
    }
  }
}

resource "kubernetes_service" "ci_agent_service" {
  metadata {
    name = "ci-agent-service"
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "false"  # External facing load balancer
      "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/health"  # Health probe path
      "service.beta.kubernetes.io/azure-dns-label-name" = "ci-agent-hdm-25"  # DNS label for the public IP
      "service.beta.kubernetes.io/azure-load-balancer-resource-group" = azurerm_resource_group.rg-thesis.name
    }
  }

  spec {
    selector = {
      app = "ci-agent"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 5001
      protocol    = "TCP"
    }

    type = "LoadBalancer"

    # Session affinity - if needed
    # session_affinity = "ClientIP"
  }
}

resource "kubernetes_secret" "azure_servicebus_auth" {
  metadata {
    name      = "azure-servicebus-auth"
    namespace = "default"
  }

  data = {
    connectionString = azurerm_servicebus_queue_authorization_rule.input-queue-connection-string.primary_connection_string
  }
}