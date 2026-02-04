# Deployment Guide

Complete step-by-step deployment instructions for Azure Data Lake Gen2 infrastructure.

---

## Prerequisites

### Required Software

```bash
# Terraform (v1.0+)
terraform --version

# Azure CLI (v2.30+)
az --version

# Make (optional)
make --version
```

### Azure Requirements

- Active Azure subscription
- Contributor or Owner role on subscription
- Sufficient quota for resources

---

## Pre-Deployment Checklist

- [ ] Azure CLI installed and configured
- [ ] Terraform installed
- [ ] Azure subscription selected
- [ ] Public IP address identified (for Synapse firewall)
- [ ] Unique names planned (storage account, key vault)
- [ ] SQL admin password generated (complex, 12+ characters)
- [ ] Region selected (check data residency requirements)

---

## Step 1: Azure Authentication

```bash
# Login to Azure
az login

# List available subscriptions
az account list --output table

# Set your subscription
az account set --subscription "SUBSCRIPTION_ID_OR_NAME"

# Verify current subscription
az account show --output table
```

---

## Step 2: Get Your Public IP

```bash
# Get your public IP address (needed for Synapse firewall)
curl -s https://ifconfig.me

# Save it for later
export MY_PUBLIC_IP=$(curl -s https://ifconfig.me)
echo "My IP: $MY_PUBLIC_IP"
```

---

## Step 3: Configure Variables

### Option A: Copy and Edit tfvars

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
# or
code terraform.tfvars
```

### Option B: Use Environment Variables

```bash
export TF_VAR_storage_account_name="stdatalakeyourorg"
export TF_VAR_synapse_sql_admin_password="YourComplexP@ssw0rd!"
export TF_VAR_client_ip_address="$MY_PUBLIC_IP"
```

### Critical Variables to Set

| Variable | Example | Notes |
|----------|---------|-------|
| `storage_account_name` | `stdatalake2024` | Must be globally unique, lowercase, 3-24 chars |
| `synapse_sql_admin_password` | `P@ssw0rd123!` | 12+ chars, complex |
| `client_ip_address` | `203.0.113.10` | Your public IP for Synapse access |
| `key_vault_name` | `kv-dl-yourorg` | Must be globally unique |
| `location` | `UK South` | Choose nearest region |

---

## Step 4: Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init
```

**Expected Output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.0"...
- Installing hashicorp/azurerm v3.x.x...

Terraform has been successfully initialized!
```

**If you see errors:**
- Check internet connection
- Verify Terraform is installed correctly
- Delete `.terraform/` and try again

---

## Step 5: Validate Configuration

```bash
# Validate Terraform syntax
terraform validate
```

**Expected Output:**
```
Success! The configuration is valid.
```

---

## Step 6: Review Deployment Plan

```bash
# Generate and review execution plan
terraform plan

# Save plan to file (optional)
terraform plan -out=tfplan
```

**What to check:**
- ✓ Correct number of resources (12+ resources)
- ✓ Resource names are correct
- ✓ Region is correct
- ✓ No unexpected deletions (should be all creates)

**Sample Output:**
```
Plan: 13 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + storage_account_name = "stdatalake2024"
  + synapse_workspace_name = "synapse-datalake-prod"
  ...
```

---

## Step 7: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply

# Or use saved plan
terraform apply tfplan
```

**Deployment Timeline:**
- Resource Group: ~10 seconds
- Storage Account: ~30 seconds
- Containers: ~10 seconds each
- Synapse Workspace: ~3-5 minutes
- Role Assignments: ~30 seconds
- **Total: 5-8 minutes**

**Expected Output:**
```
Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

Outputs:

storage_account_name = "stdatalake2024"
synapse_sql_endpoint = "synapse-datalake-prod.sql.azuresynapse.net"
...
```

---

## Step 8: Verify Deployment

### Check Azure Portal

```bash
# Open resource group in portal
az group show --name rg-datalake-prod --output table
```

Or visit: https://portal.azure.com

### Verify Resources

```bash
# List all resources in the group
az resource list \
  --resource-group rg-datalake-prod \
  --output table

# Check storage account
az storage account show \
  --name $(terraform output -raw storage_account_name) \
  --output table

# Check Synapse workspace
az synapse workspace show \
  --name $(terraform output -raw synapse_workspace_name) \
  --resource-group rg-datalake-prod \
  --output table
```

---

## Step 9: Save Important Outputs

```bash
# View all outputs
terraform output

# Save to files
terraform output -raw storage_account_name > storage_name.txt
terraform output -raw synapse_sql_on_demand_endpoint > synapse_endpoint.txt
terraform output -raw storage_account_primary_dfs_endpoint > datalake_url.txt

# Display connection info
echo "=== Connection Information ==="
echo "Storage Account: $(terraform output -raw storage_account_name)"
echo "Synapse Endpoint: $(terraform output -raw synapse_sql_on_demand_endpoint)"
echo "Data Lake URL: $(terraform output -raw storage_account_primary_dfs_endpoint)"
```

