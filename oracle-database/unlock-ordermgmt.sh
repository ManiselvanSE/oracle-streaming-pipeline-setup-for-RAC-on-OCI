#!/bin/bash
# Unlock ordermgmt and set password to ConFL#_uent12
# Run on VM where sqlplus is available.
# Usage: ./unlock-ordermgmt.sh [SYSDBA_PASSWORD]
#   If SYSDBA_PASSWORD not given, uses ConFL#_uent12 for sys

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export TNS_ADMIN="$SCRIPT_DIR"

SYSDBA_PWD="${1:-ConFL#_uent12}"
NEW_PWD="ConFL#_uent12"

echo "Unlocking ordermgmt and setting password to $NEW_PWD"
echo "Using sys with provided SYSDBA password to XSTRPDB..."

sqlplus -S "sys/${SYSDBA_PWD}@XSTRPDB as sysdba" << EOF
ALTER USER ordermgmt ACCOUNT UNLOCK;
SELECT profile FROM dba_users WHERE username='ORDMGMT';
ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_MAX UNLIMITED;
ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_TIME UNLIMITED;
ALTER USER ordermgmt IDENTIFIED BY "$NEW_PWD";
ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_MAX 10;
ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_TIME 10;
EXIT;
EOF

echo "Done. You can now run:"
echo "  export ORDMGMT_PWD='$NEW_PWD'"
echo "  ./run-generate-heavy-cdc-load.sh 50000"
