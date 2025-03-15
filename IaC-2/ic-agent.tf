resource "kubernetes_deployment" "ic_agent" {
  metadata {
    name   = "ic-agent"
    labels = { app = "ic-agent" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "ic-agent" }
    }

    template {
      metadata {
        labels = { app = "ic-agent" }
      }

      spec {
        toleration {
          key      = "virtual-kubelet.io/provider"
          operator = "Equal"
          value    = "azure"
          effect   = "NoSchedule"
        }

        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              preference {
                match_expressions {
                  key      = "kubernetes.io/role"
                  operator = "NotIn"
                  values   = ["virtual-kubelet"]
                }
              }
            }
          }
        }



        container {
          image = "ghcr.io/timburkei/ic-agent:latest"
          name  = "ic-agent"

          env {
            name  = "INPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING"
            value = data.terraform_remote_state.infrastructure.outputs.input_azure_blob_storage_connection_string
          }
          env {
            name  = "INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME"
            value = data.terraform_remote_state.infrastructure.outputs["input_azure_blob-storage_container_name"]
          }
          env {
            name  = "INPUT_SERVICE_BUS_CONNECTION_STRING"
            value = data.terraform_remote_state.infrastructure.outputs.input_service_bus_connectin_string
          }
          env {
            name  = "INPUT_SERVICE_BUS_QUEUE_NAME"
            value = data.terraform_remote_state.infrastructure.outputs.input_service_bus_queue_name
          }
          env {
            name  = "COMPRESSION_PERCENTAGE"
            value = "50"
          }
          env {
            name  = "MAX_MESSAGE_COUNT"
            value = "3"
          }
          env {
            name  = "OUTPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING"
            value = data.terraform_remote_state.infrastructure.outputs.output_azure_blob_storage_connection_string
          }
          env {
            name  = "OUTPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME"
            value = data.terraform_remote_state.infrastructure.outputs.output_azure_blob_storage_container_name
          }
          # env {
          #   name  = "OUTPUT_SERVICE_BUS_CONNECTION_STRING"
          #   value = data.terraform_remote_state.infrastructure.outputs.output_service_bus_connectin_string
          # }
          # env {
          #   name  = "OUTPUT_SERVICE_BUS_QUEUE_NAME"
          #   value = data.terraform_remote_state.infrastructure.outputs.output_service_bus_queue_name
          # }
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
            queueName    = data.terraform_remote_state.infrastructure.outputs.input_service_bus_queue_name
            messageCount = "15"
          }
          authenticationRef = {
            name = "azure-servicebus-auth"
          }
        }
      ]
    }
  }
  depends_on = [null_resource.wait_for_keda_crds, kubernetes_secret.servicebus_connection_secret]
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
  depends_on = [null_resource.wait_for_keda_crds, kubernetes_secret.servicebus_connection_secret]
}

resource "kubernetes_secret" "servicebus_connection_secret" {
  metadata {
    name      = "servicebus-connection-secret"
    namespace = "default"
  }
  data = {
    "connection-string" = data.terraform_remote_state.infrastructure.outputs.input_service_bus_connectin_string
  }
}
