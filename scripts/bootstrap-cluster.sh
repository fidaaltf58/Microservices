#!/usr/bin/env bash
# One-time cluster-admin setup after `terraform apply`:
#   - External Secrets Operator (IRSA role from Terraform) + a ClusterSecretStore limited to the app namespace
#   - metrics-server (for the HorizontalPodAutoscalers)
#   - the application namespace with Pod Security Admission "restricted"
# CI/CD then deploys into that namespace with a namespace-scoped role only.
set -euo pipefail

ESO_CHART_VERSION="2.13.0"
METRICS_SERVER_CHART_VERSION="3.14.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT/infra/terraform"

tf_out() { terraform -chdir="$TF_DIR" output -raw "$1"; }

REGION="$(tf_out region)"
CLUSTER="$(tf_out cluster_name)"
ESO_ROLE_ARN="$(tf_out external_secrets_role_arn)"

echo ">> Configuring kubectl for $CLUSTER ($REGION)"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"

echo ">> Installing External Secrets Operator $ESO_CHART_VERSION"
helm repo add external-secrets https://charts.external-secrets.io >/dev/null
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null
helm repo update >/dev/null
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --version "$ESO_CHART_VERSION" \
  --set installCRDs=true \
  --set serviceAccount.name=external-secrets \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$ESO_ROLE_ARN" \
  --wait

echo ">> Installing metrics-server $METRICS_SERVER_CHART_VERSION"
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version "$METRICS_SERVER_CHART_VERSION" \
  --wait

echo ">> Creating the application namespace (PSA restricted)"
kubectl apply -k "$ROOT/k8s/namespace"

echo ">> Creating the ClusterSecretStore (usable from the ecommerce namespace only)"
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  conditions:
    - namespaces: ["ecommerce"]
  provider:
    aws:
      service: SecretsManager
      region: $REGION
EOF

echo ">> Done. Deploy with the 'Deploy to EKS' GitHub Actions workflow."
