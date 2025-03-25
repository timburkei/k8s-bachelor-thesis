resource "kubernetes_deployment" "ci_agent" {
  metadata {
    name   = "ci-agent"
    labels = { app = "ci-agent" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "ci-agent" }
    }

    template {
      metadata {
        labels = { app = "ci-agent" }
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
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "node-type"
                  operator = "In"
                  values   = ["aks-vm"]
                }
              }
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/hostname"
                  operator = "In"
                  values   = ["virtual-node-aci-linux"]
                }
              }
            }
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "node-type"
                  operator = "In"
                  values   = ["aks-vm"]
                }
              }
            }
          }
        }


        container {
          image = "ghcr.io/timburkei/ci-agent:latest"
          name  = "ci-agent"

          resources {
            requests = {
              cpu    = "500m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          env {
            name  = "AZURE_BLOB_STORAGE_CONNECTION_STRING"
            value = data.terraform_remote_state.infrastructure.outputs.azure_blob_storage_connection_string
          }
          env {
            name = "INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME"
            value = data.terraform_remote_state.infrastructure.outputs.input_azure_blob_storage_container_name
          }
          env {
            name  = "INPUT_SERVICE_BUS_CONNECTION_STRING"
            value = data.terraform_remote_state.infrastructure.outputs.input_service_bus_connection_string
          }
          env {
            name  = "INPUT_SERVICE_BUS_QUEUE_NAME"
            value = data.terraform_remote_state.infrastructure.outputs.input_service_bus_queue_name
          }
        }
      }
    }
  }
}

# resource "helm_release" "metrics_server" {
#   name       = "metrics-server"
#   repository = "https://kubernetes-sigs.github.io/metrics-server/"
#   chart      = "metrics-server"
#   namespace  = "kube-system"

#   set {
#     name  = "args[0]"
#     value = "--kubelet-insecure-tls"
#   }
# }

resource "kubernetes_service" "ci_agent_service" {
  metadata {
    name = "ci-agent-service"
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/health"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.ci_agent.metadata[0].labels.app
    }

    port {
      name        = "http"
      port        = 80
      target_port = 5001
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "ci_agent_hpa" {
  metadata {
    name = "ci-agent-hpa"
  }

  spec {
    max_replicas                      = 10
    min_replicas                      = 1
    target_cpu_utilization_percentage = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.ci_agent.metadata[0].name
    }
  }
}




