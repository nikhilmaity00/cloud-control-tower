# Cloud Control Tower

Cloud Control Tower is a small platform engineering project that validates application deployment configuration against predefined platform policies before provisioning infrastructure to Azure.

It demonstrates how YAML configuration, platform policy enforcement, Python validation, Terraform, Bash automation, and GitHub Actions work together in a simple infrastructure governance workflow.

The project is intentionally kept small so that each component has a clear purpose and can be explained independently.

---

## What Problem Does It Solve?

Application teams should not deploy infrastructure with arbitrary configurations.

Cloud Control Tower acts as a guardrail layer that validates deployment configuration before Terraform provisions Azure resources.

Platform controls currently include:

- Allowed deployment environments: `dev`, `test`, `prod`
- Minimum replica limits
- Maximum replica limits
- Application naming conventions
- Required configuration fields
- Rejection of unknown configuration fields

If a deployment violates the defined policy, validation fails and the deployment process stops.

---

## Architecture

```text
                    Developer
                        |
                        | Deployment YAML
                        v
                Cloud Control Tower
                        |
              +---------+---------+
              |                   |
              v                   v
        Python Validator      Terraform
              |                   |
        +-----+------+      +-----+------+
        |            |      |            |
     Schema       Policy   Policy     Azure IaC
   Validation   Validation Checks
        |            |      |            |
        +------------+------+------------+
                     |
                  Approved
                     |
                     v
              Azure Container Apps
```

---

## Repository Structure

```text
cloud-control-tower/
│
├── .github/
│   └── workflows/
│       └── control-tower.yml       # GitHub Actions CI workflow
│
├── control_tower/
│   ├── control_tower_validate.py   # Core validation logic
│   ├── __init__.py
│   └── policy.yaml                 # Central platform policy
│
├── deployments/
│   ├── example.yaml                # Sample deployment
│   └── orders-api.yaml             # Second deployment example
│
├── scripts/
│   ├── bootstrap.sh                # Azure session discovery and state handling
│   ├── deploy.sh                  # Local workflow: bootstrap, validate, plan
│   └── validate.sh                # Deployment validation wrapper
│
├── terraform/
│   ├── main.tf                    # Azure infrastructure
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
│
├── tests/
│   └── test_validate.py           # Python unit tests
│
├── README.md
└── requirements.txt
```

Local/generated files such as `.terraform/`, Terraform state, `terraform.tfvars`,
Python cache files, and `.kodekloud-session` are excluded through `.gitignore`.

---

# Configuration & Platform Policy

## Deployment Definition

Applications are described using YAML deployment definitions.

Example:

```yaml
application:
  name: payments-api
  image: mcr.microsoft.com/azuredocs/containerapps-helloworld:latest

deployment:
  environment: dev

  replicas:
    min: 1
    max: 1
```

A second deployment can define different values:

```yaml
application:
  name: orders-api
  image: mcr.microsoft.com/azuredocs/containerapps-helloworld:latest

deployment:
  environment: test

  replicas:
    min: 1
    max: 2
```

The deployment YAML represents the desired application deployment configuration.

---

## Platform Policy

Platform rules are defined in:

```text
control_tower/policy.yaml
```

Current allowed environments:

```yaml
environments:
  allowed:
    - dev
    - test
    - prod
```

Current replica policy:

```yaml
replicas:
  min:
    allowed:
      - 0
      - 1

  max:
    allowed:
      - 0
      - 1
      - 2
```

Current application naming policy:

```yaml
application:
  name:
    pattern: "^[a-z0-9][a-z0-9-]{2,29}$"
```

The same policy file is consumed by both the Python validator and Terraform.

This keeps policy values centralized rather than duplicating them in multiple
configuration files.

---

# Validation Engine

Validation is performed in two main areas.

## 1. Schema Validation

Python validates the structure of the deployment configuration.

Checks include:

- Required sections exist
- Required fields exist
- Expected objects are actually objects
- Replica values have the correct type
- Unknown fields are rejected
- Boolean values are not accepted as replica integers

For example, an unsupported field such as:

```yaml
application:
  name: payments-api
  image: example/image:latest
  owner: platform-team
```

is rejected because `owner` is not part of the current deployment schema.

---

## 2. Policy Validation

The deployment is checked against `control_tower/policy.yaml`.

Checks include:

- Environment must be allowed
- Minimum replicas must be allowed
- Maximum replicas must be allowed
- Minimum replicas cannot exceed maximum replicas
- Application name must follow the naming policy
- Application image must be present

For example:

