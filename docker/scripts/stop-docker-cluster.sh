#!/bin/bash
# Stop 3-broker Kafka cluster (Docker)
# Run from project root: ./docker/scripts/stop-docker-cluster.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Stopping Docker cluster ==="
docker compose -f "$DOCKER_DIR/docker-compose.yml" down

echo "Done. Data is preserved in Docker volumes (kafka1-data, kafka2-data, kafka3-data)."
echo "To remove volumes: docker compose -f docker/docker-compose.yml down -v"
