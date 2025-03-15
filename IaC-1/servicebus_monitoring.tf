resource "azurerm_monitor_diagnostic_setting" "servicebus_monitoring" {
  name                       = "servicebus-monitoring"
  target_resource_id         = azurerm_servicebus_namespace.sb-thesis.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_workspace.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }

}
