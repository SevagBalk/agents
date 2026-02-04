# Azure Data Lake Gen2 Terraform Files

## File Structure

```
.
├── main.tf                      # Main infrastructure definitions
├── variables.tf                 # Variable declarations
├── outputs.tf                   # Output values after deployment
├── terraform.tfvars.example     # Example configuration file
├── .gitignore                   # Git ignore rules
├── Makefile                     # Common commands (make help)
├── quickstart.sh                # Interactive setup script
├── README.md                    # Complete deployment guide
└── FILES.md                     # This file
```

## Quick Start

### Option 1: Using the Quick Start Script (Easiest)

```bash
./quickstart.sh
```

This interactive script will:
- Check prerequisites
- Help you configure settings
- Deploy the infrastructure

### Option 2: Using Makefile Commands

```bash
# Setup and view commands
make help

# Deploy step by step
make setup    # Initial configuration
make init     # Initialize Terraform
make plan     # Preview changes
make apply    # Deploy infrastructure

# Get information
make output   # Show all outputs
```

### Option 3: Manual Terraform Commands

```bash
# 1. Configure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your values

# 2. Deploy
terraform init
terraform plan
terraform apply

# 3. View results
terraform output
```

## File Descriptions

### main.tf
Contains all Azure resource definitions:
- Resource Group
- Storage Account (Data Lake Gen2)
- Containers (bronze, silver, gold)
- Synapse Analytics Workspace
- Data Factory (optional)
- Key Vault (optional)
- Security and RBAC configurations

### variables.tf
Defines configurable parameters:
- Resource names
- Azure region
- Storage configuration
- Security settings
- Feature flags

### outputs.tf
Exports important values after deployment:
- Storage account endpoints
- Synapse connection strings
- Container names
- Resource identifiers

### terraform.tfvars.example
Template for your configuration:
- Copy to `terraform.tfvars`
- Update with your specific values
- Never commit `terraform.tfvars` (contains secrets)

### README.md
Complete deployment guide with:
- Prerequisites
- Step-by-step instructions
- Power BI connection guide
- Troubleshooting
- Best practices

### Makefile
Common operations:
- `make setup` - Initial setup
- `make init` - Initialize Terraform
- `make plan` - Preview changes
- `make apply` - Deploy
- `make destroy` - Remove all resources

### quickstart.sh
Interactive deployment script:
- Checks prerequisites
- Guides configuration
- Handles deployment
- Shows next steps

## What Gets Deployed

| Resource | Purpose | Estimated Cost/Month |
|----------|---------|---------------------|
| Storage Account (Gen2) | Data Lake with hierarchical namespace | $20-25 (1TB) |
| 3 Containers | Bronze, Silver, Gold layers | Included |
| Synapse Workspace | Analytics and SQL serverless | $5/TB scanned |
| Data Factory | Data ingestion pipelines | $2-5 (optional) |
| Key Vault | Secrets management | $0.03 (optional) |

## Architecture Components

```
┌─────────────────────────────────────────────────────────────┐
│                     DEPLOYED BY TERRAFORM                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Azure Data Lake Storage Gen2                        │   │
│  │  ┌──────────┬──────────┬──────────┐                 │   │
│  │  │  Bronze  │  Silver  │   Gold   │                 │   │
│  │  │  (Raw)   │(Cleaned) │(Business)│                 │   │
│  │  └──────────┴──────────┴──────────┘                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                          │                                    │
│                          ↓                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Azure Synapse Analytics                             │   │
│  │  - Serverless SQL Pool                               │   │
│  │  - External Tables                                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                          │                                    │
│                          ↓                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Azure Data Factory (Optional)                       │   │
│  │  - Data Ingestion Pipelines                          │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Azure Key Vault (Optional)                          │   │
│  │  - Secrets & Connection Strings                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                          │
                          ↓
                ┌───────────────────┐
                │     Power BI      │  ← YOU CONFIGURE THIS
                │  (Not deployed)   │     MANUALLY
                └───────────────────┘
```

## Configuration Variables

### Required Variables

```hcl
storage_account_name           # Must be globally unique
synapse_sql_admin_password     # Complex password required
```

### Important Optional Variables

```hcl
location                       # Azure region (default: "UK South")
client_ip_address              # Your IP for Synapse access
create_data_factory            # Deploy Data Factory (default: true)
create_key_vault               # Deploy Key Vault (default: true)
enable_private_access          # Enable firewall (default: false)
```

## Post-Deployment Steps

After Terraform completes:

1. **Configure Synapse SQL** - Create external tables
2. **Set up data ingestion** - Use Data Factory or upload files
3. **Connect Power BI** - Use Synapse SQL endpoint
4. **Create reports** - Build visualizations
5. **Configure security** - Add users and permissions

See [README.md](README.md) for detailed instructions.

## Cleanup

To remove all resources:

```bash
# Using Makefile
make destroy

# Or directly
terraform destroy
```

**WARNING:** This permanently deletes all data!

## Support

For issues or questions:
- Check [README.md](README.md) troubleshooting section
- Review Terraform output for error messages
- Verify Azure subscription permissions
- Check [Azure Documentation](https://docs.microsoft.com/azure/)
