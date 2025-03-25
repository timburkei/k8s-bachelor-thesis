

# resource "azurerm_portal_dashboard" "monitor_dashboard" {
#   name                = "aks-monitor-dashboard"
#   resource_group_name = azurerm_resource_group.rg-thesis.name
#   location            = azurerm_resource_group.rg-thesis.location

#   tags = {
#     environment = "thesis-monitoring"
#   }

#   dashboard_properties = jsonencode({
#     "$schema" = "https://portal.azure.com/experience/dashboard/json-schema"
#     "name"    = "aks-monitor-dashboard"
#     "version" = "1.0"
#     "lenses"  = {
#       "0" = {
#         "order" = 0,
#         "parts" = {
#           "0" = {
#             "position" = {
#               "x"       = 0,
#               "y"       = 0,
#               "colSpan" = 6,
#               "rowSpan" = 4
#             },
#             "metadata" = {
#               "type"  = "Microsoft.Azure.Monitor.Chart"
#               "name"  = "CI-Agent Container Count"
#               "inputs" = [
#                 {
#                   "name"  = "resourceType"
#                   "value" = "microsoft.operationalinsights/workspaces"
#                 },
#                 {
#                   "name"  = "resourceId"
#                   "value" = azurerm_log_analytics_workspace.log_workspace.id
#                 },
#                 {
#                   "name"  = "query"
#                   "value" = "KubePodInventory | where ClusterName == '${azurerm_kubernetes_cluster.aks_cluster_thesis_hdm_25.name}' | where ContainerName contains 'ci-agent' | summarize Count = count() by bin(TimeGenerated, 1m)"
#                 }
#               ],
#               "itemId" = "ci-agent-metric",
#               "asset" = {
#                 "type" = "Microsoft.Azure.Monitor.Chart"
#               }
#             }
#           },
#           "1" = {
#             "position" = {
#               "x"       = 6,
#               "y"       = 0,
#               "colSpan" = 6,
#               "rowSpan" = 4
#             },
#             "metadata" = {
#               "type"  = "Microsoft.Azure.Monitor.Chart"
#               "name"  = "IC-Agent Container Count"
#               "inputs" = [
#                 {
#                   "name"  = "resourceType"
#                   "value" = "microsoft.operationalinsights/workspaces"
#                 },
#                 {
#                   "name"  = "resourceId"
#                   "value" = azurerm_log_analytics_workspace.log_workspace.id
#                 },
#                 {
#                   "name"  = "query"
#                   "value" = "KubePodInventory | where ClusterName == '${azurerm_kubernetes_cluster.aks_cluster_thesis_hdm_25.name}' | where ContainerName contains 'ic-agent' | summarize Count = count() by bin(TimeGenerated, 1m)"
#                 }
#               ],
#               "itemId" = "ic-agent-metric",
#               "asset" = {
#                 "type" = "Microsoft.Azure.Monitor.Chart"
#               }
#             }
#           }
#         }
#       }
#     }
#   })
# }

# resource "azurerm_log_analytics_solution" "aks_monitoring" {
#   solution_name         = "ContainerInsights"
#   location             = azurerm_resource_group.rg-thesis.location
#   resource_group_name  = azurerm_resource_group.rg-thesis.name
#   workspace_resource_id = azurerm_log_analytics_workspace.log_workspace.id
#   workspace_name       = azurerm_log_analytics_workspace.log_workspace.name
#   plan {
#     publisher = "Microsoft"
#     product   = "OMSGallery/ContainerInsights"
#   }
# }

# resource "azurerm_portal_dashboard" "monitor_dashboard" {
#   name                = "aks-monitor-dashboard"
#   resource_group_name = azurerm_resource_group.rg-thesis.name
#   location            = azurerm_resource_group.rg-thesis.location

#   tags = {
#     environment = "thesis-monitoring"
#   }

#   dashboard_properties = jsonencode({
#     "$schema" = "https://portal.azure.com/experience/dashboard/json-schema"
#     "name"    = "aks-monitor-dashboard"
#     "version" = "1.0"
#     "lenses"  = {
#       "0" = {
#         "order" = 0,
#         "parts" = {
#           "0" = {
#             "position" = {
#               "x"       = 0,
#               "y"       = 0,
#               "colSpan" = 12,
#               "rowSpan" = 4
#             },
#             "metadata" = {
#               "type"  = "Microsoft.Portal/Widgets/Markdown"
#               "inputs" = [
#                 {
#                   "name"  = "content"
#                   "value" = "### Test Markdown Widget \n\n Dies ist ein einfaches Test-Widget, um zu prüfen, ob das Dashboard korrekt funktioniert."
#                 }
#               ],
#               "itemId" = "test-markdown-widget",
#               "asset" = {
#                 "type" = "Microsoft.Portal/Widgets/Markdown"
#               }
#             }
#           }
#         }
#       }
#     }
#   })
# }
