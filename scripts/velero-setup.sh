#!/usr/bin/env bash
#
# Install Velero on the AKS cluster using Azure Workload Identity.
#
# The Azure side (managed identity, role assignment, federated credential) is
# owned by Terraform. This script only covers the cluster side: the annotated
# service account and the Velero installation itself.
#
# Usage:
#   make setup-velero
#   ./scripts/velero-setup.sh

set -euo pipefail

AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-5e683e0f-b00c-48d6-9769-5aaf598de8f1}"
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-mpetitRG}"
AZURE_CLOUD_NAME="${AZURE_CLOUD_NAME:-AzurePublicCloud}"
CLUSTER_NAME="${CLUSTER_NAME:-aks-velero}"
IDENTITY_NAME="${IDENTITY_NAME:-id-velero}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-mpaccountstorage}"
BLOB_CONTAINER="${BLOB_CONTAINER:-storagevelerocontainer}"
VELERO_NAMESPACE="${VELERO_NAMESPACE:-velero}"
VELERO_PLUGIN="${VELERO_PLUGIN:-velero/velero-plugin-for-microsoft-azure:v1.13.0}"

CREDENTIALS_FILE=""

# The credentials file holds no secret, only identifiers, but it has no reason
# to outlive the install either.
velero_setup_cleanup() {
  [ -n "$CREDENTIALS_FILE" ] && rm -f "$CREDENTIALS_FILE"
}
trap velero_setup_cleanup EXIT

velero_setup_require_tools() {
  local tool
  local missing=0

  for tool in az kubectl velero; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'Missing required tool: %s\n' "$tool" >&2
      missing=1
    fi
  done

  return "$missing"
}

# Installing into the wrong cluster is the expensive mistake here, so refuse to
# run unless kubectl actually points at the expected one.
velero_setup_require_context() {
  local context

  context=$(kubectl config current-context 2>/dev/null || true)

  if [ -z "$context" ]; then
    printf 'No kubectl context. Run: az aks get-credentials -g %s -n %s\n' \
      "$AZURE_RESOURCE_GROUP" "$CLUSTER_NAME" >&2
    return 1
  fi

  if [ "$context" != "$CLUSTER_NAME" ]; then
    printf 'kubectl points at "%s" but this script targets "%s".\n' \
      "$context" "$CLUSTER_NAME" >&2
    return 1
  fi

  printf 'Target cluster: %s\n' "$context"
}

# The client ID comes from Azure rather than from `terraform output`, so this
# script does not depend on the remote state backend being configured.
velero_setup_resolve_client_id() {
  # Errors are swallowed so the caller can print an actionable message instead
  # of the raw ARM ResourceNotFound dump.
  az identity show \
    --subscription "$AZURE_SUBSCRIPTION_ID" \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$IDENTITY_NAME" \
    --query clientId -o tsv 2>/dev/null || true
}

# Terraform told Azure which service account may borrow the identity. This
# annotation tells the service account which identity to borrow. Both ends are
# required.
velero_setup_apply_service_account() {
  local client_id="$1"

  kubectl create namespace "$VELERO_NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: velero
  namespace: ${VELERO_NAMESPACE}
  annotations:
    azure.workload.identity/client-id: ${client_id}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: velero
subjects:
  - kind: ServiceAccount
    name: velero
    namespace: ${VELERO_NAMESPACE}
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
}

velero_setup_write_credentials() {
  CREDENTIALS_FILE=$(mktemp)

  cat > "$CREDENTIALS_FILE" <<EOF
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}
AZURE_CLOUD_NAME=${AZURE_CLOUD_NAME}
EOF
}

velero_setup_install() {
  if kubectl get deployment velero -n "$VELERO_NAMESPACE" >/dev/null 2>&1; then
    printf 'Velero is already installed in namespace "%s", skipping install.\n' \
      "$VELERO_NAMESPACE"
    return 0
  fi

  # --pod-labels is what makes the workload identity webhook inject the token.
  # Without it every other piece is correct and nothing works.
  velero install \
    --provider azure \
    --plugins "$VELERO_PLUGIN" \
    --bucket "$BLOB_CONTAINER" \
    --secret-file "$CREDENTIALS_FILE" \
    --namespace "$VELERO_NAMESPACE" \
    --service-account-name velero \
    --pod-labels azure.workload.identity/use=true \
    --use-volume-snapshots=false \
    --use-node-agent=false \
    --backup-location-config \
    useAAD=true,storageAccount="${STORAGE_ACCOUNT}",resourceGroup="${AZURE_RESOURCE_GROUP}"
}

velero_setup_verify() {
  printf 'Waiting for the Velero deployment to become available...\n'
  kubectl wait --for=condition=Available deployment/velero \
    -n "$VELERO_NAMESPACE" --timeout=180s

  velero backup-location get -n "$VELERO_NAMESPACE"
}

main() {
  local client_id

  velero_setup_require_tools
  velero_setup_require_context

  client_id=$(velero_setup_resolve_client_id)
  if [ -z "$client_id" ]; then
    printf 'Managed identity "%s" not found in resource group "%s".\n' \
      "$IDENTITY_NAME" "$AZURE_RESOURCE_GROUP" >&2
    printf 'Apply the Terraform identity resources first:\n' >&2
    printf '  terraform -chdir=terraform plan -out=tfplan.bin\n' >&2
    printf '  terraform -chdir=terraform apply tfplan.bin\n' >&2
    return 1
  fi
  printf 'Managed identity %s resolved.\n' "$IDENTITY_NAME"

  velero_setup_apply_service_account "$client_id"
  velero_setup_write_credentials
  velero_setup_install
  velero_setup_verify
}

main "$@"
