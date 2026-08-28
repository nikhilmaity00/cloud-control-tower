#!/usr/bin/env bash

set -euo pipefail

echo "--------------------------------"
echo "Cloud Control Tower bootstrap"
echo "--------------------------------"

# Verify Azure CLI authentication
if ! az account show >/dev/null 2>&1; then
    echo "ERROR: Azure CLI session is not authenticated."
    echo "Please authenticate with the KodeKloud Azure playground first."
    exit 1
fi

# Discover Azure context
subscription_id="$(az account show --query id -o tsv)"
tenant_id="$(az account show --query tenantId -o tsv)"

# Discover resource groups
resource_groups="$(az group list --query "[].name" -o tsv)"

# Remove empty lines
resource_groups="$(printf '%s\n' "$resource_groups" | sed '/^$/d')"

resource_group_count="$(printf '%s\n' "$resource_groups" | wc -l | tr -d ' ')"

if [[ "$resource_group_count" -eq 0 ]]; then
    echo "ERROR: No Azure resource group was found."
    exit 1
fi

if [[ "$resource_group_count" -gt 1 ]]; then
    echo "ERROR: Multiple resource groups were found:"
    printf '%s\n' "$resource_groups" | sed 's/^/  - /'
    exit 1
fi

resource_group_name="$resource_groups"

# Generate Terraform variable file
cat > terraform/terraform.tfvars <<EOF
resource_group_name = "$resource_group_name"
subscription_id     = "$subscription_id"
EOF

echo "Subscription  : $subscription_id"
echo "Tenant        : $tenant_id"
echo "Resource Group: $resource_group_name"
echo "--------------------------------"
echo "Generated: terraform/terraform.tfvars"
echo "--------------------------------"