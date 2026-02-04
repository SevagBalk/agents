# Security Guide

Comprehensive security configuration for Azure Data Lake Gen2 environment.

---

## Security Layers

```
┌─────────────────────────────────────────┐
│ Network Security (Firewalls, VNets)    │
├─────────────────────────────────────────┤
│ Identity & Access (Azure AD, RBAC)     │
├─────────────────────────────────────────┤
│ Data Access (ACLs, Row-Level Security) │
├─────────────────────────────────────────┤
│ Encryption (At Rest, In Transit)       │
├─────────────────────────────────────────┤
│ Monitoring & Audit (Logs, Alerts)      │
└─────────────────────────────────────────┘
```

---

## 1. Network Security

### Firewall Configuration

#### Add IP to Storage Account

```bash
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
RG_NAME=$(terraform output -raw resource_group_name)

# Add specific IP
az storage account network-rule add \
  --resource-group $RG_NAME \
  --account-name $STORAGE_ACCOUNT \
  --ip-address "203.0.113.10"

# Add IP range (CIDR)
az storage account network-rule add \
  --resource-group $RG_NAME \
  --account-name $STORAGE_ACCOUNT \
  --ip-address "10.0.0.0/24"

# Allow Azure services
az storage account update \
  --resource-group $RG_NAME \
  --name $STORAGE_ACCOUNT \
  --bypass AzureServices
```

#### Add IP to Synapse Workspace

```bash
SYNAPSE_NAME=$(terraform output -raw synapse_workspace_name)

# Add firewall rule
az synapse workspace firewall-rule create \
  --name "AllowOfficeIP" \
  --workspace-name $SYNAPSE_NAME \
  --resource-group $RG_NAME \
  --start-ip-address "203.0.113.10" \
  --end-ip-address "203.0.113.10"

# Add IP range
az synapse workspace firewall-rule create \
  --name "AllowOfficeNetwork" \
  --workspace-name $SYNAPSE_NAME \
  --resource-group $RG_NAME \
  --start-ip-address "203.0.113.0" \
  --end-ip-address "203.0.113.255"
```

### Private Endpoints (Production)

```bash
# Create virtual network
az network vnet create \
  --resource-group $RG_NAME \
  --name vnet-datalake \
  --address-prefix 10.0.0.0/16 \
  --subnet-name subnet-private-endpoints \
  --subnet-prefix 10.0.1.0/24

# Create private endpoint for Storage
az network private-endpoint create \
  --resource-group $RG_NAME \
  --name pe-storage-datalake \
  --vnet-name vnet-datalake \
  --subnet subnet-private-endpoints \
  --private-connection-resource-id $(az storage account show --name $STORAGE_ACCOUNT --query id -o tsv) \
  --group-id dfs \
  --connection-name storage-connection

# Create private endpoint for Synapse
az network private-endpoint create \
  --resource-group $RG_NAME \
  --name pe-synapse-sql \
  --vnet-name vnet-datalake \
  --subnet subnet-private-endpoints \
  --private-connection-resource-id $(az synapse workspace show --name $SYNAPSE_NAME --resource-group $RG_NAME --query id -o tsv) \
  --group-id Sql \
  --connection-name synapse-sql-connection
```

---

## 2. Identity and Access Management

### Azure AD Groups Setup

```bash
# Create security groups
az ad group create \
  --display-name "DataLake-Readers" \
  --mail-nickname "datalake-readers"

az ad group create \
  --display-name "DataLake-Contributors" \
  --mail-nickname "datalake-contributors"

az ad group create \
  --display-name "DataLake-Admins" \
  --mail-nickname "datalake-admins"

# Get group IDs
READERS_GROUP_ID=$(az ad group show --group "DataLake-Readers" --query id -o tsv)
CONTRIBUTORS_GROUP_ID=$(az ad group show --group "DataLake-Contributors" --query id -o tsv)
ADMINS_GROUP_ID=$(az ad group show --group "DataLake-Admins" --query id -o tsv)
```

### RBAC Role Assignments

#### Storage Account Roles

```bash
STORAGE_ID=$(az storage account show --name $STORAGE_ACCOUNT --query id -o tsv)

# Readers - Read only access
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee $READERS_GROUP_ID \
  --scope $STORAGE_ID

# Contributors - Read and write access
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $CONTRIBUTORS_GROUP_ID \
  --scope $STORAGE_ID

# Admins - Full control
az role assignment create \
  --role "Storage Blob Data Owner" \
  --assignee $ADMINS_GROUP_ID \
  --scope $STORAGE_ID
```

