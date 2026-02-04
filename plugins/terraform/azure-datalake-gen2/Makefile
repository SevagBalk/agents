# Makefile for Azure Data Lake Gen2 Terraform Deployment

.PHONY: help init plan apply destroy validate fmt clean setup

# Default target
help:
	@echo "Azure Data Lake Gen2 - Terraform Commands"
	@echo "=========================================="
	@echo "make setup    - Initial setup (login, copy tfvars)"
	@echo "make init     - Initialize Terraform"
	@echo "make validate - Validate Terraform configuration"
	@echo "make fmt      - Format Terraform files"
	@echo "make plan     - Preview infrastructure changes"
	@echo "make apply    - Deploy infrastructure"
	@echo "make output   - Show outputs"
	@echo "make destroy  - Destroy all infrastructure"
	@echo "make clean    - Clean Terraform files"

# Initial setup
setup:
	@echo "Setting up Azure Data Lake Gen2 deployment..."
	@if [ ! -f terraform.tfvars ]; then \
		cp terraform.tfvars.example terraform.tfvars; \
		echo "✓ Created terraform.tfvars from example"; \
		echo "⚠ Please edit terraform.tfvars with your values"; \
	else \
		echo "✓ terraform.tfvars already exists"; \
	fi
	@echo "Checking Azure CLI..."
	@az account show > /dev/null 2>&1 || (echo "⚠ Please run: az login" && exit 1)
	@echo "✓ Azure CLI authenticated"
	@echo "Your public IP: $$(curl -s https://ifconfig.me)"

# Initialize Terraform
init:
	terraform init

# Validate configuration
validate:
	terraform validate

# Format Terraform files
fmt:
	terraform fmt -recursive

# Plan changes
plan:
	terraform plan

# Apply changes
apply:
	terraform apply

# Show outputs
output:
	@terraform output

# Get specific outputs
get-storage-name:
	@terraform output -raw storage_account_name

get-synapse-endpoint:
	@terraform output -raw synapse_sql_on_demand_endpoint

get-datalake-url:
	@terraform output -raw storage_account_primary_dfs_endpoint

# Destroy infrastructure
destroy:
	@echo "⚠ WARNING: This will destroy all resources!"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		terraform destroy; \
	else \
		echo "Destroy cancelled"; \
	fi

# Clean Terraform files
clean:
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f crash.log
