data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

locals {
  deployment = yamldecode(
    file("${path.root}/${var.deployment_file}")
  )

  policy = yamldecode(
    file("${path.root}/../control_tower/policy.yaml")
  )

  application       = local.deployment.application
  deployment_config = local.deployment.deployment
  replicas          = local.deployment.deployment.replicas

  allowed_environments = local.policy.environments.allowed
  allowed_min_replicas = local.policy.replicas.min.allowed
  allowed_max_replicas = local.policy.replicas.max.allowed
}

check "deployment_policy" {
  assert {
    condition = (
      contains(local.allowed_environments, local.deployment_config.environment)
      &&
      contains(local.allowed_min_replicas, local.replicas.min)
      &&
      contains(local.allowed_max_replicas, local.replicas.max)
      &&
      local.replicas.min <= local.replicas.max
    )

    error_message = "Deployment violates the Cloud Control Tower policy."
  }
}
resource "azurerm_log_analytics_workspace" "control_tower" {
  name                = "ct-law"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  sku               = "PerGB2018"
  retention_in_days = 30
  daily_quota_gb    = 1
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
  name                         = local.application.name
  container_app_environment_id = azurerm_container_app_environment.control_tower.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  lifecycle {
    precondition {
      condition     = contains(local.allowed_min_replicas, local.replicas.min)
      error_message = "Cloud Control Tower policy violation: minimum replicas are not allowed."
    }

    precondition {
      condition     = contains(local.allowed_max_replicas, local.replicas.max)
      error_message = "Cloud Control Tower policy violation: maximum replicas are not allowed."
    }

    precondition {
      condition     = local.replicas.min <= local.replicas.max
      error_message = "Cloud Control Tower policy violation: minimum replicas cannot exceed maximum replicas."
    }
  }

  template {
    min_replicas = local.replicas.min
    max_replicas = local.replicas.max

    container {
      name   = local.application.name
      image  = local.application.image
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