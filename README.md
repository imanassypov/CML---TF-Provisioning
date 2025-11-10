# CML Terraform Provisioning

Automated provisioning of Cisco Modeling Labs (CML) topologies using Terraform. This project enables on-demand deployment of network lab environments defined in YAML topology files with complete lifecycle management including automatic node startup and proper cleanup.

## Overview

This solution uses Terraform with the CML2 provider to:
- Import network topologies from YAML files via the CML API
- Automatically start all lab nodes and wait for boot completion
- Manage lab lifecycle (start, stop, wipe, delete)
- Provide detailed deployment information and status
- Enable easy switching between different lab scenarios

**Key Features:**
- 🚀 One-command deployment from YAML topologies
- 🔐 Token-based authentication with CML API
- ⏱️ Automatic node startup with boot-wait functionality
- 🧹 Complete cleanup (stop → wipe → delete)
- 📊 Detailed deployment outputs and summaries
- 🔄 Multi-lab support with folder-based organization
- ✅ Input validation and error handling

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.1.0
- Python 3.x with `requests` and `pyyaml` libraries installed
- Access to a CML server (version 2.x)
- Valid CML credentials with permissions to create and manage labs

> **Note**: The deployment uses Python to interact with the CML API for importing YAML topologies and injecting configurations. Ensure Python 3 and required libraries are available in your PATH.

### Installing Python Dependencies

```bash
pip3 install requests pyyaml
# or
python3 -m pip install requests pyyaml
```

## Quick Start

### 1. Initial Setup

```bash
# Copy the example configuration file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your CML server details
# Update: cml_address, cml_username, cml_password
```

### 2. Configure Your Environment

Edit `terraform.tfvars`:

```hcl
# CML Server Connection (IMPORTANT: No trailing slash!)
cml_address     = "https://cml.example.com"  # NOT "https://cml.example.com/"
cml_username    = "admin"
cml_password    = "your-secure-password"
cml_skip_verify = true  # Use false if you have valid TLS certificates

# Choose which lab to deploy
lab_folder        = "lab01"
topology_filename = "TF_-_Topo_Automation.yaml"

# Auto-start configuration
auto_start     = true  # Automatically start nodes
wait_for_ready = true  # Wait for nodes to boot (recommended)
```

> ⚠️ **Important**: The `cml_address` must NOT have a trailing slash. The provider will fail if it does.

### 3. Deploy a Lab

```bash
# Initialize Terraform (first time only)
terraform init

# Preview the deployment
terraform plan

# Deploy the lab and start nodes
terraform apply

# Review the deployment summary
terraform output deployment_summary
```

**Expected Timeline:**
- Import topology: ~1-2 seconds
- Node startup and boot: ~4-5 minutes (depending on node types)
- Total deployment: ~4-5 minutes

**Output Example:**
```
═══════════════════════════════════════════════════════════
CML Lab Deployment Summary
═══════════════════════════════════════════════════════════
Lab ID:          bb128785-753e-4638-a610-45bf5c7eeb83
Lab Title:       TF - Topo Automation
Lab State:       STARTED
Total Nodes:     4
Total Links:     4
All Booted:      true
Topology Source: lab01/TF_-_Topo_Automation.yaml
═══════════════════════════════════════════════════════════

Access your lab at: https://cml.maple.ciscolabs.com
```

### 4. Manage Your Lab

```bash
# View lab details
terraform output lab_id
terraform output node_details

# Destroy the lab when done
terraform destroy
```

**Destroy Process:**
The destroy operation performs a complete 3-step cleanup:
1. **Stop** - Gracefully shutdown all running nodes
2. **Wipe** - Remove all nodes and links from the lab
3. **Delete** - Remove the lab from CML server

Expected cleanup time: ~5-10 seconds

## Usage Examples

### Deploy a Different Lab

To deploy a different topology from another folder:

```bash
# Option 1: Update terraform.tfvars
# Change: lab_folder = "lab02"
terraform apply

# Option 2: Override via command line
terraform apply -var="lab_folder=lab02"
```

### Deploy Without Auto-Starting

To provision the lab without automatically starting nodes:

```bash
terraform apply -var="auto_start=false"

# Later, manually start via CML UI or update and re-apply
terraform apply -var="auto_start=true"
```

