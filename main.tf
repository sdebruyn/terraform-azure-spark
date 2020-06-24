provider "azurerm" {
  features {}
}

locals {
  name = "solution"
}

resource "azurerm_resource_group" "rg" {
  location = "eastus2"
  name     = "rg${local.name}"
}
