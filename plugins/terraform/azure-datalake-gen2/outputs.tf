# Outputs for Azure Data Lake Gen2 Infrastructure

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.datalake_rg.name
}

output "storage_account_name" {
  description = "Name of the Data Lake Storage account"
  value       = azurerm_storage_account.datalake.name
}

output "storage_account_primary_dfs_endpoint" {
  description = "Primary DFS endpoint for Data Lake Gen2"
  value       = azurerm_storage_account.datalake.primary_dfs_endpoint
}

output "bronze_container_name" {
  description = "Bronze layer container name"
  value       = azurerm_storage_data_lake_gen2_filesystem.bronze.name
}

output "silver_container_name" {
  description = "Silver layer container name"
  value       = azurerm_storage_data_lake_gen2_filesystem.silver.name
}

output "gold_container_name" {
  description = "Gold layer container name"
  value       = azurerm_storage_data_lake_gen2_filesystem.gold.name
}

output "synapse_workspace_name" {
  description = "Name of the Synapse workspace"
  value       = azurerm_synapse_workspace.synapse.name
}

output "synapse_workspace_endpoint" {
  description = "Synapse workspace development endpoint"
  value       = azurerm_synapse_workspace.synapse.connectivity_endpoints.dev
}

output "synapse_sql_endpoint" {
  description = "Synapse SQL serverless endpoint"
  value       = azurerm_synapse_workspace.synapse.connectivity_endpoints.sql
}

output "synapse_sql_on_demand_endpoint" {
  description = "Synapse SQL on-demand endpoint"
  value       = azurerm_synapse_workspace.synapse.connectivity_endpoints.sqlOnDemand
}

output "data_factory_name" {
  description = "Name of the Data Factory (if created)"
  value       = var.create_data_factory ? azurerm_data_factory.adf[0].name : null
}

output "key_vault_name" {
  description = "Name of the Key Vault (if created)"
  value       = var.create_key_vault ? azurerm_key_vault.kv[0].name : null
}

output "powerbi_connection_string" {
  description = "Connection string for Power BI to Synapse SQL"
  value       = azurerm_synapse_workspace.synapse.connectivity_endpoints.sqlOnDemand
}
