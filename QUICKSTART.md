# Quick Reference Guide

## First Time Setup

```bash
# 1. Copy and configure your CML credentials
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your CML server details

# 2. Ensure Python requests library is installed
pip3 install requests

# 3. Initialize Terraform
terraform init
```

## Daily Workflows

### Deploy a Lab
```bash
terraform plan     # Preview changes
terraform apply    # Deploy and start nodes
```

### Check Lab Status
```bash
terraform output deployment_summary
terraform output booted  # Check if all nodes have booted
```

### Switch to Different Lab
```bash
# Edit terraform.tfvars: lab_folder = "lab02"
terraform apply
```

### Destroy Lab
```bash
terraform destroy  # Stops and removes lab from CML
```

## Common Commands

```bash
# View all outputs
terraform output

# View specific output
terraform output lab_id

# Apply with variable override
terraform apply -var="lab_folder=lab02"

# Format Terraform files
terraform fmt

# Validate configuration
terraform validate
```

## Troubleshooting

### Lab import fails
- Check CML server connectivity: `curl -k https://your-cml-server/api/v0/system_information`
- Verify credentials in `terraform.tfvars`
- Check Python requests is installed: `python3 -c "import requests"`

### Nodes won't start
- Check CML server resources (RAM, CPU, licenses)
- View terraform output for detailed error messages
- Check `.lab_id.txt` was created successfully

### Clean state
```bash
# If deployment fails partway through
rm -f .lab_id.txt
terraform destroy
terraform apply
```

## File Structure

```
├── main.tf                 # Main configuration
├── variables.tf            # Variable definitions  
├── outputs.tf              # Output definitions
├── terraform.tfvars        # Your config (never commit!)
├── .lab_id.txt             # Temp file (auto-generated)
└── lab01/                  # Lab topology folder
    ├── TF_-_Topo_Automation.yaml
    ├── Router01.cfg        # Optional node config
    └── Switch01.cfg        # Optional node config
```

## Node Configurations

Add optional startup configurations by creating `.cfg` files matching node labels:
- `<NodeLabel>.cfg` in the same folder as the topology YAML
- Completely optional - nodes without config files will start with defaults
- Configurations are injected at import time
