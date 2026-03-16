# Admin Commands

Scripts for starting, stopping, and managing the CDC pipeline.

## Start / Stop

| Script | Purpose |
|--------|---------|
| `start-confluent-standalone.sh` | Start full stack (Kafka + Schema Registry + Connect) |
| `stop-confluent-kraft.sh` | Stop all Confluent services |
| `restart-connect-only.sh` | Restart Connect only (Kafka must be running) |

## Setup

| Script | Purpose |
|--------|---------|
| `setup-vm.sh` | Initial VM setup (Confluent, Oracle client, connector) |
| `setup-from-scratch.sh` | Setup after teardown |
| `install-docker.sh` | Install Docker (optional, for monitoring) |

## Teardown

| Script | Purpose |
|--------|---------|
| `teardown-vm.sh` | Stop Confluent, delete connector, Kafka data |
| `teardown-all.sh` | Full teardown (DB + VM) |

## Utilities

| Script | Purpose |
|--------|---------|
| `check-kafka-topics.sh` | Verify CDC topics have data |
| `check-and-start-xstream.sh` | Check/start XStream capture on DB |
| `reset-oracle-xstream-connector.sh` | Full connector reset (recovery mode) |
| `verify-connectivity.sh` | Test RAC connectivity |

Run from project root: `./admin-commands/<script-name>`
