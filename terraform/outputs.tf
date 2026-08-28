output "resource_group_name" {
  description = "The KodeKloud resource group used by the project."
  value       = data.azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "The location of the KodeKloud resource group."
  value       = data.azurerm_resource_group.main.location
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace used by the Control Tower."
  value       = azurerm_log_analytics_workspace.control_tower.name
}

output "container_app_url" {
  description = "Public URL of the demo Container App."
  value       = "https://${azurerm_container_app.demo.latest_revision_fqdn}"
}