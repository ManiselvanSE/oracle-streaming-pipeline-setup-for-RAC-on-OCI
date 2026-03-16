#!/bin/bash
# =============================================================================
# Full teardown: DB (XStream outbound) + VM (Confluent, connector, Kafka data)
# Usage:
#   DB only:  DB_SYS_PWD=pwd ./teardown-all.sh --db-only
#   VM only:  ./teardown-all.sh --vm-only
#   Both:     DB_SYS_PWD=pwd ./teardown-all.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SQL_DIR="$PROJECT_DIR/oracle-database"

DB_HOST="${DB_HOST:-10.0.0.29}"
DB_PORT="${DB_PORT:-1521}"
DB_SERVICE="${DB_SERVICE:-DB0312_r8n_phx.sub01061249390.xstrmconnectdb2.oraclevcn.com}"
CONN_STR="//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"
PWD_XSTRM='ConFL#_uent12'

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/opt/oracle/instantclient/instantclient_19_30}:$LD_LIBRARY_PATH"
export PATH="${PATH:-/opt/oracle/instantclient/instantclient_19_30}:$PATH"

DO_DB=false
DO_VM=false

for arg in "$@"; do
  case "$arg" in
    --db-only) DO_DB=true ;;
    --vm-only) DO_VM=true ;;
  esac
done

# Default: both if no flags
if [ "$DO_DB" = false ] && [ "$DO_VM" = false ]; then
  DO_DB=true
  DO_VM=true
fi

# Pass TEARDOWN_FULL to VM teardown if set
if [ "$DO_VM" = true ] && [ "${TEARDOWN_FULL}" = "true" ]; then
  export TEARDOWN_FULL=true
fi

echo "=== Oracle XStream CDC - Full Teardown ==="
echo ""

if [ "$DO_DB" = true ]; then
  echo "--- Database teardown (drop XStream outbound) ---"
  if [ -z "${DB_SYS_PWD}" ]; then
    echo "Skipping DB teardown: set DB_SYS_PWD to run."
    echo "  Or run manually: sqlplus sys/<pwd>@${CONN_STR} as sysdba @${SQL_DIR}/10-teardown-xstream-outbound.sql"
  else
    sqlplus -s "sys/${DB_SYS_PWD}@${CONN_STR}" as sysdba @"${SQL_DIR}/10-teardown-xstream-outbound.sql" || true
    echo "DB teardown done."
  fi
  echo ""
fi

if [ "$DO_VM" = true ]; then
  echo "--- VM teardown ---"
  "$SCRIPT_DIR/teardown-vm.sh" "$PROJECT_DIR"
fi

echo ""
echo "=== Teardown complete ==="
