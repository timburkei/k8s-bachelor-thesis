resource "azurerm_servicebus_namespace" "sb-thesis" {
  name                = "thesis-25-hdm-stuttgart-service-bus"
  resource_group_name = azurerm_resource_group.rg-thesis.name
  location            = azurerm_resource_group.rg-thesis.location
  sku                 = "Basic"

  tags = {
    source = "terrafom"
  }
}

resource "azurerm_servicebus_queue" "input-queue" {
  name               = "input-queue"
  namespace_id       = azurerm_servicebus_namespace.sb-thesis.id
  lock_duration      = "PT30S"
  max_delivery_count = 5
}

resource "azurerm_servicebus_queue_authorization_rule" "input-queue-connection-string" {
  name     = "input-queue-connection-string"
  queue_id = azurerm_servicebus_queue.input-queue.id

  listen = true
  send   = true
  manage = true
}

resource "azurerm_servicebus_queue" "output-queue" {
  name               = "output-queue"
  namespace_id       = azurerm_servicebus_namespace.sb-thesis.id
  lock_duration      = "PT30S"
  max_delivery_count = 5
}

resource "azurerm_servicebus_queue_authorization_rule" "output-queue-connection-string" {
  name     = "output-queue-connection-string"
  queue_id = azurerm_servicebus_queue.output-queue.id

  listen = true
  send   = true
  manage = true
}
