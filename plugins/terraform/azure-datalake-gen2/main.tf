# Azure Data Lake Gen2 + Power BI Infrastructure
# Provider Configuration
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "datalake_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# Storage Account with Data Lake Gen2
resource "azurerm_storage_account" "datalake" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.datalake_rg.name
  location                 = azurerm_resource_group.datalake_rg.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"
  is_hns_enabled           = true # This enables Data Lake Gen2

  network_rules {
    default_action = var.enable_private_access ? "Deny" : "Allow"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

# Containers for Medallion Architecture
resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  name               = "bronze"
  storage_account_id = azurerm_storage_account.datalake.id

  properties = {
    description = "Bronze layer - Raw ingested data"
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "silver" {
  name               = "silver"
  storage_account_id = azurerm_storage_account.datalake.id

  properties = {
    description = "Silver layer - Cleaned and validated data"
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "gold" {
  name               = "gold"
  storage_account_id = azurerm_storage_account.datalake.id

  properties = {
    description = "Gold layer - Business-ready aggregated data"
  }
}

# Azure Synapse Workspace
resource "azurerm_synapse_workspace" "synapse" {
  name                                 = var.synapse_workspace_name
  resource_group_name                  = azurerm_resource_group.datalake_rg.name
  location                             = azurerm_resource_group.datalake_rg.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.gold.id
  sql_administrator_login              = var.synapse_sql_admin_username
  sql_administrator_login_password     = var.synapse_sql_admin_password

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Synapse Firewall Rule - Allow Azure Services
resource "azurerm_synapse_firewall_rule" "allow_azure_services" {
  name                 = "AllowAllWindowsAzureIps"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"
}

# Synapse Firewall Rule - Allow Client IP
resource "azurerm_synapse_firewall_rule" "allow_client_ip" {
  count                = var.client_ip_address != "" ? 1 : 0
  name                 = "AllowClientIP"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  start_ip_address     = var.client_ip_address
  end_ip_address       = var.client_ip_address
}

# Role Assignment - Give Synapse access to Data Lake
resource "azurerm_role_assignment" "synapse_storage_blob_contributor" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.synapse.identity[0].principal_id
}

# Azure Data Factory (optional)
resource "azurerm_data_factory" "adf" {
  count               = var.create_data_factory ? 1 : 0
  name                = var.data_factory_name
  resource_group_name = azurerm_resource_group.datalake_rg.name
  location            = azurerm_resource_group.datalake_rg.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Role Assignment - Give Data Factory access to Data Lake
resource "azurerm_role_assignment" "adf_storage_blob_contributor" {
  count                = var.create_data_factory ? 1 : 0
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.adf[0].identity[0].principal_id
}

# Key Vault for secrets (optional but recommended)
resource "azurerm_key_vault" "kv" {
  count                      = var.create_key_vault ? 1 : 0
  name                       = var.key_vault_name
  resource_group_name        = azurerm_resource_group.datalake_rg.name
  location                   = azurerm_resource_group.datalake_rg.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = var.tags
}

data "azurerm_client_config" "current" {}
