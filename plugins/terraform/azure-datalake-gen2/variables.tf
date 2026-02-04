# Variables for Azure Data Lake Gen2 Infrastructure

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-datalake-prod"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "uksouth"
}

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique, 3-24 lowercase alphanumeric characters)"
  type        = string
  default     = "stdatalakegen2prod"
}

variable "storage_account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage replication type (LRS, GRS, RAGRS, ZRS)"
  type        = string
  default     = "LRS"
}

variable "enable_private_access" {
  description = "Enable private access with firewall rules"
  type        = bool
  default     = false
}

variable "synapse_workspace_name" {
  description = "Name of the Synapse workspace"
  type        = string
  default     = "synapse-datalake-prod"
}

variable "synapse_sql_admin_username" {
  description = "SQL admin username for Synapse"
  type        = string
  default     = "sqladminuser"
  sensitive   = true
}

variable "synapse_sql_admin_password" {
  description = "SQL admin password for Synapse (must be complex)"
  type        = string
  sensitive   = true
}

variable "client_ip_address" {
  description = "Client IP address to allow through Synapse firewall (leave empty to skip)"
  type        = string
  default     = ""
}

variable "create_data_factory" {
  description = "Whether to create Azure Data Factory"
  type        = bool
  default     = true
}

variable "data_factory_name" {
  description = "Name of the Data Factory"
  type        = string
  default     = "adf-datalake-prod"
}

variable "create_key_vault" {
  description = "Whether to create Azure Key Vault"
  type        = bool
  default     = true
}

variable "key_vault_name" {
  description = "Name of the Key Vault (must be globally unique)"
  type        = string
  default     = "kv-datalake-prod"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "DataLake"
    ManagedBy   = "Terraform"
  }
}
