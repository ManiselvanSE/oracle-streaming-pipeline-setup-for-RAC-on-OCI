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
PROJECT_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# Kafka data dir - must match log.dirs in server-kraft.properties
KRAFT_LOG_DIR="${KRAFT_LOG_DIR:-$PROJECT_DIR/data/kafka}"
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

# 3b. Extra delay for Kafka to stabilize (avoids Connect "Timeout creating topic" on slow VMs)
sleep 45

# 4. Start Kafka Connect (standalone mode - no "ensuring membership" delays)
WORKER_CFG="$PROJECT_DIR/config/connect-standalone-kraft.properties"
CONNECTOR_CFG="$PROJECT_DIR/xstream-connector/oracle-xstream-rac-connector.properties"
if [ ! -f "$WORKER_CFG" ]; then
  echo "Error: $WORKER_CFG not found."
  exit 1
fi
if [ ! -f "$CONNECTOR_CFG" ]; then
  echo "Error: $CONNECTOR_CFG not found. Copy from oracle-xstream-rac-connector.properties.example"
  exit 1
fi
CONNECT_STANDALONE=""
for cmd in connect-standalone connect-standalone.sh; do
  [ -x "$KAFKA_HOME/bin/$cmd" ] && CONNECT_STANDALONE="$KAFKA_HOME/bin/$cmd" && break
done
[ -z "$CONNECT_STANDALONE" ] && { echo "Error: connect-standalone not found."; exit 1; }
echo "Starting Kafka Connect (standalone with Oracle XStream connector)..."
nohup "$CONNECT_STANDALONE" "$WORKER_CFG" "$CONNECTOR_CFG" > /tmp/connect-standalone.log 2>&1 &
echo "Connect standalone started. Log: /tmp/connect-standalone.log"
echo "Waiting 30s for Connect to start..."
sleep 30

echo ""
echo "=== Confluent Platform started (KRaft mode, Connect standalone) ==="
echo "Kafka: localhost:9092"
echo "Schema Registry: http://localhost:8081"
echo "Kafka Connect: http://localhost:8083 (connector auto-started)"
echo ""
echo "Check status: curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq ."