#### Synapse Workspace Roles

```bash
SYNAPSE_ID=$(az synapse workspace show --name $SYNAPSE_NAME --resource-group $RG_NAME --query id -o tsv)

# SQL Users
az role assignment create \
  --role "Synapse SQL User" \
  --assignee $READERS_GROUP_ID \
  --scope $SYNAPSE_ID

# Synapse Contributors
az role assignment create \
  --role "Synapse Contributor" \
  --assignee $CONTRIBUTORS_GROUP_ID \
  --scope $SYNAPSE_ID

# Synapse Admins
az role assignment create \
  --role "Synapse Administrator" \
  --assignee $ADMINS_GROUP_ID \
  --scope $SYNAPSE_ID
```

### Common RBAC Roles

| Role | Permissions | Use Case |
|------|-------------|----------|
| **Storage Blob Data Reader** | Read blobs | BI tools, read-only users |
| **Storage Blob Data Contributor** | Read, write, delete blobs | Data engineers, pipelines |
| **Storage Blob Data Owner** | Full control + ACLs | Administrators |
| **Synapse SQL User** | Connect and query | Power BI users, analysts |
| **Synapse Contributor** | Manage resources | Data engineers |
| **Synapse Administrator** | Full control | Platform administrators |

---

## 3. Access Control Lists (ACLs)

### Understanding ACLs

ACLs provide file-level security on top of RBAC:

```
RBAC: Subscription/Resource level
  ↓
ACL: Container/Folder/File level
```

### Set ACLs on Containers

```bash
# Get user or group object ID
USER_ID=$(az ad user show --id user@example.com --query id -o tsv)

# Read access on bronze container
az storage fs access set \
  --acl "user:${USER_ID}:r-x" \
  --file-system bronze \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login

# Write access on silver container
az storage fs access set \
  --acl "user:${USER_ID}:rwx" \
  --file-system silver \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login
```

### Set ACLs on Folders

```bash
# Read-only access to sales folder
az storage fs access set \
  --acl "user:${USER_ID}:r-x" \
  --path "sales" \
  --file-system gold \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login

# Recursive ACL for all files in folder
az storage fs access update-recursive \
  --acl "user:${USER_ID}:r-x" \
  --path "sales" \
  --file-system gold \
  --account-name $STORAGE_ACCOUNT \
  --auth-mode login
```

### ACL Permission Matrix

| Permission | Symbol | Meaning |
|------------|--------|---------|
| **Read** | r-- | Read file contents, list directory |
| **Write** | -w- | Write to file, create files in directory |
| **Execute** | --x | Execute file, access directory |
| **Read + Execute** | r-x | Read and navigate (common for folders) |
| **Full Control** | rwx | All permissions |

### Recommended ACL Structure

```
bronze/ (Raw data)
├── sales/          → Contributors: rwx, Readers: r-x
├── customers/      → Contributors: rwx, Readers: ---
└── sensitive/      → Admins only: rwx

silver/ (Cleaned data)
├── sales_cleaned/  → Contributors: rwx, Readers: r-x
└── customers_pii/  → Admins only: rwx, Specific users: r-x

gold/ (Business data)
├── sales_agg/      → Everyone: r-x
└── executive/      → Executives: r-x, Others: ---
```

---

## 4. Encryption

### Data at Rest

**Enabled by default:**
- Storage Account: Microsoft-managed keys (AES-256)
- Synapse: Transparent Data Encryption (TDE)

#### Use Customer-Managed Keys

```bash
# Create Key Vault (if not exists)
az keyvault create \
  --name kv-datalake-encryption \
  --resource-group $RG_NAME \
  --location uksouth \
  --enable-soft-delete true \
  --enable-purge-protection true

# Create encryption key
az keyvault key create \
  --vault-name kv-datalake-encryption \
  --name storage-encryption-key \
  --kty RSA \
  --size 2048

# Get key URL
KEY_URL=$(az keyvault key show \
  --vault-name kv-datalake-encryption \
  --name storage-encryption-key \
  --query key.kid -o tsv)

# Update storage account to use customer key
az storage account update \
  --name $STORAGE_ACCOUNT \
  --resource-group $RG_NAME \
  --encryption-key-source Microsoft.Keyvault \
  --encryption-key-vault $KEY_URL
```

### Data in Transit

**Enforced by default:**
- HTTPS only connections
- TLS 1.2 minimum

