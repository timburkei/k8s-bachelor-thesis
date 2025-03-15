resource "azurerm_log_analytics_workspace" "log_workspace" {
  name                = "log-workspace-thesis"
  location            = azurerm_resource_group.rg-thesis.location
  resource_group_name = azurerm_resource_group.rg-thesis.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# resource "azurerm_monitor_action_group" "email_notification" {
#   name                = "email-alerts"
#   resource_group_name = azurerm_resource_group.rg-thesis.name
#   short_name          = "EmailAlerts"

#   email_receiver {
#     name          = "admin_email"
#     email_address = "tb169@hdm-stuttgart.de"
#   }
# }
