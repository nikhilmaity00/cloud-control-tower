# Cloud Control Tower

A small platform engineering project that validates application deployment
configuration before allowing Terraform to create Azure infrastructure.

The project demonstrates a simple governance workflow using Python, YAML,
Terraform, Bash, Azure, and GitHub Actions.

## What problem does it solve?

Application teams should not be able to deploy infrastructure with arbitrary
settings.

Cloud Control Tower provides a simple validation layer that checks deployment
configuration against predefined platform policies.

For example, the platform can control:

- Allowed environments
- Minimum replica counts
- Maximum replica counts
- Application naming conventions
- Required deployment fields

Invalid deployments are rejected before Terraform creates infrastructure.

## Architecture

```text
Developer
   |
   | deployment YAML
   v
Cloud Control Tower
   |
   +--> Python validation
   |      |
   |      +--> Schema validation
   |      +--> Policy validation
   |
   +--> Terraform policy checks
   |
   v
Azure Container Apps