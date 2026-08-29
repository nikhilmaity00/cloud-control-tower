#!/usr/bin/env bash

# ------------------------------------------------------------
# Cloud Deployment Control Tower
# KodeKloud Azure session bootstrap
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
SESSION_FILE="$TERRAFORM_DIR/.kodekloud-session"
STATE_FILE="$TERRAFORM_DIR/terraform.tfstate"
BACKUP_STATE_FILE="$TERRAFORM_DIR/terraform.tfstate.backup"

bootstrap() {

    echo "--------------------------------"
    echo "Cloud Control Tower bootstrap"
    echo "--------------------------------"

    # --------------------------------------------------------
    # 1. Verify Azure CLI authentication
    # --------------------------------------------------------

    if ! az account show >/dev/null 2>&1; then
        echo "ERROR: Azure CLI is not authenticated."
        echo
        echo "Start or reconnect your KodeKloud Azure session and try again."
        return 1
    fi

    # --------------------------------------------------------
    # 2. Discover current Azure context
    # --------------------------------------------------------

    local subscription_id
    local tenant_id

    subscription_id="$(az account show --query id -o tsv)"
    tenant_id="$(az account show --query tenantId -o tsv)"

    if [[ -z "$subscription_id" || -z "$tenant_id" ]]; then
        echo "ERROR: Unable to determine Azure subscription or tenant."
        return 1
    fi

    # --------------------------------------------------------
    # 3. Discover KodeKloud resource group
    # --------------------------------------------------------

    local resource_groups
    local resource_group_count
    local resource_group_name

    resource_groups="$(az group list --query "[].name" -o tsv)"
    resource_groups="$(printf '%s\n' "$resource_groups" | sed '/^$/d')"

    resource_group_count="$(
        printf '%s\n' "$resource_groups" |
        wc -l |
        tr -d ' '
    )"

    if [[ "$resource_group_count" -eq 0 ]]; then
        echo "ERROR: No resource group was found in the current Azure session."
        return 1
    fi

    if [[ "$resource_group_count" -gt 1 ]]; then
        echo "ERROR: Multiple resource groups were found:"
        echo
        printf '%s\n' "$resource_groups" | sed 's/^/  - /'
        echo
        echo "The bootstrap script expects exactly one KodeKloud resource group."
        return 1
    fi

    resource_group_name="$resource_groups"

    # --------------------------------------------------------
    # 4. Build session identity
    # --------------------------------------------------------

    local current_session
    current_session="${subscription_id}|${tenant_id}|${resource_group_name}"

    # --------------------------------------------------------
    # 5. Display discovered environment
    # --------------------------------------------------------

    echo "Subscription  : $subscription_id"
    echo "Tenant        : $tenant_id"
    echo "Resource Group: $resource_group_name"
    echo "--------------------------------"

    # --------------------------------------------------------
    # 6. Detect KodeKloud session changes
    # --------------------------------------------------------

    local session_changed=false

    if [[ -f "$SESSION_FILE" ]]; then

        local previous_session
        previous_session="$(cat "$SESSION_FILE")"

        if [[ "$previous_session" != "$current_session" ]]; then
            session_changed=true

            echo "KodeKloud session change detected."
            echo
            echo "Previous session:"
            echo "  $previous_session"
            echo
            echo "Current session:"
            echo "  $current_session"
            echo
            echo "The existing Terraform state belongs to the previous"
            echo "session and will be removed."
            echo
        fi
    fi

    # --------------------------------------------------------
    # 7. Reset stale Terraform state
    # --------------------------------------------------------

    if [[ "$session_changed" == true ]]; then

        if [[ -f "$STATE_FILE" ]]; then
            echo "Removing stale Terraform state..."
            rm -f "$STATE_FILE"
        fi

        if [[ -f "$BACKUP_STATE_FILE" ]]; then
            echo "Removing stale Terraform state backup..."
            rm -f "$BACKUP_STATE_FILE"
        fi

        echo "Terraform state reset complete."
        echo
    fi

    # --------------------------------------------------------
    # 8. Generate Terraform variables
    # --------------------------------------------------------

    cat > "$TFVARS_FILE" <<EOF
resource_group_name = "$resource_group_name"
EOF

    # --------------------------------------------------------
    # 9. Export Terraform/Azure environment
    # --------------------------------------------------------

    export ARM_SUBSCRIPTION_ID="$subscription_id"
    export ARM_TENANT_ID="$tenant_id"
    export TF_VAR_resource_group_name="$resource_group_name"

    # --------------------------------------------------------
    # 10. Save session marker
    # --------------------------------------------------------

    printf '%s\n' "$current_session" > "$SESSION_FILE"

    # --------------------------------------------------------
    # 11. Final status
    # --------------------------------------------------------

    echo "Terraform environment configured."
    echo "--------------------------------"
    echo "Terraform variables:"
    echo "  $TFVARS_FILE"
    echo
    echo "Session marker:"
    echo "  $SESSION_FILE"
    echo
    echo "Current resource group:"
    echo "  $resource_group_name"
    echo
    echo "ARM_SUBSCRIPTION_ID:"
    echo "  $ARM_SUBSCRIPTION_ID"
    echo
    echo "ARM_TENANT_ID:"
    echo "  $ARM_TENANT_ID"
    echo
    echo "Ready for Terraform."
    echo "--------------------------------"
}

# ------------------------------------------------------------
# Execute only when run directly or explicitly sourced
# ------------------------------------------------------------

bootstrap