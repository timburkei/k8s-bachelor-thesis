resource "azurerm_monitor_diagnostic_setting" "aks_monitoring" {
  name                       = "aks-monitoring"
  target_resource_id         = azurerm_kubernetes_cluster.aks_cluster_thesis_hdm_25.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_workspace.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

