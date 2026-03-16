# Connector Configuration

## Standalone mode (default)

This project uses **Connect standalone mode** to avoid "ensuring membership" delays on single-broker setups.

- **oracle-xstream-rac-connector.properties** – Connector config for standalone. Copy from `oracle-xstream-rac-connector.properties.example` and set `database.password`, `database.service.name`.
- Connector starts with Connect process – no REST deploy step.
- **database.service.name**: In `.properties` files, escape `$` as `\\$` (e.g. `SYS\\$SYS.Q\\$_XOUT_65...`) to avoid "Illegal group reference" from Java regex.

## oracle-xstream-rac.json (distributed mode / REST API)

For distributed mode or REST-based deploy. Aligned with [ora0600/confluent-new-cdc-connector](https://github.com/ora0600/confluent-new-cdc-connector) best practices.

### Properties added from ora0600 demo

| Property | Value | Purpose |
|----------|-------|---------|
| snapshot.fetch.size | 10000 | Rows per snapshot fetch |
| snapshot.max.threads | 4 | Parallel snapshot threads |
| query.fetch.size | 10000 | JDBC fetch size |
| max.queue.size | 65536 | Internal queue capacity |
| max.batch.size | 16384 | Max records per batch |
| producer.override.batch.size | 204800 | Kafka producer batch size |
| producer.override.linger.ms | 50 | Producer linger time |
| heartbeat.interval.ms | 300000 | Heartbeat topic interval (5 min) |

### Confluent Cloud only

If using **Confluent Cloud** (fully-managed), add:

```json
"database.processor.licenses": "CONFLUENT"
```

Required on CC, optional on self-managed Confluent Platform (GA since Apr 2025).

### Before deploy

1. Replace `database.password` with actual password.
2. **Get `database.service.name`** from RAC (run on DB):
   ```sql
   SELECT inst_id, service_id, name, network_name FROM gv$SERVICES WHERE NAME LIKE '%XOUT%';
   ```
   Use `network_name` as `database.service.name` in `oracle-xstream-rac.json`.
3. Update `table.include.list` for your tables. **For CDB/PDB**, use PDB prefix: `.*\.ORDERMGMT\.(REGIONS|COUNTRIES|...)` or `XSTRPDB\.ORDERMGMT\.(REGIONS|...)`.
4. Set `schema.history.internal.kafka.bootstrap.servers` to your Kafka bootstrap.

See `oracle-xstream-rac.json.example` for a template with placeholders.

### Snapshot modes

| Mode | Use case |
|------|----------|
| `initial` | First run: full snapshot + streaming. Creates all topics. |
| `no_data` | Streaming only: no initial snapshot. Requires schema history from prior `initial` or `recovery` run. |
| `recovery` | Rebuild schema history from DB when topic is missing/corrupt. |

**Streaming test:** Use `initial` first to create topics, then switch to `no_data`:
```bash
# After initial snapshot completes, switch to streaming-only:
curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/config | \
  jq '. + {"snapshot.mode": "no_data"} | del(.name)' | \
  curl -s -X PUT -H "Content-Type: application/json" -d @- \
  http://localhost:8083/connectors/oracle-xstream-rac-connector/config
curl -X POST http://localhost:8083/connectors/oracle-xstream-rac-connector/restart?includeTasks=true
```
