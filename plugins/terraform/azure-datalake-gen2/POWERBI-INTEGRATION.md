# Power BI Integration Guide

Complete guide for connecting Power BI to your Azure Data Lake Gen2 environment.

---

## Overview

This guide covers three methods to connect Power BI to your data lake:

1. **Direct to Synapse SQL** (Recommended) - Serverless SQL queries
2. **Direct to Data Lake** - Read Parquet/CSV files directly
3. **Via Dataflows** - Transform data in Power BI Service

---

## Prerequisites

- Terraform deployment completed
- Power BI Desktop installed
- Power BI Pro or Premium license (for publishing)
- Azure Active Directory account with access to resources

---

## Method 1: Connect via Synapse SQL (Recommended)

### Why Synapse SQL?

✅ Best performance for large datasets
✅ Query optimization built-in
✅ DirectQuery support
✅ Security through SQL views
✅ No Power BI Premium required

### Step 1: Get Synapse Endpoint

```bash
# Get the connection endpoint
terraform output -raw synapse_sql_on_demand_endpoint

# Example output:
# synapse-datalake-prod-ondemand.sql.azuresynapse.net
```

### Step 2: Create Synapse SQL Database

Open Azure Data Studio or connect via Azure Portal:

```sql
-- Create a database for Power BI
CREATE DATABASE PowerBIDB;
GO

USE PowerBIDB;
GO
```

### Step 3: Create External Data Source

```sql
-- Get your storage account name from terraform output
-- Replace [STORAGE_ACCOUNT] with your storage account name

CREATE EXTERNAL DATA SOURCE DataLakeGold
WITH (
    LOCATION = 'https://[STORAGE_ACCOUNT].dfs.core.windows.net/gold'
);
GO

-- Optional: Create sources for other layers
CREATE EXTERNAL DATA SOURCE DataLakeSilver
WITH (
    LOCATION = 'https://[STORAGE_ACCOUNT].dfs.core.windows.net/silver'
);
GO
```

### Step 4: Create External File Format

```sql
-- For Parquet files
CREATE EXTERNAL FILE FORMAT ParquetFormat
WITH (
    FORMAT_TYPE = PARQUET,
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
);
GO

-- For CSV files
CREATE EXTERNAL FILE FORMAT CsvFormat
WITH (
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS (
        FIELD_TERMINATOR = ',',
        STRING_DELIMITER = '"',
        FIRST_ROW = 2,
        USE_TYPE_DEFAULT = TRUE
    ),
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.GzipCodec'
);
GO
```

### Step 5: Create External Tables or Views

```sql
-- Example 1: External table over Parquet files
CREATE EXTERNAL TABLE SalesData
(
    OrderID INT,
    OrderDate DATE,
    CustomerID INT,
    ProductID INT,
    Quantity INT,
    Amount DECIMAL(10,2)
)
WITH (
    LOCATION = 'sales_aggregated/*.parquet',
    DATA_SOURCE = DataLakeGold,
    FILE_FORMAT = ParquetFormat
);
GO

-- Example 2: View with OPENROWSET for flexibility
CREATE VIEW vw_CustomerInsights AS
SELECT
    CustomerID,
    CustomerName,
    TotalPurchases,
    LastPurchaseDate,
    CustomerSegment
FROM OPENROWSET(
    BULK 'customer_insights/*.parquet',
    DATA_SOURCE = 'DataLakeGold',
    FORMAT = 'PARQUET'
) AS customers;
GO

-- Example 3: Query multiple files with pattern
CREATE VIEW vw_MonthlySales AS
SELECT
    Year,
    Month,
    TotalRevenue,
    OrderCount
FROM OPENROWSET(
    BULK 'sales_aggregated/year=*/month=*/*.parquet',
    DATA_SOURCE = 'DataLakeGold',
    FORMAT = 'PARQUET'
) AS sales;
GO
```

### Step 6: Connect Power BI Desktop

1. **Open Power BI Desktop**

2. **Get Data** → **Azure** → **Azure Synapse Analytics (SQL)**

3. **Enter Server Details:**
   - **Server**: Paste your Synapse endpoint
   - **Database**: `PowerBIDB`

4. **Choose Data Connectivity Mode:**
   - **DirectQuery** (recommended for large datasets, always current)
   - **Import** (faster queries, scheduled refresh needed)

5. **Authenticate:**
   - Select **Microsoft account**
   - Click **Sign in**
   - Use your Azure AD credentials

6. **Select Tables:**
   - Choose `SalesData`, `vw_CustomerInsights`, etc.
   - Click **Load**

### Step 7: Build Your Report

```
# Create visualizations
1. Add visuals to canvas
2. Configure fields and filters
3. Create measures with DAX
4. Format and design

# Example DAX measures
Total Revenue = SUM(SalesData[Amount])
Order Count = COUNTROWS(SalesData)
Average Order Value = DIVIDE([Total Revenue], [Order Count])
```

