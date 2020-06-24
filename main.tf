provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  location = var.region
  name     = "rg${var.name}"
}

resource "azurerm_role_assignment" "rg_self" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_account" "sa" {
  name                      = "sa${var.name}"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = var.region
  account_replication_type  = "LRS"
  account_tier              = "Standard"
  is_hns_enabled            = true
  enable_https_traffic_only = true
}

resource "azurerm_storage_data_lake_gen2_filesystem" "adls" {
  storage_account_id = azurerm_storage_account.sa.id
  name               = "spark"
}

resource "azurerm_user_assigned_identity" "spark" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  name                = "spark"
}

resource "azurerm_role_assignment" "sa_self" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "sa_owner" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.owner_object_id
}

resource "azurerm_role_assignment" "sa_spark" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.spark.principal_id
}

resource "azurerm_key_vault" "kv" {
  name                = "kv${var.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_key_vault_access_policy" "self" {
  key_vault_id            = azurerm_key_vault.kv.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = data.azurerm_client_config.current.object_id
  secret_permissions      = local.kv_all_secret_permissions
  storage_permissions     = local.kv_all_storage_permissions
  key_permissions         = local.kv_all_key_permissions
  certificate_permissions = local.kv_all_cert_permissions
}

resource "azurerm_key_vault_access_policy" "owner" {
  key_vault_id            = azurerm_key_vault.kv.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = var.owner_object_id
  secret_permissions      = local.kv_all_secret_permissions
  storage_permissions     = local.kv_all_storage_permissions
  key_permissions         = local.kv_all_key_permissions
  certificate_permissions = local.kv_all_cert_permissions
}

resource "random_password" "spark_password" {
  length = 32
}

resource "random_pet" "spark_username" {}

resource "azurerm_key_vault_secret" "spark_username" {
  key_vault_id = azurerm_key_vault.kv.id
  name         = "spark-username"
  value        = random_pet.spark_username.id
}

resource "azurerm_key_vault_secret" "spark_password" {
  key_vault_id = azurerm_key_vault.kv.id
  name         = "spark-password"
  value        = random_password.spark_password.result
}

resource "azurerm_hdinsight_spark_cluster" "spark" {
  depends_on          = [azurerm_role_assignment.sa_spark]
  name                = "spark${var.name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  cluster_version     = "4.0"
  tier                = "Standard"

  component_version {
    spark = "2.4"
  }

  storage_account_gen2 {
    is_default                   = true
    filesystem_id                = azurerm_storage_data_lake_gen2_filesystem.adls.id
    storage_resource_id          = azurerm_storage_account.sa.id
    managed_identity_resource_id = azurerm_user_assigned_identity.spark.id
  }

  gateway {
    enabled  = true
    username = random_pet.spark_username.id
    password = random_password.spark_password.result
  }

  roles {
    head_node {
      username = random_pet.spark_username.id
      password = random_password.spark_password.result
      vm_size  = "Standard_D12_v2"
    }

    worker_node {
      username              = random_pet.spark_username.id
      password              = random_password.spark_password.result
      vm_size               = "Standard_D12_v2"
      target_instance_count = 1
    }

    zookeeper_node {
      username = random_pet.spark_username.id
      password = random_password.spark_password.result
      vm_size  = "Standard_A2_v2"
    }
  }
}
