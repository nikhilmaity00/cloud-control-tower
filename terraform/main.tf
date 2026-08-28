data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_log_analytics_workspace" "control_tower" {
  name                = "ct-law"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  sku               = "PerGB2018"
  retention_in_days = 30

  daily_quota_gb = 1
}

resource "azurerm_container_app_environment" "control_tower" {
  name                       = "container-app-env"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.control_tower.id


  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_container_app" "demo" {
  name                         = "ct-demo-app"
  container_app_environment_id = azurerm_container_app_environment.control_tower.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "demo"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}