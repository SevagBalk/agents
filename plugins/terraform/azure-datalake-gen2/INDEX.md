# Azure Data Lake Gen2 + Power BI - Complete Documentation

**Terraform Infrastructure-as-Code for Azure Data Lake Storage Gen2 with Power BI Integration**

---

## 🚀 Quick Start

Choose your preferred method:

### Option 1: Interactive Quick Start (Recommended)
```bash
cd terraform/azure-datalake-gen2
./quickstart.sh
```

### Option 2: Using Makefile
```bash
cd terraform/azure-datalake-gen2
make setup
make init
make plan
make apply
```

### Option 3: Manual Terraform
```bash
cd terraform/azure-datalake-gen2
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

---

## 📚 Documentation Index

### Getting Started

| Document | Description |
|----------|-------------|
| **[README.md](README.md)** | Main overview and quick start guide |
| **[FILES.md](FILES.md)** | File structure and usage reference |
| **[DEPLOYMENT.md](DEPLOYMENT.md)** | Detailed step-by-step deployment instructions |

### Configuration Guides

| Document | Description |
|----------|-------------|
| **[POWERBI-INTEGRATION.md](POWERBI-INTEGRATION.md)** | Connect Power BI to your data lake |
| **[SECURITY.md](SECURITY.md)** | Security configuration and best practices |
| **[BEST-PRACTICES.md](BEST-PRACTICES.md)** | Architecture and operational best practices |

### Reference

| Document | Description |
|----------|-------------|
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Common issues and solutions |
| **[architecture.html](architecture.html)** | Visual architecture diagram |

---

## 📦 What's Included

### Terraform Files

| File | Purpose |
|------|---------|
| `main.tf` | Infrastructure resource definitions |
| `variables.tf` | Configurable parameters |
| `outputs.tf` | Export values after deployment |
| `terraform.tfvars.example` | Configuration template |

### Helper Scripts

| File | Purpose |
|------|---------|
| `quickstart.sh` | Interactive deployment wizard |
| `Makefile` | Common command shortcuts |
| `.gitignore` | Protect sensitive files |

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Data Lake Gen2                      │
│                                                               │
│  Data Sources → Bronze (Raw) → Silver (Clean) → Gold (Ready) │
│                                        ↓                      │
│                              Azure Synapse Analytics          │
│                                        ↓                      │
│                                    Power BI                   │
└─────────────────────────────────────────────────────────────┘
```

View the full diagram: [architecture.html](architecture.html)

---

## 🎯 Use Cases

This infrastructure is perfect for:

- **Business Intelligence** - Connect Power BI for analytics
- **Data Warehousing** - Centralized data storage
- **Big Data Analytics** - Process large datasets with Synapse
- **Data Science** - ML/AI model training
- **Compliance** - Audit trails and data governance

---

## 🔑 Key Features

### Deployed Resources

✅ **Storage Account** with Data Lake Gen2 (hierarchical namespace)
✅ **Three Containers** for medallion architecture (Bronze/Silver/Gold)
✅ **Azure Synapse Analytics** workspace with serverless SQL
✅ **Azure Data Factory** for data ingestion (optional)
✅ **Azure Key Vault** for secrets management (optional)
✅ **RBAC Permissions** properly configured
✅ **Firewall Rules** for secure access

### Features

- Infrastructure as Code (reproducible, version-controlled)
- Medallion architecture built-in
- Security best practices by default
- Optimized for Power BI connectivity
- Cost-effective serverless compute
- Scalable to petabytes of data

---

## 📖 Documentation Paths

### For First-Time Users

1. Start with **[README.md](README.md)** for overview
2. Follow **[DEPLOYMENT.md](DEPLOYMENT.md)** for step-by-step deployment
3. Read **[POWERBI-INTEGRATION.md](POWERBI-INTEGRATION.md)** to connect Power BI
4. Review **[SECURITY.md](SECURITY.md)** for production hardening

### For Data Engineers

1. Review **[BEST-PRACTICES.md](BEST-PRACTICES.md)** for architecture patterns
2. Understand the medallion architecture (Bronze/Silver/Gold)
3. Learn partitioning and file format strategies
4. Implement data quality checks

### For Administrators

1. Study **[SECURITY.md](SECURITY.md)** for access controls
2. Set up monitoring and alerting
3. Configure backup and disaster recovery
4. Review **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for common issues

### For Business Analysts

1. Start with **[POWERBI-INTEGRATION.md](POWERBI-INTEGRATION.md)**
2. Learn DirectQuery vs Import modes
3. Understand row-level security
4. Optimize report performance