```yaml
deployment:
  environment: dev

  replicas:
    min: 1
    max: 10
```

fails because `10` is not an allowed maximum replica count.

Example:

```text
Deployment validation: FAILED

  - deployment.replicas.max '10' is not allowed. Allowed values: [0, 1, 2].
```

The validator returns a non-zero exit code when validation fails.

---

## Run Validation Locally

Validate the sample deployment:

```bash
./scripts/validate.sh deployments/example.yaml
```

Expected result:

```text
Deployment validation: PASS

Application : payments-api
Environment : dev
Replicas    : 1-1
```

Validate the second deployment:

```bash
./scripts/validate.sh deployments/orders-api.yaml
```

Expected result:

```text
Deployment validation: PASS

Application : orders-api
Environment : test
Replicas    : 1-2
```

---

## Run Unit Tests

Run the Python test suite:

```bash
python3 -m unittest discover -s tests -v
```

The tests cover cases including:

- Valid deployment
- Invalid environment
- Invalid application name
- Missing image
- Invalid replica limits
- Minimum replicas greater than maximum replicas
- Missing required fields
- Unknown fields
- Invalid object structure
- Boolean replica values

---

# Deployment Workflow

The project intentionally separates automated validation and planning from
the final infrastructure deployment.

```text
Deployment YAML
      |
      v
Bootstrap
      |
      v
Schema & Policy Validation
      |
      v
Terraform Plan
      |
      v
Human Review
      |
      v
Terraform Apply (Manual)
      |
      v
Azure Container App
```

## Step 1 — Bootstrap

Start the deployment workflow with:

```bash
./scripts/deploy.sh deployments/example.yaml
```

The bootstrap process discovers the current Azure environment and prepares
Terraform for the current session.

It discovers:

- Azure subscription
- Azure tenant
- Azure resource group

## Step 2 — Validate

The deployment configuration is validated against the schema and platform
policy.

If validation fails, the process stops.

No Terraform deployment should proceed with an invalid configuration.

## Step 3 — Terraform Plan

The deployment workflow generates a Terraform plan:

```bash
cd terraform
terraform validate
terraform plan -input=false
```

Planning does not create or modify Azure resources.

## Step 4 — Manual Terraform Apply

The final infrastructure change is intentionally a manual action.

After reviewing the Terraform plan:

```bash
cd terraform
terraform apply -input=false
```

The current deployment creates:

- Azure Log Analytics Workspace
- Azure Container Apps Environment
- Azure Container App

## Step 5 — Verify the Deployment

View Terraform outputs:

```bash
terraform output
```

Then test the Container App endpoint:

```bash
curl https://<container-app-hostname>
```

A successful response confirms that the Container App is running.

---

# KodeKloud Ephemeral Environment

This project was developed and tested using a temporary KodeKloud Azure
environment.

This environment is different from a permanent production Azure environment.

## Environment Constraints

The KodeKloud environment is ephemeral.

This means:

- Azure sessions can expire
- A new session can provide a different resource group
- Resources from a previous session may no longer be accessible
- Local Terraform state may reference resources from an expired session
- Azure authentication must be established again for a new session

Because of this, the project does not hard-code the KodeKloud resource group.

## Dynamic Session Discovery

`scripts/bootstrap.sh` discovers the current Azure context using Azure CLI.

```text
KodeKloud Azure Session
        |
        v
     Azure CLI
        |
        +---- Subscription ID
        |
        +---- Tenant ID
        |
        +---- Resource Group
        |
        v
Terraform Environment
```

This allows the deployment workflow to adapt to the current KodeKloud session.

## Session Change Detection

The bootstrap script stores a local session marker:

```text
terraform/.kodekloud-session
```

On subsequent runs, the current Azure context is compared with the previous
session information.

```text
Current Azure Context
        |
        v
Compare with .kodekloud-session
        |
        +---- Same session ----> Continue
        |
        +---- New session -----> Reset stale local state
                                      |
                                      v
                              Configure new session
```

## Why Terraform State Is Reset

Terraform state records the Azure resources that Terraform manages.

In a permanent environment, that state is normally retained and reused.

In an ephemeral KodeKloud environment, a new session may point to a different
resource group.

For example:

```text
Session A
    |
    +--> Resource Group A
    +--> Azure resources
    +--> Terraform state
    |
    X
Session expires
    |
    v
Session B
    |
    +--> Resource Group B
    +--> Different Azure environment
```

Terraform state from Session A may therefore reference resources that are no
longer accessible in Session B.

The bootstrap script detects this session change and removes stale local
Terraform state and backup state.

