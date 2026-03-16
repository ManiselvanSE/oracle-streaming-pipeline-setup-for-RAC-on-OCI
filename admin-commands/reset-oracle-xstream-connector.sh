#!/bin/bash
# =============================================================================
# Full reset of Oracle XStream connector - fresh snapshot for all tables
# Prerequisites: Run 04b-grant-ordermgmt-select.sql on DB first
# Usage: ./reset-oracle-xstream-connector.sh [path-to-oracle-xstream-cdc-poc]
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONNECTOR_JSON="$PROJECT_DIR/xstream-connector/oracle-xstream-rac.json"
CONNECTOR_NAME="oracle-xstream-rac-connector"
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONFLUENT_BIN="${CONFLUENT_HOME:-/opt/confluent/confluent}/bin"

echo "=== Oracle XStream Connector Full Reset ==="
echo "Project: $PROJECT_DIR"
echo ""

# 1. Stop connector
echo "1. Stopping connector..."
curl -s -X PUT "$CONNECT_URL/connectors/$CONNECTOR_NAME/stop" 2>/dev/null || true
sleep 5

# 2. Delete connector offsets (enables fresh snapshot)
echo "2. Resetting connector offsets..."
curl -s -X DELETE "$CONNECT_URL/connectors/$CONNECTOR_NAME/offsets" 2>/dev/null || true
sleep 2

# 3. Delete connector
echo "3. Deleting connector..."
curl -s -X DELETE "$CONNECT_URL/connectors/$CONNECTOR_NAME" 2>/dev/null || true
sleep 3

# 4. Delete schema history topic
echo "4. Deleting schema history topic..."
$CONFLUENT_BIN/kafka-topics --bootstrap-server localhost:9092 \
  --delete --topic __orcl-schema-changes.racdb 2>/dev/null || echo "   (topic may not exist)"
sleep 2

# 5. Recreate connector with recovery mode (rebuilds schema history)
echo "5. Creating connector (recovery mode)..."
cd "$PROJECT_DIR"
python3 -c "
import json
with open('xstream-connector/oracle-xstream-rac.json') as f:
    d = json.load(f)
d['config']['snapshot.mode'] = 'recovery'
print(json.dumps(d))
" > /tmp/connector-recovery.json
curl -s -X POST -H "Content-Type: application/json" \
  --data @/tmp/connector-recovery.json \
  "$CONNECT_URL/connectors"

echo ""
echo "6. Waiting 90s for recovery (schema history rebuild)..."
sleep 90

# 7. Update to initial mode and restart
echo "7. Updating to initial snapshot mode..."
python3 -c "
import json
with open('xstream-connector/oracle-xstream-rac.json') as f:
    d = json.load(f)
c = d['config'].copy()
c['snapshot.mode'] = 'initial'
print(json.dumps(c))
" > /tmp/connector-config-initial.json
curl -s -X PUT -H "Content-Type: application/json" \
  --data @/tmp/connector-config-initial.json \
  "$CONNECT_URL/connectors/$CONNECTOR_NAME/config"

echo ""
echo "8. Restarting connector..."
curl -s -X POST "$CONNECT_URL/connectors/$CONNECTOR_NAME/restart"
sleep 5

echo ""
echo "=== Reset complete ==="
echo "Wait 2-3 minutes for snapshot, then list topics:"
echo "  $CONFLUENT_BIN/kafka-topics --bootstrap-server localhost:9092 --list | grep racdb"
echo ""
echo "Check status:"
echo "  curl -s $CONNECT_URL/connectors/$CONNECTOR_NAME/status | python3 -m json.tool"
