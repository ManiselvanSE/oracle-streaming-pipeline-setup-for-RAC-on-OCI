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
- Run full reset: `./admin-commands/reset-oracle-xstream-connector.sh`

---

## Connect Standalone Mode (No "Ensuring Membership")

This project uses **Connect standalone mode** by default. The connector starts with the Connect process – no consumer group, no "ensuring membership" delays. Use `./admin-commands/start-confluent-standalone.sh` or `./admin-commands/start-confluent-kraft.sh`.

---

## Connect Won't Start After Manual Kill (Connection Refused on 8083)

**Symptom:** `curl localhost:8083` returns "Connection refused". Connect was working until you killed it with `kill -9` or `pkill`.

**Cause:** Connect process was terminated; it doesn't auto-restart.

**Fix (standalone mode):** Use the restart script (Kafka must already be running). Connector starts with Connect – no deploy step.

```bash
cd /home/opc/oracle-xstream-cdc-poc
chmod +x admin-commands/restart-connect-only.sh
./admin-commands/restart-connect-only.sh
```

**Connect crashes with "Timeout expired while trying to create topic(s)":** Fixes:
1. Ensure Kafka is healthy: `kafka-broker-api-versions --bootstrap-server localhost:9092`
2. Wait 60+ seconds after stop before starting Connect

**Alternative – full restart:** If Connect still won't start, restart the whole stack:

```bash
./admin-commands/stop-confluent-kraft.sh
sleep 15
./admin-commands/start-confluent-standalone.sh
```

---

## Deploy Returns 404 Not Found for /connectors

**Symptom:** `curl -X POST ... http://localhost:8083/connectors` returns HTML with "404 Not Found" for URI /connectors.

**Causes:**
1. **Wrong service on 8083** – Another process (e.g. Schema Registry) bound to 8083. Check: `lsof -i:8083`
2. **Connect not fully started** – Polling reported "ready" too early. The updated `start-confluent-standalone.sh` now waits for a valid JSON array from GET /connectors.
3. **Missing Accept header** – Connect REST API expects `Accept: application/json`. The script adds this.

**Fix:**
1. Copy the updated `start-confluent-standalone.sh` to the VM and run it.
2. Verify Connect is on 8083: `curl -s -H "Accept: application/json" http://localhost:8083/` should return `{"version":"...","commit":"...","kafka_cluster_id":"..."}`.
3. If you get HTML instead, stop all services and restart in order: Kafka → Schema Registry (8081) → Connect (8083).

---

## All CDC Topics Empty (0 Messages)

**Symptom:** `kafka-console-consumer` returns 0 messages for all topics (REGIONS, MTX_TRANSACTION_ITEMS, heartbeat, etc.).

**Possible causes:**
1. **UNKNOWN_TOPIC_OR_PARTITION race** – Connector produced before topics existed; messages may have been lost. The start script now pre-creates CDC topics before Connect starts.
2. **Kafka data lost on reboot** – If using `/tmp` for log.dirs, VM reboot clears it. This project now uses `/home/opc/oracle-xstream-cdc-poc/data/kafka` for persistence.
3. **Stale Connect offset** – Standalone offset file has old position; connector thinks it's caught up but never produced.
4. **Producer not flushing** – Connector reads from Oracle but Kafka producer fails (check Connect logs for errors).

**Fix – Clean restart with fresh snapshot:**

```bash
# 1. Stop everything
./admin-commands/stop-confluent-kraft.sh
sleep 10

# 2. Clear Connect offset (forces fresh snapshot on next start)
rm -f /home/opc/oracle-xstream-cdc-poc/data/connect-standalone.offsets 2>/dev/null || rm -f /tmp/connect-standalone.offsets

# 3. Optional: clear Kafka data to force full re-snapshot
# rm -rf /home/opc/oracle-xstream-cdc-poc/data/kafka/*

# 4. Start fresh
./admin-commands/start-confluent-standalone.sh
```

Then wait 2–5 minutes for initial snapshot. Check Connect log:
```bash
tail -f /tmp/connect-standalone.log
```
Look for "Snapshot completed" or "records sent". Then consume:
```bash
/opt/confluent/confluent/bin/kafka-console-consumer --bootstrap-server localhost:9092 --topic racdb.XSTRPDB.ORDERMGMT.REGIONS --from-beginning --max-messages 3
```

**Verify Kafka works:** Create topic, produce, then consume (run separately):
```bash
# Create topic first (avoids UNKNOWN_TOPIC_OR_PARTITION)
/opt/confluent/confluent/bin/kafka-topics --bootstrap-server localhost:9092 --create --topic test-topic --partitions 1 --replication-factor 1

# Produce
echo '{"test":1}' | /opt/confluent/confluent/bin/kafka-console-producer --bootstrap-server localhost:9092 --topic test-topic

# Consume (separate command)
/opt/confluent/confluent/bin/kafka-console-consumer --bootstrap-server localhost:9092 --topic test-topic --from-beginning --max-messages 1
```

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

Or run `./admin-commands/reset-oracle-xstream-connector.sh`.

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
  <rac-scan-ip> racdb-scan.<your-vcn>.oraclevcn.com
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
