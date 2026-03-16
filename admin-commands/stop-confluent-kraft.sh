#!/bin/bash
# =============================================================================
# Stop Confluent Platform (KRaft mode)

CONFLUENT_HOME="${CONFLUENT_HOME:-/opt/confluent/confluent}"

echo "Stopping Confluent Platform..."
pkill -f "connect-standalone" || true
pkill -f "connect-distributed" || true
pkill -f "schema-registry-start" || true
pkill -f "kafka-server-start" || true
# Wait for processes to exit
sleep 15
echo "Stopped."
