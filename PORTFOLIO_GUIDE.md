# Portfolio & Project Guide

This repository is a hands-on reference implementation for streaming Oracle RAC change data into Kafka using Oracle XStream and Confluent Platform on Oracle Cloud Infrastructure (OCI).

## Start here

- [Project README](README.md) — overview, architecture, prerequisites, quick start, demo, and troubleshooting.
- [Architecture](docs/ARCHITECTURE.md) — components and network flow.
- [Implementation guide](docs/IMPLEMENTATION-GUIDE.md) — end-to-end setup.
- [Execution guide](docs/EXECUTION-GUIDE.md) — command-oriented setup reference.
- [Validation](docs/VALIDATION.md) — verify Oracle RAC and connector health.
- [Troubleshooting](troubleshooting/TROUBLESHOOTING.md) — common failures and diagnostic steps.

## Optional deep dives

- [Performance optimization](docs/PERFORMANCE-OPTIMIZATION.md)
- [Load testing](load-testing/README.md)
- [Monitoring](monitoring/README.md)
- [Demo script](docs/DEMO.md)
- [OCI VM setup](docs/OCI-VM-SETUP.md)
- [OCI DB System setup](docs/OCI-DB-SYSTEM-SETUP.md)

## End-to-end flow

1. Oracle RAC generates redo for database changes.
2. XStream Out exposes logical change records (LCRs).
3. The Oracle XStream CDC connector reads changes through Kafka Connect.
4. Kafka topics make CDC events available to downstream consumers.
5. Optional Prometheus and Grafana components support operational monitoring.

## Safety and reproducibility

- Use example configuration files as templates and provide secrets locally.
- Do not commit real API keys, database passwords, private keys, or cloud credentials.
- Review cloud resources and estimated costs before deploying; destroy test resources when finished.
- Treat throughput numbers as environment-specific benchmarks, not universal guarantees. Record hardware, configuration, workload, and measurement method when publishing results.

## Related repositories

This project focuses on Oracle RAC on OCI with a self-managed Kafka/connector environment. Other related labs may cover different deployment targets or managed Confluent Cloud; keep their scopes distinct and cross-link only where the workflows genuinely differ.
