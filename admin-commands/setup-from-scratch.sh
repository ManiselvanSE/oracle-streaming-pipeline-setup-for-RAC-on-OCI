#!/bin/bash
# =============================================================================
# Setup from scratch: Run after teardown-all.sh
# Prerequisites: Oracle DB scripts 01-06 already run (schema, users, outbound)
#                OR run teardown-all first and have DB scripts ready
#
# Usage:
#   ./setup-from-scratch.sh                    # VM only (Confluent + connector)
#   DB_SYS_PWD=pwd ./setup-from-scratch.sh --with-db   # DB + VM (full)
#   DB_XSTRM_PWD=pwd  # If c##xstrmadmin has different password than sys
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SQL_DIR="$PROJECT_DIR/oracle-database"

DB_HOST="${DB_HOST:-your-rac-scan-host}"
DB_PORT="${DB_PORT:-1521}"
DB_SERVICE="${DB_SERVICE:-your-db-service.oraclevcn.com}"
PDB_SERVICE="${PDB_SERVICE:-XSTRPDB.your-vcn.oraclevcn.com}"
CONN_STR="//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"
PDB_CONN="//${DB_HOST}:${DB_PORT}/${PDB_SERVICE}"
PWD_CFLT="${PWD_CFLT:-your-ordermgmt-password}"
# c##xstrmadmin password (often same as c##cfltuser)
PWD_XSTRM="${DB_XSTRM_PWD:-$DB_SYS_PWD}"

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/opt/oracle/instantclient/instantclient_19_30}:$LD_LIBRARY_PATH"
export PATH="${PATH:-/opt/oracle/instantclient/instantclient_19_30}:$PATH"

WITH_DB=false
for arg in "$@"; do
  [ "$arg" = "--with-db" ] && WITH_DB=true
done

echo "=== Oracle XStream CDC - Setup from Scratch ==="
echo ""

# 1. DB setup (optional)
if [ "$WITH_DB" = true ]; then
  if [ -z "${DB_SYS_PWD}" ]; then
    echo "Error: DB_SYS_PWD required for --with-db"
    exit 1
  fi
  echo "1. Creating XStream outbound (06)..."
  sqlplus -s "c##xstrmadmin/\"${PWD_XSTRM}\"@${CONN_STR}" as sysdba @"${SQL_DIR}/06-create-outbound-ordermgmt.sql"
  sqlplus -s "sys/\"${DB_SYS_PWD}\"@${CONN_STR}" as sysdba << 'EOSQL'
BEGIN
  DBMS_XSTREAM_ADM.ALTER_OUTBOUND(server_name => 'xout', connect_user => 'c##cfltuser');
  DBMS_CAPTURE_ADM.SET_PARAMETER(capture_name => 'confluent_xout1', parameter => 'use_rac_service', value => 'Y');
END;
/
EXIT;
EOSQL
  echo "2. Grants and start capture/apply..."
  sqlplus -s "sys/\"${DB_SYS_PWD}\"@${CONN_STR}" as sysdba @"${SQL_DIR}/04b-grant-ordermgmt-select.sql"
  sqlplus -s "sys/\"${DB_SYS_PWD}\"@${CONN_STR}" as sysdba @"${SQL_DIR}/09-check-and-start-xstream.sql"
  echo "3. Loading sample data..."
  sqlplus -s "ordermgmt/\"${PWD_CFLT}\"@${PDB_CONN}" @"${SQL_DIR}/05-load-sample-data.sql" 2>/dev/null || true
  echo ""
fi

# 2. Start Confluent
echo "Starting Confluent Platform..."
"$SCRIPT_DIR/start-confluent-kraft.sh" "$PROJECT_DIR"

# 3. Deploy connector
echo ""
echo "Deploying connector..."
sleep 5
curl -s -X POST -H "Content-Type: application/json" \
  --data @"${PROJECT_DIR}/xstream-connector/oracle-xstream-rac.json" \
  http://localhost:8083/connectors

echo ""
echo "=== Setup complete ==="
echo "Wait 2-3 min for snapshot, then:"
echo "  /opt/confluent/confluent/bin/kafka-topics --bootstrap-server localhost:9092 --list | grep racdb"
echo "  curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | python3 -m json.tool"
