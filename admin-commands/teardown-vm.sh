#!/bin/bash
# =============================================================================
# Teardown VM: Stop Confluent, delete connector, delete Kafka data
# Run on connector VM - use before setup-from-scratch
# Usage: ./teardown-vm.sh [path-to-oracle-xstream-cdc-poc]
#        TEARDOWN_FULL=true ./teardown-vm.sh   # Also remove /opt/confluent, /opt/oracle
# =============================================================================

set -e

CONFLUENT_HOME="${CONFLUENT_HOME:-/opt/confluent/confluent}"
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="oracle-xstream-rac-connector"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
KRAFT_LOG_DIR="$PROJECT_DIR/data/kafka"

echo "=== Oracle XStream CDC - VM Teardown ==="
echo ""

# 1. Stop connector (if Connect is running)
echo "1. Stopping connector..."
curl -s -X PUT "$CONNECT_URL/connectors/$CONNECTOR_NAME/stop" 2>/dev/null || true
sleep 2

# 2. Delete connector
echo "2. Deleting connector..."
curl -s -X DELETE "$CONNECT_URL/connectors/$CONNECTOR_NAME" 2>/dev/null || true
sleep 2

# 3. Stop Confluent services
echo "3. Stopping Confluent Platform..."
pkill -f "connect-standalone" 2>/dev/null || true
pkill -f "connect-distributed" 2>/dev/null || true
pkill -f "schema-registry-start" 2>/dev/null || true
pkill -f "kafka-server-start" 2>/dev/null || true
sleep 5

# 4. Delete Kafka data (KRaft log dir)
echo "4. Deleting Kafka data..."
if [ -d "$KRAFT_LOG_DIR" ]; then
  rm -rf "$KRAFT_LOG_DIR"/*
  echo "   Deleted $KRAFT_LOG_DIR/*"
else
  echo "   (Kraft log dir not found)"
fi

# 5. Delete Confluent logs (optional - avoids stale logs)
echo "5. Clearing Confluent logs..."
if [ -d "$CONFLUENT_HOME/logs" ]; then
  rm -rf "$CONFLUENT_HOME/logs"/* 2>/dev/null || sudo rm -rf "$CONFLUENT_HOME/logs"/* 2>/dev/null || true
  echo "   Cleared $CONFLUENT_HOME/logs"
fi

# 6. Optional: Full reinstall (remove Confluent + Oracle client)
if [ "${TEARDOWN_FULL:-false}" = "true" ]; then
  echo "6. Full reinstall: Removing Confluent and Oracle client..."
  sudo rm -rf /opt/confluent
  sudo rm -rf /opt/oracle/instantclient
  echo "   Removed. Run setup-vm.sh to reinstall."
fi

echo ""
echo "=== VM teardown complete ==="
echo "Kafka data and connector removed. Confluent is stopped."
echo ""
echo "To set up from scratch:"
echo "  1. Run DB teardown (10-teardown-xstream-outbound.sql) if needed"
echo "  2. ./admin-commands/start-confluent-kraft.sh"
echo "  3. Deploy connector: curl -X POST -H 'Content-Type: application/json' --data @xstream-connector/oracle-xstream-rac.json $CONNECT_URL/connectors"
