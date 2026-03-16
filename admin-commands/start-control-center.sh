#!/bin/bash
# Start Confluent Control Center - Oracle XStream CDC POC
# Requires: Kafka and Schema Registry running. Run after start-confluent-standalone.sh
# Usage: ./admin-commands/start-control-center.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="${PROJECT_DIR}/monitoring/config/control-center.properties"

mkdir -p "$PROJECT_DIR/data/control-center"

echo "Starting Confluent Control Center..."
/opt/confluent/confluent/bin/control-center-start "$CONFIG" &

echo "Control Center starting. URL: http://localhost:9021"
echo "Wait 1-2 minutes for startup. Check: tail -f /opt/confluent/confluent/logs/control-center.log"
