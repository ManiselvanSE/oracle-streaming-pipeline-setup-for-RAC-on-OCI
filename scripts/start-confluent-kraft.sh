#!/bin/bash
# =============================================================================
# Start Confluent Platform 7.9 with KRaft (no Zookeeper)
# Run on VM after setup-vm.sh
# Usage: ./start-confluent-kraft.sh [path-to-oracle-xstream-cdc-poc]
# =============================================================================

# Set Oracle Instant Client path for Kafka Connect
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/opt/oracle/instantclient/instantclient_19_30}:$LD_LIBRARY_PATH"

CONFLUENT_HOME="${CONFLUENT_HOME:-/opt/confluent/confluent}"
KAFKA_HOME="$CONFLUENT_HOME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(dirname "$SCRIPT_DIR")}"
KRAFT_LOG_DIR="/tmp/kraft-combined-logs"
mkdir -p "$KRAFT_LOG_DIR"

# Ensure Confluent logs dir exists and is writable (installed with sudo = root owned)
if [ ! -w "$KAFKA_HOME/logs" ] 2>/dev/null; then
  sudo mkdir -p "$KAFKA_HOME/logs"
  sudo chown -R "$(whoami):$(id -gn)" "$KAFKA_HOME/logs" 2>/dev/null || sudo chown -R opc:opc "$KAFKA_HOME/logs" 2>/dev/null || true
fi

# Detect kafka-storage (Confluent: kafka-storage, Apache: kafka-storage.sh)
KAFKA_STORAGE=""
for cmd in kafka-storage kafka-storage.sh; do
  [ -x "$KAFKA_HOME/bin/$cmd" ] && KAFKA_STORAGE="$KAFKA_HOME/bin/$cmd" && break
done

# Use KRaft configs from project (or Confluent etc if copied)
SERVER_KRAFT="$PROJECT_DIR/config/server-kraft.properties"
SCHEMA_KRAFT="$PROJECT_DIR/config/schema-registry-kraft.properties"
if [ ! -f "$SERVER_KRAFT" ]; then
  SERVER_KRAFT="$KAFKA_HOME/etc/kafka/server-kraft.properties"
  SCHEMA_KRAFT="$KAFKA_HOME/etc/schema-registry/schema-registry-kraft.properties"
fi
if [ ! -f "$SERVER_KRAFT" ]; then
  echo "Error: server-kraft.properties not found. Copy config/ to VM or run from project dir."
  exit 1
fi

echo "=== Starting Confluent Platform 7.9 (KRaft mode) ==="

# 1. Format storage (first run only - skip if already formatted)
if [ ! -f "$KRAFT_LOG_DIR/meta.properties" ] && [ -n "$KAFKA_STORAGE" ]; then
  echo "Formatting Kafka storage for KRaft..."
  KAFKA_CLUSTER_ID=$("$KAFKA_STORAGE" random-uuid)
  "$KAFKA_STORAGE" format -t "$KAFKA_CLUSTER_ID" -c "$SERVER_KRAFT"
elif [ ! -f "$KRAFT_LOG_DIR/meta.properties" ]; then
  echo "Warning: kafka-storage not found. Skipping format. Kafka may fail to start."
else
  echo "Kafka storage already formatted, skipping..."
fi

# 2. Start Kafka (KRaft mode)
echo "Starting Kafka (KRaft)..."
"$KAFKA_HOME/bin/kafka-server-start" -daemon "$SERVER_KRAFT"

# Wait for Kafka to be ready (required before Connect can join)
echo "Waiting for Kafka broker..."
i=0
while [ $i -lt 30 ]; do
  if "$KAFKA_HOME/bin/kafka-broker-api-versions" --bootstrap-server localhost:9092 2>/dev/null | head -1 | grep -q "localhost:9092"; then
    echo "Kafka ready."
    break
  fi
  sleep 2
  i=$((i + 1))
done

# 3. Start Schema Registry (uses bootstrap.servers for KRaft)
echo "Starting Schema Registry..."
"$KAFKA_HOME/bin/schema-registry-start" -daemon "$SCHEMA_KRAFT"
sleep 10

# 4. Start Kafka Connect (use project config with longer timeouts)
CONNECT_CFG="$PROJECT_DIR/config/connect-distributed-kraft.properties"
if [ ! -f "$CONNECT_CFG" ]; then
  CONNECT_CFG="$KAFKA_HOME/etc/kafka/connect-distributed.properties"
fi
echo "Starting Kafka Connect (config: $CONNECT_CFG)..."
"$KAFKA_HOME/bin/connect-distributed" -daemon "$CONNECT_CFG"
echo "Waiting 150s for Connect to join cluster (Herder needs ~110s on slow VMs)..."
sleep 150

echo ""
echo "=== Confluent Platform started (KRaft mode) ==="
echo "Kafka: localhost:9092"
echo "Schema Registry: http://localhost:8081"
echo "Kafka Connect: http://localhost:8083"
echo ""
echo "Deploy connector:"
echo "  curl -X POST -H 'Content-Type: application/json' --data @connector-config/oracle-xstream-rac.json http://localhost:8083/connectors"