### Custom Lab Title and Description

```bash
terraform apply \
  -var="lab_title=Production Test Environment" \
  -var="lab_description=Testing new router configurations"
```

### Check Lab Status

```bash
# View if all nodes have booted
terraform output booted

# View complete deployment summary
terraform output deployment_summary

# Get just the lab ID (useful for scripts)
terraform output -raw lab_id
```

## Project Structure

```
.
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Input variable definitions
├── outputs.tf                   # Output definitions
├── terraform.tfvars.example     # Example configuration (template)
├── terraform.tfvars             # Your configuration (gitignored)
├── lab01/                       # Lab topology folder
│   └── TF_-_Topo_Automation.yaml
├── lab02/                       # Additional lab topologies
│   └── ...
└── README.md                    # This file
```

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `cml_address` | CML server URL | - | Yes |
| `cml_username` | CML username | - | Yes |
| `cml_password` | CML password | - | Yes |
| `cml_skip_verify` | Skip TLS verification | `false` | No |
| `lab_folder` | Lab folder name | `lab01` | No |
| `topology_filename` | YAML topology file | `TF_-_Topo_Automation.yaml` | No |
| `lab_title` | Custom lab title | Auto-generated | No |
| `lab_description` | Custom description | Auto-generated | No |
| `auto_start` | Auto-start nodes | `true` | No |
| `wait_for_ready` | Wait for boot completion | `true` | No |

## Outputs

After deployment, Terraform provides:

- **lab_id**: CML lab identifier
- **lab_title**: Lab title
- **lab_state**: Current lifecycle state
- **node_count**: Total number of nodes
- **node_details**: Node states and configurations
- **deployment_summary**: Formatted deployment overview

## How It Works

### Architecture

The solution uses a hybrid approach combining Terraform resources with Python scripts for CML API interaction:

1. **Topology Import** (`null_resource.import_lab`)
   - Python script authenticates with CML API (token-based)
   - Imports YAML topology file via `/api/v0/import` endpoint
   - Stores lab ID in `.lab_id.txt` for tracking

2. **Lab Data Source** (`data.cml2_lab.imported_lab`)
   - Reads the imported lab details using the lab ID
   - Provides lab metadata (title, node count, link count, state)

3. **Lifecycle Management** (`cml2_lifecycle.lab_lifecycle`)
   - Controls lab state (STARTED, STOPPED, DEFINED_ON_CORE)
   - Waits for all nodes to reach BOOTED state
   - Tracks individual node states and boot status

4. **Cleanup on Destroy** (`null_resource` destroy provisioner)
   - Stops all running nodes
   - Wipes the lab (removes nodes/links)
   - Deletes the lab from CML
   - Removes tracking file

### Authentication Flow

```
1. POST /api/v0/authenticate
   ↓ (returns JWT token)
2. Use token in Authorization: Bearer <token> header
   ↓
3. All subsequent API calls use this token
```

### CML Lab Lifecycle States

- **DEFINED_ON_CORE** - Lab exists but nodes are not started
- **STARTED** - Lab is running, nodes are booting or booted
- **STOPPED** - Lab was stopped, nodes are shutdown
- **BOOTED** - Individual nodes have completed boot process

### File Tracking

- `.lab_id.txt` - Temporary file storing the CML lab UUID
- Used to link Terraform state to actual CML lab
- Automatically removed on successful destroy
- Gitignored for security

## Troubleshooting

### Certificate Verification Issues

If you encounter TLS certificate errors with self-signed certificates:

```hcl
# In terraform.tfvars
cml_skip_verify = true
```

For production environments with valid certificates:
```hcl
cml_skip_verify = false
```

### Lab Won't Start

**Symptoms**: Terraform hangs during `cml2_lifecycle.lab_lifecycle` creation

**Common Causes**:
- Insufficient CML server resources (RAM, CPU)
- License limitations (node count, features)
- Image definitions not available on server

**Troubleshooting**:
```bash
# Check node details
terraform output node_details

# Check CML server resources via API
curl -k -H "Authorization: Bearer <token>" \
  https://your-cml-server/api/v0/system_information
```

### Authentication Failures

**Error**: `401 Unauthorized` or `Authentication failed`

