#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-/opt/todolist/prod/k8s}"
IMAGE_TAG="${2:-latest}"
DB_HOST="${3:-127.0.0.1}"
DB_PORT="${4:-5432}"
DB_NAME="${5:-todolist_prod}"
DB_USER="${6:-todo_prod_user}"
DB_PASSWORD="${7:-}"
KUBE_CONTEXT="${8:-kind-todo-prod}"
CLUSTER_NAME="${9:-todo-prod}"
DOCKER_REPO="${10:-buiminh03}"

mkdir -p "$TARGET_DIR/postgres"

cat > "$TARGET_DIR/postgres/secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: todolist
type: Opaque
stringData:
  POSTGRES_USER: ${DB_USER}
  POSTGRES_PASSWORD: ${DB_PASSWORD}
  POSTGRES_DB: ${DB_NAME}
EOF

cat > "$TARGET_DIR/backend/configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: todolist
data:
  DATABASE_HOST: "${DB_HOST}"
  DATABASE_PORT: "${DB_PORT}"
  DATABASE_NAME: "${DB_NAME}"
  PORT: "5000"
  NODE_ENV: "production"
EOF

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is required on the Application EC2 host"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required on the Application EC2 host"
  exit 1
fi

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "Creating kind cluster $CLUSTER_NAME"
  kind create cluster --name "$CLUSTER_NAME" --config "$TARGET_DIR/kind-config.yaml"
fi

kubectl config use-context "$KUBE_CONTEXT" >/dev/null 2>&1 || true
kubectl apply -k "$TARGET_DIR"

kubectl set image deployment/backend backend=${DOCKER_REPO}/vntechies-todolist-backend:${IMAGE_TAG} -n todolist
kubectl set image deployment/frontend frontend=${DOCKER_REPO}/vntechies-todolist-frontend:${IMAGE_TAG} -n todolist
kubectl rollout status deployment/backend -n todolist --timeout=300s
kubectl rollout status deployment/frontend -n todolist --timeout=300s