---

## 🛠️ Common Tasks

### Deploy Infrastructure
```bash
cd terraform/azure-datalake-gen2
terraform init
terraform apply
```

### Get Connection Info
```bash
terraform output
# Or specific values:
terraform output -raw synapse_sql_endpoint
terraform output -raw storage_account_name
```

### Add Firewall Rule
```bash
az synapse workspace firewall-rule create \
  --name "MyIP" \
  --workspace-name $(terraform output -raw synapse_workspace_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --start-ip-address $(curl -s https://ifconfig.me) \
  --end-ip-address $(curl -s https://ifconfig.me)
```

### Grant User Access
```bash
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee user@example.com \
  --scope $(az storage account show --name $(terraform output -raw storage_account_name) --query id -o tsv)
```

### Destroy Infrastructure
```bash
terraform destroy
```

---

## 💰 Cost Estimate

**Typical monthly cost: $30-40**

| Component | Configuration | Cost |
|-----------|--------------|------|
| Storage Account | 1 TB Standard LRS | $20-25 |
| Synapse Serverless SQL | 1 TB data scanned | $5 |
| Data Factory | 10 pipelines/day | $2-5 |
| Key Vault | 1000 operations | $0.03 |

*Costs scale with actual usage. Use lifecycle policies and query optimization to minimize costs.*

---

## 📋 Prerequisites

### Required

- Azure subscription
- Terraform installed (v1.0+)
- Azure CLI installed (v2.30+)
- Contributor or Owner role on subscription

### Optional

- Power BI Desktop (for report development)
- Power BI Pro/Premium license (for publishing)
- Azure Data Studio (for SQL queries)

---

## 🔗 External Resources

### Official Documentation

- [Azure Data Lake Gen2](https://docs.microsoft.com/azure/storage/blobs/data-lake-storage-introduction)
- [Azure Synapse Analytics](https://docs.microsoft.com/azure/synapse-analytics/)
- [Power BI](https://docs.microsoft.com/power-bi/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Community

- [Azure Updates](https://azure.microsoft.com/updates/)
- [Power BI Community](https://community.powerbi.com/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/azure-data-lake-gen2)

---

## 🤝 Support

### Having Issues?

1. Check **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** first
2. Review Azure service health: https://status.azure.com
3. Search existing GitHub issues
4. Create a new issue with:
   - Error messages
   - Terraform version
   - Azure CLI version
   - Steps to reproduce

### Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📄 License

This project is licensed under the MIT License.

---

## 🎓 Learning Path

### Week 1: Foundation
- [ ] Deploy infrastructure with Terraform
- [ ] Understand medallion architecture
- [ ] Upload sample data to bronze layer
- [ ] Connect to storage with Azure Storage Explorer

### Week 2: Data Processing
- [ ] Create Synapse SQL database
- [ ] Define external tables over Parquet files
- [ ] Write queries to transform data
- [ ] Move data from bronze → silver → gold

### Week 3: Business Intelligence
- [ ] Connect Power BI to Synapse
- [ ] Create data model with relationships
- [ ] Build sample dashboard
- [ ] Publish to Power BI Service

### Week 4: Production Readiness
- [ ] Implement security (RBAC, RLS)
- [ ] Set up monitoring and alerts
- [ ] Configure backup and disaster recovery
- [ ] Document your data catalog

---

## 📞 Quick Links

| Task | Link |
|------|------|
| Deploy infrastructure | [DEPLOYMENT.md](DEPLOYMENT.md) |
| Connect Power BI | [POWERBI-INTEGRATION.md](POWERBI-INTEGRATION.md) |
| Configure security | [SECURITY.md](SECURITY.md) |
| Optimize performance | [BEST-PRACTICES.md](BEST-PRACTICES.md) |
| Troubleshoot issues | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| View architecture | [architecture.html](architecture.html) |

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] Azure subscription ready
- [ ] Tools installed (Terraform, Azure CLI)
- [ ] Unique names chosen
- [ ] Configuration file created

### Deployment
- [ ] Terraform initialized
- [ ] Plan reviewed
- [ ] Infrastructure deployed
- [ ] Outputs saved

### Post-Deployment
- [ ] Storage account verified
- [ ] Synapse workspace accessible
- [ ] Folders created
- [ ] Security configured
- [ ] Power BI connected
- [ ] Documentation updated

---

**Ready to get started? Choose a quick start option above or dive into [DEPLOYMENT.md](DEPLOYMENT.md)!**
