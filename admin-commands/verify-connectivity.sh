#!/bin/bash
# =============================================================================
# Verify connectivity from VM to Oracle RAC database
# Run this on the xstrm-con VM after SSH login
# =============================================================================

RAC_SCAN="${RAC_SCAN:-racdb-scan.your-vcn.oraclevcn.com}"
RAC_PORT=1521

echo "=== Oracle RAC Connectivity Check ==="
echo "Target: $RAC_SCAN:$RAC_PORT"
echo ""

echo "1. DNS Resolution:"
if command -v nslookup &>/dev/null; then
  nslookup $RAC_SCAN
else
  getent hosts $RAC_SCAN || host $RAC_SCAN
fi
echo ""

echo "2. Port connectivity (nc):"
if command -v nc &>/dev/null; then
  nc -zv $RAC_SCAN $RAC_PORT 2>&1 && echo "SUCCESS: Port $RAC_PORT is reachable" || echo "FAILED: Cannot reach port $RAC_PORT"
else
  echo "nc not found, trying timeout + bash..."
  timeout 5 bash -c "echo >/dev/tcp/$RAC_SCAN/$RAC_PORT" 2>/dev/null && echo "SUCCESS" || echo "FAILED or timeout"
fi
echo ""

echo "3. Telnet test (if available):"
if command -v telnet &>/dev/null; then
  echo "quit" | timeout 5 telnet $RAC_SCAN $RAC_PORT 2>&1 | head -5
fi