```bash
# Verify HTTPS enforcement
az storage account show \
  --name $STORAGE_ACCOUNT \
  --query "enableHttpsTrafficOnly"

# Enable if not set
az storage account update \
  --name $STORAGE_ACCOUNT \
  --resource-group $RG_NAME \
  --https-only true \
  --min-tls-version TLS1_2
```

---

## 5. Row-Level Security (RLS)

### Synapse SQL RLS

```sql
-- Create security predicate function
CREATE FUNCTION dbo.fn_SecurityPredicate(@Region AS VARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_SecurityPredicate_result
    WHERE
        @Region = USER_NAME()
        OR IS_MEMBER('db_owner') = 1;
GO

-- Create security policy
CREATE SECURITY POLICY RegionSecurityPolicy
ADD FILTER PREDICATE dbo.fn_SecurityPredicate(Region)
ON dbo.SalesData
WITH (STATE = ON);
GO

-- Test as different user
EXECUTE AS USER = 'EastRegionUser';
SELECT * FROM SalesData;  -- Only sees East region data
REVERT;
```

### Power BI RLS

```dax
-- In Power BI Desktop, create role
-- Modeling → Manage roles → Create role "RegionFilter"

-- Add table filter for SalesData table:
[Region] = USERNAME()

-- Or for email-based filtering:
[SalesPersonEmail] = USERPRINCIPALNAME()

-- Dynamic filtering by security table
VAR UserEmail = USERPRINCIPALNAME()
VAR UserRegions =
    CALCULATETABLE(
        VALUES(SecurityTable[Region]),
        SecurityTable[UserEmail] = UserEmail
    )
RETURN
    [Region] IN UserRegions
```

---

## 6. Service Principal (Automation)

### Create Service Principal

```bash
# Create service principal for Data Factory
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "sp-datalake-automation" \
  --role "Storage Blob Data Contributor" \
  --scopes $STORAGE_ID \
  --sdk-auth)

# Extract credentials
echo $SP_OUTPUT | jq -r '.clientId'       # Application ID
echo $SP_OUTPUT | jq -r '.clientSecret'   # Secret
echo $SP_OUTPUT | jq -r '.tenantId'       # Tenant ID

# Save to Key Vault
az keyvault secret set \
  --vault-name $(terraform output -raw key_vault_name) \
  --name "sp-datalake-clientid" \
  --value "$(echo $SP_OUTPUT | jq -r '.clientId')"

az keyvault secret set \
  --vault-name $(terraform output -raw key_vault_name) \
  --name "sp-datalake-secret" \
  --value "$(echo $SP_OUTPUT | jq -r '.clientSecret')"
```

### Grant Permissions

```bash
# Get service principal object ID
SP_OBJECT_ID=$(az ad sp show --id $(echo $SP_OUTPUT | jq -r '.clientId') --query id -o tsv)

# Grant Storage access
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $SP_OBJECT_ID \
  --scope $STORAGE_ID

# Grant Synapse access
az role assignment create \
  --role "Synapse Contributor" \
  --assignee $SP_OBJECT_ID \
  --scope $SYNAPSE_ID
```

---

## 7. Key Vault Integration

### Store Secrets

```bash
KV_NAME=$(terraform output -raw key_vault_name)

# Store connection strings
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "storage-connection-string" \
  --value "$(az storage account show-connection-string --name $STORAGE_ACCOUNT -o tsv)"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name "synapse-sql-password" \
  --value "YourSynapsePassword"

# Store API keys
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "external-api-key" \
  --value "your-api-key-here"
```

### Access Secrets from Applications

```python
# Python example
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(
    vault_url=f"https://{kv_name}.vault.azure.net",
    credential=credential
)

# Retrieve secret
connection_string = client.get_secret("storage-connection-string").value
```

```bash
# Azure CLI
az keyvault secret show \
  --vault-name $KV_NAME \
  --name "storage-connection-string" \
  --query "value" -o tsv
```

---

## 8. Monitoring and Auditing

### Enable Diagnostic Logs

#### Storage Account Logging

```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group $RG_NAME \
  --workspace-name la-datalake-logs

WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RG_NAME \
  --workspace-name la-datalake-logs \
  --query id -o tsv)

# Enable diagnostics for storage
az monitor diagnostic-settings create \
  --name "storage-diagnostics" \
  --resource $(az storage account show --name $STORAGE_ACCOUNT --query id -o tsv) \
  --workspace $WORKSPACE_ID \
  --logs '[{"category":"StorageRead","enabled":true},{"category":"StorageWrite","enabled":true},{"category":"StorageDelete","enabled":true}]' \
  --metrics '[{"category":"Transaction","enabled":true}]'
```

