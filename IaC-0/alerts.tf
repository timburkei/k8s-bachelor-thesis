# resource "azurerm_monitor_metric_alert" "high_cpu_alert" {
#   name                = "high-cpu-alert"
#   resource_group_name = azurerm_resource_group.rg-thesis.name
#   scopes              = [azurerm_kubernetes_cluster.aks_cluster_thesis_hdm_25.id]
#   description         = "Warnung bei hoher CPU-Last in Kubernetes"

#   criteria {
#     metric_namespace = "Insights.Metrics"
#     metric_name      = "CPUPercentage"
#     aggregation      = "Average"
#     operator         = "GreaterThan"
#     threshold        = 80
#   }

#   severity    = 2
#   frequency   = "PT5M"
#   window_size = "PT15M"

#   action {
#     action_group_id = azurerm_monitor_action_group.email_notification.id
#   }
# }

# resource "azurerm_monitor_metric_alert" "queue_depth_alert" {
#   name                = "queue-depth-alert"
#   resource_group_name = azurerm_resource_group.rg-thesis.name
#   scopes              = [azurerm_servicebus_namespace.sb-thesis.id]
#   description         = "Warnung bei zu vielen wartenden Nachrichten"

#   criteria {
#     metric_namespace = "Microsoft.ServiceBus/namespaces"
#     metric_name      = "ActiveMessages"
#     aggregation      = "Average"
#     operator         = "GreaterThan"
#     threshold        = 500
#   }

#   severity    = 2
#   frequency   = "PT5M"
#   window_size = "PT15M"

#   action {
#     action_group_id = azurerm_monitor_action_group.email_notification.id
#   }
# }