---

## Step 10: Test Connectivity

### Test Storage Account

```bash
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)

# List containers
az storage fs list \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login

# Create test directory
az storage fs directory create \
  --name "test" \
  --file-system bronze \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login
```

### Test Synapse Workspace

```bash
# Get Synapse endpoint
SYNAPSE_ENDPOINT=$(terraform output -raw synapse_sql_on_demand_endpoint)

# Test connection (requires sqlcmd or Azure Data Studio)
echo "Connect to: $SYNAPSE_ENDPOINT"
```

---

## Post-Deployment Tasks

### 1. Create Folder Structure

```bash
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)

# Bronze layer
az storage fs directory create --name "sales" --file-system bronze --account-name $STORAGE_ACCOUNT --auth-mode login
az storage fs directory create --name "customers" --file-system bronze --account-name $STORAGE_ACCOUNT --auth-mode login
az storage fs directory create --name "products" --file-system bronze --account-name $STORAGE_ACCOUNT --auth-mode login

# Silver layer
az storage fs directory create --name "sales_cleaned" --file-system silver --account-name $STORAGE_ACCOUNT --auth-mode login
az storage fs directory create --name "customers_validated" --file-system silver --account-name $STORAGE_ACCOUNT --auth-mode login

# Gold layer
az storage fs directory create --name "sales_aggregated" --file-system gold --account-name $STORAGE_ACCOUNT --auth-mode login
az storage fs directory create --name "customer_insights" --file-system gold --account-name $STORAGE_ACCOUNT --auth-mode login
```

### 2. Configure Synapse SQL

See [POWERBI-INTEGRATION.md](POWERBI-INTEGRATION.md) for creating external tables.

### 3. Set Up Security

See [SECURITY.md](SECURITY.md) for user access configuration.

---

## Deployment Validation Checklist

After deployment, verify:

- [ ] Resource group exists in Azure Portal
- [ ] Storage account has hierarchical namespace enabled
- [ ] Three containers exist (bronze, silver, gold)
- [ ] Synapse workspace is accessible
- [ ] Firewall rules include your IP
- [ ] Role assignments are configured
- [ ] Data Factory exists (if enabled)
- [ ] Key Vault exists (if enabled)
- [ ] `terraform output` shows all endpoints
- [ ] Can list containers via Azure CLI
- [ ] Can connect to Synapse from Azure Data Studio

---

## Common Deployment Issues

### Issue: Storage account name not available

**Error:**
```
Error: creating Storage Account: storage.AccountsClient#Create:
The storage account named 'stdatalake' is already taken.
```

**Solution:**
Change `storage_account_name` in `terraform.tfvars` to a unique value:
```hcl
storage_account_name = "stdatalakeyourorg2024"
```

### Issue: Insufficient permissions

**Error:**
```
Error: authorization.RoleAssignmentsClient#Create:
Principal does not have authorization to create role assignment
```

**Solution:**
- Ensure you have `Owner` or `User Access Administrator` role
- Or have your subscription admin run the deployment

### Issue: SQL password too simple

**Error:**
```
Error: Invalid password. Password does not meet complexity requirements.
```

**Solution:**
Update password to include:
- At least 12 characters
- Uppercase and lowercase letters
- Numbers
- Special characters

### Issue: Region quota exceeded

**Error:**
```
Error: creating Synapse Workspace: QuotaExceeded
```

**Solution:**
- Choose a different region in `terraform.tfvars`
- Or request quota increase in Azure Portal

---

## Updating the Deployment

To modify the infrastructure:

```bash
# 1. Edit variables
nano terraform.tfvars

# 2. Review changes
terraform plan

# 3. Apply updates
terraform apply
```

**Common updates:**
- Adding firewall rules (update `client_ip_address`)
- Changing replication type
- Adding tags
- Enabling/disabling optional components

---

## Destroying the Infrastructure

**⚠️ WARNING: This permanently deletes all data!**

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Type 'yes' to confirm
```

**Alternative: Selective destruction**
```bash
# Remove only Data Factory
terraform destroy -target=azurerm_data_factory.adf[0]
```

---

## Backup and State Management

### Backup Terraform State

```bash
# Copy state file to backup location
cp terraform.tfstate terraform.tfstate.backup

# Or use remote backend (recommended for production)
```

### Remote State Configuration

For team environments, use Azure Storage backend:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "datalake.terraform.tfstate"
  }
}
```

---

## Next Steps

1. ✅ Deployment complete
2. → [Configure Power BI connection](POWERBI-INTEGRATION.md)
3. → [Set up security and access](SECURITY.md)
4. → [Review best practices](BEST-PRACTICES.md)
5. → [Troubleshooting guide](TROUBLESHOOTING.md)
