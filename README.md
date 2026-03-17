# Oracle CDC XStream Connector – OCI RAC

A self-managed Oracle CDC (Change Data Capture) pipeline using the **Confluent Oracle XStream CDC Connector**, streaming changes from **Oracle RAC** to **Apache Kafka** on OCI.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Quick Start](#quick-start)
- [Oracle Database](#oracle-database)
- [XStream Connector](#xstream-connector)
- [Demo: End-to-End Flow](#demo-end-to-end-flow)
- [Troubleshooting](#troubleshooting)
- [Monitoring Tools](#monitoring-tools)
- [Admin Commands](#admin-commands)
- [Project Structure](#project-structure)
- [References](#references)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│  OCI - US West (Phoenix)                                                 │
│                                                                          │
│  ┌──────────────────────┐         ┌─────────────────────────────────┐  │
│  │  Connector VM         │         │  Oracle RAC                     │  │
│  │  (connector-vm)      │  ────►  │  SCAN: racdb-scan...             │  │
│  │  Port: 1521           │  1521   │  XStream Out configured          │  │
│  │                       │         │                                  │  │
│  │  • Confluent Platform │         │  • XStream Out outbound server   │  │
│  │  • Oracle XStream     │         │  • Supplemental logging         │  │
│  │    CDC Connector      │         │  • ORDERMGMT sample schema       │  │
│  │  • Kafka Connect      │         │                                  │  │
│  └──────────────────────┘         └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

> **Screenshot:** Add `screenshots/architecture-overview.png` for a visual diagram.

---

## Quick Start

| Step | Action |
|------|--------|
| 1 | SSH to VM: `ssh -i key.pem opc@<vm-ip>` |
| 2 | Copy project: `scp -r oracle-xstream-cdc-poc opc@<vm-ip>:/home/opc/` |
| 3 | Run setup: `sudo ./oracle-xstream-cdc-poc/admin-commands/setup-vm.sh` |
| 4 | Configure connector: Copy `xstream-connector/oracle-xstream-rac-connector.properties.example` → `oracle-xstream-rac-connector.properties` and set `database.password`, `database.service.name` |
| 5 | Start stack: `./admin-commands/start-confluent-standalone.sh` |
| 6 | Verify: `curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status \| jq .` |

**Detailed guides:**
- [docs/EXECUTION-GUIDE.md](docs/EXECUTION-GUIDE.md) – Full setup commands
- [docs/DEMO.md](docs/DEMO.md) – Step-by-step live demo script
- [docs/EXECUTION-GUIDE.md#part-6-onboard-new-tables](docs/EXECUTION-GUIDE.md#part-6-onboard-new-tables-to-existing-cdc-pipeline) – Add new tables to CDC

### Demo Flow (5 steps)

1. **Oracle** – Run SQL scripts 01→06 in `oracle-database/` to enable XStream and create outbound server  
2. **VM** – Run `setup-vm.sh` to install Confluent, Oracle client, connector  
3. **Connector** – Copy `oracle-xstream-rac-connector.properties.example` → `oracle-xstream-rac-connector.properties` and set credentials  
4. **Start** – Run `start-confluent-standalone.sh`  
5. **Verify** – Insert into `ORDERMGMT.MTX_TRANSACTION_ITEMS`, consume from Kafka topic `racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS`

---

## Directory Structure

| Directory | Contents |
|-----------|----------|
| [oracle-database/](oracle-database/) | SQL scripts for Oracle RAC setup (run 01→14 in order) |
| [xstream-connector/](xstream-connector/) | Connector configuration (properties, examples) |
| [admin-commands/](admin-commands/) | Start, stop, setup, teardown scripts |
| [monitoring/](monitoring/) | Grafana, Prometheus, Kafka Exporter setup and docs |
| [troubleshooting/](troubleshooting/) | Troubleshooting guide |
| [screenshots/](screenshots/) | Documentation screenshots |
| [config/](config/) | Kafka, Schema Registry, Connect configs |

---

## Oracle Database

The Oracle RAC database must have XStream enabled and the outbound server configured. Run the SQL scripts in [oracle-database/](oracle-database/) **in order** (01 → 14).

### Prerequisites

| Requirement | Check |
|-------------|-------|
| Oracle 19c/21c Enterprise/Standard | `SELECT * FROM v$version;` |
| ARCHIVELOG mode | `SELECT LOG_MODE FROM V$DATABASE;` |
| XStream enabled | `SELECT VALUE FROM V$PARAMETER WHERE NAME = 'enable_goldengate_replication';` |
| Supplemental logging | See script `03-supplemental-logging.sql` |

### Script Execution Order

| # | Script | Purpose |
|---|--------|---------|
| 01 | `01-create-sample-schema.sql` | ORDERMGMT schema and tables |
| 02 | `02-enable-xstream.sql` | Enable XStream replication |
| 03 | `03-supplemental-logging.sql` | Supplemental logging for CDC |
| 04 | `04-create-xstream-users.sql` | XStream admin and connect users |
| 05 | `05-load-sample-data.sql` | Sample data for ORDERMGMT |
| 06 | `06-create-outbound-ordermgmt.sql` | XStream Out outbound server |
| 07 | `07-produce-orders-procedure.sql` | Test data generation |
| 08 | `08-verify-xstream-outbound.sql` | Verify outbound configuration |
| 09 | `09-check-and-start-xstream.sql` | Check/start capture and apply |
| 10 | `10-teardown-xstream-outbound.sql` | Drop outbound (teardown) |
| 11 | `11-add-table-to-cdc.sql` | Add new table to existing CDC |
| 12–14 | `12-create-mtx-transaction-items.sql` etc. | MTX_TRANSACTION_ITEMS onboarding |

### Key SQL Commands

```sql
-- Enable XStream (all RAC instances)
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;

-- Get XStream service name (for connector config)
SELECT network_name FROM gv$SERVICES WHERE NAME LIKE '%XOUT%' AND ROWNUM=1;

-- Verify capture process
SELECT CAPTURE_NAME, STATE FROM DBA_CAPTURE;
```

---

## XStream Connector

The connector runs in **Kafka Connect standalone mode**. It starts automatically with Connect—no REST deploy step.

### Configuration

| Property | Description |
|----------|-------------|
| `database.hostname` | RAC SCAN address |
| `database.service.name` | XStream service from `gv$SERVICES` (escape `$` as `\\$`) |
| `database.pdb.name` | PDB name (e.g. `XSTRPDB`) |
| `table.include.list` | Regex of tables to capture (e.g. `ORDERMGMT\.(REGIONS\|ORDERS\|...)`) |
| `snapshot.mode` | `initial` (full snapshot + streaming) or `recovery` (schema history rebuild) |

### Connector Status

![Connector Status](screenshots/connector-status.png)

*Add screenshot: `screenshots/connector-status.png` – Output of `curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq .`*

```bash
# Check connector and task status
curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq .

# Expected: connector.state=RUNNING, tasks[0].state=RUNNING
```

### Kafka Topics (CDC)

![Kafka Topics](screenshots/kafka-topics.png)

*Add screenshot: `screenshots/kafka-topics.png` – Output of `kafka-topics --list`*

| Topic | Purpose |
|-------|---------|
| `__orcl-schema-changes.racdb` | Schema history (internal) |
| `__cflt-oracle-heartbeat.racdb` | Heartbeat |
| `racdb.ORDERMGMT.REGIONS` | CDC data per table |
| `racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS` | CDC data |

---

## Demo: End-to-End Flow

This section demonstrates the complete data flow from **Oracle** → **XStream** → **Connector** → **Kafka** using the `MTX_TRANSACTION_ITEMS` table.

> **Live demo script:** For a step-by-step script suitable for live demonstrations, see [docs/DEMO.md](docs/DEMO.md).

### 1. Source Table

`MTX_TRANSACTION_ITEMS` is the source table in the Oracle Database (ORDERMGMT schema, XSTRPDB PDB). It stores transaction item records for CDC capture.

**Key columns:**

| Column | Type | Description |
|--------|------|--------------|
| `UNIQUE_SEQ_NUMBER` | VARCHAR2(50) | Primary key |
| `TRANSFER_ID` | VARCHAR2(20) | Transfer identifier |
| `PARTY_ID` | VARCHAR2(20) | Party identifier |
| `ACCOUNT_ID` | VARCHAR2(60) | Account identifier |
| `REQUESTED_VALUE` | NUMBER(19,0) | Requested amount |
| `APPROVED_VALUE` | NUMBER(19,0) | Approved amount |
| `TRANSFER_DATE` | DATE | Transfer date |
| `TRANSACTION_TYPE` | VARCHAR2(6) | Transaction type |
| `TRANSFER_STATUS` | VARCHAR2(3) | Status (e.g. COM, PEN) |

Full DDL: [oracle-database/12-create-mtx-transaction-items.sql](oracle-database/12-create-mtx-transaction-items.sql)

![Oracle Table](screenshots/demo-oracle-insert.png)

*Add screenshot: `screenshots/demo-oracle-insert.png` – Oracle SQL*Plus or SQL Developer showing the table structure*

---

### 2. Insert Data into Oracle

Connect as `ordermgmt` and run:

```sql
INSERT INTO ORDERMGMT.MTX_TRANSACTION_ITEMS (
  TRANSFER_ID, PARTY_ID, USER_TYPE, ENTRY_TYPE, ACCOUNT_ID,
  TRANSFER_DATE, TRANSACTION_TYPE, SECOND_PARTY, PROVIDER_ID,
  TXN_SEQUENCE_NUMBER, PAYMENT_TYPE_ID, SECOND_PARTY_PROVIDER_ID, UNIQUE_SEQ_NUMBER,
  REQUESTED_VALUE, APPROVED_VALUE, TRANSFER_STATUS, USER_NAME
) VALUES (
  'TRF001', 'P001', 'REG', 'DR', 'ACC001',
  SYSDATE, 'TRANS', 'P002', 1,
  1001, 1, 1, 'SEQ-MTX-001-' || TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS'),
  1000, 1000, 'COM', 'DemoUser'
);
COMMIT;
```

Or use the provided script:

```bash
sqlplus ordermgmt/<password>@//racdb-scan...:1521/XSTRPDB... @oracle-database/14-insert-mtx-transaction-items.sql
```

---

### 3. XStream Capture

1. **Oracle redo/archive logs** – The INSERT is written to the redo log.
2. **XStream Capture process** (`CONFLUENT_XOUT1`) – Reads from the redo stream and captures the change (INSERT) for tables in the XStream outbound.
3. **XStream Out** – Delivers the Logical Change Record (LCR) to the connector via the XStream API.

The connector subscribes to the XStream outbound server and receives LCRs in near real-time.

---

### 4. Kafka Connector Processing

1. **Oracle XStream CDC Connector** – Receives the LCR from XStream.
2. **Debezium format** – Converts the change into a Debezium JSON envelope (`before`, `after`, `source`).
3. **Kafka produce** – Publishes the event to the CDC topic.

**Kafka topic:** `racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS` (or `racdb.XSTRPDB.ORDERMGMT.MTX_TRANSACTION_ITEMS` depending on connector config)

![Connector Logs](screenshots/demo-connector-logs.png)

*Add screenshot: `screenshots/demo-connector-logs.png` – Connect log showing "records sent" or streaming activity (optional)*

---

### 5. Verify Data in Kafka

**Consumer command:**

```bash
/opt/confluent/confluent/bin/kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS \
  --partition 0 --offset 0 \
  --max-messages 3
```

**Sample output** (Debezium JSON for an INSERT):

```json
{"before":null,"after":{"TRANSFER_ID":"TRF001","PARTY_ID":"P001","USER_TYPE":"REG","ENTRY_TYPE":"DR","ACCOUNT_ID":"ACC001","REQUESTED_VALUE":1000,"APPROVED_VALUE":1000,"TRANSFER_STATUS":"COM","USER_NAME":"DemoUser",...},"source":{"version":"1.3.2","connector":"Oracle XStream CDC","name":"racdb","ts_ms":1710700000000,"snapshot":"false","db":"XSTRPDB","schema":"ORDERMGMT","table":"MTX_TRANSACTION_ITEMS"},"op":"c","ts_ms":1710700001234}
```

- `before`: null (INSERT has no previous state)
- `after`: New row data
- `source`: Connector metadata (table, schema, timestamp)
- `op`: `c` = create (INSERT)

![Kafka Output](screenshots/demo-kafka-output.png)

*Add screenshot: `screenshots/demo-kafka-output.png` – Kafka consumer output showing the CDC message*

---

### 6. Full Flow Summary

```
Oracle Table          XStream Capture       XStream Connector      Kafka Topic                    Consumer
MTX_TRANSACTION_ITEMS ──► LCR (redo) ──► Debezium JSON ──► racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS ──► JSON output
      │                       │                    │                           │
   INSERT                  Redo log            LCR → JSON                 Produce event
```

| Step | Component | Action |
|------|-----------|--------|
| 1 | Oracle | INSERT into MTX_TRANSACTION_ITEMS |
| 2 | XStream Capture | Reads redo, produces LCR |
| 3 | XStream Connector | Receives LCR, converts to Debezium JSON |
| 4 | Kafka | Event published to topic |
| 5 | Consumer | Reads message from topic |

---

### 7. Screenshots Checklist

| Screenshot | Path | Description |
|------------|------|--------------|
| Oracle insert | `screenshots/demo-oracle-insert.png` | SQL*Plus or SQL Developer – table/insert |
| Connector logs | `screenshots/demo-connector-logs.png` | Connect log – streaming/snapshot (optional) |
| Kafka output | `screenshots/demo-kafka-output.png` | Kafka consumer – sample CDC message |
| Monitoring | `screenshots/demo-monitoring.png` | Grafana/Prometheus – throughput (optional) |

---

## Troubleshooting

See [troubleshooting/TROUBLESHOOTING.md](troubleshooting/TROUBLESHOOTING.md) for detailed fixes. Summary:

| Issue | Fix |
|-------|-----|
| **Tasks empty after restart** | Remove `data/connect-standalone.offsets`, restart Connect |
| **All CDC topics empty** | Clean restart: stop stack, remove offset file, start `admin-commands/start-confluent-standalone.sh` |
| **Connect won't start** | `./admin-commands/restart-connect-only.sh` (Kafka must be running) |
| **ORA-12514 / service name** | Re-query `gv$SERVICES` for `network_name`, update `database.service.name` |
| **Capture ABORTED** | `DBMS_CAPTURE_ADM.STOP_CAPTURE` then `START_CAPTURE` |
| **Schema history missing** | Use `snapshot.mode=recovery` first, then switch to `initial` |

### Clean Restart (Forces Fresh Snapshot)

```bash
./admin-commands/stop-confluent-kraft.sh
sleep 10
rm -f /home/opc/oracle-xstream-cdc-poc/data/connect-standalone.offsets
./admin-commands/start-confluent-standalone.sh
```

---

## Monitoring Tools

Grafana, Prometheus, and Kafka Exporter provide throughput and lag monitoring.

### Port Forwarding

Forward monitoring ports to your local machine:

```bash
ssh -i /path/to/ssh-key.pem \
  -L 3000:localhost:3000 \
  -L 8081:localhost:8081 \
  -L 8083:localhost:8083 \
  -L 9090:localhost:9090 \
  -L 9308:localhost:9308 \
  opc@<vm-ip>
```

Then open the URLs below on **localhost**.

### Dashboard URLs

| Service | Port | URL (via tunnel) | Purpose |
|---------|------|------------------|---------|
| **Grafana** | 3000 | http://localhost:3000 | Dashboards, Kafka throughput |
| **Prometheus** | 9090 | http://localhost:9090 | Metrics, targets |
| **Kafka Exporter** | 9308 | http://localhost:9308/metrics | Kafka metrics (Prometheus format) |
| **Schema Registry** | 8081 | http://localhost:8081 | Schema Registry REST API |
| **Kafka Connect** | 8083 | http://localhost:8083 | Connect REST API, connector status |

### Grafana Dashboard

![Grafana Kafka Dashboard](screenshots/grafana-dashboard.png)

*Add screenshot: `screenshots/grafana-dashboard.png` – Grafana Kafka Exporter dashboard*

1. Add Prometheus datasource: URL `http://localhost:9090` or `http://prometheus:9090`
2. Import dashboard: **Dashboards** → **Import** → ID **7589** (Kafka Exporter)

### Prometheus Targets

![Prometheus Targets](screenshots/prometheus-targets.png)

*Add screenshot: `screenshots/prometheus-targets.png` – Prometheus targets page*

### Start / Stop Monitoring Services

| Action | Command |
|--------|---------|
| **Install Grafana** | `./monitoring/scripts/install-grafana-docker.sh` |
| **Install Prometheus + Kafka Exporter** | `./monitoring/scripts/install-prometheus-kafka-exporter.sh` |
| **Start Grafana** | `docker start grafana` |
| **Stop Grafana** | `docker stop grafana` |
| **Start Prometheus** | `docker start prometheus` |
| **Stop Prometheus** | `docker stop prometheus` |
| **Start Kafka Exporter** | `docker start kafka-exporter` |
| **Stop Kafka Exporter** | `docker stop kafka-exporter` |
| **Stop all monitoring** | `docker stop grafana prometheus kafka-exporter` |
| **Check status** | `docker ps \| grep -E 'grafana\|prometheus\|kafka-exporter'` |

**Docs:** [monitoring/docs/GRAFANA-SETUP.md](monitoring/docs/GRAFANA-SETUP.md), [monitoring/docs/MONITORING-SETUP.md](monitoring/docs/MONITORING-SETUP.md)

---

## Admin Commands

### Connector (Kafka Connect)

| Action | Command |
|--------|---------|
| **Start** | Connector starts with Connect. Use `./admin-commands/restart-connect-only.sh` |
| **Stop** | `pkill -f connect-standalone` |
| **Status** | `curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status \| jq .` |
| **List connectors** | `curl -s http://localhost:8083/connectors \| jq .` |
| **Logs** | `tail -f /tmp/connect-standalone.log` |

### Schema Registry

| Action | Command |
|--------|---------|
| **Start** | Started by `admin-commands/start-confluent-standalone.sh` or `admin-commands/start-confluent-kraft.sh` |
| **Stop** | `pkill -f schema-registry` |
| **Status** | `curl -s http://localhost:8081/subjects \| jq .` |
| **Health** | `curl -s http://localhost:8081/` |

### Kafka

| Action | Command |
|--------|---------|
| **Start** | `./admin-commands/start-confluent-standalone.sh` or `./admin-commands/start-confluent-kraft.sh` |
| **Stop** | `./admin-commands/stop-confluent-kraft.sh` |
| **Status** | `kafka-broker-api-versions --bootstrap-server localhost:9092` |
| **List topics** | `kafka-topics --bootstrap-server localhost:9092 --list` |
| **Describe topic** | `kafka-topics --bootstrap-server localhost:9092 --describe --topic <topic>` |

### Full Stack

| Action | Command |
|--------|---------|
| **Start all** | `./admin-commands/start-confluent-standalone.sh` |
| **Stop all** | `./admin-commands/stop-confluent-kraft.sh` |
| **Restart Connect only** | `./admin-commands/restart-connect-only.sh` (Kafka + Schema Registry must be running) |

### Quick Validation

```bash
# Connector
curl -s http://localhost:8083/connectors | jq .
curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq .

# Schema Registry
curl -s http://localhost:8081/subjects | jq .

# Kafka
/opt/confluent/confluent/bin/kafka-topics --bootstrap-server localhost:9092 --list | grep racdb

# Prometheus
curl -s http://localhost:9090/-/healthy

# Kafka Exporter
curl -s http://localhost:9308/metrics | head -5
```

---

## Project Structure

```
oracle-xstream-cdc-poc/
├── README.md
├── config/                      # Kafka, Schema Registry, Connect (standalone)
│   ├── server-kraft.properties
│   ├── schema-registry-kraft.properties
│   └── connect-standalone-kraft.properties
├── data/                        # Kafka logs, Connect offsets (persistent)
├── oracle-database/             # SQL scripts (run 01→14 in order)
├── xstream-connector/           # Connector config (properties, examples)
├── admin-commands/              # Start, stop, setup, teardown
│   ├── setup-vm.sh
│   ├── start-confluent-standalone.sh
│   ├── stop-confluent-kraft.sh
│   ├── restart-connect-only.sh
│   └── ...
├── monitoring/                  # Optional: Grafana, Prometheus, Kafka Exporter
│   ├── config/prometheus.yml
│   ├── scripts/
│   │   ├── install-grafana-docker.sh
│   │   └── install-prometheus-kafka-exporter.sh
│   └── docs/
├── troubleshooting/             # Troubleshooting guide
│   └── TROUBLESHOOTING.md
├── screenshots/                 # Add screenshots here
└── docs/
    ├── EXECUTION-GUIDE.md       # Full setup commands
    ├── DEMO.md                  # Step-by-step live demo script
    └── optional/                # Optional configs (e.g. distributed Connect)
```

---

## What's Optional

| Component | Purpose |
|-----------|---------|
| **monitoring/** | Grafana, Prometheus, Kafka Exporter – for throughput/lag dashboards. Not required for core CDC demo. |
| **docs/optional/** | Distributed Connect config – use if you prefer distributed mode instead of standalone. |

---

## Prerequisites

- **SSH:** Private key for VM access (e.g. `your-ssh-key.pem`)
- **Network:** Security List allows TCP 1521 from VM subnet to RAC
- **Oracle:** 19c/21c, ARCHIVELOG, XStream enabled
- **VM:** Oracle Linux 9, ~11 GB RAM recommended

---

## Security Note

- Connector config with credentials (`xstream-connector/oracle-xstream-rac-connector.properties`) is in `.gitignore`
- SQL scripts use POC passwords—**change before production**

---

## License

This project (scripts, configs, docs) is licensed under the [Apache License 2.0](LICENSE).

**Note:** The Oracle XStream CDC connector is a **Confluent Premium connector** requiring an Enterprise subscription. A 30-day trial is available for POC evaluation.

---

## References

- [Confluent Oracle XStream CDC Connector](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/overview.html)
- [Oracle XStream Out Configuration](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/configuring-xstream-out.html)
