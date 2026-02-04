# Azure Data Lake Gen2 + Power BI - Terraform Deployment Guide

This guide walks you through deploying a complete Azure Data Lake Gen2 environment with Power BI integration using Terraform.

---

## Architecture Overview

```
Data Sources → Azure Data Lake Gen2 (Bronze/Silver/Gold) → Azure Synapse → Power BI
```

### Components Deployed

- **Azure Data Lake Storage Gen2** with medallion architecture (Bronze, Silver, Gold containers)
- **Azure Synapse Analytics** workspace with serverless SQL pool
- **Azure Data Factory** (optional) for data ingestion
- **Azure Key Vault** (optional) for secrets management
- **Security configurations** (RBAC, firewall rules)

---

## Prerequisites

### 1. Install Required Tools

```bash
# Install Terraform
brew install terraform  # macOS
# OR download from https://www.terraform.io/downloads

# Install Azure CLI
brew install azure-cli  # macOS
# OR download from https://docs.microsoft.com/cli/azure/install-azure-cli

# Verify installations
terraform --version
az --version
```

### 2. Authenticate to Azure

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify current subscription
az account show
```

### 3. Get Your Public IP (for Synapse firewall)

```bash
# Get your public IP address
curl -s https://ifconfig.me
```

---

## Step-by-Step Deployment

### Step 1: Clone/Download Terraform Files

Create a new directory and save these Terraform files:
- `main.tf` - Main infrastructure definitions
- `variables.tf` - Variable declarations
- `outputs.tf` - Output values
- `terraform.tfvars.example` - Example configuration

### Step 2: Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Important configurations to update:**

```hcl
# Unique names (must be globally unique)
storage_account_name = "stdatalakeyourorg"  # lowercase, no special chars
key_vault_name       = "kv-datalake-yourorg"

# Security
synapse_sql_admin_username = "sqladminuser"
synapse_sql_admin_password = "YourComplexPassword123!"
client_ip_address          = "YOUR_PUBLIC_IP"  # From Step 3 of prerequisites

# Location
location = "UK South"  # Choose your preferred region
```

### Step 3: Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 4: Review the Plan

```bash
# Preview what will be created
terraform plan
```

Review the output to see:
- Resources to be created
- Configuration values
- Any potential issues

### Step 5: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply

# Type 'yes' when prompted
```

This will create:
- 1 Resource Group
- 1 Storage Account (Data Lake Gen2)
- 3 Containers (bronze, silver, gold)
- 1 Synapse Workspace
- 2 Synapse Firewall Rules
- 1 Data Factory (optional)
- 1 Key Vault (optional)
- Role assignments for access

**Deployment time: 5-10 minutes**

### Step 6: Save Important Outputs

```bash
# View all outputs
terraform output

# Save specific values
terraform output -raw synapse_sql_endpoint > synapse_endpoint.txt
terraform output -raw storage_account_primary_dfs_endpoint > datalake_endpoint.txt
```

---

## Post-Deployment Configuration

### Step 7: Verify Storage Account

```bash
# List containers
az storage fs list \
  --account-name $(terraform output -raw storage_account_name) \
  --auth-mode login

# Create sample folder structure
az storage fs directory create \
  --name "sales" \
  --file-system bronze \
  --account-name $(terraform output -raw storage_account_name) \
  --auth-mode login
```

### Step 8: Configure Synapse SQL

```bash
# Get Synapse SQL endpoint
SYNAPSE_ENDPOINT=$(terraform output -raw synapse_sql_on_demand_endpoint)
echo $SYNAPSE_ENDPOINT
```

Connect using Azure Data Studio or SQL Server Management Studio:
- Server: `[synapse_sql_on_demand_endpoint]`
- Authentication: Azure Active Directory
- Database: master

Create external tables:

```sql
-- Create database
CREATE DATABASE PowerBIDB;
GO

USE PowerBIDB;
GO

-- Create external data source
CREATE EXTERNAL DATA SOURCE DataLakeSource
WITH (
    LOCATION = 'https://[storage_account_name].dfs.core.windows.net/gold',
    CREDENTIAL = [WorkspaceIdentity]
);
GO

-- Create external file format
CREATE EXTERNAL FILE FORMAT ParquetFormat
WITH (
    FORMAT_TYPE = PARQUET,
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
);
GO

-- Example: Create external table
CREATE EXTERNAL TABLE SalesData (
    OrderID INT,
    OrderDate DATE,
    CustomerID INT,
    Amount DECIMAL(10,2)
)
WITH (
    LOCATION = 'sales/*.parquet',
    DATA_SOURCE = DataLakeSource,
    FILE_FORMAT = ParquetFormat
);
GO
```

---

## Connecting Power BI

### Step 9: Connect Power BI Desktop to Synapse

1. **Open Power BI Desktop**

2. **Get Data → Azure → Azure Synapse Analytics (SQL)**

3. **Enter connection details:**
   ```
   Server: [synapse_sql_on_demand_endpoint]
   Database: PowerBIDB
   ```

4. **Choose DirectQuery or Import:**
   - **DirectQuery**: Live connection, always fresh data
   - **Import**: Cached data, faster performance

5. **Authenticate:**
   - Select "Microsoft account"
   - Sign in with your Azure credentials

6. **Select tables/views** and click Load

### Step 10: Create Power BI Report

1. Build visualizations using your data
2. Create relationships between tables
3. Add measures using DAX
4. Design dashboard layout

### Step 11: Publish to Power BI Service

```bash
# From Power BI Desktop:
# File → Publish → Publish to Power BI
# Choose workspace
```

### Step 12: Configure Scheduled Refresh (Import Mode Only)