#### Synapse Logging

```bash
# Enable Synapse diagnostics
az monitor diagnostic-settings create \
  --name "synapse-diagnostics" \
  --resource $SYNAPSE_ID \
  --workspace $WORKSPACE_ID \
  --logs '[{"category":"SQLSecurityAuditEvents","enabled":true},{"category":"BuiltinSqlReqsEnded","enabled":true}]'
```

### Query Audit Logs

```kusto
// Log Analytics query for unauthorized access attempts
AzureDiagnostics
| where ResourceType == "STORAGEACCOUNTS"
| where StatusCode >= 400
| project TimeGenerated, CallerIpAddress, OperationName, StatusCode, StatusText
| order by TimeGenerated desc

// Query for Synapse SQL audit events
AzureDiagnostics
| where ResourceType == "SYNAPSE/WORKSPACES"
| where Category == "SQLSecurityAuditEvents"
| where action_name_s contains "FAILED"
| project TimeGenerated, client_ip_s, server_principal_name_s, statement_s
```

### Create Security Alerts

```bash
# Alert for failed authentication
az monitor metrics alert create \
  --name "high-failed-auth" \
  --resource-group $RG_NAME \
  --scopes $STORAGE_ID \
  --condition "count AuthenticationError > 10" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action-group alert-admins
```

---

## 9. Security Checklist

### Initial Setup
- [ ] Network firewall rules configured
- [ ] Azure AD groups created
- [ ] RBAC roles assigned
- [ ] ACLs set on sensitive folders
- [ ] Service principals created
- [ ] Secrets stored in Key Vault
- [ ] Diagnostic logging enabled
- [ ] Security alerts configured

### Production Hardening
- [ ] Private endpoints enabled
- [ ] Customer-managed encryption keys
- [ ] TLS 1.2 minimum enforced
- [ ] Shared key access disabled
- [ ] Azure Defender enabled
- [ ] Regular access reviews scheduled
- [ ] Data classification implemented
- [ ] Backup and disaster recovery tested

### Compliance
- [ ] Data residency requirements met
- [ ] Audit logs retained per policy
- [ ] PII data masked/encrypted
- [ ] Access audit trail maintained
- [ ] Security documentation updated
- [ ] Compliance certifications verified

---

## 10. Security Best Practices

### Principle of Least Privilege

```bash
# Don't do this (too permissive)
az role assignment create \
  --role "Owner" \
  --assignee user@example.com \
  --scope $STORAGE_ID

# Do this instead (specific role)
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee user@example.com \
  --scope "${STORAGE_ID}/blobServices/default/containers/gold"
```

### Separation of Duties

```
Data Engineers → silver/ (read+write)
Data Analysts → gold/ (read-only)
Administrators → all/ (owner)
```

### Regular Access Reviews

```bash
# List all role assignments
az role assignment list \
  --scope $STORAGE_ID \
  --output table

# Find stale assignments
az role assignment list \
  --all \
  --query "[?principalName=='former-employee@example.com']"
```

### Rotate Credentials

```bash
# Rotate service principal secret
az ad sp credential reset \
  --id $SP_OBJECT_ID \
  --append  # Keeps old secret valid during rotation

# Update in Key Vault
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "sp-datalake-secret" \
  --value "NEW_SECRET_VALUE"
```

---

## Emergency Procedures

### Revoke Access Immediately

```bash
# Remove user access
az role assignment delete \
  --assignee user@example.com \
  --scope $STORAGE_ID

# Block IP at firewall
az storage account network-rule remove \
  --account-name $STORAGE_ACCOUNT \
  --ip-address "203.0.113.10"
```

### Audit After Security Incident

```kusto
// Find all operations by specific user in time range
AzureDiagnostics
| where TimeGenerated between (datetime(2024-02-01) .. datetime(2024-02-04))
| where identity_claim_http_schemas_xmlsoap_org_ws_2005_05_identity_claims_upn_s == "user@example.com"
| project TimeGenerated, OperationName, ResourceId, StatusCode
| order by TimeGenerated desc
```

---

## Next Steps

1. ✅ Security configured
2. → [Review best practices](BEST-PRACTICES.md)
3. → [Troubleshooting guide](TROUBLESHOOTING.md)
