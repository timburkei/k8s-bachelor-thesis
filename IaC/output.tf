output "input_azure_blob_storage_connection_string" {
  description = "INPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING="
  value       = azurerm_storage_account.hdm-25-stg-input-storage-acc.primary_connection_string
  sensitive   = true 
}

output "input_azure_blob-storage_container_name" {
  description = "INPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME="
  value       = azurerm_storage_container.input-container.name
}

output "input_service_bus_connectin_string" {
  description = "INPUT_AZURE_SERVICE_BUS_CONNECTION_STRING="
  value       = azurerm_servicebus_queue_authorization_rule.input-queue-connection-string.primary_connection_string
  sensitive   = true
}

output "input_service_bus_queue_name" {
  description = "INPUT_AZURE_SERVICE_BUS_QUEUE_NAME="
  value       = azurerm_servicebus_queue.input-queue.name
}

output "output_azure_blob_storage_connection_string" {
  description = "OUTPUT_AZURE_BLOB_STORAGE_CONNECTION_STRING="
  value       = azurerm_storage_account.hdm-25-output-storage-acc.primary_connection_string
  sensitive   = true 
}

output "output_azure_blob_storage_container_name" {
  description = "OUTPUT_AZURE_BLOB_STORAGE_CONTAINER_NAME="
  value       = azurerm_storage_container.output-container.name
}

output "output_service_bus_connectin_string" {
  description = "OUTPUT_AZURE_SERVICE_BUS_CONNECTION_STRING="
  value       = azurerm_servicebus_queue_authorization_rule.output-queue-connection-string.primary_connection_string
  sensitive   = true
}

output "output_service_bus_queue_name" {
  description = "OUTPUT_AZURE_SERVICE_BUS_QUEUE_NAME="
  value       = azurerm_servicebus_queue.output-queue.name
}