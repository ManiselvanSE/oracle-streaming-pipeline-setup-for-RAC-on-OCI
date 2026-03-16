# Monitoring

Grafana, Prometheus, and Kafka Exporter for throughput and lag monitoring.

## Quick Start

```bash
# Install Grafana
./monitoring/scripts/install-grafana-docker.sh

# Install Prometheus + Kafka Exporter
./monitoring/scripts/install-prometheus-kafka-exporter.sh
```

## Documentation

| Doc | Purpose |
|-----|---------|
| [docs/GRAFANA-SETUP.md](docs/GRAFANA-SETUP.md) | Grafana installation and configuration |
| [docs/MONITORING-SETUP.md](docs/MONITORING-SETUP.md) | Prometheus, Kafka Exporter, dashboards |

## Ports

| Service | Port | URL |
|---------|------|-----|
| Grafana | 3000 | http://localhost:3000 |
| Prometheus | 9090 | http://localhost:9090 |
| Kafka Exporter | 9308 | http://localhost:9308/metrics |

Use SSH port forwarding to access from your local machine. See main [README](../README.md#port-forwarding).
