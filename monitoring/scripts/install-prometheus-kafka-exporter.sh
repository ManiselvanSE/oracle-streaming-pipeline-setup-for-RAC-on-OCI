#!/bin/bash
# =============================================================================
# Install Prometheus + Kafka Exporter for Grafana throughput dashboards
# Oracle XStream CDC POC - run on VM. Requires Docker.
# Usage: ./monitoring/scripts/install-prometheus-kafka-exporter.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMETHEUS_CONFIG="${PROMETHEUS_CONFIG:-$PROJECT_DIR/monitoring/config/prometheus.yml}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
KAFKA_EXPORTER_PORT="${KAFKA_EXPORTER_PORT:-9308}"
KAFKA_BOOTSTRAP="${KAFKA_BOOTSTRAP:-localhost:9092}"
NETWORK_NAME="monitoring-net"

echo "=== Installing Prometheus + Kafka Exporter ==="
echo "Prometheus port: $PROMETHEUS_PORT"
echo "Kafka Exporter port: $KAFKA_EXPORTER_PORT"
echo "Kafka bootstrap: $KAFKA_BOOTSTRAP"
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker not found. Install first: sudo ./admin-commands/install-docker.sh"
  exit 1
fi

DOCKER="docker"
if ! docker ps &>/dev/null; then
  DOCKER="sudo docker"
fi

# Create network for container discovery
$DOCKER network create $NETWORK_NAME 2>/dev/null || true

# Stop/remove existing containers
$DOCKER stop kafka-exporter prometheus 2>/dev/null || true
$DOCKER rm kafka-exporter prometheus 2>/dev/null || true

# Create Prometheus data volume
$DOCKER volume create prometheus-data 2>/dev/null || true

# Kafka Exporter - connect to Kafka on host
# host.docker.internal resolves to host IP on Linux (Docker 20.10+)
echo "Starting Kafka Exporter..."
$DOCKER run -d \
  --name kafka-exporter \
  --restart unless-stopped \
  --network $NETWORK_NAME \
  --add-host=host.docker.internal:host-gateway \
  -p ${KAFKA_EXPORTER_PORT}:9308 \
  danielqsj/kafka-exporter:latest \
  --kafka.server=host.docker.internal:9092

# Prometheus - scrape Kafka Exporter
if [ ! -f "$PROMETHEUS_CONFIG" ]; then
  echo "ERROR: Prometheus config not found: $PROMETHEUS_CONFIG"
  exit 1
fi

echo "Starting Prometheus..."
$DOCKER run -d \
  --name prometheus \
  --restart unless-stopped \
  --network $NETWORK_NAME \
  -p ${PROMETHEUS_PORT}:9090 \
  -v "$PROMETHEUS_CONFIG:/etc/prometheus/prometheus.yml:ro" \
  -v prometheus-data:/prometheus \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.retention.time=7d \
  --web.enable-lifecycle

# Connect Grafana to monitoring network (if running) so it can reach Prometheus
$DOCKER network connect $NETWORK_NAME grafana 2>/dev/null || true

echo ""
echo "=== Prometheus + Kafka Exporter installed ==="
echo "Prometheus:  http://localhost:${PROMETHEUS_PORT}"
echo "Kafka Exporter metrics: http://localhost:${KAFKA_EXPORTER_PORT}/metrics"
echo ""
echo "Next: Add Prometheus as Grafana datasource"
echo "  URL: http://prometheus:9090  (if Grafana is on monitoring-net)"
echo "  URL: http://host.docker.internal:9090  (or http://localhost:9090 from host)"
echo "Then: Dashboards → Import → ID 7589 or 23757"
echo ""
