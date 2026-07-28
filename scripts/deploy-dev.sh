#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-/opt/todolist/dev}"
IMAGE_TAG="${2:-latest}"
DB_HOST="${3:-127.0.0.1}"
DB_PORT="${4:-5432}"
DB_NAME="${5:-todolist_dev}"
DB_USER="${6:-todo_dev_user}"
# The password is supplied as argument seven for local use, or through the
# environment by the Jenkins pipeline so it never appears in an SSH command.
DB_PASSWORD="${7:-${DB_PASSWORD:-}}"
BACKEND_PORT="${8:-5000}"
FRONTEND_PORT="${9:-3000}"
NEXT_PUBLIC_API_URL="${10:-http://127.0.0.1:5000/api}"
DOCKER_REPO="${11:-buiminh03}"

if [[ -z "$DB_PASSWORD" ]]; then
  echo "DB password is required"
  exit 1
fi

# Files generated below contain the database password.
umask 077

mkdir -p "$TARGET_DIR"

cat > "$TARGET_DIR/promtail-config.yaml" <<'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0
positions:
  filename: /var/lib/promtail/positions.yaml
clients:
  - url: http://10.0.1.10:3100/loki/api/v1/push
scrape_configs:
  - job_name: todolist-dev-containers
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 10s
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        regex: /todolist-(backend|frontend)-dev
        action: keep
      - source_labels: [__meta_docker_container_name]
        regex: /todolist-(backend|frontend)-dev
        target_label: service
        replacement: $1
      - target_label: environment
        replacement: dev
    pipeline_stages:
      - docker: {}
EOF

cat > "$TARGET_DIR/.env" <<EOF
IMAGE_TAG=${IMAGE_TAG}
DATABASE_HOST=${DB_HOST}
DATABASE_PORT=${DB_PORT}
DATABASE_NAME=${DB_NAME}
DATABASE_USER=${DB_USER}
DATABASE_PASSWORD=${DB_PASSWORD}
BACKEND_PORT=${BACKEND_PORT}
FRONTEND_PORT=${FRONTEND_PORT}
NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
EOF

cat > "$TARGET_DIR/docker-compose.yml" <<EOF
services:
  backend:
    image: ${DOCKER_REPO}/vntechies-todolist-backend:${IMAGE_TAG}
    container_name: todolist-backend-dev
    restart: unless-stopped
    environment:
      DATABASE_HOST: ${DB_HOST}
      DATABASE_PORT: ${DB_PORT}
      DATABASE_NAME: ${DB_NAME}
      DATABASE_USER: ${DB_USER}
      DATABASE_PASSWORD: ${DB_PASSWORD}
      PORT: "5000"
      NODE_ENV: production
    ports:
      - "${BACKEND_PORT}:5000"
    healthcheck:
      test: ["CMD-SHELL", "node -e \"require('http').get('http://127.0.0.1:5000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))\""]
      interval: 15s
      timeout: 3s
      retries: 5
      start_period: 20s
    networks:
      - application-network

  frontend:
    image: ${DOCKER_REPO}/vntechies-todolist-frontend:${IMAGE_TAG}
    container_name: todolist-frontend-dev
    restart: unless-stopped
    environment:
      NEXT_PUBLIC_API_URL: ${NEXT_PUBLIC_API_URL}
    ports:
      - "${FRONTEND_PORT}:3000"
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - application-network

  promtail:
    image: grafana/promtail:3.0.0
    container_name: todolist-promtail-dev
    restart: unless-stopped
    command: -config.file=/etc/promtail/config.yml
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${TARGET_DIR}/promtail-config.yaml:/etc/promtail/config.yml:ro
      - promtail-positions:/var/lib/promtail

networks:
  application-network:
    driver: bridge

volumes:
  promtail-positions:
EOF

docker compose -f "$TARGET_DIR/docker-compose.yml" pull

docker rm -f \
  todolist-backend-dev \
  todolist-frontend-dev \
  2>/dev/null || true

docker compose \
  -f "$TARGET_DIR/docker-compose.yml" \
  up -d --remove-orphans

docker compose \
  -f "$TARGET_DIR/docker-compose.yml" \
  ps

echo "=== Docker compose status ==="
docker compose -f "$TARGET_DIR/docker-compose.yml" ps

echo "=== Backend logs ==="
docker logs --tail=100 todolist-backend-dev || true

echo "=== Frontend logs ==="
docker logs --tail=100 todolist-frontend-dev || true

echo "=== Backend health ==="
curl --fail --retry 10 --retry-delay 3 \
  http://127.0.0.1:"$BACKEND_PORT"/health

echo "=== Waiting for frontend ==="

for i in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:"$FRONTEND_PORT"/ >/dev/null; then
    echo "Frontend is ready"
    break
  fi

  echo "Frontend not ready yet: attempt $i/20"
  docker logs --tail=30 todolist-frontend-dev || true
  sleep 3

  if [ "$i" -eq 20 ]; then
    echo "Frontend failed readiness check"
    docker inspect todolist-frontend-dev
    exit 1
  fi
done
