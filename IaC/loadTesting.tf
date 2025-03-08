resource "azurerm_load_test" "load_test" {
  name                = "loadTestService"
  resource_group_name = azurerm_resource_group.rg-thesis.name
  location            = azurerm_resource_group.rg-thesis.location
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_load_test_test" "test" {
  name                 = "image-compression-test"
  load_test_id         = azurerm_load_test.load_test.id
  display_name         = "Load Test for Image Compression"
  description          = "Simulating concurrent image compression and storage retrieval"
  engine_instances     = 5

  test_plan {
    content_type = "application/json"
    content      = jsonencode({
      "variables" = {
        "uniqueId" = {
          "type" = "random",
          "format" = "uuid"  # Generiert für jeden Request eine eindeutige UUID
        },
        "imageName" = {
          "type" = "static",
          "value" = "test-image.jpg"  # Der Name der hochgeladenen Datei
        }
      },
      "configurations" = {
        "target_lb" = azurerm_lb.load_balancer.frontend_ip_configuration[0].public_ip_address,
        "target_blob" = "https://${azurerm_storage_account.storage_account.name}.blob.core.windows.net/${azurerm_storage_container.image_container.name}"
      },
      "load_profile" = {
        "type" = "staged",
        "stages" = [
          { "type": "ramp", "start_users": 1, "end_users": 25, "duration": "2m" },  # Hochfahren in 2 Min
          { "type": "constant", "users": 25, "duration": "5m" },                     # 5 Minuten konstante Last
          { "type": "ramp", "start_users": 25, "end_users": 0, "duration": "2m" }   # Runterfahren in 2 Min
        ]
      },
      "test_cases" = [
        {
          "name" = "upload-image-test",
          "request_type" = "POST",
          "endpoint" = "/upload",
          "base_url" = "$target_lb",
          "headers" = {
            "Content-Type" = "application/json" 
          },
          "body" = jsonencode({
            "image" = "data:image/jpeg;base64,${file("./image_data.txt")}",
            "load_testing_id" = "${uniqueId}"
          }),
          "concurrency" = 1
        },
        {
          "name" = "check-image-exists-test",
          "request_type" = "HEAD",  # HEAD-Request, um nur zu prüfen, ob das Bild existiert
          "base_url" = "$target_blob",
          "endpoint" = "/${uniqueId}",
        #   "headers" = {
        #     "x-ms-version" = "2020-08-04"  # Optional: API-Version von Azure Blob Storage
        #   },
          "concurrency" = 1
          "retry" = {
            "max_retries" = 3,   # Bis zu 3 Wiederholungen
            "delay" = "10s",     # 10 Sekunden Wartezeit zwischen den Wiederholungen
           # "retry_on" = [500, 503, 504]  # Nur bei bestimmten Fehlercodes erneut senden
          }
        }
      ]
    })
  }
}


# Erfolgs-Endpunkt nach der Verarbeitung
resource "azurerm_load_test_metric" "success_metric" {
  load_test_id     = azurerm_load_test.load_test.id
  name             = "image-processing-success"
  metric_namespace = "Azure Load Testing"
  metric_name      = "successful_requests"
}


## uuid als namen nehmen und auch als namen belassen im anderen file.
## co-agent herausnehmen
## 