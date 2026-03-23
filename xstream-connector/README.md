# Connector Configuration

This project uses the **Docker 3-broker cluster** with Kafka Connect REST API deployment.

## Setup

1. Edit `xstream-connector/oracle-xstream-rac-docker.json`:
   - `database.password` – c##cfltuser password
   - `database.hostname` – RAC SCAN hostname
   - `database.service.name` – from `SELECT network_name FROM gv$SERVICES WHERE NAME LIKE '%XOUT%';` (escape `$` as `\\$`)

2. Deploy: `./docker/scripts/complete-migration-on-vm.sh`

## Config Formats

| File | Use case |
|------|----------|
| `oracle-xstream-rac-docker.json` | Docker / REST API deployment (JSON) |
| `oracle-xstream-rac-connector.properties.example` | Standalone Connect (properties) |

Both examples include throughput-optimized settings (see [docs/PERFORMANCE-OPTIMIZATION.md](../docs/PERFORMANCE-OPTIMIZATION.md)).

## Snapshot Modes

| Mode | Use case |
|------|----------|
| `initial` | First run: full snapshot + streaming |
| `no_data` | Streaming only; requires schema history from prior run |
| `recovery` | Rebuild schema history when topic is missing/corrupt |
