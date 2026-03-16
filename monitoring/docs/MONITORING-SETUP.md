# Kafka Throughput Monitoring with Grafana, Prometheus & Kafka Exporter

This document describes how to set up throughput dashboards in Grafana for the Oracle XStream CDC POC, using Prometheus and Kafka Exporter.

## Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐     ┌─────────┐
│   Kafka     │────►│  Kafka Exporter  │────►│ Prometheus  │────►│ Grafana │
│ :9092       │     │  :9308 /metrics  │     │  :9090      │     │ :3000   │
└─────────────┘     └──────────────────┘     └─────────────┘     └─────────┘
```

- **Kafka Exporter** – Exposes Kafka metrics (throughput, lag, topic stats) in Prometheus format
- **Prometheus** – Scrapes metrics every 15s, stores for 7 days
- **Grafana** – Visualizes metrics via pre-built dashboards

## Prerequisites

- Docker installed on the VM
- Kafka running (localhost:9092)
- Grafana installed ([docs/GRAFANA-SETUP.md](GRAFANA-SETUP.md))

## Installation

### Step 1: Install Prometheus + Kafka Exporter

```bash
cd /home/opc/oracle-xstream-cdc-poc
chmod +x monitoring/scripts/install-prometheus-kafka-exporter.sh
./monitoring/scripts/install-prometheus-kafka-exporter.sh
```

This will:
- Start Kafka Exporter (connects to Kafka at localhost:9092)
- Start Prometheus (scrapes Kafka Exporter, 7-day retention)
- Connect Grafana to the monitoring network (if Grafana is running)

### Step 2: Add Prometheus as Grafana Datasource

1. Open Grafana: http://localhost:3000 (or via SSH tunnel)
2. Go to **Connections** → **Data sources** → **Add data source**
3. Select **Prometheus**
4. Set **URL** to one of:
   - `http://prometheus:9090` (if Grafana is on the same Docker network)
   - `http://host.docker.internal:9090` (Linux with host-gateway)
   - `http://localhost:9090` (if Grafana can reach host)
5. Click **Save & test** – should show "Data source is working"

### Step 3: Import Throughput Dashboard

1. Go to **Dashboards** → **Import**
2. Enter dashboard ID: **7589** (Kafka Exporter) or **23757** (alternative)
3. Click **Load**
4. Select **Prometheus** as the datasource
5. Click **Import**

## Dashboard IDs

| ID    | Name              | Description                    |
|-------|-------------------|--------------------------------|
| 7589  | Kafka Exporter    | Topic throughput, consumer lag |
| 23757 | Kafka Exporter    | Alternative layout            |
| 721   | Kafka Overview    | Broker metrics (needs JMX)     |

## Ports

| Service        | Port | URL                          |
|----------------|------|------------------------------|
| Grafana        | 3000 | http://localhost:3000         |
| Prometheus     | 9090 | http://localhost:9090        |
| Kafka Exporter | 9308 | http://localhost:9308/metrics |

## Configuration

### Environment Variables (install script)

```bash
export PROMETHEUS_PORT=9090
export KAFKA_EXPORTER_PORT=9308
export KAFKA_BOOTSTRAP=localhost:9092
./monitoring/scripts/install-prometheus-kafka-exporter.sh
```

### Prometheus Config

Edit `monitoring/config/prometheus.yml` to add more scrape targets or change the interval:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'kafka-exporter'
    static_configs:
      - targets: ['kafka-exporter:9308']
```

## Common Commands

```bash
# Check status
docker ps | grep -E 'prometheus|kafka-exporter'

# View Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq .

# View Kafka Exporter metrics
curl -s http://localhost:9308/metrics | head -50

# Restart Prometheus (after config change)
docker restart prometheus

# Stop monitoring
docker stop prometheus kafka-exporter
```

## Resource Usage

| Component       | Memory (approx) | Disk        |
|----------------|-----------------|-------------|
| Kafka Exporter | ~50–100 MB      | Minimal     |
| Prometheus     | ~500 MB–1 GB    | ~1–2 GB (7d)|

Total additional footprint: ~1–1.5 GB RAM. Suitable for the 11 GB VM.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Grafana "Data source is not working" | Use `http://localhost:9090` or ensure Grafana is on `monitoring-net` |
| Kafka Exporter "connection refused" | Ensure Kafka is running on 9092; check `KAFKA_BOOTSTRAP` |
| No data in dashboard | Verify Prometheus targets: http://localhost:9090/targets |
| Dashboard shows "No data" | Wait 1–2 minutes for first scrape; check topic has activity |

## References

- [Kafka Exporter](https://github.com/danielqsj/kafka_exporter)
- [Prometheus](https://prometheus.io/docs/)
- [Grafana Kafka Dashboards](https://grafana.com/grafana/dashboards/?search=kafka)
