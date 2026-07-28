#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-/opt/todolist/dev}"
IMAGE_TAG="${2:-latest}"
DB_HOST="${3:-127.0.0.1}"
DB_PORT="${4:-5432}"
DB_NAME="${5:-todolist_dev}"
DB_USER="${6:-todo_dev_user}"
DB_PASSWORD="${7:-}"
BACKEND_PORT="${8:-5000}"
FRONTEND_PORT="${9:-3000}"
NEXT_PUBLIC_API_URL="${10:-http://127.0.0.1:5000/api}"
DOCKER_REPO="${11:-buiminh03}"

mkdir -p "$TARGET_DIR"

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

networks:
  application-network:
    driver: bridge
EOF

docker compose -f "$TARGET_DIR/docker-compose.yml" pull
docker compose -f "$TARGET_DIR/docker-compose.yml" up -d --remove-orphans
docker compose -f "$TARGET_DIR/docker-compose.yml" ps
