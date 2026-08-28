variable "resource_group_name" {
  description = "Name of the existing Azure resource group provided by KodeKloud."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "resource_group_name must not be empty."
  }
}

variable "subscription_id" {
  description = "Azure subscription ID for the current KodeKloud session."
  type        = string
  nullable    = false

  validation {
    condition = can(regex(
      "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
      var.subscription_id
    ))

    error_message = "subscription_id must be a valid Azure subscription UUID."
  }
}