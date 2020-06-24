provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  location = "eastus2"
  name     = "rg${local.solution}"
}

resource "azurerm_storage_account" "sa" {
  name                     = "sa${local.solution}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_replication_type = "LRS"
  account_tier             = "Standard"
}

resource "azurerm_key_vault" "kv" {
  name                = "kv${local.solution}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

# resource "azurerm_hdinsight_spark_cluster" "spark" {
#   name                = "spark${local.solution}"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   cluster_version     = "4.0"
#   tier                = "Standard"

#   component_version {
#     spark = "2.4"
#   }

#   gateway {
#     enabled = true

#   }
# }
