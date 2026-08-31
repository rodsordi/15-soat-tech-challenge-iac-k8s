#!/usr/bin/env bash
# Uso: source use-kubeconfig.sh
# Atualiza o KUBECONFIG local apontando para o cluster EKS criado pelo Terraform.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

CLUSTER_NAME="$(terraform -chdir="$SCRIPT_DIR" output -raw eks_cluster_name 2>/dev/null)"
AWS_REGION="$(terraform -chdir="$SCRIPT_DIR" output -raw aws_region 2>/dev/null || echo "us-east-1")"

if [ -z "$CLUSTER_NAME" ]; then
  echo "Error: Could not obtain EKS cluster name. Run 'terraform apply' first." >&2
  return 1 2>/dev/null || exit 1
fi

echo "Updating kubeconfig for cluster: $CLUSTER_NAME in region: $AWS_REGION..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

