# CML Server Connection Variables
variable "cml_address" {
  description = "CML server address (e.g., https://cml-controller.example.com) - NO trailing slash"
  type        = string
  
  validation {
    condition     = can(regex("^https://[^/]+$", var.cml_address))
    error_message = "The cml_address must start with https:// and must NOT have a trailing slash."
  }
}

variable "cml_username" {
  description = "CML server username"
  type        = string
  sensitive   = true
}

variable "cml_password" {
  description = "CML server password"
  type        = string
  sensitive   = true
}

variable "cml_skip_verify" {
  description = "Skip TLS certificate verification (use true for self-signed certs)"
  type        = bool
  default     = false
}

# Lab Configuration Variables
variable "lab_folder" {
  description = "Lab folder containing the topology YAML file (e.g., lab01, lab02)"
  type        = string
  default     = "lab01"
}

variable "topology_filename" {
  description = "Name of the topology YAML file within the lab folder"
  type        = string
  default     = "TF_-_Topo_Automation.yaml"
}

variable "lab_title" {
  description = "Custom title for the lab (defaults to title from YAML if empty)"
  type        = string
  default     = ""
}

variable "lab_description" {
  description = "Custom description for the lab (defaults to generated description if empty)"
  type        = string
  default     = ""
}

# Lifecycle Configuration Variables
variable "auto_start" {
  description = "Automatically start the lab nodes after provisioning"
  type        = bool
  default     = true
}

variable "wait_for_ready" {
  description = "Wait for nodes to be in BOOTED state before completing deployment"
  type        = bool
  default     = true
}
