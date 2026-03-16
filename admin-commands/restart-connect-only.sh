#!/bin/bash
# =============================================================================
# Restart Connect (standalone mode) when Kafka is already running.
# Use after manually killing Connect - avoids full platform restart.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/opt/oracle/instantclient/instantclient_19_30}:$LD_LIBRARY_PATH"

CONFLUENT_HOME="${CONFLUENT_HOME:-/opt/confluent/confluent}"
WORKER_CFG="$PROJECT_DIR/config/connect-standalone-kraft.properties"
CONNECTOR_CFG="$PROJECT_DIR/xstream-connector/oracle-xstream-rac-connector.properties"

echo "=== Restarting Connect standalone (Kafka must already be running) ==="

# 1. Kill existing Connect
echo "Stopping Connect..."
pkill -f "connect-standalone" 2>/dev/null || true
pkill -f "connect-distributed" 2>/dev/null || true
sleep 10

if command -v lsof >/dev/null 2>&1; then
  pid=$(lsof -t -i:8083 2>/dev/null) || true
  if [ -n "$pid" ]; then
    echo "Force killing PID $pid on port 8083"
    kill -9 $pid 2>/dev/null || true
    sleep 5
  fi
fi

# 2. Verify Kafka is running
if ! "$CONFLUENT_HOME/bin/kafka-broker-api-versions" --bootstrap-server localhost:9092 2>/dev/null | head -1 | grep -q "localhost:9092"; then
  echo "ERROR: Kafka is not running. Start it first: ./admin-commands/start-confluent-kraft.sh"
  exit 1
fi
echo "Kafka is running."

# 3. Start Connect standalone
if [ ! -f "$CONNECTOR_CFG" ]; then
  echo "ERROR: $CONNECTOR_CFG not found."
  exit 1
fi
CONNECT_STANDALONE=""
for cmd in connect-standalone connect-standalone.sh; do
  [ -x "$CONFLUENT_HOME/bin/$cmd" ] && CONNECT_STANDALONE="$CONFLUENT_HOME/bin/$cmd" && break
done
[ -z "$CONNECT_STANDALONE" ] && { echo "Error: connect-standalone not found."; exit 1; }
echo "Starting Kafka Connect (standalone)..."
nohup "$CONNECT_STANDALONE" "$WORKER_CFG" "$CONNECTOR_CFG" > /tmp/connect-standalone.log 2>&1 &
echo "Connect started. Log: /tmp/connect-standalone.log"
sleep 20

# 4. Verify
if curl -s -H "Accept: application/json" http://localhost:8083/connectors 2>/dev/null | grep -qE '^\['; then
  echo ""
  echo "=== Connect is running ==="
  echo "curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq ."
else
  echo "WARNING: Connect may not be ready. Check: tail -50 /tmp/connect-standalone.log"
fi
