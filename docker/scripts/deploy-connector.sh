#!/bin/bash
# Deploy Oracle XStream connector to Connect (Docker)
# Run from project root: ./docker/scripts/deploy-connector.sh
# Requires: oracle-xstream-rac.json in xstream-connector/ with correct bootstrap.servers for Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Use Docker-specific JSON if exists, else try oracle-xstream-rac.json
CONNECTOR_JSON="$PROJECT_DIR/xstream-connector/oracle-xstream-rac-docker.json"
if [ ! -f "$CONNECTOR_JSON" ]; then
  CONNECTOR_JSON="$PROJECT_DIR/xstream-connector/oracle-xstream-rac.json"
fi
if [ ! -f "$CONNECTOR_JSON" ]; then
  echo "ERROR: Connector config not found."
  echo "  Edit xstream-connector/oracle-xstream-rac-docker.json with database credentials"
  echo "  Run this script again."
  exit 1
fi

echo "Deploying connector from $CONNECTOR_JSON..."
curl -s -X POST -H "Content-Type: application/json" \
  --data @"$CONNECTOR_JSON" \
  http://localhost:8083/connectors

echo ""
echo "Check status: curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq ."
