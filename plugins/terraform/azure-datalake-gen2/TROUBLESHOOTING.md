# Troubleshooting Guide

Common issues and solutions for Azure Data Lake Gen2 environment.

---

## Table of Contents

1. [Terraform Deployment Issues](#terraform-deployment-issues)
2. [Storage Account Issues](#storage-account-issues)
3. [Synapse Workspace Issues](#synapse-workspace-issues)
4. [Power BI Connection Issues](#power-bi-connection-issues)
5. [Authentication and Authorization](#authentication-and-authorization)
6. [Performance Issues](#performance-issues)
7. [Data Pipeline Issues](#data-pipeline-issues)
8. [Network and Connectivity](#network-and-connectivity)

---

## Terraform Deployment Issues

### Issue: Storage account name already taken

**Error:**
```
Error: creating Storage Account: storage.AccountsClient#Create:
The storage account named 'stdatalake' is already taken.
```

**Cause:** Storage account names must be globally unique

**Solution:**
```bash
# Choose a unique name
storage_account_name = "stdatalakeyourorg2024"
# Or append random suffix
storage_account_name = "stdatalake${random_string.suffix.result}"
```

---

### Issue: Terraform state locked

**Error:**
```
Error: Error acquiring the state lock
Lock Info:
  ID: xxxx-xxxx-xxxx
  Operation: OperationTypeApply
```

**Cause:** Another terraform operation is running or crashed

**Solution:**
```bash
# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>

# Better: Find and kill the process
ps aux | grep terraform
kill -9 <PID>

# Then retry
terraform apply
```

---

### Issue: Insufficient permissions

**Error:**
```
Error: authorization.RoleAssignmentsClient#Create:
Principal does not have authorization to create role assignment
```

**Cause:** Your account lacks Owner or User Access Administrator role

**Solution:**
```bash
# Check your current role
az role assignment list \
    --assignee $(az account show --query user.name -o tsv) \
    --scope /subscriptions/<SUBSCRIPTION_ID> \
    --output table

# Request Owner role from subscription admin
# Or use --skip-role-assignments flag in terraform
```

---

### Issue: Provider version conflict

**Error:**
```
Error: Failed to query available provider packages
```

**Solution:**
```bash
# Clear provider cache
rm -rf .terraform/
rm .terraform.lock.hcl

# Reinitialize
terraform init -upgrade
```

---

## Storage Account Issues

### Issue: Cannot access storage account

**Error:**
```
Status: 403 (This request is not authorized to perform this operation)
```

**Cause:** Missing RBAC permissions or firewall rules

**Solution:**
```bash
# Check firewall rules
az storage account show \
    --name $STORAGE_ACCOUNT \
    --query "networkRuleSet.ipRules"

# Add your IP
az storage account network-rule add \
    --account-name $STORAGE_ACCOUNT \
    --ip-address $(curl -s https://ifconfig.me)

# Check RBAC permissions
az role assignment list \
    --assignee $(az account show --query user.name -o tsv) \
    --scope $(az storage account show --name $STORAGE_ACCOUNT --query id -o tsv)

# Grant access
az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee $(az account show --query user.name -o tsv) \
    --scope $(az storage account show --name $STORAGE_ACCOUNT --query id -o tsv)
```

---

### Issue: Hierarchical namespace not enabled

**Error:**
```
The account does not have hierarchical namespace enabled
```

**Cause:** Storage account created without Gen2 enabled

**Solution:**
```bash
# Check if Gen2 is enabled
az storage account show \
    --name $STORAGE_ACCOUNT \
    --query "isHnsEnabled"

# Unfortunately, cannot enable on existing account
# Must create new storage account with HNS enabled
# Or update Terraform:
is_hns_enabled = true
```

---

### Issue: Cannot list containers

**Error:**
```
AuthorizationPermissionMismatch
This request is not authorized to perform this operation using this permission.
```

**Cause:** Using storage account key auth when AAD is required

**Solution:**
```bash
# Use --auth-mode login
az storage fs list \
    --account-name $STORAGE_ACCOUNT \
    --auth-mode login  # Force AAD auth

# Or set default
az config set storage_auth_mode=login
```

---

## Synapse Workspace Issues

### Issue: Cannot connect to Synapse

**Error:**
```
Cannot open server 'synapse-xxx' requested by the login.
Client with IP address 'x.x.x.x' is not allowed to access the server.
```

**Cause:** IP not in firewall whitelist

**Solution:**
```bash
# Get your public IP
MY_IP=$(curl -s https://ifconfig.me)
echo "My IP: $MY_IP"

# Add to Synapse firewall
az synapse workspace firewall-rule create \
    --name "MyClientIP" \
    --workspace-name $(terraform output -raw synapse_workspace_name) \
    --resource-group $(terraform output -raw resource_group_name) \
    --start-ip-address $MY_IP \
    --end-ip-address $MY_IP

# Wait 2-3 minutes for firewall update to propagate
```

---

### Issue: Synapse has no access to storage

**Error:**
```
External table 'xxx' is not accessible because location does not exist
or it is used by another process.
```

**Cause:** Synapse managed identity lacks storage permissions

**Solution:**
```bash
# Get Synapse managed identity
SYNAPSE_ID=$(az synapse workspace show \
    --name $(terraform output -raw synapse_workspace_name) \
    --resource-group $(terraform output -raw resource_group_name) \
    --query identity.principalId -o tsv)

# Grant Storage Blob Data Contributor
az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee $SYNAPSE_ID \
    --scope $(az storage account show --name $(terraform output -raw storage_account_name) --query id -o tsv)

# Wait 5-10 minutes for permission propagation
```

---

### Issue: External table query fails

**Error:**
```
Failed to execute query. Error: Generic ODBC error: External file access failed
```

**Cause:** Incorrect path, missing files, or permission issues

**Solution:**
```sql
-- Verify path exists
SELECT *
FROM OPENROWSET(
    BULK 'https://<storage>.dfs.core.windows.net/gold/',
    FORMAT = 'DELTA'  -- or PARQUET
) AS files;

-- Check specific file
SELECT *
FROM OPENROWSET(
    BULK 'https://<storage>.dfs.core.windows.net/gold/sales/*.parquet',
    FORMAT = 'PARQUET'
) AS data;

-- Common path issues:
-- Wrong: /gold/sales/      (missing container)
-- Wrong: gold/sales/       (missing https://)
-- Correct: https://<storage>.dfs.core.windows.net/gold/sales/
```

---

### Issue: Query runs slowly

**Symptoms:** Queries take minutes instead of seconds

**Solutions:**
```sql
-- 1. Check if scanning too much data
-- Enable query insights in Synapse Studio

-- 2. Add partition filters
SELECT * FROM sales
WHERE year = 2024 AND month = 1;  -- Much faster

-- 3. Use Parquet instead of CSV
-- CSV requires parsing entire file
-- Parquet reads only needed columns

-- 4. Create statistics
CREATE STATISTICS stat_date ON sales(order_date);

-- 5. Limit result set
SELECT TOP 1000 * FROM large_table;

-- 6. Use CETAS to materialize expensive queries
CREATE EXTERNAL TABLE AS SELECT
    customer_id,
    SUM(amount) AS total_revenue
FROM sales
GROUP BY customer_id;
```

---

## Power BI Connection Issues

### Issue: Cannot connect Power BI to Synapse

**Error:**
```
We couldn't connect to the server. Please try again later.
```

**Causes and Solutions:**

**1. Wrong endpoint format**
```
Wrong: synapse-workspace-name.sql.azuresynapse.net
Correct: synapse-workspace-name-ondemand.sql.azuresynapse.net
         └─ Note the "-ondemand" for serverless
```

**2. Firewall blocks Power BI**
```bash
# Allow Power BI service IPs
az synapse workspace firewall-rule create \
    --name "AllowPowerBI" \
    --workspace-name $SYNAPSE_NAME \
    --resource-group $RG_NAME \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0
```

**3. Wrong authentication**
```
Use: Microsoft account (Azure AD)
Not: Database credentials
```

---

### Issue: Power BI shows no tables

**Cause:** Database empty or no permissions

**Solution:**
```sql
-- Verify database has tables
USE PowerBIDB;
GO

SELECT * FROM INFORMATION_SCHEMA.TABLES;

-- If empty, create external tables
CREATE EXTERNAL TABLE sales_data (...)
WITH (
    LOCATION = 'sales/*.parquet',
    DATA_SOURCE = DataLakeGold,
    FILE_FORMAT = ParquetFormat
);

-- Grant permissions
GRANT SELECT ON sales_data TO [user@example.com];
```

---

### Issue: DirectQuery performance poor

**Symptoms:** Reports load slowly, visuals timeout

**Solutions:**

**1. Add filters to reduce data**
```dax
-- In Power BI, add page-level filter
[Date] >= DATE(2024, 1, 1)
```

**2. Create aggregated views in Synapse**
```sql
CREATE VIEW vw_sales_summary AS
SELECT
    CAST(order_date AS DATE) AS date,
    customer_id,
    SUM(amount) AS total_amount
FROM sales_data
GROUP BY CAST(order_date AS DATE), customer_id;
```

**3. Use Import mode for smaller datasets**
```
Power BI Desktop → Transform Data → Import
```

**4. Enable query folding**
```m
// In Power Query, verify "View Native Query" is available
// If not, simplify transformations
```

---

### Issue: Scheduled refresh fails

**Error:**
```
Data source error: Unable to refresh the data source credentials
```

**Solution:**
```
1. Go to Power BI Service
2. Dataset Settings
3. Data source credentials → Edit credentials
4. Select OAuth2
5. Sign in with Azure AD account
6. Test connection
7. Re-run refresh
```

---

## Authentication and Authorization

### Issue: Login fails with MFA

**Error:**
```
Interactive authentication is disabled. Use token/credential-based auth.
```

**Solution:**
```bash
# Use device code flow
az login --use-device-code

# Or service principal
az login --service-principal \
    --username $CLIENT_ID \
    --password $CLIENT_SECRET \
    --tenant $TENANT_ID
```

---

### Issue: Service principal cannot access storage

**Error:**
```
This request is not authorized to perform this operation using this permission.
```

**Solution:**
```bash
# Get service principal object ID
SP_OBJECT_ID=$(az ad sp show --id $CLIENT_ID --query id -o tsv)

# Grant access
az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee $SP_OBJECT_ID \
    --scope $(az storage account show --name $STORAGE_ACCOUNT --query id -o tsv)

# Verify
az role assignment list \
    --assignee $SP_OBJECT_ID \
    --output table
```

---

### Issue: User cannot see data in Power BI

**Cause:** Row-level security (RLS) is filtering all data

**Solution:**
```sql
-- Check RLS in Synapse
SELECT * FROM sys.security_policies;

-- Temporarily disable for testing
ALTER SECURITY POLICY RegionSecurityPolicy
WITH (STATE = OFF);

-- Test query
SELECT * FROM sales_data;

-- Re-enable
ALTER SECURITY POLICY RegionSecurityPolicy
WITH (STATE = ON);

-- Fix RLS logic or grant user access
```

---

## Performance Issues

### Issue: Small file problem

**Symptoms:**
- Thousands of small files (< 10 MB)
- Slow query performance
- High metadata overhead

**Solution:**
```python
# Compact files
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("compact").getOrCreate()

# Read small files
df = spark.read.parquet("gold/sales/year=2024/month=01/")

# Rewrite as fewer larger files
df.coalesce(10) \  # 10 output files
    .write \
    .mode("overwrite") \
    .parquet("gold/sales/year=2024/month=01/")
```

Or use Azure Data Factory:
```json
{
  "enablePartitionDiscovery": true,
  "maxConcurrentConnections": 10,
  "enableCompression": true
}
```

---

### Issue: Large file problem

**Symptoms:**
- Files > 1 GB
- Cannot open in tools
- Slow parallel processing

**Solution:**
```python
# Split large files
df = spark.read.parquet("gold/large_file.parquet")

# Repartition into optimal sizes
# Target: 128-256 MB per file
num_partitions = int(df.count() / 1000000)  # ~1M rows per file

df.repartition(num_partitions) \
    .write \
    .mode("overwrite") \
    .parquet("gold/sales_optimized/")
```

---

### Issue: Memory errors in Spark

**Error:**
```
java.lang.OutOfMemoryError: GC overhead limit exceeded
```

**Solutions:**

**1. Increase executor memory**
```python
spark = SparkSession.builder \
    .config("spark.executor.memory", "4g") \
    .config("spark.driver.memory", "4g") \
    .getOrCreate()
```

**2. Process in smaller batches**
```python
# Instead of loading all at once
dates = ["2024-01-01", "2024-01-02", "2024-01-03"]

for date in dates:
    df = spark.read.parquet(f"bronze/sales/date={date}")
    process(df)
    df.unpersist()  # Free memory
```

**3. Use efficient operations**
```python
# Bad: Collect entire dataset
data = df.collect()  # Pulls all data to driver

# Good: Aggregate first
count = df.count()
summary = df.groupBy("region").agg(sum("amount")).collect()
```

---

## Data Pipeline Issues

### Issue: Data Factory pipeline fails

**Error:**
```
Copy activity encountered a user error at Sink side.
```

**Common causes and solutions:**

**1. Permission issues**
```bash
# Grant Data Factory managed identity access
ADF_ID=$(az datafactory show \
    --name $(terraform output -raw data_factory_name) \
    --resource-group $RG_NAME \
    --query identity.principalId -o tsv)

az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee $ADF_ID \
    --scope $(az storage account show --name $STORAGE_ACCOUNT --query id -o tsv)
```

**2. File path errors**
```
Wrong: /container/folder/
Correct: container/folder/

Wrong: https://<account>.blob.core.windows.net/
Correct: https://<account>.dfs.core.windows.net/
```

**3. Schema mismatch**
```json
// In Copy Activity, enable:
{
  "enableSkipIncompatibleRow": true,
  "validateDataConsistency": true
}
```

---

### Issue: Incremental load not working

**Problem:** Full load every time instead of incremental

**Solution:**
```python
# Store last load timestamp
from delta.tables import DeltaTable

# Read last successful load
last_load = spark.read \
    .parquet("metadata/watermark/sales/") \
    .select(max("load_timestamp")) \
    .collect()[0][0]

# Incremental load
incremental_df = source_df.filter(col("modified_date") > last_load)

# Process and save
incremental_df.write.mode("append").parquet("bronze/sales/")

# Update watermark
new_watermark = datetime.now()
spark.createDataFrame([(new_watermark,)], ["load_timestamp"]) \
    .write \
    .mode("overwrite") \
    .parquet("metadata/watermark/sales/")
```

---

## Network and Connectivity

### Issue: Cannot connect from on-premises

**Error:**
```
Timeout expired. The timeout period elapsed prior to completion of the operation.
```

**Solutions:**

**1. Check firewall**
```bash
# Get on-premises gateway public IP
# Add to both storage and Synapse firewalls

az storage account network-rule add \
    --account-name $STORAGE_ACCOUNT \
    --ip-address "GATEWAY_PUBLIC_IP"

az synapse workspace firewall-rule create \
    --name "OnPremGateway" \
    --workspace-name $SYNAPSE_NAME \
    --resource-group $RG_NAME \
    --start-ip-address "GATEWAY_PUBLIC_IP" \
    --end-ip-address "GATEWAY_PUBLIC_IP"
```

**2. Use private endpoints** (preferred for production)
```bash
# See SECURITY.md for private endpoint setup
```

**3. Test connectivity**
```bash
# Test from on-premises
curl https://<storage-account>.dfs.core.windows.net

# Test Synapse
telnet <synapse-workspace>-ondemand.sql.azuresynapse.net 1433
```

---

## Diagnostic Commands

### Check resource health
```bash
# Storage account
az storage account show \
    --name $STORAGE_ACCOUNT \
    --query "{name:name, status:statusOfPrimary, location:location}" \
    --output table

# Synapse workspace
az synapse workspace show \
    --name $SYNAPSE_NAME \
    --resource-group $RG_NAME \
    --query "{name:name, state:state, location:location}" \
    --output table
```

### List all role assignments
```bash
az role assignment list \
    --scope $(az storage account show --name $STORAGE_ACCOUNT --query id -o tsv) \
    --output table
```

### View activity logs
```bash
# Recent operations
az monitor activity-log list \
    --resource-group $RG_NAME \
    --max-events 50 \
    --query "[].{Time:eventTimestamp, Operation:operationName.value, Status:status.value}" \
    --output table
```

### Test Synapse SQL connection
```bash
# Using sqlcmd
sqlcmd -S <synapse-name>-ondemand.sql.azuresynapse.net \
       -d PowerBIDB \
       -G  # Use Azure AD auth

# Test query
1> SELECT @@VERSION;
2> GO
```

---

## Getting Help

### Azure Support Resources

1. **Azure Portal** → Resource → Support + troubleshooting
2. **Azure Status**: https://status.azure.com
3. **Azure Documentation**: https://docs.microsoft.com/azure
4. **Stack Overflow**: Tag with `azure-synapse`, `azure-data-lake-gen2`

### Collect diagnostic information

```bash
# Resource IDs
terraform output -json > resource_info.json

# Recent errors
az monitor activity-log list \
    --resource-group $RG_NAME \
    --start-time $(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ') \
    --query "[?level=='Error']" \
    --output json > errors.json

# Configuration
az storage account show --name $STORAGE_ACCOUNT > storage_config.json
az synapse workspace show --name $SYNAPSE_NAME --resource-group $RG_NAME > synapse_config.json
```

---

## Prevention Checklist

Avoid common issues by following these practices:

- [ ] Use unique names for globally-scoped resources
- [ ] Always enable hierarchical namespace for Gen2
- [ ] Configure firewall rules before testing
- [ ] Grant proper RBAC roles to managed identities
- [ ] Use Parquet format for analytics workloads
- [ ] Partition large datasets appropriately
- [ ] Monitor file sizes (avoid too small or too large)
- [ ] Enable diagnostic logging
- [ ] Document all custom configurations
- [ ] Test connections before deploying to production
