# Oracle CDC XStream Connector – OCI RAC

A self-managed Oracle CDC (Change Data Capture) pipeline using the **Confluent Oracle XStream CDC Connector**, streaming changes from **Oracle RAC** to **Apache Kafka** on OCI.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Quick Start](#quick-start)
- [Oracle Database](#oracle-database)
- [Demo: End-to-End Flow](#demo-end-to-end-flow)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)
- [References](#references)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│  OCI / On-Premises                                                       │
│                                                                          │
│  ┌──────────────────────┐         ┌─────────────────────────────────┐  │
│  │  Connector VM         │         │  Oracle RAC                     │  │
│  │  (Docker)             │  ────►  │  SCAN: racdb-scan...            │  │
│  │  Port: 1521            │  1521   │  XStream Out configured         │  │
│  │                        │         │                                  │  │
│  │  • 3-Broker Kafka      │         │  • XStream Out outbound server   │  │
│  │  • Kafka Connect       │         │  • Supplemental logging         │  │
│  │  • Oracle XStream CDC  │         │  • ORDERMGMT sample schema       │  │
│  └──────────────────────┘         └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

| Step | Action |
|------|--------|
| 1 | SSH to VM: `ssh -i key.pem opc@<vm-ip>` |
| 2 | Copy project: `scp -r oracle-xstream-cdc-poc opc@<vm-ip>:/home/opc/` |
| 3 | Install Docker (if needed): `sudo ./docker/scripts/install-docker.sh` |
| 4 | Configure: `cp docker/.env.example docker/.env` and set `ORACLE_INSTANTCLIENT_PATH` |
| 5 | Connector config: `cp docker/xstream-connector-docker.json.example xstream-connector/oracle-xstream-rac-docker.json` — edit `database.password`, `database.hostname`, `database.service.name` |
| 6 | Start: `./docker/scripts/start-docker-cluster.sh` |
| 7 | Pre-create topics: `./docker/scripts/precreate-topics.sh` |
| 8 | Deploy connector: `./docker/scripts/complete-migration-on-vm.sh` |
| 9 | Verify: `curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq .` |

**Detailed guides:**
- [docs/IMPLEMENTATION-GUIDE.md](docs/IMPLEMENTATION-GUIDE.md) – **Complete end-to-end implementation guide**
- [docs/EXECUTION-GUIDE.md](docs/EXECUTION-GUIDE.md) – Full setup commands
- [docs/DEMO.md](docs/DEMO.md) – Step-by-step live demo script

### Demo Flow (5 steps)

1. **Oracle** – Run SQL scripts 01→06 in `oracle-database/` to enable XStream and create outbound server  
2. **VM** – Install Docker, extract Oracle Instant Client to `/opt/oracle/instantclient/instantclient_19_30`  
3. **Connector** – Copy `docker/xstream-connector-docker.json.example` → `xstream-connector/oracle-xstream-rac-docker.json` and set credentials  
4. **Start** – Run `./docker/scripts/start-docker-cluster.sh`, `precreate-topics.sh`, `complete-migration-on-vm.sh`  
5. **Verify** – Insert into `ORDERMGMT.MTX_TRANSACTION_ITEMS`, consume from Kafka topic `racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS`

---

## Project Structure

```
oracle-xstream-cdc-poc/
├── README.md
├── docker/                         # 3-broker Kafka cluster (primary)
│   ├── docker-compose.yml
│   ├── Dockerfile.connect
│   ├── .env.example
│   ├── xstream-connector-docker.json.example
│   └── scripts/
│       ├── start-docker-cluster.sh
│       ├── stop-docker-cluster.sh
│       ├── precreate-topics.sh
│       ├── deploy-connector.sh
│       ├── complete-migration-on-vm.sh
│       ├── increase-rf-to-3.sh
│       └── install-docker.sh
├── oracle-database/                # SQL scripts (run 01→14 in order)
├── xstream-connector/              # Connector config (oracle-xstream-rac-docker.json)
├── troubleshooting/
│   └── TROUBLESHOOTING.md
├── screenshots/
└── docs/
    ├── IMPLEMENTATION-GUIDE.md
    ├── EXECUTION-GUIDE.md
    └── DEMO.md
```

---

## Oracle Database

The Oracle RAC database must have XStream enabled and the outbound server configured. Run the SQL scripts in [oracle-database/](oracle-database/) **in order** (01 → 14).

### Prerequisites

| Requirement | Check |
|-------------|-------|
| Oracle 19c/21c Enterprise/Standard | `SELECT * FROM v$version;` |
| ARCHIVELOG mode | `SELECT LOG_MODE FROM V$DATABASE;` |
| XStream enabled | `SELECT VALUE FROM V$PARAMETER WHERE NAME = 'enable_goldengate_replication';` |

### Script Execution Order

| # | Script | Purpose |
|---|--------|---------|
| 01 | `01-create-sample-schema.sql` | ORDERMGMT schema and tables |
| 02 | `02-enable-xstream.sql` | Enable XStream replication |
| 03 | `03-supplemental-logging.sql` | Supplemental logging |
| 04 | `04-create-xstream-users.sql` | XStream admin and connect users |
| 05 | `05-load-sample-data.sql` | Sample data |
| 06 | `06-create-outbound-ordermgmt.sql` | XStream Out outbound server |
| 07–14 | See [oracle-database/README.md](oracle-database/README.md) | Verification, teardown, onboarding |

---

## Demo: End-to-End Flow

### 1. Insert Data into Oracle

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

### 2. Consume from Kafka (after 10–30 seconds)

```bash
docker exec kafka2 kafka-console-consumer \
  --bootstrap-server kafka1:29092,kafka2:29092,kafka3:29092 \
  --topic racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS \
  --from-beginning --max-messages 5
```

Expected: Debezium JSON with `"op":"c"` (create/INSERT), `"after"` with row data.

---

## Troubleshooting

See [troubleshooting/TROUBLESHOOTING.md](troubleshooting/TROUBLESHOOTING.md). Summary:

| Issue | Fix |
|-------|-----|
| **Connection reset on deploy** | Wait 60s after cluster start; ensure Oracle JARs in connector lib |
| **No suitable driver (OCI)** | Verify `LD_LIBRARY_PATH`, `ojdbc8.jar`, `xstreams.jar` in connector plugin |
| **ORA-12514 / service name** | Re-query `gv$SERVICES` for `network_name`, update `database.service.name` (escape `$` as `\\$`) |
| **Connection to node 1/3 could not be established** | Use `kafka1:29092,kafka2:29092,kafka3:29092` for bootstrap (not localhost) |

### Status Commands

```bash
# Containers
docker ps --format '{{.Names}}: {{.Status}}' | grep -E 'kafka|connect|schema'

# Connector
curl -s http://localhost:8083/connectors/oracle-xstream-rac-connector/status | jq .

# Topics
docker exec kafka2 kafka-topics --bootstrap-server kafka1:29092,kafka2:29092,kafka3:29092 --list | grep racdb
```

---

## Prerequisites

- **Docker** and Docker Compose
- **Oracle Instant Client** (Basic + SQL*Plus) on host at path in `docker/.env`
- **Oracle RAC** 19c/21c, ARCHIVELOG, XStream enabled
- **VM** – Oracle Linux 9, 4+ OCPUs, 16+ GB RAM recommended

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).

**Note:** The Oracle XStream CDC connector is a Confluent Premium connector. A 30-day trial is available for POC.

---

## References

- [Confluent Oracle XStream CDC Connector](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/overview.html)
- [Oracle XStream Out Configuration](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/configuring-xstream-out.html)
