#!/bin/bash
# =============================================================================
# Check and start XStream capture/outbound - run from VM with DB access
# Usage: DB_SYS_PWD=yourpwd ./check-and-start-xstream.sh [path-to-oracle-xstream-cdc-poc]
# =============================================================================

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/opt/oracle/instantclient/instantclient_19_30}:$LD_LIBRARY_PATH"
export PATH="${PATH:-/opt/oracle/instantclient/instantclient_19_30}:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SQL_DIR="$PROJECT_DIR/oracle-database"

DB_HOST="${DB_HOST:-racdb-scan.your-vcn.oraclevcn.com}"
DB_PORT="${DB_PORT:-1521}"
DB_SERVICE="${DB_SERVICE:-your-db-service.oraclevcn.com}"
CONN_STR="//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

echo "=== XStream Check and Start ==="
echo ""

if [ -z "${DB_SYS_PWD}" ]; then
  echo "Usage: DB_SYS_PWD=<sys_password> $0"
  echo ""
  echo "Or run manually:"
  echo "  sqlplus sys/<pwd>@//${DB_HOST}:${DB_PORT}/${DB_SERVICE} as sysdba @${SQL_DIR}/09-check-and-start-xstream.sql"
  echo ""
  echo "If outbound does not exist, create it first:"
  echo "  sqlplus c##xstrmadmin/<password>@//${DB_HOST}:${DB_PORT}/${DB_SERVICE} as sysdba @${SQL_DIR}/06-create-outbound-ordermgmt.sql"
  exit 1
fi

echo "1. Checking status..."
sqlplus -s "sys/${DB_SYS_PWD}@${CONN_STR}" as sysdba << 'EOSQL'
SET PAGESIZE 20 FEEDBACK OFF
SELECT 'Outbound:' c, NVL(SERVER_NAME,'(none)') n, NVL(STATUS,'N/A') s FROM DBA_XSTREAM_OUTBOUND WHERE SERVER_NAME = 'XOUT'
UNION ALL
SELECT 'Capture:', NVL(CAPTURE_NAME,'(none)'), NVL(STATUS,'N/A') FROM DBA_CAPTURE WHERE CAPTURE_NAME = 'CONFLUENT_XOUT1'
UNION ALL
SELECT 'Apply:', NVL(APPLY_NAME,'(none)'), NVL(STATUS,'N/A') FROM DBA_APPLY WHERE APPLY_NAME = 'XOUT';
EXIT;
EOSQL

echo ""
echo "2. Starting capture/apply if disabled..."
sqlplus -s "sys/${DB_SYS_PWD}@${CONN_STR}" as sysdba @"${SQL_DIR}/09-check-and-start-xstream.sql"

echo ""
echo "=== Done ==="
