# Oracle CDC XStream Connector – Troubleshooting (Docker)

## Only REGIONS Topic (Other Tables Not Created)

**Symptom:** Only `racdb.XSTRPDB.ORDERMGMT.REGIONS` topic exists; other tables have no topics.

**Fix:** Add `database.pdb.name` to connector config:
```json
"database.pdb.name": "XSTRPDB",
```

Use regex for `table.include.list`: `ORDERMGMT\\.(REGIONS|COUNTRIES|LOCATIONS|...)`

---

## Connection Reset on Deploy

**Symptom:** `curl -X POST ... http://localhost:8083/connectors` returns "Connection reset by peer".

**Causes:**
1. Connect not fully ready – wait 60+ seconds after cluster start
2. Oracle OCI driver missing – ensure `ojdbc8.jar` and `xstreams.jar` in connector plugin lib (connect-entrypoint.sh copies from Instant Client)
3. `libnsl.so.1` missing – Dockerfile creates symlink; rebuild Connect image if needed

---

## No Suitable Driver (jdbc:oracle:oci)

**Symptom:** "No suitable driver found for jdbc:oracle:oci"

**Fix:** Oracle JARs must be in connector plugin lib. The `connect-entrypoint.sh` copies `ojdbc8.jar` and `xstreams.jar` from mounted Instant Client. Verify:
```bash
docker exec connect ls /usr/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib/ | grep -E 'ojdbc|xstreams'
```

---

## libnsl.so.1 Cannot Open Shared Object

**Symptom:** `UnsatisfiedLinkError: libnsl.so.1: cannot open shared object file`

**Fix:** Rebuild Connect image – Dockerfile installs libaio and creates libnsl.so.1 symlink.

---

## Connect Timeout Creating Topics

**Symptom:** "Timeout expired while trying to create topic(s)" for `_connect-offsets`.

**Cause:** Connect uses replication factor 3 for internal topics; only 2 brokers may be up (e.g. kafka1 down).

**Fix:** `docker-compose.yml` uses `CONNECT_*_REPLICATION_FACTOR: 2` for compatibility. Ensure at least 2 brokers are healthy.

---

## Connection to Node 1/3 Could Not Be Established

**Symptom:** Warnings when running `kafka-topics` or `kafka-console-consumer` with `localhost:9094`.

**Cause:** From inside a container, `localhost` refers to the container itself. Brokers advertise `localhost:9092`, etc., which are unreachable from other containers.

**Fix:** Use internal bootstrap: `kafka1:29092,kafka2:29092,kafka3:29092`
```bash
docker exec kafka2 kafka-console-consumer \
  --bootstrap-server kafka1:29092,kafka2:29092,kafka3:29092 \
  --topic racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS --from-beginning --max-messages 5
```

---

## XStream Service Name Changes

**Symptom:** ORA-12514 or connector fails after dropping/recreating outbound.

**Fix:** Get current service name:
```sql
SELECT network_name FROM gv$SERVICES WHERE NAME LIKE '%XOUT%' AND ROWNUM=1;
```
Update `database.service.name` in connector config. Escape `$` as `\\$`.

---

## Schema History Topic Missing

**Symptom:** "The db history topic is missing"

**Fix:**
1. Delete connector
2. Create with `snapshot.mode: recovery`
3. Wait 90s
4. Update to `snapshot.mode: initial`, restart

---

## Capture Process ABORTED

**Symptom:** "The capture process 'CONFLUENT_XOUT1' is in an 'ABORTED' status"

**Fix:** Stop and restart capture (run on Oracle as SYSDBA):
```sql
BEGIN DBMS_CAPTURE_ADM.STOP_CAPTURE(capture_name => 'CONFLUENT_XOUT1'); END;
/
-- Wait a few seconds
BEGIN DBMS_CAPTURE_ADM.START_CAPTURE(capture_name => 'CONFLUENT_XOUT1'); END;
/
```

---

## Connector in FAILED State

**Fix:** Restart connector:
```bash
curl -X POST http://localhost:8083/connectors/oracle-xstream-rac-connector/restart
```

Check logs: `docker logs connect --tail 100`

---

## Snapshot Modes Reference

| Mode | Use |
|------|-----|
| `initial` | Full snapshot + streaming (first run) |
| `recovery` | Rebuild schema history when topic missing/corrupt |
| `no_data` | Streaming only; requires schema history from prior run |