This allows Terraform to initialize the new session as a fresh deployment
target.

## Local Environment Files

The following files are environment-specific and intentionally excluded from Git:

```text
terraform/.kodekloud-session
terraform/terraform.tfstate
terraform/terraform.tfstate.*
terraform/terraform.tfvars
.terraform/
__pycache__/
```

## Production Difference

The session-reset approach is specifically an adaptation for the temporary
KodeKloud learning environment.

It is **not** a recommended production Terraform state strategy.

In a permanent production environment, Terraform would normally use persistent
remote state storage, such as an Azure Storage backend, with appropriate state
locking and access controls.

The key design principle is:

```text
Discover current environment
          |
          v
Detect session changes
          |
          v
Handle stale local state
          |
          v
Configure Terraform
          |
          v
Deploy to current session
```

---

# CI/CD Model

This project uses **automated Continuous Integration with a controlled manual
deployment process**.

It is intentionally not presented as a fully automated production CD system.

## Continuous Integration — Automated

GitHub Actions is defined in:

```text
.github/workflows/control-tower.yml
```

The workflow runs for pull requests and pushes to `main`.

The CI workflow:

1. Checks out the repository
2. Sets up Python
3. Installs dependencies
4. Runs unit tests
5. Runs deployment validation

Invalid deployments fail the CI check.

The GitHub Actions workflow does **not** automatically deploy infrastructure
to Azure.

## Controlled Deployment — Manual Apply

After a change passes CI and is merged:

```text
main
 |
 v
./scripts/deploy.sh
 |
 +--> Bootstrap
 |
 +--> Deployment validation
 |
 +--> Terraform plan
 |
 v
Human review
 |
 v
terraform apply
 |
 v
Azure Container App
```

The final `terraform apply` is manual.

This provides a clear separation between:

- Automated validation
- Infrastructure planning
- Human-approved infrastructure changes

---

# End-to-End Example

## 1. Define a deployment

```yaml
application:
  name: payments-api
  image: mcr.microsoft.com/azuredocs/containerapps-helloworld:latest

deployment:
  environment: dev

  replicas:
    min: 1
    max: 1
```

## 2. Validate

```bash
./scripts/validate.sh deployments/example.yaml
```

Expected:

```text
Deployment validation: PASS
```

## 3. Run the deployment workflow

```bash
./scripts/deploy.sh deployments/example.yaml
```

This performs:

```text
Bootstrap
    |
    v
Validation
    |
    v
Terraform Plan
```

No infrastructure is applied by this command.

## 4. Review Terraform

```bash
cd terraform
terraform validate
terraform plan -input=false
```

Review the proposed changes.

## 5. Apply manually

```bash
terraform apply -input=false
```

Confirm the Terraform operation after reviewing the plan.

## 6. Verify Azure

```bash
terraform output
```

Then test the Container App endpoint:

```bash
curl https://<container-app-hostname>
```

---

# Example of a Rejected Deployment

Consider:

```yaml
deployment:
  environment: dev

  replicas:
    min: 1
    max: 10
```

The platform policy only allows:

```text
Maximum replicas: 0, 1, 2
```

Running:

```bash
./scripts/validate.sh deployments/example.yaml
```

results in:

```text
Deployment validation: FAILED
```

The invalid deployment is rejected before the normal deployment workflow can
continue.

```text
Invalid Configuration
        |
        v
     Validation
        |
        v
      REJECT
        |
        X
   No Deployment
```

---

# Technology Stack

- **Cloud Provider:** Microsoft Azure
- **Compute:** Azure Container Apps
- **Logging:** Azure Log Analytics
- **Infrastructure as Code:** Terraform
- **Policy & Validation:** Python 3, PyYAML
- **Automation:** Bash
- **Version Control:** Git / GitHub
- **CI:** GitHub Actions

---

# Project Scope

This project is a learning implementation of a small internal platform /
deployment control tower.

The project demonstrates:

- Infrastructure as Code with Terraform
- Azure Container Apps deployment
- YAML-based deployment configuration
- Deployment schema validation
- Platform policy validation
- Terraform policy enforcement
- Bash automation
- GitHub Actions CI
- Python unit testing
- Handling temporary KodeKloud Azure environments
- Separation between validation, planning, and deployment

The project intentionally avoids unnecessary complexity so that each component
has a clear purpose and can be explained independently.

For a production implementation, additional capabilities such as persistent
Terraform remote state, dedicated Azure authentication for CI/CD, secrets
management, and a fully automated deployment pipeline could be introduced.
These are outside the scope of this learning project.