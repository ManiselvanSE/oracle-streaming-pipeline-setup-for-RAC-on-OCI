# Connector Configuration

This project uses the **Docker 3-broker cluster** with Kafka Connect REST API deployment.

## Setup

1. Copy the example config and set credentials:
   ```bash
   cp xstream-connector/oracle-xstream-rac-docker.json.example xstream-connector/oracle-xstream-rac-docker.json
   # Or: cp docker/xstream-connector-docker.json.example xstream-connector/oracle-xstream-rac-docker.json
   ```

2. Edit `oracle-xstream-rac-docker.json`:
   - `database.password` – c##cfltuser password
   - `database.hostname` – RAC SCAN hostname
   - `database.service.name` – from `SELECT network_name FROM gv$SERVICES WHERE NAME LIKE '%XOUT%';` (escape `$` as `\\$`)

3. Deploy: `./docker/scripts/complete-migration-on-vm.sh`

## Config Formats

| File | Use case |
|------|----------|
| `oracle-xstream-rac-docker.json.example` | Docker / REST API deployment (JSON) |
| `oracle-xstream-rac-connector.properties.example` | Standalone Connect (properties) |

Both examples include throughput-optimized settings (see [docs/PERFORMANCE-OPTIMIZATION.md](../docs/PERFORMANCE-OPTIMIZATION.md)).

## Snapshot Modes

| Mode | Use case |
|------|----------|
| `initial` | First run: full snapshot + streaming |
| `no_data` | Streaming only; requires schema history from prior run |
| `recovery` | Rebuild schema history when topic is missing/corrupt |
