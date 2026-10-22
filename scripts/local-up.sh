#!/usr/bin/env bash
# Run the whole platform on a local kind cluster: same manifests as AWS, with in-cluster databases.
# Requires: docker, kind (>= 0.24, whose default CNI enforces NetworkPolicies), kubectl.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="ecommerce"
SERVICES=(eureka-server config-server api-gateway product-service order-service)
DB_DIR="$ROOT/k8s/overlays/local/databases"

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
fi

for svc in "${SERVICES[@]}"; do
  echo ">> Building $svc"
  docker build -t "ecommerce/$svc:local" "$ROOT/$svc"
  kind load docker-image "ecommerce/$svc:local" --name "$CLUSTER"
done

# Local DB credentials: random per machine, never committed (see .gitignore)
for db in product-db order-db; do
  if [[ ! -f "$DB_DIR/$db.env" ]]; then
    sed "s/change-me-local-only/$(openssl rand -hex 16)/" "$DB_DIR/$db.env.example" > "$DB_DIR/$db.env"
  fi
done

kubectl apply -k "$ROOT/k8s/overlays/local"

echo ">> Waiting for rollouts"
for svc in "${SERVICES[@]}"; do
  kubectl -n ecommerce rollout status "deployment/$svc" --timeout=10m
done

echo ">> Ready. In another terminal:"
echo "   kubectl -n ecommerce port-forward svc/api-gateway 8080:8080"
echo "   curl http://localhost:8080/api/products"
