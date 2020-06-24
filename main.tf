provider "azurerm" {
  features {}
}

locals {
  solution = "tfhdi"
}

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
