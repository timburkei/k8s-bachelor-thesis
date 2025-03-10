resource "azurerm_kubernetes_cluster" "aks_cluster_thesis_hdm_25" {
  name                = "thesis-aks-cluster-hdm-25"
  location            = azurerm_resource_group.rg-thesis.location
  resource_group_name = azurerm_resource_group.rg-thesis.name
  dns_prefix          = "thesisaks"

  default_node_pool {
    name = "default"
    # node_count = 1
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id

    auto_scaling_enabled = true
    min_count            = 1
    max_count            = 2
  }

  aci_connector_linux {
    subnet_name = azurerm_subnet.aci_subnet.name
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
}
