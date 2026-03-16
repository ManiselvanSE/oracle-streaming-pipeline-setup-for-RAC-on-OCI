#!/bin/bash
# =============================================================================
# Install Grafana via Docker - Oracle XStream CDC POC
# Run on VM (e.g. connector-vm). Requires Docker.
# Usage: ./monitoring/scripts/install-grafana-docker.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
GRAFANA_VOLUME="${GRAFANA_VOLUME:-grafana-storage}"
GRAFANA_IMAGE="${GRAFANA_IMAGE:-grafana/grafana-enterprise:latest}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
CONTAINER_NAME="grafana"

echo "=== Installing Grafana via Docker ==="
echo "Image: $GRAFANA_IMAGE"
echo "Port: $GRAFANA_PORT"
echo "Volume: $GRAFANA_VOLUME"
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker not found. Install first: sudo ./admin-commands/install-docker.sh"
  exit 1
fi

# Use sudo if user cannot run docker
DOCKER="docker"
if ! docker ps &>/dev/null; then
  DOCKER="sudo docker"
fi

# Stop and remove existing container (if any)
$DOCKER stop $CONTAINER_NAME 2>/dev/null || true
$DOCKER rm $CONTAINER_NAME 2>/dev/null || true

# Create Docker volume for persistence (avoids permission issues)
$DOCKER volume create $GRAFANA_VOLUME 2>/dev/null || true

# Pull image
echo "Pulling Grafana image..."
$DOCKER pull $GRAFANA_IMAGE

# Run Grafana (Docker volume for persistence - no permission issues)
echo "Starting Grafana..."
$DOCKER run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -p ${GRAFANA_PORT}:3000 \
  -v "$GRAFANA_VOLUME:/var/lib/grafana" \
  -e "GF_SERVER_HTTP_PORT=3000" \
  -e "GF_USERS_ALLOW_SIGN_UP=false" \
  $GRAFANA_IMAGE

echo ""
echo "=== Grafana installed ==="
echo "URL: http://localhost:${GRAFANA_PORT}"
echo "Default login: admin / admin (change on first login)"
echo ""
echo "To check status: $DOCKER ps | grep grafana"
echo "To view logs:    $DOCKER logs -f $CONTAINER_NAME"
echo "To stop:         $DOCKER stop $CONTAINER_NAME"
echo ""
