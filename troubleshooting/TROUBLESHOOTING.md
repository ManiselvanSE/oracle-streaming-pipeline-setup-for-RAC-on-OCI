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

## Generate CDC Throughput for Grafana

**Goal:** Produce visible throughput in Grafana "Oracle XStream Connector Throughput" and "CDC Throughput" panels.

### Light load (~200 rows, 30 sec)
**Script:** `oracle-database/15-generate-cdc-throughput.sql`

### Heavy load (10,000+ rows, high throughput)
**Script:** `oracle-database/16-generate-heavy-cdc-load.sql` – inserts as fast as possible for sustained high connector throughput.

```bash
cd oracle-database
export ORDMGMT_PWD='YourP@ssw0rd123'   # if password contains @

# Default: 10,000 rows
./run-generate-heavy-cdc-load.sh

# Heavier: 50,000 rows
./run-generate-heavy-cdc-load.sh 50000
```

**Run (from host with Oracle client):**
```bash
sqlplus ordermgmt/"<password>"@//<rac-scan>:1521/<service> @oracle-database/15-generate-cdc-throughput.sql
```

**Example (OCI RAC) – use run script (handles TNS and password with @):**
```bash
cd oracle-database
export ORDMGMT_PWD='YourP@ssw0rd123'
./run-generate-cdc-throughput.sh      # light
./run-generate-heavy-cdc-load.sh      # heavy (10K rows)
./run-generate-heavy-cdc-load.sh 50000 # heavier (50K rows)
```

**If ORA-28000 (account locked):** Unlock as SYSDBA: `ALTER USER ordermgmt ACCOUNT UNLOCK;`

**Prerequisites:** Sample data loaded (`05-load-sample-data.sql`), connector RUNNING. Watch Grafana 10–30 seconds after the script completes.

---

## Grafana Connector Throughput Shows "No Data"

**Symptom:** Oracle XStream Connector Throughput panel is empty; Targets Up shows `kafka-connect: 0`.

**Cause:** Prometheus cannot scrape Kafka Connect's JMX exporter. Connector metrics come from Connect JMX.

**Verify Connect JMX:**
```bash
# From host - JMX exporter exposes HTTP metrics on 9994
curl -s http://localhost:9994/metrics | grep -E "kafka_connect|up"

# From inside Prometheus container
docker exec prometheus wget -qO- http://connect:9991/metrics | head -30
```

**If curl to 9994 fails:**
1. Check Connect logs for JMX agent errors: `docker logs connect 2>&1 | head -50`
2. Ensure Connect was started with monitoring: `docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d`
3. Verify JMX config mount: `docker exec connect ls -la /etc/jmx-exporter/`
4. Restart Connect: `docker restart connect`

**If Connect JMX works but connector metric is missing:** The connector must be RUNNING and actively streaming. Check: `curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq .`

---

## Snapshot Modes Reference

| Mode | Use |
|------|-----|
| `initial` | Full snapshot + streaming (first run) |
| `recovery` | Rebuild schema history when topic missing/corrupt |
| `no_data` | Streaming only; requires schema history from prior run |
