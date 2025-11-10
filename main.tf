terraform {
  required_providers {
    cml2 = {
      source  = "CiscoDevNet/cml2"
      version = "~> 0.7.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
  required_version = ">= 1.1.0"
}

provider "cml2" {
  address     = var.cml_address
  username    = var.cml_username
  password    = var.cml_password
  skip_verify = var.cml_skip_verify
}

# Read the topology YAML file from the selected lab folder
locals {
  topology_file = "${var.lab_folder}/${var.topology_filename}"
  topology_data = file(local.topology_file)
  topology_yaml = yamldecode(local.topology_data)
  
  # Extract lab title from YAML or use provided variable
  lab_title_final = var.lab_title != "" ? var.lab_title : try(local.topology_yaml.lab.title, "TF Provisioned Lab")
  lab_description_final = var.lab_description != "" ? var.lab_description : try(local.topology_yaml.lab.description, "Lab provisioned via Terraform from ${var.lab_folder}")
  
  # Build configuration map: node_label => config_file_content (if exists)
  # Configuration files should be named: <node_label>.cfg in the lab folder
  node_configs = {
    for node in local.topology_yaml.nodes :
    node.label => try(file("${var.lab_folder}/${node.label}.cfg"), "")
    if node.label != null
  }
}

# Import the lab topology using CML API
resource "null_resource" "import_lab" {
  triggers = {
    topology_hash = md5(local.topology_data)
    lab_folder    = var.lab_folder
    cml_address   = var.cml_address
    cml_username  = var.cml_username
    cml_password  = var.cml_password
  }

  provisioner "local-exec" {
    command = <<-EOT
      python3 << 'PYTHON_EOF'
import requests
import json
import sys
import urllib.parse
import yaml

# Disable SSL warnings for self-signed certs
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Authenticate and get token
auth_url = "${var.cml_address}/api/v0/authenticate"
auth_response = requests.post(
    auth_url,
    json={"username": "${var.cml_username}", "password": "${var.cml_password}"},
    verify=False
)

if auth_response.status_code != 200:
    print(f"Authentication failed: {auth_response.status_code} - {auth_response.text}")
    sys.exit(1)

token = auth_response.text.strip('"')
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/x-yaml"
}

# Read and parse topology file
with open("${local.topology_file}", "r") as f:
    topology_data = yaml.safe_load(f)

# Inject configurations from local files
node_configs = ${jsonencode(local.node_configs)}

for node in topology_data.get('nodes', []):
    node_label = node.get('label')
    if node_label and node_label in node_configs and node_configs[node_label]:
        # Store config as a single string (not array) for CML import
        node['configuration'] = node_configs[node_label]
        print(f"Injected configuration for {node_label}")
    else:
        # Set empty string if no configuration
        node['configuration'] = ""

# Convert back to YAML
topology_yaml_str = yaml.dump(topology_data, default_flow_style=False, sort_keys=False)

# Import lab
title = urllib.parse.quote("${local.lab_title_final}")
url = f"${var.cml_address}/api/v0/import?title={title}"
response = requests.post(
    url,
    data=topology_yaml_str,
    headers=headers,
    verify=False
)

if response.status_code in [200, 201]:
    lab_id = response.json().get("id")
    with open(".lab_id.txt", "w") as f:
        f.write(lab_id)
    print(f"Lab imported successfully: {lab_id}")
else:
    print(f"Error: {response.status_code} - {response.text}")
    sys.exit(1)
PYTHON_EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      python3 << 'PYTHON_EOF'
import requests
import os
import sys
import time
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

try:
    # Authenticate and get token
    auth_url = "${self.triggers.cml_address}/api/v0/authenticate"
    auth_response = requests.post(
        auth_url,
        json={"username": "${self.triggers.cml_username}", "password": "${self.triggers.cml_password}"},
        verify=False
    )

    if auth_response.status_code != 200:
        print(f"Authentication failed during destroy: {auth_response.status_code}")
        sys.exit(0)  # Continue even if auth fails during destroy

    token = auth_response.text.strip('"')
    headers = {"Authorization": f"Bearer {token}"}

    # Read lab ID
    if os.path.exists(".lab_id.txt"):
        with open(".lab_id.txt", "r") as f:
            lab_id = f.read().strip()
        
        print(f"Cleaning up lab: {lab_id}")
        
        # Step 1: Stop the lab
        print("Stopping lab...")
        stop_url = f"${self.triggers.cml_address}/api/v0/labs/{lab_id}/stop"
        stop_response = requests.put(stop_url, headers=headers, verify=False)
        print(f"Stop status: {stop_response.status_code}")
        time.sleep(2)
        
        # Step 2: Wipe the lab (remove all nodes/links)
        print("Wiping lab...")
        wipe_url = f"${self.triggers.cml_address}/api/v0/labs/{lab_id}/wipe"
        wipe_response = requests.put(wipe_url, headers=headers, verify=False)
        print(f"Wipe status: {wipe_response.status_code}")
        time.sleep(2)
        
        # Step 3: Delete lab
        print("Deleting lab...")
        delete_url = f"${self.triggers.cml_address}/api/v0/labs/{lab_id}"
        delete_response = requests.delete(delete_url, headers=headers, verify=False)
        
        if delete_response.status_code in [200, 204]:
            print(f"Lab {lab_id} deleted successfully")
            os.remove(".lab_id.txt")
        else:
            print(f"Warning: Could not delete lab {lab_id}: {delete_response.status_code} - {delete_response.text}")
    else:
        print("No lab ID file found, skipping cleanup")
        
except Exception as e:
    print(f"Error during destroy: {str(e)}")
    sys.exit(0)  # Don't fail destroy on cleanup errors
PYTHON_EOF
    EOT
  }
}

# Read the imported lab ID
data "local_file" "lab_id" {
  filename   = "${path.module}/.lab_id.txt"
  depends_on = [null_resource.import_lab]
}

# Get lab details using the imported lab ID
data "cml2_lab" "imported_lab" {
  id         = trimspace(data.local_file.lab_id.content)
  depends_on = [null_resource.import_lab]
}

# Get topology elements (nodes and links) for lifecycle management
locals {
  # Parse the YAML to extract all node and link IDs for lifecycle management
  topology_nodes = [for node in local.topology_yaml.nodes : node.id]
  topology_links = [for link in local.topology_yaml.links : link.id]
  topology_elements = concat(local.topology_nodes, local.topology_links)
}

# Lifecycle configuration - start the lab automatically
resource "cml2_lifecycle" "lab_lifecycle" {
  lab_id   = data.cml2_lab.imported_lab.id
  elements = local.topology_elements
  
  # Define the lifecycle state
  state = var.auto_start ? "STARTED" : "DEFINED_ON_CORE"
  
  # Wait for nodes to be ready before considering deployment complete
  wait = var.wait_for_ready
}
