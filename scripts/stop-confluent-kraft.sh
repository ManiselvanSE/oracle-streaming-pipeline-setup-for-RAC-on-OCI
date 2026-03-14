#!/bin/bash
# =============================================================================
# Stop Confluent Platform (KRaft mode)

CONFLUENT_HOME="${CONFLUENT_HOME:-/opt/confluent/confluent}"

echo "Stopping Confluent Platform..."
pkill -f "connect-distributed" || true
pkill -f "schema-registry-start" || true
pkill -f "kafka-server-start" || true
# Wait for Connect to leave consumer group (avoids stale member on next start)
sleep 40
echo "Stopped."