1. Go to Power BI Service
2. Navigate to dataset settings
3. Configure data source credentials
4. Set refresh schedule (daily, hourly, etc.)

---

## Data Ingestion Setup

### Option A: Using Azure Data Factory

```bash
# Get Data Factory name
terraform output data_factory_name
```

1. Open Azure Portal → Data Factory
2. Launch Data Factory Studio
3. Create linked services:
   - Source: Your data source (SQL, API, etc.)
   - Sink: Data Lake Gen2 (already has permissions)
4. Create pipelines with copy activities
5. Schedule triggers

### Option B: Upload Sample Data

```bash
# Upload CSV file to bronze layer
az storage fs file upload \
  --source ./sample-data.csv \
  --path sales/sample-data.csv \
  --file-system bronze \
  --account-name $(terraform output -raw storage_account_name) \
  --auth-mode login
```

---

## Folder Structure Best Practices

Organize your data lake:

```
bronze/
├── sales/
│   ├── 2024/01/
│   ├── 2024/02/
├── customers/
└── products/

silver/
├── sales_cleaned/
├── customers_validated/
└── products_enriched/

gold/
├── sales_aggregated/
├── customer_insights/
└── product_performance/
```

Create folders:

```bash
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)

# Bronze layer folders
az storage fs directory create --name "sales" --file-system bronze --account-name $STORAGE_ACCOUNT --auth-mode login
az storage fs directory create --name "customers" --file-system bronze --account-name $STORAGE_ACCOUNT --auth-mode login
az storage fs directory create --name "products" --file-system bronze --account-name $STORAGE_ACCOUNT --auth-mode login

# Silver layer folders
az storage fs directory create --name "sales_cleaned" --file-system silver --account-name $STORAGE_ACCOUNT --auth-mode login
az storage fs directory create --name "customers_validated" --file-system silver --account-name $STORAGE_ACCOUNT --auth-mode login

# Gold layer folders
az storage fs directory create --name "sales_aggregated" --file-system gold --account-name $STORAGE_ACCOUNT --auth-mode login
az storage fs directory create --name "customer_insights" --file-system gold --account-name $STORAGE_ACCOUNT --auth-mode login
```

---

## Security Configuration

### Add Users/Groups

```bash
# Get storage account resource ID
STORAGE_ID=$(terraform output -raw storage_account_name)

# Grant read access to a user
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee "user@example.com" \
  --scope "/subscriptions/YOUR_SUB_ID/resourceGroups/rg-datalake-prod/providers/Microsoft.Storage/storageAccounts/$STORAGE_ID"

# Grant contributor access
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "user@example.com" \
  --scope "/subscriptions/YOUR_SUB_ID/resourceGroups/rg-datalake-prod/providers/Microsoft.Storage/storageAccounts/$STORAGE_ID"
```

### Configure ACLs (Access Control Lists)

```bash
# Set ACLs on specific folders
az storage fs access set \
  --acl "user:objectid:rwx" \
  --path "sales" \
  --file-system bronze \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login
```

---

## Monitoring and Maintenance

### View Terraform State

```bash
# List all resources
terraform state list

# Show specific resource
terraform show
```

### Update Infrastructure

```bash
# Modify terraform.tfvars or *.tf files
# Then apply changes
terraform plan
terraform apply
```

### Destroy Infrastructure

```bash
# Remove all resources (CAUTION: Deletes everything!)
terraform destroy
```

---

## Troubleshooting

### Issue: "Storage account name already taken"
**Solution:** Change `storage_account_name` in `terraform.tfvars` to a unique value

### Issue: "Cannot access Synapse workspace"
**Solution:** Add your IP to `client_ip_address` in `terraform.tfvars` and run `terraform apply`

### Issue: "Power BI cannot connect"
**Solution:** Verify firewall rules allow Power BI service IPs:

```bash
az synapse workspace firewall-rule create \
  --name AllowPowerBI \
  --workspace-name $(terraform output -raw synapse_workspace_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### Issue: "Synapse has no access to storage"
**Solution:** Role assignment may have failed. Manually grant:

```bash
# Get Synapse managed identity
SYNAPSE_ID=$(az synapse workspace show \
  --name $(terraform output -raw synapse_workspace_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query identity.principalId -o tsv)

# Grant access
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $SYNAPSE_ID \
  --scope $(az storage account show --name $(terraform output -raw storage_account_name) --query id -o tsv)
```

---

## Cost Estimation

**Monthly costs (East US region):**

| Resource | Configuration | Estimated Cost |
|----------|--------------|----------------|
| Storage Account | 1 TB Standard LRS | $20-25 |
| Synapse Serverless SQL | 1 TB data scanned | $5 per TB |
| Data Factory | 10 pipelines/day | $2-5 |
| Key Vault | 1000 operations | $0.03 |
| **Total** | | **$30-40/month** |

*Note: Costs scale with actual usage*

---

## Next Steps

1. **Set up CI/CD** - Version control your Terraform code
2. **Enable monitoring** - Configure Azure Monitor and alerts
3. **Implement data transformation** - Use Databricks or Synapse Spark
4. **Create data quality checks** - Validate data in each layer
5. **Document data catalog** - Use Azure Purview
6. **Implement backup strategy** - Enable soft delete and versioning

---

## Additional Resources

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Data Lake Gen2 Docs](https://docs.microsoft.com/azure/storage/blobs/data-lake-storage-introduction)
- [Azure Synapse Analytics Docs](https://docs.microsoft.com/azure/synapse-analytics/)
- [Power BI Documentation](https://docs.microsoft.com/power-bi/)
