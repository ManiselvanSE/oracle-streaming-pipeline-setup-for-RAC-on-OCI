#!/bin/bash
# Complete migration - deploy connector (run on VM after Docker cluster is up)
# Usage: ./docker/scripts/complete-migration-on-vm.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Deploying Oracle XStream connector..."
curl -s -X POST -H "Content-Type: application/json" \
  --max-time 180 \
  --data @"$PROJECT_DIR/xstream-connector/oracle-xstream-rac-docker.json" \
  http://localhost:8083/connectors

echo ""
echo "Check status: curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq ."
