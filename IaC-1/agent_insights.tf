resource "azurerm_application_insights" "app_insights" {
  name                = "agent-telemetry"
  location            = azurerm_resource_group.rg-thesis.location
  resource_group_name = azurerm_resource_group.rg-thesis.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log_workspace.id
}
