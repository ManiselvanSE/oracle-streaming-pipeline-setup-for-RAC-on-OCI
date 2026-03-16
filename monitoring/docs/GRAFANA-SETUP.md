# Grafana Setup via Docker

This document describes how to install and run Grafana on the Oracle XStream CDC POC VM using Docker.

## Overview

| Item | Value |
|------|-------|
| **Image** | `grafana/grafana-enterprise:latest` |
| **Port** | 3000 |
| **Data** | Docker volume `grafana-storage` (persistent) |
| **Default login** | admin / admin |

## Prerequisites

- Docker installed on the VM (see [admin-commands/install-docker.sh](../../admin-commands/install-docker.sh))
- VM accessible (e.g. `137.131.53.98` for mani-xstrm-vm)

## Installation

### Option 1: Run the install script (recommended)

```bash
cd /home/opc/oracle-xstream-cdc-poc
chmod +x monitoring/scripts/install-grafana-docker.sh
./monitoring/scripts/install-grafana-docker.sh
```

### Option 2: Manual Docker commands

```bash
# Create Docker volume for persistence
docker volume create grafana-storage

# Pull and run Grafana
docker run -d \
  --name grafana \
  --restart unless-stopped \
  -p 3000:3000 \
  -v grafana-storage:/var/lib/grafana \
  grafana/grafana-enterprise:latest
```

## Access

| Environment | URL |
|-------------|-----|
| **From VM** | http://localhost:3000 |
| **From local (SSH tunnel)** | http://localhost:3000 after: `ssh -i key.pem -L 3000:localhost:3000 opc@137.131.53.98` |
| **Direct (if firewall allows)** | http://137.131.53.98:3000 |

**First login:** admin / admin — you will be prompted to change the password.

## Configuration

### Environment variables (optional)

Override before running the script:

```bash
export GRAFANA_IMAGE=grafana/grafana-enterprise:11.0.0   # Pin version
export GRAFANA_PORT=3000
export GRAFANA_VOLUME=grafana-storage
./monitoring/scripts/install-grafana-docker.sh
```

### Data persistence

Grafana data (dashboards, datasources, users) is stored in the Docker volume `grafana-storage`. This survives container restarts and VM reboots.

## Common commands

```bash
# Check status
docker ps | grep grafana

# View logs
docker logs -f grafana

# Stop
docker stop grafana

# Start (after stop)
docker start grafana

# Restart
docker restart grafana

# Remove container (data in grafana-storage volume is preserved)
docker stop grafana && docker rm grafana
```

## Integrating with Kafka / CDC

To monitor Kafka and Kafka Connect from Grafana:

1. **Add Prometheus** – Expose JMX metrics from Kafka/Connect and scrape with Prometheus.
2. **Add Prometheus datasource** in Grafana: Configuration → Data Sources → Add Prometheus.
3. **Import dashboards** – Use community dashboards for Kafka (e.g. Confluent Kafka dashboard) or build custom ones.

Alternatively, use the [Grafana Kafka datasource plugin](https://grafana.com/grafana/plugins/grafana-kafka-datasource/) if available for your Grafana version.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Port 3000 in use | Set `GRAFANA_PORT=3001` and use that port |
| Permission denied / not writable | Use Docker volume (default) instead of bind mount |
| Container exits immediately | Check `docker logs grafana` for errors |
| Cannot access from browser | Use SSH tunnel: `ssh -L 3000:localhost:3000 opc@<vm-ip>` |

## References

- [Grafana Docker documentation](https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/)
- [Grafana Docker Hub](https://hub.docker.com/r/grafana/grafana-enterprise)