---

## Method 2: Connect Directly to Data Lake

### When to Use

- Prototyping with raw files
- Simple CSV/Parquet datasets
- No SQL transformation needed

### Step 1: Get Data Lake URL

```bash
terraform output -raw storage_account_primary_dfs_endpoint
```

### Step 2: Connect Power BI

1. **Get Data** → **Azure** → **Azure Data Lake Storage Gen2**

2. **Enter URL:**
   ```
   https://[STORAGE_ACCOUNT].dfs.core.windows.net/gold
   ```

3. **Authenticate:**
   - **Organizational account** (Azure AD)
   - OR **Account key** (from Azure Portal)

4. **Navigate to Files:**
   - Browse folder structure
   - Select Parquet or CSV files
   - Click **Combine & Transform** or **Load**

### Step 3: Transform Data (Power Query)

```m
// Example Power Query transformations
let
    Source = AzureStorage.DataLake("https://[STORAGE_ACCOUNT].dfs.core.windows.net/gold"),
    SalesFolder = Source{[Name="sales_aggregated"]}[Content],
    ParquetFiles = Table.SelectRows(SalesFolder, each Text.EndsWith([Name], ".parquet")),
    CombinedData = Table.Combine(ParquetFiles[Content]),
    ChangedTypes = Table.TransformColumnTypes(CombinedData, {
        {"OrderDate", type date},
        {"Amount", Currency.Type}
    })
in
    ChangedTypes
```

---

## Method 3: Use Power BI Dataflows

### When to Use

- Centralized data transformation
- Shared datasets across reports
- Scheduled incremental refresh

### Step 1: Create Dataflow in Power BI Service

1. Go to **Power BI Service** (app.powerbi.com)
2. Select a workspace
3. **New** → **Dataflow**
4. **Add new tables**

### Step 2: Connect to Data Lake

1. Choose **Azure Data Lake Storage Gen2**
2. Enter connection details:
   ```
   URL: https://[STORAGE_ACCOUNT].dfs.core.windows.net
   ```
3. Authenticate with Azure AD

### Step 3: Transform and Load

1. Use Power Query to transform data
2. Configure refresh schedule
3. Save dataflow

### Step 4: Use Dataflow in Reports

1. Open Power BI Desktop
2. **Get Data** → **Power Platform** → **Power BI dataflows**
3. Select your dataflow
4. Load tables into report

---

## Connection String Reference

### Synapse SQL Connection

```
Server: [workspace-name]-ondemand.sql.azuresynapse.net
Database: PowerBIDB
Authentication: Azure Active Directory
```

### Data Lake Connection

```
URL: https://[storage-account].dfs.core.windows.net/[container]
Authentication: Azure Active Directory
```

---

## DirectQuery vs Import Mode

| Feature | DirectQuery | Import |
|---------|-------------|--------|
| **Data Freshness** | Real-time | Scheduled refresh |
| **Performance** | Depends on source | Fast (cached) |
| **Dataset Size** | Unlimited | Limited by Power BI capacity |
| **DAX Support** | Limited | Full |
| **Offline Access** | No | Yes |
| **Cost** | Pay per query | Pay for storage |

### When to Use DirectQuery

- Data changes frequently
- Dataset > 10 GB
- Need real-time dashboards
- Source handles queries efficiently

### When to Use Import

- Data changes infrequently
- Dataset < 10 GB
- Need complex DAX calculations
- Users need offline access

---

## Optimizing Performance

### 1. Partition Your Data

```
gold/
├── sales_aggregated/
│   ├── year=2024/
│   │   ├── month=01/*.parquet
│   │   ├── month=02/*.parquet
```

### 2. Use Appropriate File Formats

**Best to Worst:**
1. Parquet (columnar, compressed)
2. Delta Lake (ACID, versioning)
3. CSV (slow, uncompressed)

### 3. Create Aggregated Tables

```sql
-- Pre-aggregate in gold layer
CREATE VIEW vw_DailySalesSummary AS
SELECT
    CAST(OrderDate AS DATE) AS Date,
    SUM(Amount) AS TotalRevenue,
    COUNT(*) AS OrderCount
FROM SalesData
GROUP BY CAST(OrderDate AS DATE);
```

### 4. Use Indexes (Synapse)

```sql
-- Create statistics for better query performance
CREATE STATISTICS stat_OrderDate ON SalesData(OrderDate);
CREATE STATISTICS stat_CustomerID ON SalesData(CustomerID);
```

### 5. Limit Data in Power BI

```sql
-- Create filtered views for Power BI
CREATE VIEW vw_Last12MonthsSales AS
SELECT *
FROM SalesData
WHERE OrderDate >= DATEADD(MONTH, -12, GETDATE());
```