**Solutions**:
1. Verify credentials in `terraform.tfvars`
2. Check CML server is accessible:
   ```bash
   curl -k https://your-cml-server/api/v0/system_information
   ```
3. Test authentication manually:
   ```bash
   curl -k -X POST https://your-cml-server/api/v0/authenticate \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"yourpass"}'
   ```

### Terraform State Issues

**Orphaned Labs**: Lab exists in CML but not in Terraform state

**Solution**:
```bash
# Manually delete the lab via Python
python3 << 'EOF'
import requests
import urllib3
urllib3.disable_warnings()

auth_resp = requests.post(
    'https://your-cml/api/v0/authenticate',
    json={'username': 'admin', 'password': 'pass'},
    verify=False
)
token = auth_resp.text.strip('"')
headers = {'Authorization': f'Bearer {token}'}

# Stop, wipe, delete
lab_id = 'your-lab-id'
requests.put(f'https://your-cml/api/v0/labs/{lab_id}/stop', headers=headers, verify=False)
requests.put(f'https://your-cml/api/v0/labs/{lab_id}/wipe', headers=headers, verify=False)
requests.delete(f'https://your-cml/api/v0/labs/{lab_id}', headers=headers, verify=False)
EOF

# Clean up Terraform state
rm -f .lab_id.txt terraform.tfstate*
terraform init
```

### Import Fails

**Error**: Lab import returns non-200 status code

**Checks**:
1. Verify YAML topology file is valid
2. Check file path in `lab_folder` variable
3. Ensure CML server has required node definitions/images
4. Check server logs for detailed error messages

### Destroy Doesn't Remove Lab

If `terraform destroy` completes but lab remains in CML:

1. Check `.lab_id.txt` exists (should be removed on success)
2. Manually verify lab state:
   ```bash
   # Get lab ID
   cat .lab_id.txt
   
   # Check lab status via API
   python3 << 'EOF'
   import requests, urllib3
   urllib3.disable_warnings()
   auth = requests.post('https://cml/api/v0/authenticate', 
                        json={'username':'admin','password':'pass'}, verify=False)
   token = auth.text.strip('"')
   lab = requests.get(f'https://cml/api/v0/labs/{open(".lab_id.txt").read().strip()}',
                      headers={'Authorization': f'Bearer {token}'}, verify=False)
   print(f"Lab exists: {lab.status_code == 200}, State: {lab.json().get('state') if lab.status_code == 200 else 'N/A'}")
   EOF
   ```

### URL Format Errors

**Error**: `Invalid value for variable "cml_address"`

**Solution**: Ensure no trailing slash in CML address:
```hcl
# ✓ Correct
cml_address = "https://cml.example.com"

# ✗ Wrong
cml_address = "https://cml.example.com/"
```

## Security Best Practices

- **Never commit `terraform.tfvars`** - Contains sensitive credentials (already in `.gitignore`)
- **Use environment variables** for sensitive data:
  ```bash
  export TF_VAR_cml_password="your-password"
  # Remove from terraform.tfvars
  ```
- **Consider using HashiCorp Vault** or similar secret management for production
- **Use HTTPS with valid certificates** when possible (`cml_skip_verify = false`)
- **Rotate credentials regularly** and use service accounts where available
- **Review `.lab_id.txt` permissions** - contains lab UUID
- **Audit Terraform state files** - may contain sensitive output data

### Environment Variable Usage

```bash
# Set environment variables (not stored in files)
export TF_VAR_cml_address="https://cml.example.com"
export TF_VAR_cml_username="admin"
export TF_VAR_cml_password="your-password"
export TF_VAR_cml_skip_verify="true"

# Run Terraform without tfvars file
terraform plan
terraform apply
```

## Adding New Lab Topologies

1. Create a new folder (e.g., `lab02/`)
2. Add your CML YAML topology file to the folder
3. **(Optional)** Add startup configuration files for nodes
4. Update `terraform.tfvars`:
   ```hcl
   lab_folder = "lab02"
   topology_filename = "your-topology.yaml"
   ```
5. Run `terraform apply`

### Node Startup Configurations

You can optionally provide startup configurations for nodes by creating configuration files in the same lab folder:

**File Naming Convention**: `<node_label>.cfg`

