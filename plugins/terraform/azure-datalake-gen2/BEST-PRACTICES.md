# Best Practices Guide

Data Lake Gen2 best practices for architecture, performance, and operations.

---

## Table of Contents

1. [Medallion Architecture](#medallion-architecture)
2. [Data Organization](#data-organization)
3. [File Formats](#file-formats)
4. [Partitioning Strategy](#partitioning-strategy)
5. [Performance Optimization](#performance-optimization)
6. [Data Governance](#data-governance)
7. [Cost Optimization](#cost-optimization)
8. [Operational Excellence](#operational-excellence)

---

## Medallion Architecture

### The Three Layers

```
Bronze (Raw) → Silver (Refined) → Gold (Curated)
```

### Bronze Layer

**Purpose:** Store raw, unprocessed data

```
bronze/
├── source_system_name/
│   ├── table_name/
│   │   ├── year=2024/
│   │   │   ├── month=01/
│   │   │   │   ├── day=15/
│   │   │   │   │   └── data_20240115_123045.parquet
```

**Characteristics:**
- Exact copy of source data
- Append-only (never delete)
- Original data types preserved
- Metadata: load timestamp, source file, etc.
- Retention: 90 days to 7 years (compliance dependent)

**Best Practices:**
```python
# Include metadata in bronze layer
bronze_df = source_df.withColumn("_load_timestamp", current_timestamp()) \
                     .withColumn("_source_file", input_file_name()) \
                     .withColumn("_batch_id", lit(batch_id))
```

### Silver Layer

**Purpose:** Cleaned, validated, conformed data

```
silver/
├── domain_name/
│   ├── entity_name/
│   │   ├── year=2024/
│   │   │   └── month=01/
│   │   │       └── entity_20240101.parquet
```

**Transformations:**
- Data cleansing (nulls, duplicates, outliers)
- Type conversions and standardization
- Business rule validation
- Data enrichment
- Slowly Changing Dimensions (SCD)

**Best Practices:**
```python
# Silver layer transformations
silver_df = bronze_df \
    .dropDuplicates(["id"]) \
    .filter(col("amount") > 0) \
    .withColumn("email", lower(trim(col("email")))) \
    .withColumn("order_date", to_date(col("order_date"))) \
    .na.fill({"region": "UNKNOWN"})
```

### Gold Layer

**Purpose:** Business-level aggregates for analytics

```
gold/
├── business_unit/
│   ├── report_name/
│   │   └── aggregated_data.parquet
```

**Characteristics:**
- Highly aggregated
- Business-friendly column names
- Optimized for query performance
- Filtered to relevant data only
- Directly consumable by BI tools

**Best Practices:**
```python
# Gold layer aggregations
gold_df = silver_df \
    .groupBy("customer_id", "order_month") \
    .agg(
        sum("amount").alias("total_revenue"),
        count("order_id").alias("order_count"),
        avg("amount").alias("average_order_value")
    ) \
    .withColumn("revenue_category",
        when(col("total_revenue") > 10000, "High")
        .when(col("total_revenue") > 1000, "Medium")
        .otherwise("Low")
    )
```

---

## Data Organization

### Folder Structure

```
container/
├── source_system/          # Group by data source
│   ├── entity/             # Group by logical entity
│   │   ├── year=YYYY/      # Partition by date
│   │   │   ├── month=MM/
│   │   │   │   └── files
```

### Naming Conventions

**Files:**
```
# Pattern: {entity}_{date}_{batch_id}.{format}
sales_20240115_001.parquet
customers_20240115_002.parquet

# For partitioned data (no date in filename)
part-00000-uuid.snappy.parquet
part-00001-uuid.snappy.parquet
```

**Folders:**
```
# Use lowercase with underscores
sales_transactions/     ✓
SalesTransactions/      ✗

# Use singular names
customer/               ✓
customers/              ✗ (unless it's a list/collection)

# Be descriptive
sales_daily_summary/    ✓
sds/                    ✗
```

### Directory Layout Examples

**By Source System:**
```
bronze/
├── erp_system/
│   ├── orders/
│   ├── products/
│   └── customers/
├── crm_system/
│   ├── contacts/
│   └── opportunities/
└── web_analytics/
    ├── page_views/
    └── user_sessions/
```

**By Business Domain:**
```
gold/
├── sales/
│   ├── daily_revenue/
│   ├── top_products/
│   └── customer_segments/
├── marketing/
│   ├── campaign_performance/
│   └── customer_acquisition/
└── finance/
    ├── monthly_pl/
    └── budget_actuals/
```

---

## File Formats

### Format Comparison

| Format | Use Case | Read Speed | Write Speed | Compression | Schema |
|--------|----------|------------|-------------|-------------|--------|
| **Parquet** | Analytics (columnar) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Excellent | Yes |
| **Delta Lake** | ACID transactions | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Excellent | Yes |
| **CSV** | Legacy/interchange | ⭐⭐ | ⭐⭐⭐⭐⭐ | Poor | No |
| **JSON** | Semi-structured | ⭐⭐⭐ | ⭐⭐⭐⭐ | Good | Flexible |
| **Avro** | Streaming data | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Good | Yes |

### Recommended: Parquet

**Why Parquet?**
- Columnar storage (10-100x faster for analytics)
- Built-in compression (50-80% storage savings)
- Schema evolution support
- Native support in Azure tools

**Configuration:**
```python
# Optimal Parquet settings
df.write \
    .mode("overwrite") \
    .format("parquet") \
    .option("compression", "snappy") \  # Fast compression
    .option("parquet.block.size", 268435456) \  # 256MB
    .partitionBy("year", "month") \
    .save("gold/sales_data/")
```

### Delta Lake (Advanced)

**When to use:**
- Need ACID transactions
- Time travel required
- Frequent updates/deletes
- Streaming + batch workloads

```python
# Delta Lake example
from delta.tables import DeltaTable

# Write
df.write \
    .format("delta") \
    .mode("overwrite") \
    .partitionBy("date") \
    .save("/mnt/gold/sales_delta/")

# Update
deltaTable = DeltaTable.forPath(spark, "/mnt/gold/sales_delta/")
deltaTable.update(
    condition = "order_status = 'pending'",
    set = {"order_status": "'processed'"}
)

# Time travel
df = spark.read \
    .format("delta") \
    .option("versionAsOf", 0) \
    .load("/mnt/gold/sales_delta/")
```

---

## Partitioning Strategy

### When to Partition

**Partition if:**
- ✓ Dataset > 1 GB
- ✓ Query filters on specific columns (date, region, etc.)
- ✓ Data has natural segmentation

**Don't partition if:**
- ✗ Dataset < 1 GB
- ✗ Too many small files (< 10 MB each)
- ✗ No common query filters

### Partition Schemes

**By Date (Most Common):**
```
sales/
├── year=2024/
│   ├── month=01/
│   │   ├── day=01/
│   │   ├── day=02/
```

**By Region:**
```
sales/
├── region=EMEA/
├── region=AMER/
├── region=APAC/
```

**Multi-level (Be Careful):**
```
sales/
├── year=2024/
│   ├── region=EMEA/
│   │   ├── product_category=Electronics/
```

⚠️ **Warning:** Too many partition levels → Too many small files

### File Sizing

**Optimal file size: 128 MB - 1 GB**

```python
# Control file size with repartition
df.repartition(10) \  # Creates 10 files
    .write \
    .parquet("gold/sales/")

# Or use coalesce for fewer files
df.coalesce(5) \
    .write \
    .parquet("gold/sales/")

# Dynamic partitioning
df.repartition("year", "month") \  # One file per partition
    .write \
    .partitionBy("year", "month") \
    .parquet("gold/sales/")
```

---

## Performance Optimization

### 1. File Compaction

Merge small files into larger ones:

```python
# Read small files
df = spark.read.parquet("gold/sales/year=2024/month=01/")

# Rewrite as larger files
df.coalesce(5) \
    .write \
    .mode("overwrite") \
    .parquet("gold/sales/year=2024/month=01/")
```

### 2. Statistics and Indexing

```sql
-- Synapse: Create statistics
CREATE STATISTICS stat_order_date ON sales_data(order_date);
CREATE STATISTICS stat_customer_id ON sales_data(customer_id);

-- Analyze frequently joined columns
CREATE STATISTICS stat_product_id ON sales_data(product_id);
```

### 3. Caching

```python
# Cache frequently accessed data
df = spark.read.parquet("gold/customer_summary/")
df.cache()
df.count()  # Triggers caching

# Use cached data multiple times
result1 = df.filter(col("total_revenue") > 10000).count()
result2 = df.groupBy("segment").sum("total_revenue").collect()
```

### 4. Predicate Pushdown

```python
# Good: Filter pushed to storage
df = spark.read \
    .parquet("bronze/sales/") \
    .filter(col("year") == 2024) \
    .filter(col("month") == 1)

# Bad: Filter after loading all data
df = spark.read.parquet("bronze/sales/")
df = df.filter((col("year") == 2024) & (col("month") == 1))
```

### 5. Column Pruning

```python
# Good: Read only needed columns
df = spark.read \
    .parquet("bronze/sales/") \
    .select("order_id", "amount", "order_date")

# Bad: Read all columns then select
df = spark.read.parquet("bronze/sales/")
df = df.select("order_id", "amount", "order_date")
```

---

## Data Governance

### Data Catalog

**Metadata to track:**
```yaml
dataset:
  name: sales_daily_summary
  location: gold/sales/daily_summary/
  format: parquet
  owner: data-team@company.com
  created_date: 2024-01-15
  updated_date: 2024-02-04

  schema:
    - name: order_date
      type: date
      description: Date of the order
    - name: total_revenue
      type: decimal(10,2)
      description: Sum of all orders for the day

  lineage:
    source: bronze/erp/orders/
    transformations:
      - silver/orders_cleaned/
      - gold/sales/daily_summary/

  quality:
    completeness: 99.8%
    accuracy: 99.5%
    timeliness: Daily by 6 AM
```

### Data Quality

**Quality Checks:**
```python
# Completeness
null_count = df.filter(col("order_id").isNull()).count()
total_count = df.count()
completeness = 1 - (null_count / total_count)

# Uniqueness
unique_count = df.select("order_id").distinct().count()
uniqueness = unique_count / total_count

# Validity
valid_count = df.filter(
    (col("amount") > 0) &
    (col("order_date") <= current_date())
).count()
validity = valid_count / total_count

# Freshness
max_date = df.select(max("order_date")).collect()[0][0]
days_old = (datetime.now().date() - max_date).days
is_fresh = days_old <= 1
```

### Data Lineage

```python
# Track lineage in metadata
lineage_metadata = {
    "job_id": "job_123",
    "source": "bronze/erp/orders/",
    "target": "silver/orders_cleaned/",
    "transformation": "data_cleansing",
    "timestamp": datetime.now(),
    "row_count_in": source_df.count(),
    "row_count_out": cleaned_df.count(),
    "records_dropped": dropped_count,
    "drop_reason": "invalid_date"
}

# Store in audit table
spark.createDataFrame([lineage_metadata]).write \
    .mode("append") \
    .parquet("metadata/lineage/")
```

---

## Cost Optimization

### Storage Costs

**Lifecycle Management:**
```bash
# Move old data to cool tier (Azure CLI)
az storage account blob-service-properties update \
    --account-name $STORAGE_ACCOUNT \
    --enable-last-access-tracking true

# Create lifecycle policy
az storage account management-policy create \
    --account-name $STORAGE_ACCOUNT \
    --policy @policy.json
```

**policy.json:**
```json
{
  "rules": [
    {
      "enabled": true,
      "name": "move-bronze-to-cool",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCool": {
              "daysAfterModificationGreaterThan": 30
            },
            "tierToArchive": {
              "daysAfterModificationGreaterThan": 90
            }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["bronze/"]
        }
      }
    }
  ]
}
```

### Query Costs (Synapse Serverless)

**Cost = $5 per TB scanned**

**Optimization tips:**
```sql
-- 1. Use partitioning
SELECT * FROM sales
WHERE year = 2024 AND month = 1;  -- Only scans Jan 2024

-- 2. Select specific columns
SELECT order_id, amount  -- Only scans 2 columns
FROM sales
WHERE year = 2024;

-- 3. Use Parquet (columnar)
-- CSV: Scans entire file
-- Parquet: Scans only needed columns

-- 4. Aggregate in gold layer
-- Instead of aggregating in Synapse every time,
-- pre-aggregate in gold layer
```

### Data Factory Costs

**Optimize pipeline runs:**
```python
# Incremental load instead of full load
last_load = get_last_load_date()

incremental_df = df.filter(col("modified_date") > last_load)

incremental_df.write \
    .mode("append") \
    .parquet("bronze/orders/")
```

---

## Operational Excellence

### Monitoring

**Key Metrics:**
```
1. Data Freshness
   - Time since last load
   - SLA: < 1 hour for critical tables

2. Data Quality
   - Completeness > 99%
   - Accuracy > 99%
   - Validity > 98%

3. Pipeline Performance
   - Execution time
   - Failure rate < 1%
   - Data volume processed

4. Storage Usage
   - Total size by layer
   - Growth rate
   - Cost per GB

5. Query Performance
   - Average query time
   - Data scanned per query
   - Concurrent users
```

### Alerting

```bash
# Alert on pipeline failure
az monitor metrics alert create \
    --name "pipeline-failure" \
    --resource-group $RG_NAME \
    --scopes $(terraform output -raw data_factory_id) \
    --condition "count FailedRuns > 0" \
    --window-size 5m \
    --action alert-data-team

# Alert on data freshness
# (Implement via Azure Function + Logic App)
```

### Documentation

**Maintain:**
1. **Architecture Diagram** - Keep updated
2. **Data Dictionary** - All tables and columns
3. **Runbooks** - Operational procedures
4. **Troubleshooting Guide** - Common issues
5. **Change Log** - Track schema changes

### Backup and Recovery

```bash
# Enable soft delete
az storage account blob-service-properties delete-policy update \
    --account-name $STORAGE_ACCOUNT \
    --enable true \
    --days-retained 30

# Enable versioning
az storage account blob-service-properties versioning-policy update \
    --account-name $STORAGE_ACCOUNT \
    --enable true

# Snapshot critical data
az storage blob snapshot \
    --account-name $STORAGE_ACCOUNT \
    --container-name gold \
    --name sales_summary/data.parquet
```

---

## Summary Checklist

### Architecture
- [ ] Medallion architecture implemented (Bronze/Silver/Gold)
- [ ] Logical folder structure
- [ ] Consistent naming conventions

### Performance
- [ ] Parquet format for analytics
- [ ] Data properly partitioned
- [ ] Files sized 128 MB - 1 GB
- [ ] Statistics created in Synapse

### Governance
- [ ] Data catalog maintained
- [ ] Quality checks automated
- [ ] Lineage tracked
- [ ] Security policies enforced

### Cost
- [ ] Lifecycle policies configured
- [ ] Incremental loads implemented
- [ ] Query optimization applied
- [ ] Unused data archived

### Operations
- [ ] Monitoring dashboard created
- [ ] Alerts configured
- [ ] Documentation updated
- [ ] Backup strategy implemented

---

## Next Steps

- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Security Configuration](SECURITY.md)
- [Power BI Integration](POWERBI-INTEGRATION.md)
