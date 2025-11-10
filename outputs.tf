# Lab Information
output "lab_id" {
  description = "The ID of the provisioned CML lab"
  value       = data.cml2_lab.imported_lab.id
}

output "lab_title" {
  description = "The title of the provisioned lab"
  value       = data.cml2_lab.imported_lab.lab.title
}

output "lab_state" {
  description = "Current state of the lab lifecycle"
  value       = cml2_lifecycle.lab_lifecycle.state
}

# Node Information
output "node_count" {
  description = "Total number of nodes in the lab"
  value       = data.cml2_lab.imported_lab.lab.node_count
}

output "link_count" {
  description = "Total number of links in the lab"
  value       = data.cml2_lab.imported_lab.lab.link_count
}

output "booted" {
  description = "Whether all nodes have booted"
  value       = cml2_lifecycle.lab_lifecycle.booted
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of the lab deployment"
  value       = <<-EOT
  
  ═══════════════════════════════════════════════════════════
  CML Lab Deployment Summary
  ═══════════════════════════════════════════════════════════
  Lab ID:          ${data.cml2_lab.imported_lab.id}
  Lab Title:       ${data.cml2_lab.imported_lab.lab.title}
  Lab State:       ${cml2_lifecycle.lab_lifecycle.state}
  Total Nodes:     ${data.cml2_lab.imported_lab.lab.node_count}
  Total Links:     ${data.cml2_lab.imported_lab.lab.link_count}
  All Booted:      ${cml2_lifecycle.lab_lifecycle.booted}
  Topology Source: ${local.topology_file}
  ═══════════════════════════════════════════════════════════
  
  Access your lab at: ${var.cml_address}
  EOT
}