Example for a lab with nodes labeled `Router01` and `Switch01`:
```
lab01/
├── TF_-_Topo_Automation.yaml
├── Router01.cfg              # Optional startup config
└── Switch01.cfg              # Optional startup config
```

**Router01.cfg example:**
```cisco
!
hostname Router01
!
interface GigabitEthernet1
 description Link to Switch01
 ip address 10.0.0.1 255.255.255.0
 no shutdown
!
interface GigabitEthernet2
 description WAN Link
 ip address dhcp
 no shutdown
!
interface Loopback0
 description Management
 ip address 192.168.1.1 255.255.255.255
!
router ospf 1
 network 10.0.0.0 0.0.0.255 area 0
 network 192.168.1.1 0.0.0.0 area 0
!
end
```

**Switch01.cfg example:**
```cisco
!
hostname Switch01
!
vlan 10
 name DATA
!
vlan 20
 name VOICE
!
interface GigabitEthernet1/0/1
 description Trunk to Router01
 switchport mode trunk
 switchport trunk allowed vlan 10,20
!
interface GigabitEthernet1/0/2
 description Access Port
 switchport mode access
 switchport access vlan 10
!
end
```

**Important Notes:**
- Configuration files are **completely optional** - if no `.cfg` file exists for a node, it will start with empty/default configuration
- Configuration is injected at import time, not after nodes boot
- The node label in the YAML topology must match the configuration filename (case-sensitive)
- Configurations are applied on first boot
- For nodes that don't need configuration (like `external_connector` or `unmanaged_switch`), simply don't create a config file

### YAML Topology Requirements

Your topology YAML must include:
- **nodes** section with node definitions
- **links** section connecting nodes
- **lab** section with title and description

Example structure:
```yaml
nodes:
  - id: n0
    label: Router01
    node_definition: cat8000v
    interfaces:
      - id: i0
        label: Loopback0
        type: loopback
      - id: i1
        label: GigabitEthernet1
        type: physical
        slot: 0

links:
  - id: l0
    n1: n0
    n2: n1
    i1: i1
    i2: i0

lab:
  title: My Lab
  description: Lab description
  version: 0.3.0
```

### Supported Node Types

Common CML node definitions:
- `cat8000v` - Catalyst 8000V router
- `catalyst9000v_uadp` - Catalyst 9000V switch
- `external_connector` - External network connection
- `unmanaged_switch` - Basic L2 switch
- `iosv` - IOSv router
- `iosxrv9000` - IOS XRv 9000 router
- `nxosv9000` - NX-OSv 9000 switch
- `ubuntu` - Ubuntu Linux host
- `alpine` - Alpine Linux host

> **Note**: Available node types depend on your CML server's installed image definitions.

## Resources

- [CML2 Terraform Provider Documentation](https://registry.terraform.io/providers/CiscoDevNet/cml2/latest/docs)
- [Cisco Modeling Labs Documentation](https://developer.cisco.com/docs/modeling-labs/)
- [CML API Documentation](https://developer.cisco.com/docs/modeling-labs/#!api-reference)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Python Requests Library](https://requests.readthedocs.io/)

## Contributing

When contributing to this project:

1. Test changes with `terraform validate` and `terraform plan`
2. Verify full lifecycle: `terraform apply` and `terraform destroy`
3. Update documentation for new features
4. Follow existing code style and patterns
5. Test with different lab topologies

## Known Limitations

- Lab import uses Python scripts (requires Python 3 + requests library)
- Destroy provisioner output is suppressed due to sensitive credentials
- CML API rate limiting may affect rapid create/destroy cycles
- Large topologies (>20 nodes) may exceed default timeouts
- Node boot times vary by device type (routers: 3-5 min, switches: 4-6 min)

## Future Enhancements

Potential improvements:
- [ ] Support for pre-configured node settings
- [ ] Network impairment configuration (latency, jitter, packet loss)
- [ ] Automated configuration injection
- [ ] Multi-lab concurrent deployment
- [ ] Integration with external configuration management (Ansible, etc.)
- [ ] Custom node placement/coordinates
- [ ] Lab templates with parameterization

## License

Internal use for RBC network topology provisioning.

## Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review Terraform and CML provider documentation
3. Verify CML server logs for API errors
4. Contact your CML administrator for server-specific issues
