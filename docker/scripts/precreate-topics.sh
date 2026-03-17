#!/bin/bash
# Pre-create CDC topics on 3-broker cluster (replication factor 3)
# Run from project root: ./docker/scripts/precreate-topics.sh

set -e

BOOTSTRAP="localhost:9092"
KAFKA_TOPICS="docker exec kafka1 kafka-topics"
# Alternative if kafka-topics not in PATH: docker exec kafka1 /usr/bin/kafka-topics

echo "Pre-creating CDC topics (replication-factor=3)..."

for topic in __orcl-schema-changes.racdb __cflt-oracle-heartbeat.racdb \
  racdb.ORDERMGMT.REGIONS racdb.ORDERMGMT.COUNTRIES racdb.ORDERMGMT.LOCATIONS \
  racdb.ORDERMGMT.WAREHOUSES racdb.ORDERMGMT.EMPLOYEES racdb.ORDERMGMT.PRODUCT_CATEGORIES \
  racdb.ORDERMGMT.PRODUCTS racdb.ORDERMGMT.CUSTOMERS racdb.ORDERMGMT.CONTACTS \
  racdb.ORDERMGMT.ORDERS racdb.ORDERMGMT.ORDER_ITEMS racdb.ORDERMGMT.INVENTORIES \
  racdb.ORDERMGMT.NOTES racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS \
  racdb.XSTRPDB.ORDERMGMT.REGIONS racdb.XSTRPDB.ORDERMGMT.MTX_TRANSACTION_ITEMS; do
  $KAFKA_TOPICS --bootstrap-server $BOOTSTRAP --create --if-not-exists \
    --topic "$topic" --partitions 1 --replication-factor 3 2>/dev/null || true
done

echo "Done."
