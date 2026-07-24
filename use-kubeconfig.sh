#!/usr/bin/env bash
# Uso: source iac/use-kubeconfig.sh
# Exporta KUBECONFIG apontando para o cluster criado pelo terraform apply.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

KUBECONFIG_PATH="$(terraform -chdir="$SCRIPT_DIR" output -raw kubeconfig_path 2>/dev/null)"

if [ -z "$KUBECONFIG_PATH" ] || [ ! -f "$KUBECONFIG_PATH" ]; then
  echo "Could not obtain kubeconfig. Run 'terraform apply' first." >&2
  return 1 2>/dev/null || exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"
echo "KUBECONFIG redefined to: $KUBECONFIG_PATH"