---

## Setting Up Scheduled Refresh

### For Import Mode

1. **Publish Report to Power BI Service**
   - File → Publish → Select workspace

2. **Configure Dataset Settings**
   - Go to workspace
   - Find your dataset
   - Click **⋯** → **Settings**

3. **Set Data Source Credentials**
   - Expand **Data source credentials**
   - Click **Edit credentials**
   - Select **OAuth2**
   - Sign in with Azure AD

4. **Configure Refresh Schedule**
   - Expand **Scheduled refresh**
   - Toggle **Keep your data up to date** to ON
   - Set frequency (daily, weekly)
   - Add time slots
   - Click **Apply**

### For DirectQuery

No refresh needed - data is always current!

---

## Security Configuration

### Row-Level Security (RLS) in Synapse

```sql
-- Create security view
CREATE VIEW vw_SalesWithSecurity AS
SELECT *
FROM SalesData
WHERE Region = USER_NAME();  -- Filter by logged-in user
GO

-- Grant permissions
GRANT SELECT ON vw_SalesWithSecurity TO [PowerBI_Users_Group];
GO
```

### Row-Level Security in Power BI

1. **Modeling** tab → **Manage roles**
2. Create role (e.g., "RegionFilter")
3. Add DAX filter:
   ```dax
   [Region] = USERNAME()
   ```
4. Assign users to roles in Power BI Service

---

## Sample Power BI Report Template

### Data Model

```
SalesData (Fact)
├── OrderID (PK)
├── OrderDate
├── CustomerID (FK)
├── ProductID (FK)
└── Amount

Customers (Dimension)
├── CustomerID (PK)
├── CustomerName
└── Segment

Products (Dimension)
├── ProductID (PK)
├── ProductName
└── Category

DateTable (Dimension)
├── Date (PK)
├── Year
├── Month
└── Quarter
```

### Key Measures

```dax
// Sales Measures
Total Revenue = SUM(SalesData[Amount])

YTD Revenue =
TOTALYTD(
    [Total Revenue],
    DateTable[Date]
)

Revenue vs LY =
VAR CurrentRevenue = [Total Revenue]
VAR LastYearRevenue =
    CALCULATE(
        [Total Revenue],
        DATEADD(DateTable[Date], -1, YEAR)
    )
RETURN
    CurrentRevenue - LastYearRevenue

// Customer Measures
Active Customers =
DISTINCTCOUNT(SalesData[CustomerID])

Customer Lifetime Value =
DIVIDE(
    [Total Revenue],
    [Active Customers]
)
```

---

## Testing Your Connection

### Verify Synapse Connection

```sql
-- Test query in Azure Data Studio
USE PowerBIDB;
GO

SELECT TOP 10 *
FROM SalesData;

-- Check row count
SELECT COUNT(*) AS TotalRows
FROM SalesData;

-- Verify data types
SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'SalesData';
```

### Test Power BI Connection

1. Load small table first
2. Create simple visual (table or card)
3. Verify data displays correctly
4. Check refresh time

---

## Troubleshooting Connection Issues

### Cannot connect to Synapse

**Check:**
- Synapse firewall includes your IP
- Using correct endpoint (serverless, not dedicated)
- Database exists and you have permissions

**Solution:**
```bash
# Add your IP to firewall
az synapse workspace firewall-rule create \
  --name MyClientIP \
  --workspace-name $(terraform output -raw synapse_workspace_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --start-ip-address YOUR_IP \
  --end-ip-address YOUR_IP
```

### Authentication errors

**Check:**
- Using correct Azure AD account
- Account has access to Synapse workspace
- Not using personal Microsoft account

**Solution:**
Grant access in Azure Portal:
```
Synapse Workspace → Access Control (IAM) → Add role assignment
→ Synapse SQL User → Select user
```

### Slow query performance

**Check:**
- File format (use Parquet)
- Data partitioning
- Query complexity

**Solution:**
- Create aggregated views
- Use DirectQuery for large datasets
- Optimize Synapse SQL queries

---

## Best Practices

1. **Use the Gold layer** for Power BI (pre-aggregated, clean data)
2. **Create views in Synapse** instead of complex Power Query
3. **Enable query folding** for better performance
4. **Use DirectQuery** for datasets > 5 GB
5. **Implement RLS** for multi-tenant scenarios
6. **Monitor refresh times** and optimize as needed
7. **Document your data model** for team collaboration
8. **Use incremental refresh** for large historical datasets

---

## Next Steps

1. ✅ Power BI connected
2. → [Implement security](SECURITY.md)
3. → [Review best practices](BEST-PRACTICES.md)
4. → [Troubleshooting guide](TROUBLESHOOTING.md)
