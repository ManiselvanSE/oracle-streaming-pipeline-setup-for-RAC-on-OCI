#!/bin/bash
# Start Confluent stack with Connect in STANDALONE mode (no "ensuring membership" delays)
# Connector starts with Connect process - no REST deploy needed.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/opt/oracle/instantclient/instantclient_19_30}:$LD_LIBRARY_PATH"

echo "=== Starting Confluent with Connect STANDALONE mode ==="

# 1. Stop everything
echo "Stopping Connect, Schema Registry, Kafka..."
pkill -f connect-standalone 2>/dev/null || true
pkill -f connect-distributed 2>/dev/null || true
pkill -f schema-registry 2>/dev/null || true
pkill -f kafka-server 2>/dev/null || true
sleep 30

# 2. Force kill if still on ports
if command -v lsof >/dev/null 2>&1; then
  for port in 8083 8081 9092; do
    pid=$(lsof -t -i:$port 2>/dev/null) || true
    if [ -n "$pid" ]; then
      echo "Force killing PID $pid on port $port"
      kill -9 $pid 2>/dev/null || true
      sleep 5
    fi
  done
fi

sleep 20

# 3. Ensure data dir exists (Kafka + Connect use persistent paths)
KRAFT_LOG_DIR="$PROJECT_DIR/data/kafka"
mkdir -p "$KRAFT_LOG_DIR" "$PROJECT_DIR/data"

# 4. Format Kafka storage if first run with new path (KRaft requires format before first start)
KAFKA_STORAGE=""
for cmd in kafka-storage kafka-storage.sh; do
  [ -x "/opt/confluent/confluent/bin/$cmd" ] && KAFKA_STORAGE="/opt/confluent/confluent/bin/$cmd" && break
done
if [ -n "$KAFKA_STORAGE" ] && [ ! -f "$KRAFT_LOG_DIR/meta.properties" ]; then
  echo "Formatting Kafka storage (first run with data/kafka)..."
  KAFKA_CLUSTER_ID=$("$KAFKA_STORAGE" random-uuid)
  "$KAFKA_STORAGE" format -t "$KAFKA_CLUSTER_ID" -c "$PROJECT_DIR/config/server-kraft.properties"
fi

# 5. Start Kafka
echo "Starting Kafka..."
/opt/confluent/confluent/bin/kafka-server-start -daemon "$PROJECT_DIR/config/server-kraft.properties"
echo "Waiting for Kafka..."
for i in $(seq 1 30); do
  if /opt/confluent/confluent/bin/kafka-broker-api-versions --bootstrap-server localhost:9092 2>/dev/null | head -1 | grep -q "localhost:9092"; then
    echo "Kafka ready."
    break
  fi
  sleep 2
done

sleep 20

# 6. Start Schema Registry
echo "Starting Schema Registry..."
/opt/confluent/confluent/bin/schema-registry-start -daemon "$PROJECT_DIR/config/schema-registry-kraft.properties"
sleep 15

# 7. Pre-create CDC topics (avoids UNKNOWN_TOPIC_OR_PARTITION race when connector produces)
echo "Pre-creating CDC topics..."
KAFKA_TOPICS="/opt/confluent/confluent/bin/kafka-topics"
[ -x "$KAFKA_TOPICS" ] || KAFKA_TOPICS="kafka-topics"
for topic in __orcl-schema-changes.racdb __cflt-oracle-heartbeat.racdb \
  racdb.ORDERMGMT.REGIONS racdb.ORDERMGMT.COUNTRIES racdb.ORDERMGMT.LOCATIONS \
  racdb.ORDERMGMT.WAREHOUSES racdb.ORDERMGMT.EMPLOYEES racdb.ORDERMGMT.PRODUCT_CATEGORIES \
  racdb.ORDERMGMT.PRODUCTS racdb.ORDERMGMT.CUSTOMERS racdb.ORDERMGMT.CONTACTS \
  racdb.ORDERMGMT.ORDERS racdb.ORDERMGMT.ORDER_ITEMS racdb.ORDERMGMT.INVENTORIES \
  racdb.ORDERMGMT.NOTES racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS \
  racdb.XSTRPDB.ORDERMGMT.REGIONS racdb.XSTRPDB.ORDERMGMT.MTX_TRANSACTION_ITEMS; do
  "$KAFKA_TOPICS" --bootstrap-server localhost:9092 --create --if-not-exists \
    --topic "$topic" --partitions 1 --replication-factor 1 2>/dev/null || true
done

# 8. Start Connect STANDALONE (connector starts with process - no deploy step)
WORKER_CFG="$PROJECT_DIR/config/connect-standalone-kraft.properties"
CONNECTOR_CFG="$PROJECT_DIR/xstream-connector/oracle-xstream-rac-connector.properties"

if [ ! -f "$CONNECTOR_CFG" ]; then
  echo "ERROR: $CONNECTOR_CFG not found. Copy from xstream-connector/oracle-xstream-rac-connector.properties.example and set credentials."
  exit 1
fi

# Find connect-standalone (Confluent: connect-standalone or connect-standalone.sh)
CONNECT_STANDALONE=""
for cmd in connect-standalone connect-standalone.sh; do
  if [ -x "/opt/confluent/confluent/bin/$cmd" ]; then
    CONNECT_STANDALONE="/opt/confluent/confluent/bin/$cmd"
    break
  fi
done
if [ -z "$CONNECT_STANDALONE" ]; then
  echo "ERROR: connect-standalone not found in /opt/confluent/confluent/bin/"
  exit 1
fi

echo "Starting Kafka Connect (standalone with Oracle XStream connector)..."
nohup "$CONNECT_STANDALONE" \
  "$WORKER_CFG" \
  "$CONNECTOR_CFG" \
  > /tmp/connect-standalone.log 2>&1 &
CONNECT_PID=$!
echo "Connect standalone started (PID $CONNECT_PID). Log: /tmp/connect-standalone.log"

# 9. Wait for REST API (standalone starts quickly; Oracle validation may add ~30s)
echo "Waiting for Connect REST API (up to 90s)..."
for i in $(seq 1 18); do
  if curl -s -H "Accept: application/json" --max-time 5 http://localhost:8083/connectors 2>/dev/null | grep -qE '^\['; then
    echo "Connect ready after ~$((i * 5))s."
    break
  fi
  [ $i -eq 18 ] && echo "Connect may still be starting. Check: tail -50 /tmp/connect-standalone.log"
  sleep 5
done

echo ""
echo "=== Done (standalone mode) ==="
echo "Connector started with Connect. No deploy step needed."
echo "Check: curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq ."
