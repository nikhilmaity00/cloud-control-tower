variable "resource_group_name" {
  description = "Name of the existing Azure resource group provided by KodeKloud."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "resource_group_name must not be empty."
  }
}

variable "deployment_file" {
  description = "Path to the deployment intent YAML file."
  type        = string
  nullable    = false
  default     = "../deployments/example.yaml"

  validation {
    condition     = length(trimspace(var.deployment_file)) > 0
    error_message = "deployment_file must not be empty."
  }
}
