# Oracle CDC XStream Connector Setup in OCI RAC - Troubleshooting Reference

## Only REGIONS Topic (Other Tables Not Created)

**Symptom:** Only `racdb.XSTRPDB.ORDERMGMT.REGIONS` topic exists; other 12 ORDERMGMT tables have no topics.

**Root cause:** Connector not scoped to PDB for snapshot; `capturing: []` in logs.

**Fix:** Add `database.pdb.name` to connector config:
```json
"database.pdb.name": "XSTRPDB",
```

**Additional config:**
- `table.include.list`: Use regex format, e.g. `ORDERMGMT\\.(REGIONS|COUNTRIES|LOCATIONS|...)`
- Run full reset: `./scripts/reset-oracle-xstream-connector.sh`

---

## XStream Service Name Changes After Outbound Recreate

**Symptom:** ORA-12514 or connector fails to connect after dropping/recreating outbound.

**Cause:** XStream service ID changes (e.g. `Q$_XOUT_5` → `Q$_XOUT_65`).

**Fix:** Get current service name:
```sql
SELECT network_name FROM gv$SERVICES WHERE NAME LIKE '%XOUT%' AND ROWNUM=1;
```
Update `database.service.name` in connector config (escape `$` as `\\$`).

---

## Schema History Topic Missing

**Symptom:** "The db history topic is missing. You may attempt to recover it by reconfiguring the connector to recovery."

**Fix:** Use recovery mode first, then switch to initial:
1. Delete connector
2. Create connector with `snapshot.mode: recovery`
3. Wait 90s
4. Update config to `snapshot.mode: initial`, restart

Or run `./scripts/reset-oracle-xstream-connector.sh`.

---

## Capture Process ABORTED

**Symptom:** "The capture process 'CONFLUENT_XOUT1' is in an 'ABORTED' status"

**Fix:** Stop and restart capture:
```sql
BEGIN DBMS_CAPTURE_ADM.STOP_CAPTURE(capture_name => 'CONFLUENT_XOUT1'); END;
/
-- Wait a few seconds
BEGIN DBMS_CAPTURE_ADM.START_CAPTURE(capture_name => 'CONFLUENT_XOUT1'); END;
/
```

---

## SSH Connection Issues

**"Permission denied (publickey)"**
- Use private key (`.key`), not public (`.pub`)
- `chmod 600 ssh-key.key`
- OCI Oracle Linux default user: `opc`

**"Connection timed out"**
- Check Security List allows SSH (port 22) from your IP
- Verify VM has public IP

---

## RAC Database Connectivity

**Port 1521 unreachable from VM**
- Add Security List ingress: Source=10.0.0.0/24, Dest Port=1521, Protocol=TCP

**SCAN hostname not resolving**
- Add to VM `/etc/hosts`:
  ```
  10.0.0.29 racdb-scan.sub01061249390.xstrmconnectdb2.oraclevcn.com
  ```

---

## Connector Issues

**ORA-01017: invalid username/password**
- Verify `c##cfltuser` password in connector config
- Ensure `ALTER_OUTBOUND` set `connect_user => 'c##cfltuser'`

**Tables must match**
- `table.include.list` must match tables in XStream outbound (CREATE_OUTBOUND)

**Oracle Instant Client**
- Set before starting Connect: `export LD_LIBRARY_PATH=/opt/oracle/instantclient/instantclient_19_30:$LD_LIBRARY_PATH`

---

## Snapshot Modes Reference

| Mode | Use |
|------|-----|
| `initial` | Full snapshot + streaming (first run) |
| `recovery` | Rebuild schema history when topic missing/corrupt |
| `no_data` | Streaming only; requires schema history from prior run |
