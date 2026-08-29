Here is the clean, consolidated `README.md` file formatted specifically for clear readability without being over-documented.

```markdown
# Cloud Control Tower

Cloud Control Tower is a platform engineering project that validates application deployment configuration against predefined platform policies before provisioning infrastructure to Azure.

It demonstrates how YAML configurations, platform policy enforcement, Python validation, Terraform, Bash automation, and GitHub Actions work together in an infrastructure governance workflow.

---

## What Problem Does It Solve?

Application teams should not deploy infrastructure with arbitrary configurations. Cloud Control Tower acts as a guardrail layer that enforces policy compliance prior to running Terraform.

**Platform controls include:**
- Allowed deployment environments (`dev`, `test`, `prod`)
- Min/Max replica bounds (e.g., maximum allowed replicas capped at 2)
- Strict application naming patterns
- Required configuration fields (rejects unknown/arbitrary YAML fields)

If a configuration violates platform policy, execution halts immediately before any cloud resources are touched.

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

## Ephemeral Lab Adaptation (KodeKloud Sessions)

This project was developed and tested within temporary Azure lab sessions (KodeKloud).

Because lab environments are ephemeral, session expiration introduces specific challenges:

* Resource group names change across sessions.
* Existing local Terraform state files (`.tfstate`) reference inaccessible resources from expired sessions.

### Dynamic Session Handling

To solve this, `scripts/bootstrap.sh` performs automated session discovery and stale-state cleanup:

```text
Current Azure context
        |
        v
Compare with terraform/.kodekloud-session
        |
        +---- Same session ----> Continue with existing plan
        |
        +---- New session -----> Remove stale local .tfstate
                                       |
                                       v
                                Configure new session targets

```

*(In a permanent production environment, this would instead use persistent remote backend storage such as Azure Blob Storage with state locking).*

---

## Repository Structure

```text
cloud-control-tower/
├── .github/
│   └── workflows/
│       └── control-tower.yml       # GitHub Actions CI workflow
├── control_tower/
│   ├── control_tower_validate.py   # Core validation logic
│   ├── __init__.py
│   └── policy.yaml                 # Central platform policy definition
├── deployments/
│   ├── example.yaml                # Sample application deployment spec
│   └── orders-api.yaml
├── scripts/
│   ├── bootstrap.sh                # Azure session discovery & state management
│   ├── deploy.sh                   # Local workflow runner (validate + plan)
│   └── validate.sh                 # Validation test script
├── terraform/
│   ├── main.tf                     # Azure Container Apps & Log Analytics IaC
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
├── tests/
│   └── test_validate.py            # Unit test suite for Python validator
├── README.md
└── requirements.txt

```

> **Note:** Local and sensitive files (`.terraform/`, `*.tfstate`, `terraform.tfvars`, `__pycache__`, `.kodekloud-session`) are excluded via `.gitignore`.

---

## Configuration & Policy

### 1. Deployment Definition (`deployments/example.yaml`)

Applications define their target configuration in simple YAML:

```yaml
application:
  name: payments-api
  image: [mcr.microsoft.com/azuredocs/containerapps-helloworld:latest](https://mcr.microsoft.com/azuredocs/containerapps-helloworld:latest)

deployment:
  environment: dev
  replicas:
    min: 1
    max: 1

```

### 2. Platform Policy (`control_tower/policy.yaml`)

Central governance rules consumed by both the Python validator and Terraform:

```yaml
environments:
  allowed:
    - dev
    - test
    - prod

replicas:
  min:
    allowed: [0, 1]
  max:
    allowed: [0, 1, 2]

application:
  name:
    pattern: "^[a-z0-9][a-z0-9-]{2,29}$"

```

---

## Validation Engine

Validation operates in two stages:

1. **Schema Validation:** Verifies structural integrity, required blocks, expected types, and rejects unknown fields (e.g., adding an unapproved `owner` key).
2. **Policy Validation:** Asserts values match `policy.yaml` constraints (e.g., rejecting `replicas.max: 10` or invalid environment names).

### Run Validation Locally

```bash
# Validate sample deployment
./scripts/validate.sh deployments/example.yaml

# Run test suite
python3 -m unittest discover -s tests -v

```

---

## Deployment Workflow

```text
Deployment YAML
      |
      v
Bootstrap (Session Detection)
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

### 1. CI Pipeline (Automated)

GitHub Actions (`.github/workflows/control-tower.yml`) runs on PRs and pushes to `main`:

* Runs Python unit tests
* Executes schema and policy validation against deployment manifests
* Fails the build on policy violations to prevent bad merges

### 2. Local Preparation

Run the automated bootstrap, validation, and planning script:

```bash
./scripts/deploy.sh deployments/example.yaml

```

### 3. Review & Apply (Manual Gate)

Apply infrastructure changes explicitly after reviewing the plan:

```bash
cd terraform
terraform plan -input=false
terraform apply -input=false

```

### 4. Verification

Retrieve the provisioned Container App FQDN:

```bash
# View output URL
terraform output

# Test endpoint
curl https://<container-app-hostname>

```

---

## Tech Stack

* **Cloud Provider:** Microsoft Azure (Container Apps, Log Analytics Workspace)
* **Infrastructure as Code:** Terraform
* **Policy & Automation:** Python 3, PyYAML, Bash
* **CI/CD:** GitHub Actions

```

```