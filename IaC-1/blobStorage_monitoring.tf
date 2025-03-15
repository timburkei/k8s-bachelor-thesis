resource "azurerm_monitor_diagnostic_setting" "blob_storage_monitoring" {
  name                       = "blob-monitoring"
  target_resource_id         = azurerm_storage_account.hdm-25-stg-input-storage-acc.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_workspace.id
  metric {
    category = "Transaction"
    enabled  = true
  }
}
